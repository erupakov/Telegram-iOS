import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import DivoCore
import MessageUI
import TelegramPresentationData
import AccountContext
import ShareController
import AlertUI
import PresentationDataUtils
import SearchUI
import LegacyMediaPickerUI
import CountrySelectionUI
import ChatScheduleTimeController
import DivoUIKit

protocol EditSocialLinksDelegate: AnyObject {
    func didUpdateSocialLinksData()
}

public class EditSocialLinksController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext

    private var editSocialLinksNode: EditSocialLinksNode {
        return self.displayNode as! EditSocialLinksNode
    }

    private var presentationData: PresentationData
    private var presentationDataDisposable: Any?
    private var linksData: LinksData
    // nil — режим model (legacy model.*Url через /user/update-profile);
    // не nil — режим agency: поля из справочника /social-network, запись в /user-social-network
    private let agencyNetworks: [UserSocialNetwork]?
    private var socialNetworksDictionary: [SocialNetworkItem] = []
    // Профиль агентства: сайт живёт в agency.site и пишется через /agency/update (не /user-social-network)
    private let agencyDetail: UserDetail?
    // id поля «Сайт» агентства — отрицательный, не пересекается с socialNetworkId справочника
    private static let agencySiteFieldId = -100

    // Отрицательные id model-полей, чтобы не пересекаться с socialNetworkId справочника
    private enum ModelField: Int {
        case instagram = -1
        case tiktok = -2
        case youtube = -3
        case website = -4
    }

    weak var delegate: EditSocialLinksDelegate?

    public init(context: AccountContext, presentationData: PresentationData, linksData: LinksData, agencyNetworks: [UserSocialNetwork]? = nil, agencyDetail: UserDetail? = nil) {
        self.context = context
        self.linksData = linksData
        self.agencyNetworks = agencyNetworks
        self.agencyDetail = agencyDetail

        self.presentationData = presentationData

        super.init(navigationBarPresentationData: nil)

        self.presentationDataDisposable = (context.sharedContext.presentationData
                                           |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            self?.presentationData = presentationData
        })
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        (self.presentationDataDisposable as? Disposable)?.dispose()
    }

    override public func loadDisplayNode() {

        self.displayNode = EditSocialLinksNode(
            context: self.context,
            presentationData: self.presentationData
        )

        self.editSocialLinksNode.onSave = { [weak self] texts, changedIds in
            guard let self else { return }
            if self.agencyNetworks != nil {
                self.saveAgencySocialLinks(texts: texts, changedIds: changedIds)
            } else {
                self.saveModelSocialLinks(texts: texts)
            }
        }

        self.editSocialLinksNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        self.displayNodeDidLoad()

        if self.agencyNetworks != nil {
            self.loadSocialNetworksDictionary()
        } else {
            self.editSocialLinksNode.setFields(self.modelFieldSpecs())
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
    }

    // MARK: - Поля

    private func modelFieldSpecs() -> [SocialLinkFieldSpec] {
        return [
            SocialLinkFieldSpec(id: ModelField.instagram.rawValue, prefix: "instagram.com/", placeholder: nil, initialText: linksData.instagramUrl ?? ""),
            SocialLinkFieldSpec(id: ModelField.tiktok.rawValue, prefix: "tiktok.com/", placeholder: nil, initialText: linksData.tiktokUrl ?? ""),
            SocialLinkFieldSpec(id: ModelField.youtube.rawValue, prefix: "youtube.com/", placeholder: nil, initialText: linksData.youtubeUrl ?? ""),
            SocialLinkFieldSpec(id: ModelField.website.rawValue, prefix: "", placeholder: DivoStrings.enterYourWebsite, initialText: linksData.websiteUrl ?? "")
        ]
    }

    /// Сети для полей агентства: справочник /social-network + уже сохранённые соцсети, которых в справочнике
    /// нет (иначе добавленная ссылка пропадала с экрана правки и её нельзя было ни увидеть, ни удалить).
    private var agencyNetworkItems: [SocialNetworkItem] {
        var items = socialNetworksDictionary
        var knownIds = Set(items.compactMap { $0.id })
        for saved in agencyNetworks ?? [] {
            guard let network = saved.socialNetwork, let id = network.id, !knownIds.contains(id) else { continue }
            knownIds.insert(id)
            items.append(network)
        }
        return items
    }

    private func agencyFieldSpecs() -> [SocialLinkFieldSpec] {
        var specs: [SocialLinkFieldSpec] = [
            SocialLinkFieldSpec(
                id: Self.agencySiteFieldId,
                prefix: "",
                placeholder: DivoStrings.enterYourWebsite,
                initialText: agencyDetail?.agency?.site ?? ""
            )
        ]
        specs += agencyNetworkItems.compactMap { network in
            guard let networkId = network.id else { return nil }
            let prefix = Self.urlPrefix(for: network.provider)
            let existing = self.existingNetwork(forId: networkId)
            let initialText: String
            if prefix.isEmpty {
                initialText = existing?.link ?? existing?.nickname ?? ""
            } else {
                initialText = existing?.nickname ?? Self.lastPathComponent(of: existing?.link)
            }
            return SocialLinkFieldSpec(
                id: networkId,
                prefix: prefix,
                placeholder: prefix.isEmpty ? network.name : nil,
                initialText: initialText
            )
        }
        return specs
    }

    private func existingNetwork(forId networkId: Int) -> UserSocialNetwork? {
        return agencyNetworks?.first { $0.socialNetwork?.id == networkId }
    }

    private func loadSocialNetworksDictionary() {
        self.editSocialLinksNode.setFieldsLoading(true)
        Task { @MainActor in
            do {
                let response: SocialNetworkListResponse = try await DivoAPIClient.shared.request(
                    path: "/social-network",
                    method: "GET"
                )
                self.socialNetworksDictionary = response.data ?? []
                self.editSocialLinksNode.setFieldsLoading(false)
                self.editSocialLinksNode.setFields(self.agencyFieldSpecs())
            } catch {
                // Hardcoded-список сетей не подставляем: без справочника поля не строим, даём Retry
                self.editSocialLinksNode.setFieldsLoading(false)
                let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.failedToLoadSocialNetworks
                self.editSocialLinksNode.showSnackbar(
                    message: userMsg,
                    style: .error,
                    retryAction: { [weak self] in
                        self?.loadSocialNetworksDictionary()
                    },
                    persistent: true
                )
            }
        }
    }

    // MARK: - Сохранение

    private func saveModelSocialLinks(texts: [Int: String]) {
        Task { @MainActor in
            do {
                let request = UpdateSocialLinksRequest(
                    model: UpdateSocialLinksRequest.ModelData(
                        tiktokUrl: Self.constructFullURL(from: texts[ModelField.tiktok.rawValue] ?? "", with: "tiktok.com/") ?? "",
                        youtubeUrl: Self.constructFullURL(from: texts[ModelField.youtube.rawValue] ?? "", with: "youtube.com/") ?? "",
                        telegramUrl: "",
                        instagramUrl: Self.constructFullURL(from: texts[ModelField.instagram.rawValue] ?? "", with: "instagram.com/") ?? "",
                        websiteUrl: Self.constructFullURL(from: texts[ModelField.website.rawValue] ?? "", with: "") ?? ""
                    )
                )

                let _: UpdateSocialLinksResponse = try await DivoAPIClient.shared.request(
                    path: "/user/update-profile",
                    method: "POST",
                    body: request
                )

                divoTrack(.socialLinksSaved)
                self.delegate?.didUpdateSocialLinksData()
                self.navigationController?.popViewController(animated: true)

            } catch {
                self.handleSaveError(error)
            }
        }
    }

    private func saveAgencySocialLinks(texts: [Int: String], changedIds: Set<Int>) {
        Task { @MainActor in
            do {
                if changedIds.contains(Self.agencySiteFieldId) {
                    try await self.saveAgencySite(text: texts[Self.agencySiteFieldId] ?? "")
                }
                for network in self.agencyNetworkItems {
                    guard let networkId = network.id, changedIds.contains(networkId) else { continue }

                    let text = texts[networkId] ?? ""
                    let prefix = Self.urlPrefix(for: network.provider)

                    if let link = Self.constructFullURL(from: text, with: prefix) {
                        let request = UserSocialNetworkUpsertRequest(
                            socialNetworkId: networkId,
                            nickname: Self.lastPathComponent(of: link),
                            link: link
                        )
                        let _: UserSocialNetworkMutationResponse = try await DivoAPIClient.shared.request(
                            path: "/user-social-network/upsert",
                            method: "POST",
                            body: request
                        )
                    } else if let recordId = self.existingNetwork(forId: networkId)?.id {
                        // Поле очистили — удаляем сохранённую соцсеть
                        let _: UserSocialNetworkMutationResponse = try await DivoAPIClient.shared.request(
                            path: "/user-social-network/\(recordId)",
                            method: "DELETE"
                        )
                    }
                }

                divoTrack(.socialLinksSaved)
                self.delegate?.didUpdateSocialLinksData()
                self.navigationController?.popViewController(animated: true)

            } catch {
                self.handleSaveError(error)
            }
        }
    }

    /// Сайт агентства → /agency/update. Бэк делает replace, поэтому остальные поля агентства пересылаем
    /// из текущего профиля (как EditProfileController); пустой сайт уходит явным null.
    private func saveAgencySite(text: String) async throws {
        let agency = self.agencyDetail?.agency
        let request = UpdateDescriptionAgencyRequest(
            agencyId: agency?.id,
            title: agency?.title,
            site: Self.constructFullURL(from: text, with: ""),
            description: agency?.description,
            background: agency?.background?.fileUuid.map { UpdateDescriptionAgencyRequest.AvatarUuid(uuid: $0) },
            photo: agency?.photo?.fileUuid.map { UpdateDescriptionAgencyRequest.AvatarUuid(uuid: $0) },
            // Без города address не шлём: {"cityId": null} при replace затёр бы город на беке
            address: (agency?.address?.city?.id).map { UpdateAgencyAddress(cityId: $0) }
        )
        let _: UpdateDescriptionAgencyResponse = try await DivoAPIClient.shared.request(
            path: "/agency/update",
            method: "POST",
            body: request
        )
    }

    private func handleSaveError(_ error: Error) {
        divoLog("Error saving social links: \(error)", level: .error)
        self.editSocialLinksNode.toggleSaving(active: false)
        let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.failedLinksUpdated
        self.editSocialLinksNode.showSnackbar(
            message: userMsg,
            style: .error
        )
    }

    // MARK: - URL helpers

    private static func urlPrefix(for provider: String?) -> String {
        switch provider {
        case "instagram": return "instagram.com/"
        case "facebook": return "facebook.com/"
        case "tiktok": return "tiktok.com/"
        case "youtube": return "youtube.com/"
        default: return ""
        }
    }

    private static func lastPathComponent(of link: String?) -> String {
        guard let link, !link.isEmpty else { return "" }
        return link.split(separator: "/").last.map(String.init) ?? ""
    }

    private static func constructFullURL(from handle: String, with prefix: String) -> String? {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let plainHandle = trimmed
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")

        var userPath = plainHandle
        if !prefix.isEmpty {
            let cleanPrefix = prefix.replacingOccurrences(of: "/", with: "")
            userPath = plainHandle.replacingOccurrences(of: cleanPrefix, with: "")
        }

        let cleanedPath = userPath.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if cleanedPath.isEmpty { return nil }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") { return trimmed }
        return "https://\(trimmed)"
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.editSocialLinksNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

}
