import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ChatListSearchItemHeader
import AppBundle
import ItemListUI
import Postbox

final class EditProfileNode: ASDisplayNode, UITextFieldDelegate {
    
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let presentationDataPromise: Promise<PresentationData>
    
    private let _ready = Promise<Bool>()
    private var readyValue = false {
        didSet {
            if self.readyValue, self.readyValue != oldValue {
                self._ready.set(.single(self.readyValue))
            }
        }
    }
    var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }
    
    private let scrollNode: ASScrollNode
    
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50
        iv.layer.borderWidth = 3
        iv.layer.borderColor = UIColor.white.cgColor
        iv.backgroundColor = .systemGray
        iv.isUserInteractionEnabled = true
        return iv
    }()
    
    private let nameEventTextField: TextFieldNode
    private let lastNameEventTextField: TextFieldNode
    private let aboutEventTextField: DivoTextView
    
    private let applyButton: ASControlNode
    private let addPhoto: () -> Void
    var showAlert: ((String) -> Void)?
    
    private let model: ProfileModel
    
    var currentPhoto: UIImage? = nil {
        didSet {
            if let currentPhoto = self.currentPhoto {
                avatarImageView.image = currentPhoto
            } else {
                self.avatarImageView.image = nil
            }
        }
    }
    
    private let avatarSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .whiteLarge)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    init(context: AccountContext, model: ProfileModel, addPhoto: @escaping () -> Void) {
        self.context = context
        self.addPhoto = addPhoto
        self.model = model
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.scrollNode = ASScrollNode()

        self.nameEventTextField = getTextFiel(title: model.name)
        if !model.name.isEmpty {
            nameEventTextField.textField.text = model.name
        }
        self.lastNameEventTextField = getTextFiel(title: "Enter Last Name")
        if let lastName = model.lastName {
            lastNameEventTextField.textField.text = lastName
        }
        
        self.aboutEventTextField = DivoTextView(title: "Biography", initialText: model.biography)
        
        self.applyButton = ButtonWithIconNode(title: "Save", icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        super.init()
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        
        self.addSubnode(self.scrollNode)
        
        self.scrollNode.view.addSubview(self.avatarImageView)
        self.scrollNode.view.addSubview(avatarSpinner)
        NSLayoutConstraint.activate([
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor)
        ])
        
        self.scrollNode.addSubnode(self.nameEventTextField)
        self.scrollNode.addSubnode(self.lastNameEventTextField)
        self.scrollNode.addSubnode(self.aboutEventTextField)
        self.scrollNode.addSubnode(self.applyButton)
        
        let avatarTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.avatarTapped))
        self.avatarImageView.addGestureRecognizer(avatarTapGesture)
        
        if !model.photos.isEmpty, let photo = model.photos.first, let representation = largestImageRepresentation(photo.image.representations) {
            let resourceData = context.account.postbox.mediaBox.resourceData(representation.resource)
            let _ = (resourceData
                     |> deliverOnMainQueue).start(next: { [weak self] data in
                if data.complete {
                    if let uiImage = UIImage(contentsOfFile: data.path) {
                        self?.avatarImageView.image = uiImage
                    }
                }
            })
        }
    }
    
    deinit {
        self.supportPeerDisposable.dispose()
    }
    
    
    @objc private func avatarTapped() {
        self.addPhoto()
    }

    func toggleSpinner(active: Bool) {
        if active {
            avatarSpinner.startAnimating()
            avatarImageView.alpha = 0.5
        } else {
            avatarSpinner.stopAnimating()
            avatarImageView.alpha = 1.0
        }
    }
    
    override func didLoad() {
        super.didLoad()
        self.applyButton.addTarget(self, action: #selector(self.updateAccountPeerName), forControlEvents: .touchUpInside)
    }

    @objc private func updateProfileNameAndBio() {
        
        print("updateProfileNameAndBio Tapped!")
        
        let supportPeer = Promise<String?>()
        let data = ProfileParametersData(
            firstName: nameEventTextField.textField.text ?? "",
            lastName: lastNameEventTextField.textField.text ?? "",
            country: nil,
            about: aboutEventTextField.text,
            gender: nil,
            birthDate: nil,
            height: nil,
            waist: nil,
            hips: nil,
            shoeSize: nil,
            hairLength: nil,
            hairColor: nil,
            eyeColor: nil,
            skinColor: nil,
            breastSize: nil,
            photoId: nil
        )
        
        supportPeer.set(context.engine.profileEngine.updateProfileNameAndBio(data: data))
        self.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { peerId in
            print("🔕 updateProfile", peerId ?? "")
            self.showAlert?("Saved")
        }))
    }
    
    @objc private  func updateAccountPeerName() {
        let firstName = nameEventTextField.textField.text ?? ""
        let lastName = lastNameEventTextField.textField.text ?? ""
        let _ = (context.engine.accountData.updateAccountPeerName(firstName: firstName, lastName: lastName)
                 |> castError(UpdateInfoError.self)).start()
        
        enum UpdateInfoError {
            case generic
            case birthdayFlood
        }
        
        let _ = (context.engine.accountData.updateAbout(about: aboutEventTextField.text)
                 |> `catch` { _ -> Signal<Void, NoError> in
            return .complete()
        }).start()
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
        let topInset = navigationBarHeight
        self.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset))
        
        let avatarSize = CGSize(width: 100.0, height: 100.0)
        let avatarX = (layout.size.width - avatarSize.width) / 2.0
        
        self.avatarImageView.frame = CGRect(x: avatarX, y: 20.0, width: avatarSize.width, height: avatarSize.height)
        
        let sidePadding: CGFloat = 16.0
        let sectionSpacing: CGFloat = 24.0
        let itemHeight: CGFloat = 48.0
        
        var currentY: CGFloat = 140.0
        
        self.nameEventTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        self.lastNameEventTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing

        let aboutEventHeight: CGFloat = 100.0
        self.aboutEventTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: aboutEventHeight))
        currentY += aboutEventHeight + sectionSpacing
        
        self.applyButton.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: 50.0))
        
        currentY += 70.0
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: currentY)
        self.readyValue = true
    }
}

private func getTextFiel(title: String, isMultiline: Bool = false) -> TextFieldNode {
    let field = TextFieldNode()
    field.textField.font = Font.regular(16.0)
    field.textField.textColor = .white
    field.textField.textAlignment = .natural
    field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.4))
    field.textField.autocapitalizationType = .none
    field.textField.autocorrectionType = .no
    //    field.textField.keyboardType = .URL
    field.borderWidth = 1.0
    field.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4).cgColor
    field.cornerRadius = 11.0
    field.clipsToBounds = true
    if isMultiline {
        field.padding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    } else {
        field.padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
    
    return field
}
