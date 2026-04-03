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
import MediaPickerUI
import AttachmentUI
import MediaEditorScreen
import CameraScreen
import Camera
import CountrySelectionUI
import ChatScheduleTimeController
import MapResourceToAvatarSizes
import LegacyComponents
import Photos

protocol AddModelControllerDelegate: AnyObject {
    func didUpdateProfileData()
}

public class AddModelController: ViewController {
    private let context: AccountContext

    private var createAddModelNode: AddModelNode {
        return self.displayNode as! AddModelNode
    }

    private var presentationData: PresentationData
    private var presentationDataDisposable: Any?

    private var selectedAvatarImage: UIImage?
    private var selectedAvatarUUID: String?
    private var avatarPickerHolder: Any?

    weak var delegate: EditProfileDelegate?
    
    public init(context: AccountContext, presentationData: PresentationData) {
        self.context = context

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
        (self.presentationDataDisposable as? Disposable)?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AddModelNode(
            context: self.context,
            presentationData: presentationData
        )
 
        self.createAddModelNode.saveProfile = { [weak self] rawData in
            self?.handleSave(with: rawData)
        }

        self.createAddModelNode.showAlert = { [weak self] text in
            self?.showAlert(text: text)
        }
        
        self.createAddModelNode.onAvatarTap = { [weak self] in
            self?.openPhotoGallery()
        }
        
        self.createAddModelNode.onExitTapped = {[weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.createAddModelNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme, displayCodes: false, glass: true)
                controller.completeWithCountryCode = { _, countryId, name in
                    
                    if let strongSelf = self {
                        strongSelf.createAddModelNode.updateCountry(countryId: countryId, countryName: name)
                    }
                }
                controller.dismissed = {
//                    self?.controllerNode.activateInput()
                }
                strongSelf.push(controller)
            }
        }

        self.displayNodeDidLoad()

