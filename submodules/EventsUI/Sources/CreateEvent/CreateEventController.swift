import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import DivoCore
import DivoUIKit
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
import Postbox
import PhotosUI
import DivoGallery

protocol CreateEventDelegate: AnyObject {
    func didCreateEvent()
}

public class CreateEventController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext
    private let mode: CreateEventMode

    private var eventId: Int? { mode.eventId }

    private var createEventNode: CreateEventNode {
        return self.displayNode as! CreateEventNode
    }

    private var presentationData: PresentationData
    
    public var onEventCreated: (() -> Void)?
    
    private var selectedAvatarImage: UIImage?
    private var selectedAvatarUUID: String?
    
    private enum PhotoPickerTarget {
        case avatar
        case gallery
    }
    private var currentPickerTarget: PhotoPickerTarget = .avatar
    
    private weak var activeGalleryController: ProfileGalleryController?

    weak var delegate: CreateEventDelegate?
    
    internal var currentGalleryPhotos: [UserPhoto] = []

    public init(context: AccountContext, mode: CreateEventMode = .create) {
        self.context = context
        self.mode = mode

        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
    }

    override public func loadDisplayNode() {
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        let theme = self.presentationData.theme

        self.displayNode = CreateEventNode(
            addPhoto: { [weak self] in
            presentLegacyAvatarPicker(holder: currentAvatarMixin, signup: true, theme: theme, present: { c, a in
                self?.view.endEditing(true)
                self?.present(c, in: .window(.root), with: a)
            }, openCurrent: nil, completion: { image in
                self?.createEventNode.currentPhoto = image
                self?.uploadAvatarPhoto(image)
            }, videoCompletion: { image, asset, adjustments in
                self?.createEventNode.currentPhoto = image
                self?.uploadAvatarPhoto(image)
            })
        })

        self.createEventNode.scheduleTimeController = { [weak self] mode in
            self?.scheduleTimeController(mode: mode)
        }
        self.createEventNode.scheduleDeadlineTimeController = { [weak self] mode in
            self?.scheduleDeadlineTimeController(mode: mode)
        }
        self.createEventNode.onCreateEventTapped = { [weak self] in
            self?.createPressed()
        }
        self.createEventNode.onAddGalleryPhotoTapped = { [weak self] in
            if #available(iOS 14, *) {
                self?.openMultiPhotoPicker()
            }
        }
        
        self.createEventNode.onAvatarTap = { [weak self] in
            if #available(iOS 14, *) {
                self?.openPhotoGallery()
            }
        }
        
        self.createEventNode.loadEventTypesList = { [weak self] offset, limit in
            self?.loadEventTypesList(offset: offset, limit: limit)
        }
        
        self.createEventNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.createEventNode.presentController = { [weak self] vc in
            self?.view.window?.rootViewController?.present(vc, animated: true)
        }
        
        self.createEventNode.onGalleryItemTapped = {[weak self] fileUuid in
            self?.openFullScreenGallery(for: fileUuid)
        }

        self.createEventNode.retryLoadEventData = { [weak self] in
            self?.retryLoadEventData()
        }

        self.createEventNode.onCityChosen = { [weak self] cityName in
            self?.resolveCityOnBackend(cityName: cityName)
        }

        self.displayNodeDidLoad()
        
        self.loadInitialData()
    }
    
    private func loadInitialData() {
        self.createEventNode.showScreenLoading()
        
        Task { @MainActor in
            do {
                async let appearanceTask = DivoAPIClient.shared.request(path: "/dictionary/appearances", method: "GET") as AppearanceDictionaryResponse
                async let genderTask = DivoAPIClient.shared.request(path: "/dictionary/gender", method: "GET") as GenderResponse
                
                let typesRequest = AgencyListRequest(offset: 0, limit: 20, title: nil)
                async let eventTypesTask = DivoAPIClient.shared.request(path: "/event/types", method: "POST", body: typesRequest) as AgencyListResponse
                
                let eventDetail: EventFullDetailData? = try await {
                    if case .edit(let eventId) = self.mode {
                        self.createEventNode.configure(mode: self.mode)
                        let response: EventFullDetailResponse = try await DivoAPIClient.shared.request(path: "/event/\(eventId)", method: "GET")
                        return response.data
                    }
                    return nil
                }()
                
                let (appearance, gender, eventTypes) = try await (appearanceTask, genderTask, eventTypesTask)
                
                self.createEventNode.configureAppearanceDictionaries(appearance.data)
                self.createEventNode.configureGenderDictionaries(gender)
                self.createEventNode.loadEventTypesComplete(eventTypes.data.items, totalCount: eventTypes.data.pagination.meta.totalCount, offset: 0)

                if !self.mode.isEdit {
                    self.createEventNode.applyDefaultStep2Parameters(overrideExisting: true)
                }

                if let detail = eventDetail {
                    self.createEventNode.populate(with: detail)
                    self.createEventNode.markDataLoaded()
                    if let files = detail.files {
                        // Файлы без order считаем «без порядка» и кладём в конец списка.
                        let sortedFiles = files.sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
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
                                id: abs(uuid.hashValue),
                                photo: userFile,
                                likesCount: 0,
                                isLikedByUser: false,
                                preview: nil
                            )
                        }
                    }
                }
                
                self.createEventNode.markDataLoaded()
                
            } catch {
                self.createEventNode.markDataLoadFailed(networkError: false)
            }
        }
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.createEventNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }

    private func loadEventTypesList(offset: Int, limit: Int) {
        Task { @MainActor in
            do {
                let request = AgencyListRequest(offset: offset, limit: limit, title: nil)
                let response: AgencyListResponse = try await DivoAPIClient.shared.request(
                    path: "/event/types",
                    method: "POST",
                    body: request
                )

                self.createEventNode.loadEventTypesComplete(
                    response.data.items,
                    totalCount: response.data.pagination.meta.totalCount,
                    offset: offset
                )

            } catch {
                divoLog("❌ Error loading event types list: \(error)", level: .error)
                self.createEventNode.loadEventTypesComplete([], totalCount: 0, offset: offset)
            }
        }
    }
    
    private func uploadAvatarPhoto(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        Task {
            do {
                let uploadResponse: FileUploadResponse = try await DivoAPIClient.shared.upload(
                    path: "/file/upload-file",
                    fileData: imageData,
                    fileName: "event_cover.jpg",
                    mimeType: "image/jpeg"
                )
                
                guard let fileUuid = uploadResponse.data?.uuid else {
                    throw DivoAPIError.unknown
                }
                
                await MainActor.run {
                    self.createEventNode.avatarFileUuid = fileUuid
                }
                
            } catch {
                await MainActor.run {
                    self.createEventNode.currentPhoto = nil
                    let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.failedToUploadAvatar
                    self.createEventNode.showSnackbar(
                        message: userMsg,
                        style: .error
                    )
                }
            }
        }
    }
    
    @objc private func createPressed() {
        
        do {
            let requestPayload = try self.createEventNode.collectEventData()
            let collectPreviewData = try self.createEventNode.collectPreviewEventData()
            
            let previewData = EventPreviewData(
                request: collectPreviewData,
                coverImage: self.createEventNode.currentPhoto,
                gallery: self.currentGalleryPhotos
            )
            
            let previewController = EventDetailController(
                context: self.context,
                eventId: self.eventId,
                isMyEvent: true,
                isPreviewMode: true,
                previewData: previewData
            )
            
            previewController.onPublishConfirmed = { [weak self, weak previewController] in
                self?.performPublishRequest(requestPayload, previewController: previewController)
            }

            divoTrack(.eventCreatePreviewOpened)
            self.push(previewController)
            
        } catch {
            divoLog("\(error.localizedDescription)", level: .error)
        }
    }
    
    private func performPublishRequest(_ payload: CreateEventRequest, previewController: EventDetailController?) {
        self.createEventNode.showScreenLoading()
        Task { @MainActor in
            do {
                let path: String
                switch self.mode {
                case .create:
                    path = "/event/create"
                case .edit(let eventId):
                    path = "/event/update/\(eventId)"
                }
                let response: CreateEventResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: payload
                )
                
                self.createEventNode.hideScreenLoading()
                
                if response.errors == nil || response.errors?.isEmpty == true {
                    self.onEventCreated?()

                    switch self.mode {
                    case .create:
                        if let createdId = response.data?.id {
                            divoTrack(.eventCreateSuccess(eventId: Int64(createdId)))
                        }
                    case .edit(let eventId):
                        divoTrack(.eventEdited(eventId: Int64(eventId)))
                    }

                    NotificationCenter.default.post(
                        name: DivoConfig.divoEventCreated,
                        object: nil,
                        userInfo: nil
                    )
                    
                    let successController = EventPublishedSuccessController(context: self.context)

                    // id события для перехода с экрана успеха: create — из ответа, edit — из mode.
                    let resultEventId: Int? = response.data?.id ?? { if case .edit(let id) = self.mode { return id } else { return nil } }()

                    let backToProfile: () -> Void = { [weak self] in
                        guard let self = self, let nav = self.navigationController else { return }
                        let controllers = nav.viewControllers
                        
                        if let myIndex = controllers.firstIndex(where: { $0 === self }), myIndex > 0 {
                            let profileController = controllers[myIndex - 1]
                            self.delegate?.didCreateEvent()
                            nav.popToViewController(profileController, animated: true)
                        } else {
                            self.delegate?.didCreateEvent()
                            nav.popViewController(animated: true)
                        }
                    }
                    
                    successController.onViewEventTapped = { [weak self] in
                        guard let self else { return }
                        if let id = resultEventId {
                            self.push(EventDetailController(context: self.context, eventId: id, isMyEvent: true))
                        } else {
                            backToProfile()
                        }
                    }
                    successController.onManageApplicationsTapped = { [weak self] in
                        guard let self else { return }
                        if let id = resultEventId {
                            self.push(ApplicationsListController(context: self.context, eventId: id))
                        } else {
                            backToProfile()
                        }
                    }
                    previewController?.toggleSaving(active: false)
                    self.push(successController)
                } else {
                    let errorMsg = response.errors?.joined(separator: "\n") ?? DivoStrings.unknownError
                    previewController?.toggleSaving(active: false)
                    previewController?.showSnackbar(message: DivoStrings.errorCreateUpdateEvent)
                    self.createEventNode.showSnackbar(message: errorMsg, style: .error)
                }
                
            } catch {
                self.createEventNode.hideScreenLoading()
                previewController?.toggleSaving(active: false)
                let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.errorCreateUpdateEvent
                previewController?.showSnackbar(message: userMsg)
                self.createEventNode.showSnackbar(message: userMsg, style: .error)
            }
        }
    }
    
    private func scheduleTimeController(mode: TimeControllerMode) {
        let pickerMode: DivoDatePickerController.Mode
        let currentTime: Int32
        
        var minimumTimestamp: Int32? = nil
        
        switch mode {
        case .date:
            pickerMode = .date
            currentTime = self.createEventNode.eventDateInt

            let todayStart = Calendar.current.startOfDay(for: Date())
            minimumTimestamp = Int32(todayStart.timeIntervalSince1970)

        case .time:
            pickerMode = .time
            currentTime = self.createEventNode.eventTimeInt

            // Если выбранная дата события — сегодня, минимально допустимое время
            // — текущий момент (нельзя в прошлое). Для дат в будущем ограничения нет.
            // Если дата ещё не выбрана — страхуемся таким же ограничением.
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let eventDateStart = self.createEventNode.eventDateInt > 0
                ? calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(self.createEventNode.eventDateInt)))
                : todayStart
            if eventDateStart == todayStart {
                minimumTimestamp = Int32(Date().timeIntervalSince1970)
            }
        }
        
        let initialTime = currentTime > 0 ? currentTime : Int32(Date().timeIntervalSince1970)
        
        let controller = DivoDatePickerController(
            mode: pickerMode,
            initialTimestamp: initialTime,
            title: mode == .date ? DivoStrings.eventDate : DivoStrings.eventTime,
            minimumTimestamp: minimumTimestamp
        )
        
        controller.onSave = {[weak self] selectedTimestamp in
            guard let self = self else { return }
            
            self.createEventNode.updateTime(selectedTimestamp, mode)
            
            if mode == .date {
                let currentDeadlineInt = self.createEventNode.deadlineDateInt

                if currentDeadlineInt > 0 {
                    let newEventStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(selectedTimestamp)))
                    let currentDeadlineStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(currentDeadlineInt)))

                    // Deadline допустим в день события включительно — сбрасываем
                    // только если он строго позже новой даты события.
                    if currentDeadlineStart > newEventStart {
                        let newDeadlineTimestamp = Int32(newEventStart.timeIntervalSince1970)
                        self.createEventNode.updateDeadlineTime(newDeadlineTimestamp, .date)
                    }
                }
            }
        }
        
        let nav = UINavigationController(rootViewController: controller)
        nav.setNavigationBarHidden(true, animated: false)
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = DivoDesignTokens.Radius.card
            }
        }
        
        self.present(nav, animated: true)
    }
    
    private func scheduleDeadlineTimeController(mode: TimeControllerMode) {
        let pickerMode: DivoDatePickerController.Mode
        let currentTime: Int32
        
        var maximumTimestamp: Int32? = nil
        var minimumTimestamp: Int32? = nil
        
        switch mode {
        case .date:
            pickerMode = .date
            currentTime = self.createEventNode.deadlineDateInt
            
            let todayStart = Calendar.current.startOfDay(for: Date())
            minimumTimestamp = Int32(todayStart.timeIntervalSince1970)
            
            let eventDateInt = self.createEventNode.eventDateInt
            if eventDateInt > 0 {
                // Deadline допустим в тот же день, что и событие (но не позже).
                let eventStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(eventDateInt)))
                maximumTimestamp = Int32(eventStart.timeIntervalSince1970)
            }
            
        case .time:
            pickerMode = .time
            currentTime = self.createEventNode.deadlineTimeInt
        }
        
        let initialTime = currentTime > 0 ? currentTime : Int32(Date().timeIntervalSince1970)
        
        let controller = DivoDatePickerController(
            mode: pickerMode,
            initialTimestamp: initialTime,
            title: mode == .date ? DivoStrings.deadlineDate : DivoStrings.deadlineTime,
            minimumTimestamp: minimumTimestamp,
            maximumTimestamp: maximumTimestamp
        )
        
        controller.onSave = { [weak self] selectedTimestamp in
            self?.createEventNode.updateDeadlineTime(selectedTimestamp, mode)
        }
        
        let nav = UINavigationController(rootViewController: controller)
        nav.setNavigationBarHidden(true, animated: false)
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = DivoDesignTokens.Radius.card
            }
        }
        
        self.present(nav, animated: true)
    }
    
    private func uploadAvatar(image: UIImage) {
        self.selectedAvatarImage = image
        self.selectedAvatarUUID = nil

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            self.createEventNode.setAvatarLoading(false)
            return
        }

        Task { @MainActor in
            do {
                let response: FileUploadResponse = try await DivoAPIClient.shared.upload(
                    path: "/file/upload-file",
                    fileData: imageData
                )
                self.selectedAvatarUUID = response.data?.uuid
                self.createEventNode.avatarFileUuid = response.data?.uuid
                self.createEventNode.currentPhoto = selectedAvatarImage
                self.createEventNode.setAvatarLoading(false)
            } catch {
                self.createEventNode.setAvatarLoading(false)
                let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.failedToUploadPhoto
                self.createEventNode.showSnackbar(
                    message: userMsg,
                    style: .error
                )
            }
        }
    }
    
    private func openPhotoGallery() {
        self.currentPickerTarget = .avatar
        
        if #available(iOS 14, *) {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            self.present(picker, animated: true)
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate
            self.present(picker, animated: true)
        }
    }
    
    private func openMultiPhotoPicker() {
        self.currentPickerTarget = .gallery
        
        if #available(iOS 14, *) {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 10
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            self.present(picker, animated: true)
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate
            self.present(picker, animated: true)
        }
    }

    private func uploadEventPhoto(image: UIImage, item: EventGalleryItem) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            self.createEventNode.cancelPhotoUpload(item: item)
            return
        }
        
        Task {
            do {
                let uploadResponse: FileUploadResponse = try await DivoAPIClient.shared.upload(
                    path: "/file/upload-file",
                    fileData: imageData,
                    fileName: "event_photo.jpg",
                    mimeType: "image/jpeg"
                )
                
                guard let fileUuid = uploadResponse.data?.uuid else {
                    throw DivoAPIError.unknown
                }
                
                let userFile = UserFile(
                    fileName: uploadResponse.data?.fileName,
                    fullUrl: uploadResponse.data?.fullUrl,
                    fileExtension: uploadResponse.data?.extensionFile,
                    fileUuid: fileUuid
                )
                
                let newPhoto = UserPhoto(
                    id: abs(fileUuid.hashValue),
                    photo: userFile,
                    likesCount: 0,
                    isLikedByUser: false,
                    preview: nil
                )
                
                await MainActor.run {
                    self.createEventNode.finishPhotoUpload(item: item, fileUuid: fileUuid)
                    
                    self.currentGalleryPhotos.append(newPhoto)
                    
                    let uiItems = self.createEventNode.galleryItems
                    self.currentGalleryPhotos.sort { photo1, photo2 in
                        let index1 = uiItems.firstIndex(where: { $0.fileUuid == photo1.photo.fileUuid }) ?? 999
                        let index2 = uiItems.firstIndex(where: { $0.fileUuid == photo2.photo.fileUuid }) ?? 999
                        return index1 < index2
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.createEventNode.cancelPhotoUpload(item: item)
                    let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.failedToUploadPhoto
                    self.createEventNode.showSnackbar(
                        message: userMsg,
                        style: .error
                    )
                }
            }
        }
    }
    
    // Открытие галереи на полный экран
    private func openFullScreenGallery(for uuid: String) {
        guard let initialIndex = self.currentGalleryPhotos.firstIndex(where: { $0.photo.fileUuid == uuid }) else { return }
        
        let galleryController = ProfileGalleryController(
            context: self.context,
            photos: self.currentGalleryPhotos,
            initialIndex: initialIndex,
            isVideoGallery: false,
            isOwnProfile: true,
            isLocalOnly: true
        )
        
        galleryController.onDeletePublication = { [weak self] deletedId in
            guard let self = self else { return }
            if let photoToDelete = self.currentGalleryPhotos.first(where: { $0.id == deletedId }) {
                let uuidToDelete = photoToDelete.photo.fileUuid
                self.currentGalleryPhotos.removeAll { $0.id == deletedId }
                if let itemToRemove = self.createEventNode.galleryItems.first(where: { $0.fileUuid == uuidToDelete }) {
                    self.createEventNode.removePhoto(item: itemToRemove)
                }
            }
        }

        self.activeGalleryController = galleryController
        self.push(galleryController)
    }

    // Retry после ошибки
    private func retryLoadEventData() {
        createEventNode.resetToInitialLoading()
        self.loadInitialData()
    }

    private func resolveCityOnBackend(cityName: String) {
        self.createEventNode.setCityRowLoading(true)
        
        Task { @MainActor in
            do {
                let encodedQuery = cityName.divoURLQueryEncoded

                let response: GeoSearchResponse = try await DivoAPIClient.shared.request(
                    path: "/geo/search-by-address-name?query=\(encodedQuery)",
                    method: "GET"
                )
                
                self.createEventNode.setCityRowLoading(false)
                
                if let firstResult = response.data?.first, let cityId = firstResult.city?.id {
                    let resolvedCityId = String(cityId)
                    
                    let resolvedCityName = firstResult.city?.name ?? cityName
                    let countryCode = firstResult.country?.code ?? firstResult.city?.countryCode
                    
                    self.createEventNode.updateCity(id: resolvedCityId, title: resolvedCityName, code: countryCode)
                } else {
                    self.createEventNode.updateCity(id: nil, title: nil, code: nil)
                    self.createEventNode.showSnackbar(message: DivoStrings.cityNotFound, style: .error)
                }
            } catch {
                self.createEventNode.setCityRowLoading(false)
                self.createEventNode.updateCity(id: nil, title: nil, code: nil)
                
                let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.genericError
                self.createEventNode.showSnackbar(message: userMsg, style: .error)
            }
        }
    }
}

