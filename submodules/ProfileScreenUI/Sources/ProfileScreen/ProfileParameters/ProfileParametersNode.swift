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

final class ProfileParametersNode: ASDisplayNode, UITextFieldDelegate {
    
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
    
    private let genderTextField: TextFieldNode
    private let hairColorTextField: TextFieldNode
    
    private let eyeColorTextField: TextFieldNode
    private let skinColorTextField: TextFieldNode
    private let breastSizeTextField: TextFieldNode
    
    private let ageSliderNode: AgeSliderNode
    private let heightSliderNode: AgeSliderNode
    
    private let waisttSliderNode: AgeSliderNode
    private let hipsSliderNode: AgeSliderNode
    private let shoeSliderNode: AgeSliderNode
    private let hairSliderNode: AgeSliderNode
    
    private let applyButton: ASControlNode
    private let addPhoto: () -> Void
    var showAlert: ((String) -> Void)?
    
    private let model: ProfileModel
    
    init(context: AccountContext, model: ProfileModel, addPhoto: @escaping () -> Void) {
        self.context = context
        self.addPhoto = addPhoto
        self.model = model
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.scrollNode = ASScrollNode()
        
        self.genderTextField = getTextFiel(title: "Select a Gender")
        self.hairColorTextField = getTextFiel(title: "Choose your hair color")
        
        self.eyeColorTextField = getTextFiel(title: "Choose your eye color")
        self.skinColorTextField = getTextFiel(title: "Choose your skin color")
        self.breastSizeTextField = getTextFiel(title: "Choose your breast size")
        
        self.ageSliderNode = AgeSliderNode(title: "Age (y.o)", min: "14", max: "45", value: "17", type: "y.o")
        self.heightSliderNode = AgeSliderNode(title: "Height (cm)", min: "14", max: "250", value: "2.1", type: "cm")
        
        self.waisttSliderNode = AgeSliderNode(title: "Waist (cm)", min: "48", max: "90", value: "2.1", type: "cm")
        self.hipsSliderNode = AgeSliderNode(title: "Hips (cm)", min: "80", max: "110", value: "2.1", type: "cm")
        self.shoeSliderNode = AgeSliderNode(title: "Shoe size (EU)", min: "36", max: "42", value: "2.1", type: "EU")
        self.hairSliderNode = AgeSliderNode(title: "Hair length (cm)", min: "0", max: "200", value: "2.1", type: "cm")
        
        self.applyButton = ButtonWithIconNode(title: "Save", icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        super.init()
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.genderTextField)
        self.scrollNode.addSubnode(self.ageSliderNode)
        self.scrollNode.addSubnode(self.heightSliderNode)
        
        self.scrollNode.addSubnode(self.waisttSliderNode)
        self.scrollNode.addSubnode(self.hipsSliderNode)
        self.scrollNode.addSubnode(self.shoeSliderNode)
        self.scrollNode.addSubnode(self.hairSliderNode)
        
        self.scrollNode.addSubnode(self.hairColorTextField)
        
        self.scrollNode.addSubnode(self.eyeColorTextField)
        self.scrollNode.addSubnode(self.skinColorTextField)
        self.scrollNode.addSubnode(self.breastSizeTextField)
        self.scrollNode.addSubnode(self.applyButton)
    }
    
    deinit {
        self.supportPeerDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didLoad() {
        super.didLoad()
        self.applyButton.addTarget(self, action: #selector(self.applyButtonTapped), forControlEvents: .touchUpInside)
    }

    @objc private func applyButtonTapped() {
        
        print("applyButton Tapped!")
        
        let supportPeer = Promise<String?>()
        let data = ProfileParametersData(
            firstName: nil,
            lastName: nil,
            country: nil,
            about: nil,
            gender: nil,//Api.Gender?
            birthDate: nil,
            height: Int32(heightSliderNode.slider.value.rounded()),
            waist: 0,
            hips: 0,
            shoeSize: 0,
            hairLength: 0,
            hairColor: "String",
            eyeColor: "String",
            skinColor: "String",
            breastSize: "String",
            photoId: nil
        )
        
        supportPeer.set(context.engine.profileEngine.updateProfile(data: data))
        self.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { peerId in
            print("🔕 updateProfile", peerId ?? "")
            self.showAlert?("Saved")
        }))
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
        let topInset = navigationBarHeight
        self.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset))
        
        let sidePadding: CGFloat = 16.0
        let sectionSpacing: CGFloat = 24.0
        let itemHeight: CGFloat = 48.0
        
        var currentY: CGFloat = 30.0
        
        self.genderTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        let measuredSliderHeight = self.ageSliderNode.measure(CGSize(width: layout.size.width - sidePadding * 2, height: .greatestFiniteMagnitude)).height
        let sliderHeight = measuredSliderHeight > 0 ? measuredSliderHeight : 70.0
        
        self.ageSliderNode.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: sliderHeight))
        currentY += sliderHeight + sectionSpacing
        
        self.heightSliderNode.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: sliderHeight))
        currentY += sliderHeight + sectionSpacing
        
        self.waisttSliderNode.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: sliderHeight))
        currentY += sliderHeight + sectionSpacing
        self.hipsSliderNode.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: sliderHeight))
        currentY += sliderHeight + sectionSpacing
        self.shoeSliderNode.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: sliderHeight))
        currentY += sliderHeight + sectionSpacing
        self.hairSliderNode.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: sliderHeight))
        currentY += sliderHeight + sectionSpacing
        
        self.hairColorTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        self.eyeColorTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        self.skinColorTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        self.breastSizeTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        self.applyButton.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: 50.0))
        
        currentY += 70.0
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: currentY)
        self.readyValue = true
    }
}

private func getTextFiel(title: String, isMultiline: Bool = false) -> TextFieldNode {
    let field = TextFieldNode()
    field.textField.font = Font.regular(16.0)
    field.textField.textColor = .white.withAlphaComponent(0.6)
    field.textField.textAlignment = .natural
    field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.4))
    field.textField.autocapitalizationType = .none
    field.textField.autocorrectionType = .no
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
