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
    // не nil — режим agency: ссылки — плоские поля агентства (/agency/{id}), запись — /agency/update.
    private let agencyId: Int?
    private var agencyDetail: AgencyDetailData?

    // Поля агентства. Отрицательные id — не пересекаются с model-полями.
    private enum AgencyField: Int, CaseIterable {
        case instagram = -11
        case tiktok = -12
        case youtube = -13
        case telegram = -14
        case website = -15

        var prefix: String {
            switch self {
            case .instagram: return "instagram.com/"
            case .tiktok: return "tiktok.com/"
            case .youtube: return "youtube.com/"
            case .telegram: return "t.me/"
            case .website: return ""
            }
        }

        var requestField: AgencyLinksUpdateRequest.Field {
            switch self {
            case .instagram: return .instagramUrl
            case .tiktok: return .tiktokUrl
            case .youtube: return .youtubeUrl
            case .telegram: return .telegramUrl
            case .website: return .websiteUrl
            }
        }
    }

    // Отрицательные id model-полей, чтобы не пересекаться с socialNetworkId справочника
    private enum ModelField: Int {
        case instagram = -1
        case tiktok = -2
        case youtube = -3
        case website = -4
    }

    weak var delegate: EditSocialLinksDelegate?

    public init(context: AccountContext, presentationData: PresentationData, linksData: LinksData, agencyId: Int? = nil) {
        self.context = context
        self.linksData = linksData
        self.agencyId = agencyId

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
            if self.agencyId != nil {
                self.saveAgencyLinks(texts: texts, changedIds: changedIds)
            } else {
                self.saveModelSocialLinks(texts: texts)
            }
        }

        self.editSocialLinksNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        self.displayNodeDidLoad()

        if self.agencyId != nil {
            self.loadAgencyLinks()
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

    private func agencyFieldSpecs() -> [SocialLinkFieldSpec] {
        let detail = self.agencyDetail
        return AgencyField.allCases.map { field in
            let current: String?
            switch field {
            case .instagram: current = detail?.instagramUrl
            case .tiktok: current = detail?.tiktokUrl
            case .youtube: current = detail?.youtubeUrl
            case .telegram: current = detail?.telegramUrl
            case .website: current = detail?.effectiveWebsite
            }
            return SocialLinkFieldSpec(
                id: field.rawValue,
                prefix: field.prefix,
                placeholder: field == .website ? DivoStrings.enterYourWebsite : nil,
                initialText: Self.handle(from: current, prefix: field.prefix)
            )
        }
    }

    private func loadAgencyLinks() {
        guard let agencyId = self.agencyId else { return }
        self.editSocialLinksNode.setFieldsLoading(true)
        Task { @MainActor in
            do {
                let response: AgencyDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/\(agencyId)",
                    method: "GET"
                )
                self.agencyDetail = response.data
                self.editSocialLinksNode.setFieldsLoading(false)
                self.editSocialLinksNode.setFields(self.agencyFieldSpecs())
            } catch {
                // Без текущих значений поля не строим (иначе сохранение затёрло бы ссылки) — даём Retry.
                self.editSocialLinksNode.setFieldsLoading(false)
                let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.failedToLoadSocialNetworks
                self.editSocialLinksNode.showSnackbar(
                    message: userMsg,
                    style: .error,
                    retryAction: { [weak self] in
                        self?.loadAgencyLinks()
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

    /// Частичный `/agency/update`: только изменённые ссылки (полный URL со схемой — бэк валидирует URL,
    /// `null` — очистить). Сайт пишется и в `websiteUrl` (основное поле), и в устаревший `site` —
    /// иначе показ `websiteUrl ?? site` вернул бы очищенный сайт из старого поля.
    private func saveAgencyLinks(texts: [Int: String], changedIds: Set<Int>) {
        guard let agencyId = self.agencyId else { return }
        var values: [AgencyLinksUpdateRequest.Field: String?] = [:]
        for field in AgencyField.allCases where changedIds.contains(field.rawValue) {
            let url = Self.constructFullURL(from: texts[field.rawValue] ?? "", with: field.prefix)
            values[field.requestField] = .some(url)
            if field == .website {
                values[.site] = .some(url)
            }
        }
        guard !values.isEmpty else {
            self.navigationController?.popViewController(animated: true)
            return
        }
        Task { @MainActor in
            do {
                let _: UpdateDescriptionAgencyResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/update",
                    method: "POST",
                    body: AgencyLinksUpdateRequest(agencyId: agencyId, values: values)
                )

                divoTrack(.socialLinksSaved)
                self.delegate?.didUpdateSocialLinksData()
                self.navigationController?.popViewController(animated: true)

            } catch {
                self.handleSaveError(error)
            }
        }
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

    /// Часть ссылки после префикса поля (`https://www.instagram.com/x` → `x`). Сайт (пустой префикс) —
    /// ссылка целиком, как сохранена.
    private static func handle(from link: String?, prefix: String) -> String {
        guard let link = link?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty else { return "" }
        if prefix.isEmpty { return link }
        var stripped = link
        for scheme in ["https://", "http://"] where stripped.lowercased().hasPrefix(scheme) {
            stripped = String(stripped.dropFirst(scheme.count))
        }
        if stripped.lowercased().hasPrefix("www.") {
            stripped = String(stripped.dropFirst(4))
        }
        if stripped.lowercased().hasPrefix(prefix) {
            return String(stripped.dropFirst(prefix.count))
        }
        return stripped
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
