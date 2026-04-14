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
    private var currentEditState = EditState()

    weak var delegate: EditProfileDelegate?
    
    public init(context: AccountContext, presentationData: PresentationData, userDetailData: UserDetail?, updatePhoto: @escaping (UIImage?) -> Void) {
        self.context = context
        self.userDetailData = userDetailData
        self.updatePhoto = updatePhoto
        
        self.presentationData = presentationData
        
        super.init(navigationBarPresentationData: nil)

        self.presentationDataDisposable = (context.sharedContext.presentationData
                                           |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                }
            }
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
            model: userDetailData,
            currentEditState: currentEditState
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

        self.displayNodeDidLoad()

        self.loadAppearanceDictionary()
        self.loadGenderDictionary()
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
                print("❌ Error loading appearance dictionary: \(error)")
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
                print("❌ Error loading appearance dictionary: \(error)")
                self.editProfileNode.toggleSpinner(active: false)
            }
        }
    }
    
    private var selectedAvatarImage: UIImage?
    private var selectedAvatarUUID: String?

    private func openPhotoGallery() {
        print("📸 Opening photo gallery...")
        
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
                print("✅ Avatar uploaded, uuid: \(self.selectedAvatarUUID ?? "nil")")
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

                let response: UpdateBiographyPageResponse = try await DivoAPIClient.shared.request(
                    path: "/user/update-profile",
                    method: "POST",
                    body: request
                )
                
                print("✅ Profile successfully saved: \(response.message ?? "OK")")

                self.delegate?.didUpdateProfileData()
                self.navigationController?.popViewController(animated: true)

            } catch {
                self.editProfileNode.toggleSpinner(active: false)
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
                    description: rawData.description,
                    photo: photoUuid
                )

                let response: UpdateDescriptionAgencyResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/update",
                    method: "POST",
                    body: request
                )
                
                print("✅ Profile successfully saved: \(response.message ?? "OK")")

                self.delegate?.didUpdateProfileData()
                self.navigationController?.popViewController(animated: true)

            } catch {
                self.editProfileNode.toggleSpinner(active: false)
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
