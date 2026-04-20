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
import MapResourceToAvatarSizes
import PhotosUI
import DivoUIKit

protocol EditProfileDelegate: AnyObject {
    func didUpdateProfileData()
}

public class EditProfileController: ViewController, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
    private let context: AccountContext

    private var editProfileNode: EditProfileNode {
        return self.displayNode as! EditProfileNode
    }

    private var presentationData: PresentationData
    private var presentationDataDisposable: Any?
    private let userDetailData: UserDetail?
    private let updatePhoto: (UIImage?) -> Void

    private var selectedAvatarImage: UIImage?
    private var selectedAvatarUUID: String?
    private let loadingOverlay = DivoLoadingOverlay()

    weak var delegate: EditProfileDelegate?
    
    public init(context: AccountContext, presentationData: PresentationData, userDetailData: UserDetail?, updatePhoto: @escaping (UIImage?) -> Void) {
        self.context = context
        self.userDetailData = userDetailData
        self.updatePhoto = updatePhoto
        
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
        self.displayNode = EditProfileNode(
            context: self.context,
            presentationData: self.presentationData,
            model: userDetailData
        )
        
        self.editProfileNode.updateTitle(userDetailData?.role == "agency_employee" ? DivoStrings.agencyProfile : DivoStrings.myProfile)

        self.editProfileNode.saveAgencyProfile = { [weak self] rawData in
            self?.handleAgencySave(with: rawData)
        }

        self.editProfileNode.saveProfile = { [weak self] rawData in
            self?.handleSave(with: rawData)
        }
        
        self.editProfileNode.onAvatarTap = { [weak self] in
            self?.openPhotoGallery()
        }
        
        self.editProfileNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.editProfileNode.presentController = { [weak self] vc in
            self?.view.window?.rootViewController?.present(vc, animated: true)
        }
        
        self.editProfileNode.onAddWorkExperience = { [weak self] in
            self?.openAddWorkExperience()
        }
        
        self.editProfileNode.onEditWorkExperience = { [weak self] item in
            self?.openEditWorkExperience(item: item)
        }
        
        self.editProfileNode.onDeleteWorkExperience = { [weak self] itemId in
            self?.deleteWorkExperience(itemId: itemId)
        }

        self.displayNodeDidLoad()

        self.loadAppearanceDictionary()
        self.loadGenderDictionary()
        self.loadWorkExperience()
    }

    private func loadAppearanceDictionary() {
        self.editProfileNode.toggleSpinner(active: true)
        
        Task { @MainActor in
            do {
                let response: AppearanceDictionaryResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/appearances",
                    method: "GET"
                )
                
                self.editProfileNode.configureAppearanceDictionaries(response.data)
                self.editProfileNode.toggleSpinner(active: false)
            } catch {
                self.editProfileNode.toggleSpinner(active: false)
            }
        }
    }
    
    private func loadGenderDictionary() {
        self.editProfileNode.toggleSpinner(active: true)
        
        Task { @MainActor in
            do {
                let response: GenderResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/gender",
                    method: "GET"
                )
                
                self.editProfileNode.configureGenderDictionaries(response)
                self.editProfileNode.toggleSpinner(active: false)
                
            } catch {
                self.editProfileNode.toggleSpinner(active: false)
            }
        }
    }
    
    private func loadWorkExperience() {
        self.editProfileNode.setLoadingWorkExperience(true)

        Task { @MainActor in
            do {
                let response: WorkHistoryResponse = try await DivoAPIClient.shared.request(
                    path: "/model-work-history",
                    method: "GET"
                )

                self.editProfileNode.reloadWorkHistory(items: response.data.items)
                self.fetchAgencyLogos(for: response.data.items)
            } catch {
                if let userDetail = self.userDetailData {
                    self.editProfileNode.reloadLegacyWorkHistory(model: userDetail)
                } else {
                    self.editProfileNode.showSnackbar(
                        message: DivoStrings.failedToLoadWorkHistory,
                        style: .error,
                        retryAction: { [weak self] in
                            self?.loadWorkExperience()
                        },
                        persistent: true
                    )
                }
            }
        }
    }

    private func fetchAgencyLogos(for items:[WorkHistoryItem]) {
        AgencyLogoFetcher.fetch(for: items) { [weak self] itemId, url in
            self?.editProfileNode.updateAgencyLogo(itemId: itemId, url: url)
        }
    }
    
    private func openAddWorkExperience() {
        let controller = AddWorkExperienceController(context: self.context)
        controller.delegate = self
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    private func openEditWorkExperience(item: WorkHistoryItem) {
        let controller = AddWorkExperienceController(context: self.context, editItem: item)
        controller.delegate = self
        self.navigationController?.pushViewController(controller, animated: true)
    }

    private func deleteWorkExperience(itemId: Int) {
        let alert = UIAlertController(
            title: DivoStrings.workHistoryDeleteConfirmTitle,
            message: DivoStrings.workHistoryDeleteConfirmMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: DivoStrings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: DivoStrings.delete, style: .destructive) { [weak self] _ in
            self?.performDeleteWorkExperience(itemId: itemId)
        })
        self.present(alert, animated: true)
    }

    private func performDeleteWorkExperience(itemId: Int) {
        loadingOverlay.show(in: self.displayNode.view, message: DivoStrings.deleting)

        Task {
            do {
                let _: WorkHistoryDeleteResponse = try await DivoAPIClient.shared.request(
                    path: "/model-work-history/\(itemId)",
                    method: "DELETE"
                )
            } catch {
                await MainActor.run {
                    self.loadingOverlay.hide()
                    self.editProfileNode.showSnackbar(
                        message: DivoStrings.failedToDelete,
                        style: .error
                    )
                }
                return
            }

            do {
                let response: WorkHistoryResponse = try await DivoAPIClient.shared.request(
                    path: "/model-work-history"
                )
                let items = response.data.items
                await MainActor.run {
                    self.editProfileNode.reloadWorkHistory(items: items)
                    self.loadingOverlay.hide()
                    self.editProfileNode.showSnackbar(
                        message: DivoStrings.workHistoryDelete,
                        style: .success
                    )
                }
                self.fetchAgencyLogos(for: items)
            } catch {
                await MainActor.run {
                    var currentItems = self.editProfileNode.workRawItems
                    currentItems.removeAll { $0.id == itemId }
                    self.editProfileNode.reloadWorkHistory(items: currentItems)
                    self.loadingOverlay.hide()
                    self.editProfileNode.showSnackbar(
                        message: DivoStrings.workHistoryDelete,
                        style: .success
                    )
                }
            }
        }
    }

    private func openPhotoGallery() {
        if #available(iOS 14, *) {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            picker.view.tintColor = DivoColorPalette.accent
            self.present(picker, animated: true)
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate
            self.present(picker, animated: true)
        }
    }

    private func uploadAvatar(image: UIImage) {
        self.selectedAvatarImage = image
        self.selectedAvatarUUID = nil

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            self.editProfileNode.setAvatarLoading(false)
            return
        }

        Task { @MainActor in
            do {
                let response: FileUploadResponse = try await DivoAPIClient.shared.upload(
                    path: "/file/upload-file",
                    fileData: imageData
                )
                self.selectedAvatarUUID = response.data?.uuid
                self.editProfileNode.currentPhoto = selectedAvatarImage
                self.editProfileNode.setAvatarLoading(false)
            } catch {
                self.editProfileNode.setAvatarLoading(false)
                self.editProfileNode.showSnackbar(
                    message: DivoStrings.failedToUploadPhoto,
                    style: .error
                )
            }
        }
    }

    private func handleSave(with rawData: UpdateBiographyPageRequest) {
        Task { @MainActor in
            do {
                let avatarUuid = self.selectedAvatarUUID.map {
                    UpdateBiographyPageRequest.AvatarUuid(uuid: $0)
                }
                let request = UpdateBiographyPageRequest(
                    fullName: rawData.fullName,
                    gender: rawData.gender,
                    model: rawData.model,
                    avatar: avatarUuid
                )

                let _: UpdateBiographyPageResponse = try await DivoAPIClient.shared.request(
                    path: "/user/update-profile",
                    method: "POST",
                    body: request
                )
                

                self.delegate?.didUpdateProfileData()
                self.navigationController?.popViewController(animated: true)

            } catch {
                self.editProfileNode.toggleSaving(active: false)
                self.editProfileNode.showSnackbar(
                    message: DivoStrings.failedProfileUpdated,
                    style: .error
                )
            }
        }
    }

    private func handleAgencySave(with rawData: UpdateDescriptionAgencyRequest) {
        Task { @MainActor in
            do {
                let photoUuid = self.selectedAvatarUUID.map {
                    UpdateDescriptionAgencyRequest.AvatarUuid(uuid: $0)
                }
                let request = UpdateDescriptionAgencyRequest(
                    agencyId: rawData.agencyId,
                    title: rawData.title,
                    description: rawData.description,
                    photo: photoUuid
                )

                let _: UpdateDescriptionAgencyResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/update",
                    method: "POST",
                    body: request
                )
                

                self.delegate?.didUpdateProfileData()
                self.navigationController?.popViewController(animated: true)

            } catch {
                self.editProfileNode.toggleSaving(active: false)
                self.editProfileNode.showSnackbar(
                    message: DivoStrings.failedProfileUpdated,
                    style: .error
                )
            }
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.statusBar.isHidden = true
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.editProfileNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}


// MARK: - PHPickerViewControllerDelegate
@available(iOS 14, *)
extension EditProfileController {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else {
            return
        }

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
            guard let self = self, let uiImage = image as? UIImage else {
                return
            }
            let normalized = uiImage.fixedOrientation()
            DispatchQueue.main.async {
                self.editProfileNode.setAvatarLoading(true)
            }
            self.uploadAvatar(image: normalized)
        }
    }
}


// MARK: - UIImagePickerControllerDelegate

extension EditProfileController: UIImagePickerControllerDelegate {
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
        self.editProfileNode.setAvatarLoading(true)
        self.editProfileNode.currentPhoto = normalized
        self.uploadAvatar(image: normalized)
    }
}


// MARK: - UIImage orientation fix

extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let fixed = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return fixed
    }
}


extension EditProfileController: AddWorkExperienceDelegate {
    func didUpdateWorkExperience(isEdit: Bool) {
        self.loadWorkExperience()
        self.editProfileNode.showSnackbar(
            message: isEdit ? DivoStrings.workHistoryUpdated : DivoStrings.workHistoryCreate,
            style: .success
        )
    }
}
