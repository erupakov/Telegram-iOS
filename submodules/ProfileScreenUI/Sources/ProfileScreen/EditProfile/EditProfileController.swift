import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
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

protocol EditProfileDelegate: AnyObject {
    func didUpdateProfileData()
}

public class EditProfileController: ViewController, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
    private let context: AccountContext

    private var createEventNode: EditProfileNode {
        return self.displayNode as! EditProfileNode
    }

    private var presentationData: PresentationData
    private var presentationDataDisposable: Any?
    private let userDetailData: UserDetail?
    private let updatePhoto: (UIImage?) -> Void

    weak var delegate: EditProfileDelegate?
    
    public init(context: AccountContext, presentationData: PresentationData, userDetailData: UserDetail?, updatePhoto: @escaping (UIImage?) -> Void) {
        self.context = context
        self.userDetailData = userDetailData
        self.updatePhoto = updatePhoto
        
        self.presentationData = presentationData
        
        let darkNavigationTheme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: .white,
            disabledButtonColor: UIColor(rgb: 0x525252),
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)
        
        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))

        super.init(navigationBarPresentationData: navigationBarData)

        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style

        NotificationCenter.default.addObserver(self, selector: #selector(handleWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        self.title = DivoStrings.myProfile
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
                                           |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
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

    private func makeNavigationBarPresentationData() -> NavigationBarPresentationData {
        let theme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: .white,
            disabledButtonColor: UIColor(rgb: 0x525252),
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)
        return NavigationBarPresentationData(theme: theme, strings: NavigationBarStrings(back: DivoStrings.back, close: DivoStrings.close))
    }

    @objc private func handleWillEnterForeground() {
        self.navigationBar?.updatePresentationData(makeNavigationBarPresentationData(), transition: .immediate)
    }

    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
        self.navigationBar?.updatePresentationData(makeNavigationBarPresentationData(), transition: .immediate)

        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    override public func loadDisplayNode() {
        self.title = userDetailData?.role == "agency_employee" ? DivoStrings.agencyProfile : DivoStrings.myProfile

        self.displayNode = EditProfileNode(
            context: self.context,
            presentationData: self.presentationData,
            model: userDetailData
        )

        self.createEventNode.saveAgencyProfile = { [weak self] rawData in
            self?.handleAgencySave(with: rawData)
        }

        self.createEventNode.saveProfile = { [weak self] rawData in
            self?.handleSave(with: rawData)
        }

        self.createEventNode.showAlert = { [weak self] text in
            self?.showAlert(text: text)
        }
        
        self.createEventNode.onAvatarTap = { [weak self] in
            self?.openPhotoGallery()
        }

        self.displayNodeDidLoad()

        self.loadAppearanceDictionary()
        self.loadGenderDictionary()
    }

    private func loadAppearanceDictionary() {
        self.createEventNode.toggleSpinner(active: true)
        
        Task { @MainActor in
            do {
                let response: AppearanceDictionaryResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/appearances",
                    method: "GET"
                )
                
                self.createEventNode.configureAppearanceDictionaries(response.data)
                self.createEventNode.toggleSpinner(active: false)
                
            } catch {
                print("❌ Error loading appearance dictionary: \(error)")
                self.createEventNode.toggleSpinner(active: false)
                self.showAlert(text: DivoStrings.failedToLoadAppearance)
            }
        }
    }
    
    private func loadGenderDictionary() {
        self.createEventNode.toggleSpinner(active: true)
        
        Task { @MainActor in
            do {
                let response: GenderResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/gender",
                    method: "GET"
                )
                
                self.createEventNode.configureGenderDictionaries(response)
                self.createEventNode.toggleSpinner(active: false)
                
            } catch {
                print("❌ Error loading appearance dictionary: \(error)")
                self.createEventNode.toggleSpinner(active: false)
                self.showAlert(text: DivoStrings.failedToLoadAppearance)
            }
        }
    }
    
    private func showAlert(text: String) {

        let alertController = textAlertController(
            context: context, title: nil,
            text: text, actions: [
                TextAlertAction(type: .genericAction, title: "Ok", action: {
                    print("ok")
                })
            ])
        present(alertController, in: .window(.root))
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
            // Fallback для iOS 13 - использовать UIImagePickerController
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
                self.createEventNode.setAvatarLoading(false)
                print("✅ Avatar uploaded, uuid: \(self.selectedAvatarUUID ?? "nil")")
            } catch {
                self.createEventNode.setAvatarLoading(false)
                print("❌ Avatar upload error: \(error)")
                self.showAlert(text: "\(DivoStrings.failedToUploadPhoto): \(error.localizedDescription)")
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
                self.createEventNode.toggleSpinner(active: false)
                self.showAlert(text: DivoStrings.profileUpdated)
                
                self.navigationController?.popViewController(animated: true)
                
            } catch {
                print("❌ Error saving social links: \(error)")
                self.createEventNode.toggleSpinner(active: false)
                self.showAlert(text: error.localizedDescription)
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
                self.createEventNode.toggleSpinner(active: false)
                self.showAlert(text: DivoStrings.profileUpdated)
                
                self.navigationController?.popViewController(animated: true)
                
            } catch {
                print("❌ Error saving social links: \(error)")
                self.createEventNode.toggleSpinner(active: false)
                self.showAlert(text: error.localizedDescription)
            }
        }
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.updatePresentationData(makeNavigationBarPresentationData(), transition: .immediate)
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.createEventNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
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
                self.createEventNode.setAvatarLoading(true)
                self.createEventNode.currentPhoto = normalized
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
        self.createEventNode.setAvatarLoading(true)
        self.createEventNode.currentPhoto = normalized
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
