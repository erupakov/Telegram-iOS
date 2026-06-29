import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import DivoCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import TelegramBaseController
import DivoUIKit
import DivoGallery

public struct EventPreviewData {
    public let request: CreateEventPreview
    public let coverImage: UIImage?
    public let gallery: [UserPhoto]
}

public final class EventDetailController: TelegramBaseController {

    private var controllerNode: EventDetailControllerNode {
        return self.displayNode as! EventDetailControllerNode
    }

    private let getEventDisposable = MetaDisposable()
    private var eventId: Int?
    private var eventData: EventFullDetailData?
    private let context: AccountContext
    private let isMyEvent: Bool?
    private let isAgency: Bool?
    
    // Массив для хранения распарсенных фотографий галереи
    internal var currentGalleryPhotos: [UserPhoto] = []
    private weak var activeGalleryController: ProfileGalleryController?

    // Свойства для Preview режима
    private let isPreviewMode: Bool
    private let previewData: EventPreviewData?
    public var onPublishConfirmed: (() -> Void)?
    public var onEventModified: (() -> Void)?

    public init(
        context: AccountContext,
        eventId: Int? = nil,
        isMyEvent: Bool? = nil,
        isPreviewMode: Bool = false,
        previewData: EventPreviewData? = nil,
        isAgency: Bool? = nil
    ) {
        self.context = context
        self.eventId = eventId
        self.isMyEvent = isMyEvent
        self.isPreviewMode = isPreviewMode
        self.previewData = previewData
        self.isAgency = isAgency

        super.init(context: context, navigationBarPresentationData: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleGlobalEventCreated),
            name: DivoConfig.divoEventCreated,
            object: nil
        )
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.getEventDisposable.dispose()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
    }

    override public func loadDisplayNode() {
        self.displayNode = EventDetailControllerNode(
            context: self.context,
            isMyEvent: self.isMyEvent ?? false,
            isPreviewMode: self.isPreviewMode,
            isAgency: self.isAgency ?? false
        )
        
        // Перехватываем действия из кастомного навбара
        self.controllerNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.controllerNode.onShareTapped = {[weak self] in
            self?.sharePressed()
        }
        
        self.controllerNode.onBookmarkTapped = {[weak self] in
            self?.bookmarkPressed()
        }
        
        self.controllerNode.onApplyTapped = {[weak self] in
            self?.applyPressed()
        }
        
        self.controllerNode.onGalleryItemTapped = { [weak self] fileUuid in
            self?.openFullScreenGallery(for: fileUuid)
        }
        
        self.controllerNode.onEditPreviewTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        self.controllerNode.onPublishPreviewTapped = { [weak self] in
            self?.onPublishConfirmed?()
        }

        self.controllerNode.onEditEventTapped = { [weak self] in
            self?.navigateToEditEvent()
        }
        
        self.controllerNode.onDeleteTapped = { [weak self] in
            self?.performDeleteEvent()
        }

        self.controllerNode.onRetryTapped = { [weak self] in
            guard let self = self else { return }
            self.controllerNode.resetToLoading()
            self.getEvent()
        }

        self.controllerNode.onWithdrawTapped = { [weak self] in
            self?.presentWithdrawConfirmationSheet()
        }

        self.controllerNode.onViewApplicationsTapped = { [weak self] in
            self?.viewApplicationsPressed()
        }

        self.displayNodeDidLoad()

        if isPreviewMode {
            loadPreview()
        } else {
            if let eventId = self.eventId {
                divoTrack(.eventDetailsViewed(eventId: Int64(eventId)))
            }
            getEvent()
        }
    }

    private func presentWithdrawConfirmationSheet() {
        let theme = ActionSheetControllerTheme(
            dimColor: UIColor(white: 0, alpha: 0.5),
            backgroundType: .light,
            itemBackgroundColor: DivoColorPalette.cardBackground,
            itemHighlightedBackgroundColor: DivoColorPalette.screenBackground,
            standardActionTextColor: DivoColorPalette.primaryText,
            destructiveActionTextColor: DivoColorPalette.accent,
            disabledActionTextColor: DivoColorPalette.disabledText,
            primaryTextColor: DivoColorPalette.primaryText,
            secondaryTextColor: DivoColorPalette.secondaryText,
            controlAccentColor: DivoColorPalette.accent,
            controlColor: DivoColorPalette.secondaryText,
            switchFrameColor: DivoColorPalette.separatorSystem,
            switchContentColor: DivoColorPalette.accent,
            switchHandleColor: DivoColorPalette.cardBackground,
            baseFontSize: 17.0
        )
        let actionSheet = ActionSheetController(theme: theme)
        
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                DivoActionSheetHeaderItem(
                    title: DivoStrings.withdrawSheetTitle,
                    subtitle: DivoStrings.withdrawSheetSubtitle
                ),
                ActionSheetButtonItem(title: DivoStrings.keepApplication, color: .destructive) { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                }
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: DivoStrings.withdrawConfirm, color: .accent, font: .bold) { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    self?.withdrawApplication()
                }
            ])
        ])
        
        self.present(actionSheet, in: .window(.root))
    }
    
    private func withdrawApplication() {
        guard let eventId = self.eventId else { return }
        
        self.controllerNode.toggleWithdrawLoading(active: true)
        let body = ApplyEventRequest(eventId: eventId)
        
        Task {
            do {
                let _: ApplyEventResponse = try await DivoAPIClient.shared.request(
                    path: "/event/unapply",
                    method: "POST",
                    body: body
                )
                
                await MainActor.run {
                    self.controllerNode.toggleWithdrawLoading(active: false)
                    self.getEvent()
                    self.onEventModified?()
                }
            } catch {
                await MainActor.run {
                    self.controllerNode.toggleWithdrawLoading(active: false)
                    let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.withdrawApplicationFail
                    self.controllerNode.showSnackbar(message: userMsg, style: .error)
                }
            }
        }
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    public func toggleSaving(active: Bool) {
        self.controllerNode.toggleSaving(active: active)
    }
    
    public func showSnackbar(message: String) {
        self.controllerNode.showSnackbar(message: message, style: .error)
    }

    private func loadPreview() {
        guard let data = previewData else { return }
        self.controllerNode.updateWithPreviewData(data)
    }

    private func getEvent() {
        guard let eventId = eventId else { return }
        Task {
            do {
                let response: EventFullDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/event/\(eventId)"
                )
                guard let item = response.data else { return }
                
                // Парсим файлы галереи
                if let files = item.files {
                    let sortedFiles = files.sorted {
                        guard let order1 = $0.order else { return false }
                        guard let order2 = $1.order else { return true }
                        return order1 < order2
                    }
                    // Фильтруем обложку (обычно order == 0) и конвертируем остальные фото в UserPhoto
                    self.currentGalleryPhotos = sortedFiles.filter { $0.order != 0 }.compactMap { file in
                        guard let uuid = file.fileUuid,
                              let fileExtension = file.fileExtension,
                              let fullUrl = file.fullUrl,
                              let fileName = file.fileName
                        else { return nil }
                        
                        let userFile = UserFile(
                            fileName: fileName,
                            fullUrl: fullUrl,
                            fileExtension: fileExtension,
                            fileUuid: uuid
                        )
                        return UserPhoto(
                            id: abs(file.fileUuid.hashValue),
                            photo: userFile,
                            likesCount: 0,
                            isLikedByUser: false,
                            preview: nil
                        )
                    }
                }
                
                await MainActor.run {
                    self.eventData = item
                    self.eventId = item.id
                    self.controllerNode.updateEventData(item)
                    self.controllerNode.updateGallery(self.currentGalleryPhotos) // Отдаем фото в Node
                }
            } catch {
                divoLog("[DivoAPI] event/\(eventId) error: \(error)", level: .error)
                await MainActor.run {
                    self.controllerNode.markFailed(networkError: self.isNetworkError(error))
                }
            }
        }
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if let apiError = error as? DivoAPIError, case .noInternetConnection = apiError {
            return true
        }
        return false
    }

    // Переход на экран редактирования
    private func navigateToEditEvent() {
        guard let eventId = self.eventId else { return }

        divoTrack(.eventEditStarted(eventId: Int64(eventId)))

        let editEventController = CreateEventController(context: self.context, mode: .edit(eventId: eventId))
        
        // Обновляем текущий экран после успешного редактирования и возврата
        editEventController.onEventCreated = { [weak self] in
            self?.getEvent()
            self?.onEventModified?()
        }
        
        self.push(editEventController)
    }
    
    private func performDeleteEvent() {
        guard let eventId = self.eventId else { return }
        
        Task { @MainActor in
            do {
                let _: DeleteEventResponse = try await DivoAPIClient.shared.request(
                    path: "/event/\(eventId)",
                    method: "DELETE"
                )

                divoTrack(.eventDeleted(eventId: Int64(eventId)))

                NotificationCenter.default.post(
                    name: DivoConfig.divoEventDeleted,
                    object: nil,
                    userInfo: ["eventId": eventId]
                )
                
                self.onEventModified?()
                self.navigationController?.popViewController(animated: true)
                
            } catch {
                let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.failedToDelete
                self.controllerNode.showSnackbar(
                    message: userMsg,
                    style: .error
                )
            }
        }
    }
    
    private func sharePressed() {
        guard !isPreviewMode, let eventId = eventId else { return }
        
        let shareURL = URL(string: "\(DivoConfig.shareBaseURL)/event/\(eventId)")!
        let shareItem = DivoShareItemSource(
            url: shareURL,
            title: eventData?.title ?? "",
            subtitle: eventData?.type?.title ?? "",
            image: controllerNode.coverImage
        )
        let activityVC = UIActivityViewController(activityItems: [shareItem], applicationActivities: nil)
        self.present(activityVC, animated: true)
    }

    private func bookmarkPressed() {
        // TODO DIVO: реализовать сохранение события в избранное (REST endpoint + состояние кнопки)
        divoLog("Bookmark button pressed")
    }

    private func applyPressed() {
        divoLog("Apply button pressed")
        guard let eventId = self.eventId, let eventData = self.eventData else { return }
        
        // Инициализируем новый контроллер подтверждения параметров
        let confirmationController = EventApplyConfirmationController(
            context: self.context,
            eventId: eventId,
            eventData: eventData
        )
        
        // При успешной отправке заявки обновляем текущий экран деталей
        confirmationController.onApplySuccess = { [weak self] in
            self?.getEvent()
            self?.onEventModified?()
        }
        
        // Пушим экран в стек навигации
        self.push(confirmationController)
    }
    
    // Открытие галереи на полный экран
    private func openFullScreenGallery(for uuid: String) {
        guard let initialIndex = self.currentGalleryPhotos.firstIndex(where: { $0.photo.fileUuid == uuid }) else { return }
        
        let galleryController = ProfileGalleryController(
            context: self.context,
            photos: self.currentGalleryPhotos,
            initialIndex: initialIndex,
            isVideoGallery: false,
            isOwnProfile: false,
            isLocalOnly: false
        )

        self.activeGalleryController = galleryController
        self.push(galleryController)
    }

    // Метод для перехода на новый экран списка заявок
    private func viewApplicationsPressed() {
        guard let eventId = self.eventId else { return }
        
        let listController = ApplicationsListController(
            context: self.context,
            eventId: eventId
        )
        
        self.push(listController)
    }

    @objc private func handleGlobalEventCreated() {
        self.getEvent()
        self.onEventModified?()
    }
}
