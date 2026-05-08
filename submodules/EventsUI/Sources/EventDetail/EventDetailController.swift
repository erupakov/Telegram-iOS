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
    public let request: CreateEventRequest
    public let coverImage: UIImage?
    public let gallery: [UserPhoto]
    public let typeTitle: String
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
    
    // Массив для хранения распарсенных фотографий галереи
    internal var currentGalleryPhotos: [UserPhoto] = []
    private weak var activeGalleryController: ProfileGalleryController?

    // Свойства для Preview режима
    private let isPreviewMode: Bool
    private let previewData: EventPreviewData?
    public var onPublishConfirmed: (() -> Void)?

    public init(
        context: AccountContext,
        eventId: Int? = nil,
        isMyEvent: Bool? = nil,
        isPreviewMode: Bool = false,
        previewData: EventPreviewData? = nil
    ) {
        self.context = context
        self.eventId = eventId
        self.isMyEvent = isMyEvent
        self.isPreviewMode = isPreviewMode
        self.previewData = previewData

        super.init(context: context, navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.getEventDisposable.dispose()
    }

    override public func loadDisplayNode() {
        self.displayNode = EventDetailControllerNode(
            context: self.context,
            isMyEvent: self.isMyEvent ?? false,
            isPreviewMode: self.isPreviewMode
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
        
        self.displayNodeDidLoad()
        
        if isPreviewMode {
            loadPreview()
        } else {
            getEvent()
        }
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
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
                    let sortedFiles = files.sorted { ($0.order ?? 99) < ($1.order ?? 99) }
                    // Фильтруем обложку (обычно order == 0) и конвертируем остальные фото в UserPhoto
                    self.currentGalleryPhotos = sortedFiles.filter { $0.order != 0 }.compactMap { file in
                        let userFile = UserFile(
                            fileName: file.fileName ?? "event_photo.jpg",
                            fullUrl: file.fullUrl ?? "",
                            fileExtension: file.fileExtension ?? "jpg",
                            fileUuid: file.fileUuid
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
                print("❌[DivoAPI] event/\(eventId) error: \(error)")
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
        print("Bookmark button pressed")
    }
    
    private func applyPressed() {
        print("Apply button pressed")
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
}
