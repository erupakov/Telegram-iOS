import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import DivoCore

// DIVO: «Настройки → Конфиденциальность и безопасность → Заблокированные» — список из POST /user/blocked
// с разблокировкой через POST /user/unblock (вместо MTProto-блоклиста Telegram). Отдельный файл —
// минимизируем диф в апстрим-контроллере.

/// Число заблокированных для подписи пункта в «Конфиденциальность и безопасность»: сразу кэш,
/// затем загрузка списка и обновления по `DivoBlockedUsers.didChangeNotification`.
func divoBlockedUsersCountSignal() -> Signal<Int?, NoError> {
    return Signal { subscriber in
        subscriber.putNext(DivoBlockedUsers.cachedCount)
        let observer = NotificationCenter.default.addObserver(
            forName: DivoBlockedUsers.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            subscriber.putNext(DivoBlockedUsers.cachedCount)
        }
        let task = Task {
            do {
                try await DivoBlockedUsers.fetch()
            } catch {
                divoLog("[BLOCK] POST /user/blocked failed: \(error)", level: .warning)
            }
        }
        return ActionDisposable {
            task.cancel()
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

private final class DivoBlockedUsersControllerArguments {
    let unblock: (DivoBlockedUser) -> Void
    let retry: () -> Void

    init(unblock: @escaping (DivoBlockedUser) -> Void, retry: @escaping () -> Void) {
        self.unblock = unblock
        self.retry = retry
    }
}

private enum DivoBlockedUsersSection: Int32 {
    case users
}

private enum DivoBlockedUsersEntry: ItemListNodeEntry {
    case user(index: Int, user: DivoBlockedUser, isUnblocking: Bool)
    case empty(String)
    case failed(String)
    case retry(String)

    var section: ItemListSectionId {
        return DivoBlockedUsersSection.users.rawValue
    }

    var stableId: Int {
        switch self {
        case let .user(_, user, _):
            return user.id
        case .empty:
            return -1
        case .failed:
            return -2
        case .retry:
            return -3
        }
    }

    private var sortIndex: Int {
        switch self {
        case let .user(index, _, _):
            return index
        case .empty, .failed:
            return -2
        case .retry:
            return -1
        }
    }

    static func <(lhs: DivoBlockedUsersEntry, rhs: DivoBlockedUsersEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DivoBlockedUsersControllerArguments
        switch self {
        case let .user(_, user, isUnblocking):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: user.displayName,
                enabled: !isUnblocking,
                label: DivoStrings.unblock,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: {
                    arguments.unblock(user)
                }
            )
        case let .empty(text), let .failed(text):
            return ItemListPlaceholderItem(theme: presentationData.theme, text: text, sectionId: self.section, style: .blocks)
        case let .retry(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.retry()
            })
        }
    }
}

private enum DivoBlockedUsersLoadState: Equatable {
    case loading
    case loaded([DivoBlockedUser])
    case failed
}

private struct DivoBlockedUsersState: Equatable {
    var load: DivoBlockedUsersLoadState = .loading
    var unblockingIds: Set<Int> = []
}

private func divoBlockedUsersEntries(state: DivoBlockedUsersState) -> [DivoBlockedUsersEntry] {
    switch state.load {
    case .loading:
        return []
    case .failed:
        return [.failed(DivoStrings.blockedUsersLoadFailed), .retry(DivoStrings.retry)]
    case let .loaded(users):
        if users.isEmpty {
            return [.empty(DivoStrings.blockedUsersEmpty)]
        }
        return users.enumerated().map { index, user in
            .user(index: index, user: user, isUnblocking: state.unblockingIds.contains(user.id))
        }
    }
}

private final class DivoWeakControllerRef {
    weak var controller: ViewController?
}

func divoBlockedUsersController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(DivoBlockedUsersState(), ignoreRepeated: true)
    let stateValue = Atomic(value: DivoBlockedUsersState())
    let updateState: ((inout DivoBlockedUsersState) -> Void) -> Void = { f in
        statePromise.set(stateValue.modify { current in
            var updated = current
            f(&updated)
            return updated
        })
    }

    // Не `var`-замыкание: его захватывают Task-замыкания (concurrently-executing code).
    let controllerRef = DivoWeakControllerRef()
    let presentController: (ViewController) -> Void = { c in
        controllerRef.controller?.present(c, in: .window(.root))
    }

    let load: () -> Void = {
        updateState { $0.load = .loading }
        Task {
            do {
                let users = try await DivoBlockedUsers.fetch()
                await MainActor.run {
                    updateState { $0.load = .loaded(users) }
                }
            } catch {
                divoLog("[BLOCK] POST /user/blocked failed: \(error)", level: .warning)
                await MainActor.run {
                    updateState { $0.load = .failed }
                }
            }
        }
    }

    let performUnblock: (DivoBlockedUser) -> Void = { user in
        updateState { $0.unblockingIds.insert(user.id) }
        Task {
            do {
                try await DivoBlockedUsers.unblock(userId: user.id)
                await MainActor.run {
                    updateState { state in
                        state.unblockingIds.remove(user.id)
                        if case let .loaded(users) = state.load {
                            state.load = .loaded(users.filter { $0.id != user.id })
                        }
                    }
                }
            } catch {
                divoLog("[BLOCK] POST /user/unblock failed: \(error)", level: .warning)
                await MainActor.run {
                    updateState { $0.unblockingIds.remove(user.id) }
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    presentController(textAlertController(context: context, title: nil, text: DivoStrings.unblockUserFailed, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
                }
            }
        }
    }

    let arguments = DivoBlockedUsersControllerArguments(
        unblock: { user in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentController(textAlertController(
                context: context,
                title: DivoStrings.unblockUser,
                text: "\(user.displayName)\n\n\(DivoStrings.unblockUserConfirmMessage)",
                actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .defaultAction, title: DivoStrings.unblock, action: {
                        performUnblock(user)
                    })
                ]
            ))
        },
        retry: {
            load()
        }
    )

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let emptyStateItem: ItemListControllerEmptyStateItem?
        if case .loading = state.load {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        } else {
            emptyStateItem = nil
        }
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(DivoStrings.blockedUsersTitle),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: divoBlockedUsersEntries(state: state),
            style: .blocks,
            emptyStateItem: emptyStateItem,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controllerRef.controller = controller

    load()
    return controller
}