        self.loadAppearanceDictionary()
        self.loadGenderDictionary()
    }

    private func loadAppearanceDictionary() {
        self.createAddModelNode.toggleSpinner(active: true)
        
        Task { @MainActor in
            do {
                let response: AppearanceDictionaryResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/appearances",
                    method: "GET"
                )
                
                self.createAddModelNode.configureAppearanceDictionaries(response.data)
                self.createAddModelNode.toggleSpinner(active: false)
                
            } catch {
                print("❌ Error loading appearance dictionary: \(error)")
                self.createAddModelNode.toggleSpinner(active: false)
                self.showAlert(text: "Failed to load appearance options.")
            }
        }
    }
    
    private func loadGenderDictionary() {
        self.createAddModelNode.toggleSpinner(active: true)
        
        Task { @MainActor in
            do {
                let response: GenderResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/gender",
                    method: "GET"
                )
                
                self.createAddModelNode.configureGenderDictionaries(response)
                self.createAddModelNode.toggleSpinner(active: false)
                
            } catch {
                print("❌ Error loading appearance dictionary: \(error)")
                self.createAddModelNode.toggleSpinner(active: false)
                self.showAlert(text: "Failed to load appearance options.")
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
    
    private func openPhotoGallery() {
        self.avatarPickerHolder = nil

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) = (presentationData, .single(presentationData))

        let controller = AttachmentController(
            context: self.context,
            updatedPresentationData: updatedPresentationData,
            style: .glass,
            chatLocation: nil,
            buttons: [.standalone],
            initialButton: .standalone,
            fromMenu: false,
            hasTextInput: false,
            makeEntityInputView: { return nil }
        )

        controller.requestController = { [weak self, weak controller] _, present in
            guard let self = self, let strongController = controller else { return }

            let mediaPickerController = MediaPickerScreenImpl(
                context: self.context,
                updatedPresentationData: updatedPresentationData,
                style: .glass,
                peer: nil,
                threadTitle: nil,
                chatLocation: nil,
                bannedSendPhotos: nil,
                bannedSendVideos: nil,
                subject: .assets(nil, .addImage), // Это правильно
                mainButtonState: nil,
                mainButtonAction: nil
            )
            
            // ВАЖНО: Убедитесь, что openCamera установлен ДО того, как презентуется контроллер
            mediaPickerController.openCamera = { [weak self, weak strongController] cameraHolder in
                guard let self = self, let strongController = strongController else { return }
                
                // Для addImage нужно создать cameraHolder
                if let cameraHolder = cameraHolder as? CameraHolder {
                    // Используем существующий cameraHolder
                    let cameraScreen = self.context.sharedContext.makeCameraScreen(
                        context: self.context,
                        mode: .avatar, // или .sticker в зависимости от нужд
                        cameraHolder: cameraHolder,
                        transitionIn: CameraScreenTransitionIn(
                            sourceView: cameraHolder.parentView,
                            sourceRect: cameraHolder.parentView.bounds,
                            sourceCornerRadius: 0.0,
                            useFillAnimation: false
                        ),
                        transitionOut: { _ in
                            return CameraScreenTransitionOut(
                                destinationView: cameraHolder.parentView,
                                destinationRect: cameraHolder.parentView.bounds,
                                destinationCornerRadius: 0.0
                            )
                        },
                        completion: { [weak strongController] result, commit in
                            guard let strongController = strongController else { commit(); return }
                            
                            if let imageResult = result as? CameraScreenImpl.Result {
                                switch imageResult {
                                case let .image(image):
                                    let subject: Signal<MediaEditorScreenImpl.Subject?, NoError> = .single(.image(
                                        image: image.image,
                                        dimensions: PixelDimensions(image.image.size),
                                        additionalImage: nil,
                                        additionalImagePosition: .bottomRight,
                                        fromCamera: true
                                    ))
                                    
                                    strongController.dismiss(animated: false) {
                                        self.openAvatarEditor(subject: subject, fromCamera: true)
                                    }
                                default:
                                    break
                                }
                            }
                            commit()
                        },
                        transitionedOut: { [weak cameraHolder] in
                            cameraHolder?.restore()
                        }
                    )
                    strongController.push(cameraScreen)
                } else {
                    // Если cameraHolder не пришел, создаем новый
                    // Здесь нужно создать CameraHolder аналогично тому, как это делается в MediaPickerScreenImpl.Node
                    self.showAlert(text: "Camera not available")
                }
            }

            mediaPickerController.customSelection = { [weak self, weak strongController] mediaController, result in
                guard let strongController = strongController else { return }

                if let asset = result as? PHAsset {
                    if asset.mediaType == .video { return }
                    mediaController.updateHiddenMediaId(asset.localIdentifier)
                    
                    let transitionView = mediaController.transitionView(for: asset.localIdentifier, snapshot: false)
                    let transitionRect = transitionView?.bounds ?? .zero
                    let transitionImage = mediaController.transitionImage(for: asset.localIdentifier)
                    
                    let subject: Signal<MediaEditorScreenImpl.Subject?, NoError> = .single(.asset(asset))

                    strongController.dismiss(animated: true) {
                        self?.openAvatarEditor(
                            subject: subject,
                            fromCamera: false,
                            transitionView: transitionView,
                            transitionImage: transitionImage,
                            transitionRect: transitionRect
                        )
                    }
                } else if let image = result as? UIImage {
                    let subject: Signal<MediaEditorScreenImpl.Subject?, NoError> = .single(.image(
                        image: image,
                        dimensions: PixelDimensions(image.size),
                        additionalImage: nil,
                        additionalImagePosition: .bottomRight,
                        fromCamera: false
                    ))

                    strongController.dismiss(animated: true) {
                        self?.openAvatarEditor(subject: subject, fromCamera: false)
                    }
                }
            }

            present(mediaPickerController, mediaPickerController.mediaPickerContext)
        }

        controller.navigationPresentation = .flatModal
        controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)

        self.avatarPickerHolder = controller
        self.present(controller, in: .window(.root))
    }
    
    private func openAvatarEditor(
        subject: Signal<MediaEditorScreenImpl.Subject?, NoError>,
        fromCamera: Bool,
        transitionView: UIView? = nil,
        transitionImage: UIImage? = nil,
        transitionRect: CGRect = .zero
    ) {
        let transitionIn: MediaEditorScreenImpl.TransitionIn? = fromCamera ? .camera : transitionView.flatMap({ view in
            .gallery(MediaEditorScreenImpl.TransitionIn.GalleryTransitionIn(
                sourceView: view,
                sourceRect: transitionRect,
                sourceImage: transitionImage
            ))
        })

        let editorController = MediaEditorScreenImpl(
            context: self.context,
            mode: .avatarEditor,
            subject: subject,
            transitionIn: transitionIn,
            transitionOut: { _, _ in return nil },
            willComplete: { _, _, commit in commit() },
            completion: { [weak self] results, commit in
                guard let result = results.first else {
                    commit({})
                    return
                }
                switch result.media {
                case let .image(image, _):
                    self?.createAddModelNode.setAvatarLoading(true)
                    DispatchQueue.main.async {
                        let normalized = image.fixedOrientation()
                        self?.createAddModelNode.currentPhoto = normalized
                        self?.uploadAvatar(image: normalized)
                    }
                default:
                    break
                }
                commit({})
            } as ([MediaEditorScreenImpl.Result], @escaping (@escaping () -> Void) -> Void) -> Void
        )

        self.present(editorController, in: .current)
    }

    private func uploadAvatar(image: UIImage) {
        self.selectedAvatarImage = image
        self.selectedAvatarUUID = nil

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            self.createAddModelNode.setAvatarLoading(false)
            return
        }

        Task { @MainActor in
            do {
                let response: FileUploadResponse = try await DivoAPIClient.shared.upload(
                    path: "/file/upload-file",
                    fileData: imageData
                )
                self.selectedAvatarUUID = response.data?.uuid
                self.createAddModelNode.setAvatarLoading(false)
                print("✅ Avatar uploaded, uuid: \(self.selectedAvatarUUID ?? "nil")")
            } catch {
                self.createAddModelNode.setAvatarLoading(false)
                print("❌ Avatar upload error: \(error)")
                self.showAlert(text: "Failed to upload photo: \(error.localizedDescription)")
            }
        }
    }

    private func handleSave(with rawData: UpdateBiographyPageRequest) {
        // Task { @MainActor in
        //     do {
        //         let avatarUuid = self.selectedAvatarUUID.map {
        //             UpdateBiographyPageRequest.AvatarUuid(uuid: $0)
        //         }
        //         let request = UpdateBiographyPageRequest(
        //             fullName: rawData.fullName,
        //             gender: rawData.gender,
        //             model: rawData.model,
        //             avatar: avatarUuid
        //         )

        //         let response: UpdateBiographyPageResponse = try await DivoAPIClient.shared.request(
        //             path: "/user/update-profile",
        //             method: "POST",
        //             body: request
        //         )
                
        //         print("✅ Profile successfully saved: \(response.message ?? "OK")")
        //         self.delegate?.didUpdateProfileData()
        //         self.createAddModelNode.toggleSpinner(active: false)
        //         self.showAlert(text: "Profile updated")
                
        //         self.navigationController?.popViewController(animated: true)
                
        //     } catch {
        //         print("❌ Error saving social links: \(error)")
        //         self.createAddModelNode.toggleSpinner(active: false)
        //         self.showAlert(text: error.localizedDescription)
        //     }
        // }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.createAddModelNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}