@available(iOS 14.0, *)
extension CreateEventController: PHPickerViewControllerDelegate {
    
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        if results.isEmpty { return }
        
        switch currentPickerTarget {
        case .avatar:
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) {[weak self] image, _ in
                guard let self = self, let uiImage = image as? UIImage else { return }
                let normalized = uiImage.fixedOrientation()
                
                DispatchQueue.main.async {
                    self.createEventNode.setAvatarLoading(true)
                }
                self.uploadAvatar(image: normalized)
            }
            
        case .gallery:
            for result in results {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                    guard let self = self, let uiImage = image as? UIImage else { return }
                    let normalized = uiImage.fixedOrientation()
                    
                    DispatchQueue.main.async {
                        let galleryItem = self.createEventNode.startPhotoUpload(image: normalized)
                        
                        self.uploadEventPhoto(image: normalized, item: galleryItem)
                    }
                }
            }
        }
    }
}

extension CreateEventController: UIImagePickerControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        if let editedImage = info[.editedImage] as? UIImage {
            handleSelectedImage(editedImage)
        } else if let originalImage = info[.originalImage] as? UIImage {
            handleSelectedImage(originalImage)
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    private func handleSelectedImage(_ image: UIImage) {
        let normalized = image.fixedOrientation()
        
        switch currentPickerTarget {
        case .avatar:
            self.createEventNode.setAvatarLoading(true)
            self.createEventNode.currentPhoto = normalized
            self.uploadAvatar(image: normalized)
            
        case .gallery:
            let galleryItem = self.createEventNode.startPhotoUpload(image: normalized)
            self.uploadEventPhoto(image: normalized, item: galleryItem)
        }
    }
}
