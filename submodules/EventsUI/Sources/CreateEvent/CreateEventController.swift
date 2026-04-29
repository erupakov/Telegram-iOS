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

public class CreateEventController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext
    private let eventId: Int?
    private let isEditMode: Bool

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

    public init(context: AccountContext, eventId: Int? = nil) {
        self.context = context
        self.eventId = eventId
        self.isEditMode = (eventId != nil)

        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override public func loadDisplayNode() {
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        let theme = self.presentationData.theme

        self.displayNode = CreateEventNode(addPhoto: { [weak self] in
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

        self.createEventNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme, displayCodes: false, glass: true)
                controller.completeWithCountryCode = { _, countryId, name in

                    if let strongSelf = self {
                        strongSelf.createEventNode.updateCountry(countryId: countryId, countryName: name)
                    }
                }
                controller.dismissed = {

                }
                strongSelf.push(controller)
            }
        }

        self.createEventNode.scheduleTimeController = { [weak self] mode in
            self?.scheduleTimeController(mode: mode)
        }
        self.createEventNode.scheduleDeadlineTimeController = { [weak self] mode in
            self?.scheduleDeadlineTimeController(mode: mode)
        }
        self.createEventNode.showAlert = { [weak self] text in
            self?.showAlert(text: text)
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

        self.loadAppearanceDictionary()
        self.loadGenderDictionary()

        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isEditMode, let eventId = self.eventId {
            self.loadEventData(eventId: eventId)
        }
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.loadEventTypesList(offset: 0, limit: 20)
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.createEventNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
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
                print("❌ Error loading event types list: \(error)")
                self.createEventNode.loadEventTypesComplete([], totalCount: 0, offset: offset)
            }
        }
    }

    private func loadAppearanceDictionary() {
        Task { @MainActor in
            do {
                let response: AppearanceDictionaryResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/appearances",
                    method: "GET"
                )
                
                self.createEventNode.configureAppearanceDictionaries(response.data)
            } catch {
                print("❌ Error loading appearance dictionary: \(error)")
                self.showAlert(text: DivoStrings.failedToLoadAppearance)
            }
        }
    }
    
    private func loadGenderDictionary() {
        Task { @MainActor in
            do {
                let response: GenderResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/gender",
                    method: "GET"
                )
                
                self.createEventNode.configureGenderDictionaries(response)
            } catch {
                print("❌ Error loading appearance dictionary: \(error)")
                self.showAlert(text: DivoStrings.failedToLoadAppearance)
            }
        }
    }
    
    private func loadEventData(eventId: Int) {
        Task { @MainActor in
            do {
                // let response: EventFullDetailResponse = try await DivoAPIClient.shared.request(
                //     path: "/event/\(eventId)",
                //     method: "GET"
                // )
                
//                if let detail = response.data {
//                    self.createEventNode.populate(with: detail)
//                }
            // } catch {
            //     print("❌ Error loading event data: \(error)")
            //     self.showAlert(text: DivoStrings.failedToLoadEventData + ": \(error.localizedDescription)")
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
                    self.showAlert(text: DivoStrings.failedToUploadCover + ": \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showAlert(text: String, completion: (() -> Void)? = nil) {
        Queue.mainQueue().async {
            let alertController = textAlertController(
                context: self.context,
                title: nil,
                text: text,
                actions:[
                    TextAlertAction(type: .defaultAction, title: "OK", action: {
                        completion?()
                    })
                ]
            )
            self.present(alertController, in: .window(.root))
        }
    }
    
    @objc private func createPressed() {
        self.view.endEditing(true)

        do {
//            let requestPayload = try self.createEventNode.collectEventData()
//
//            self.navigationItem.rightBarButtonItem?.isEnabled = false
//
//            Task { @MainActor in
//                do {     
//                    var path = ""
//                    if isEditMode, let eventId = self.eventId {
//                        path = "/event/update/\(eventId)"
//                    } else {
//                        path = "/event/create"
//                    }
//                                   
//                    let response: CreateEventResponse = try await DivoAPIClient.shared.request(
//                        path: path,
//                        method: "POST",
//                        body: requestPayload
//                    )
//
//                    self.navigationItem.rightBarButtonItem?.isEnabled = true
//
//                    if response.errors == nil || response.errors?.isEmpty == true {
//                        self.onEventCreated?()
//
//                        let successMessage = isEditMode ? DivoStrings.eventSuccessfullyUpdated : DivoStrings.eventSuccessfullyCreated
//                        self.showAlert(text: successMessage) { [weak self] in
//                            guard let self = self else { return }
//                            if let nav = self.navigationController as? NavigationController {
//                                _ = nav.popViewController(animated: true)
//                            } else {
//                                self.dismiss()
//                            }
//                        }
//                    } else {
//                        let errorMsg = response.errors?.joined(separator: "\n") ?? DivoStrings.unknownError
//                        self.showAlert(text: errorMsg)
//                    }
//
//                } catch {
//                    self.navigationItem.rightBarButtonItem?.isEnabled = true
//                    print("❌ Error \(isEditMode ? "updating" : "creating") event: \(error)")
//                    let failMsg = isEditMode ? DivoStrings.failedToUpdateEvent : DivoStrings.failedToCreateEvent
//                    var detail = error.localizedDescription
//                    if case let DivoAPIError.httpError(_, body) = error,
//                       let data = body.data(using: .utf8),
//                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//                       let message = json["message"] as? String, !message.isEmpty {
//                        detail = message
//                    }
//                    self.showAlert(text: failMsg + ": \(detail)")
//                }
//            }

//        } catch {
//            self.showAlert(text: error.localizedDescription)
        }
    }
    
    private func scheduleTimeController(mode: TimeControllerMode) {
        
        // Определяем режим нашего нового контроллера
        let pickerMode: DivoDatePickerController.Mode
        let currentTime: Int32
        
        switch mode {
        case .date:
            pickerMode = .date
            currentTime = self.createEventNode.eventDateInt
        case .time:
            pickerMode = .time
            currentTime = self.createEventNode.eventTimeInt

        }
        
        // Передаем текущее время (если уже выбрано), либо текущее время системы
        let initialTime = currentTime > 0 ? currentTime : Int32(Date().timeIntervalSince1970)
        
        let controller = DivoDatePickerController(mode: pickerMode, initialTimestamp: initialTime, title: mode == .date ? DivoStrings.eventDate : DivoStrings.eventTime)
        
        // Когда пользователь нажимает галочку, обновляем UI
        controller.onSave = { [weak self] selectedTimestamp in
            self?.createEventNode.updateTime(selectedTimestamp, mode)
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
        
        // Определяем режим нашего нового контроллера
        let pickerMode: DivoDatePickerController.Mode
        let currentTime: Int32
        
        switch mode {
        case .date:
            pickerMode = .date
            currentTime = self.createEventNode.deadlineDateInt
        case .time:
            pickerMode = .time
            currentTime = self.createEventNode.deadlineTimeInt

        }
        
        // Передаем текущее время (если уже выбрано), либо текущее время системы
        let initialTime = currentTime > 0 ? currentTime : Int32(Date().timeIntervalSince1970)
        
        let controller = DivoDatePickerController(mode: pickerMode, initialTimestamp: initialTime, title: mode == .date ? DivoStrings.deadlineDate : DivoStrings.deadlineTime)
        
        // Когда пользователь нажимает галочку, обновляем UI
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
                self.createEventNode.currentPhoto = selectedAvatarImage
                self.createEventNode.setAvatarLoading(false)
            } catch {
                self.createEventNode.setAvatarLoading(false)
                self.createEventNode.showSnackbar(
                    message: DivoStrings.failedToUploadPhoto,
                    style: .error
                )
            }
        }
    }
    
    private func openPhotoGallery() {
        self.currentPickerTarget = .avatar // Указываем цель: Аватар
        
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

                await MainActor.run {
                    self.createEventNode.finishPhotoUpload(item: item, fileUuid: fileUuid)
                }

            } catch {
                await MainActor.run {
                    self.createEventNode.cancelPhotoUpload(item: item)
                    self.showAlert(text: DivoStrings.failedToUploadPhoto + ": \(error.localizedDescription)")
                }
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
