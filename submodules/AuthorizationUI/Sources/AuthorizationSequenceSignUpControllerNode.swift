import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown
import SolidRoundedButtonNode
import AuthorizationUtils
import DivoUIKit

final class AuthorizationSequenceSignUpControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let proceedNode: SolidRoundedButtonNode
    private var typeOfRole: String = ""
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    private let appearanceTimestamp = CACurrentMediaTime()
    
    var currentName: (String, String) {
        return ("", "")
    }
    
    var signUpWithName: ((String, String) -> Void)?
    var openTermsOfService: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress != oldValue {
                if self.inProgress {
                    self.proceedNode.transitionToProgress()
                } else {
                    self.proceedNode.transitionFromProgress()
                }
            }
        }
    }
    
    private let scrollNode: ASScrollNode
    private let contentNode: ASDisplayNode
    
    private let titleNode: ASTextNode
    private let subtitleNode: ASTextNode
    
    private let talentNode: RoleSelectionNode
    private let modelNode: RoleSelectionNode
    private let agencyNode: RoleSelectionNode
    private let fanNode: RoleSelectionNode
    
    private var selectedNode: RoleSelectionNode?
    private let backgroundNode: ASImageNode
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.view.showsVerticalScrollIndicator = false
        // Включаем автоматическую подстройку под Safe Area (челку)
        self.scrollNode.view.contentInsetAdjustmentBehavior = .always
        
        self.contentNode = ASDisplayNode()

        let customButtonTheme = SolidRoundedButtonTheme(
            backgroundColor: DivoColorPalette.accentCopperDeep,
            foregroundColor: .white,
            disabledBackgroundColor: DivoColorPalette.accentCopperDeep,
            disabledForegroundColor: .white
        )
        
        self.proceedNode = SolidRoundedButtonNode(title: self.strings.Login_Continue, theme: customButtonTheme, glass: false, height: 50.0, cornerRadius: 11.0)
        self.proceedNode.progressType = .embedded
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = Font.helveticaNeue("Choose a role".uppercased(), 34)
        
        self.subtitleNode = ASTextNode()
        let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        self.subtitleNode.attributedText = NSAttributedString(string: "Select the role that your profile will correspond to. The role can be changed at any time", attributes:[
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: DivoColorPalette.overlayDarkMediumLine,
            .paragraphStyle: paragraphStyle
        ])
        
        self.talentNode = RoleSelectionNode(
            roleImage: DivoImage.signUpNewTalent,
            title: "NEW TALENT",
            description: "I don’t have any experience / have little experience. I’m new in.",
            typeOfRole: "TALENT"
        )
        self.modelNode = RoleSelectionNode(
            roleImage: DivoImage.signUpModel,
            title: "MODEL",
            description: "I have working experience as a model. I’m professional.",
            typeOfRole: "MODEL"
        )
        self.agencyNode = RoleSelectionNode(
            roleImage: DivoImage.signUpAgencies,
            title: "AGENCIES & SCOUTS",
            description: "Looking for / working with models.",
            typeOfRole: "AGENCIES"
        )
        self.fanNode = RoleSelectionNode(
            roleImage: DivoImage.signUpFan,
            title: "FAN",
            description: "I will view other users' content. I am a fan.",
            typeOfRole: "FAN"
        )

        self.backgroundNode = ASImageNode()
        self.backgroundNode.contentMode = .scaleAspectFill
        self.backgroundNode.image = DivoImage.signUpChooseRoleBackground
        self.backgroundNode.displaysAsynchronously = false
        
        super.init()
        
        self.automaticallyManagesSubnodes = true
        self.backgroundColor = DivoColorPalette.darkBackground
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.scrollNode)
        
        self.scrollNode.addSubnode(self.contentNode)
        
        self.contentNode.addSubnode(titleNode)
        self.contentNode.addSubnode(subtitleNode)
        self.contentNode.addSubnode(talentNode)
        self.contentNode.addSubnode(modelNode)
        self.contentNode.addSubnode(agencyNode)
        self.contentNode.addSubnode(fanNode)
        self.contentNode.addSubnode(proceedNode)
        
        self.talentNode.tapped = { [weak self] in self?.selectNode(self!.talentNode) }
        self.modelNode.tapped = { [weak self] in self?.selectNode(self!.modelNode) }
        self.agencyNode.tapped = {[weak self] in self?.selectNode(self!.agencyNode) }
        self.fanNode.tapped = { [weak self] in self?.selectNode(self!.fanNode) }
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.proceedNode.pressed = { [weak self] in
            if let strongSelf = self,
               let typeOfRole = strongSelf.selectedNode?.typeOfRole {
                let name = strongSelf.currentName
                strongSelf.signUpWithName?(typeOfRole, name.1)
            }
        }
    }
    
    // MARK: - Setup Constraints (Auto Layout)
    override func didLoad() {
        super.didLoad()
        
        let nodesToConstraint = [
            backgroundNode, scrollNode, contentNode, proceedNode,
            titleNode, subtitleNode, talentNode, modelNode, agencyNode, fanNode
        ]
        
        nodesToConstraint.forEach { $0.view.translatesAutoresizingMaskIntoConstraints = false }
        
        let safeArea = self.view.safeAreaLayoutGuide
        let contentGuide = scrollNode.view.contentLayoutGuide
        let frameGuide = scrollNode.view.frameLayoutGuide
        
        NSLayoutConstraint.activate([
            // --- Фон ---
            backgroundNode.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            backgroundNode.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            backgroundNode.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            backgroundNode.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            // --- Скролл на весь экран ---
            scrollNode.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            scrollNode.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollNode.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollNode.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            // --- Content Node ---
            contentNode.view.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            contentNode.view.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            contentNode.view.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            contentNode.view.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor),
            contentNode.view.widthAnchor.constraint(equalTo: frameGuide.widthAnchor),
            contentNode.view.heightAnchor.constraint(greaterThanOrEqualTo: safeArea.heightAnchor),
            
            // --- Title ---
            titleNode.view.topAnchor.constraint(equalTo: contentNode.view.topAnchor, constant: 30),
            titleNode.view.heightAnchor.constraint(equalToConstant: 50),
            titleNode.view.centerXAnchor.constraint(equalTo: contentNode.view.centerXAnchor),
            titleNode.view.leadingAnchor.constraint(equalTo: contentNode.view.leadingAnchor, constant: 16),
            titleNode.view.trailingAnchor.constraint(equalTo: contentNode.view.trailingAnchor, constant: -16),
            
            // --- Subtitle ---
            subtitleNode.view.topAnchor.constraint(equalTo: titleNode.view.bottomAnchor, constant: 6),
            subtitleNode.view.centerXAnchor.constraint(equalTo: contentNode.view.centerXAnchor),
            subtitleNode.view.leadingAnchor.constraint(equalTo: contentNode.view.leadingAnchor, constant: 58),
            subtitleNode.view.trailingAnchor.constraint(equalTo: contentNode.view.trailingAnchor, constant: -58),
            subtitleNode.view.heightAnchor.constraint(equalToConstant: 80),
            
            // --- Talent Node ---
            talentNode.view.topAnchor.constraint(equalTo: subtitleNode.view.bottomAnchor, constant: 0),
            talentNode.view.leadingAnchor.constraint(equalTo: contentNode.view.leadingAnchor, constant: 16),
            talentNode.view.trailingAnchor.constraint(equalTo: contentNode.view.trailingAnchor, constant: -16),
            talentNode.view.heightAnchor.constraint(equalToConstant: 117),
            
            // --- Model Node ---
            modelNode.view.topAnchor.constraint(equalTo: talentNode.view.bottomAnchor, constant: 16),
            modelNode.view.leadingAnchor.constraint(equalTo: contentNode.view.leadingAnchor, constant: 16),
            modelNode.view.trailingAnchor.constraint(equalTo: contentNode.view.trailingAnchor, constant: -16),
            modelNode.view.heightAnchor.constraint(equalToConstant: 117),
            
            // --- Agency Node ---
            agencyNode.view.topAnchor.constraint(equalTo: modelNode.view.bottomAnchor, constant: 16),
            agencyNode.view.leadingAnchor.constraint(equalTo: contentNode.view.leadingAnchor, constant: 16),
            agencyNode.view.trailingAnchor.constraint(equalTo: contentNode.view.trailingAnchor, constant: -16),
            agencyNode.view.heightAnchor.constraint(equalToConstant: 117),
            
            // --- Fan Node ---
            fanNode.view.topAnchor.constraint(equalTo: agencyNode.view.bottomAnchor, constant: 16),
            fanNode.view.leadingAnchor.constraint(equalTo: contentNode.view.leadingAnchor, constant: 16),
            fanNode.view.trailingAnchor.constraint(equalTo: contentNode.view.trailingAnchor, constant: -16),
            fanNode.view.heightAnchor.constraint(equalToConstant: 117),
            
            // --- Кнопка Продолжить ---
            proceedNode.view.leadingAnchor.constraint(equalTo: contentNode.view.leadingAnchor, constant: 16),
            proceedNode.view.trailingAnchor.constraint(equalTo: contentNode.view.trailingAnchor, constant: -16),
            proceedNode.view.heightAnchor.constraint(equalToConstant: 50),
            
            proceedNode.view.topAnchor.constraint(greaterThanOrEqualTo: fanNode.view.bottomAnchor, constant: 20),
            proceedNode.view.bottomAnchor.constraint(equalTo: contentNode.view.bottomAnchor, constant: -20),
        ])
    }
    
    private func selectNode(_ node: RoleSelectionNode) {
        selectedNode?.isSelected = false
        selectedNode = node
        selectedNode?.isSelected = true
    }
    
    func updateData(firstName: String, lastName: String, hasTermsOfService: Bool) {
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layoutArguments = (layout, navigationBarHeight)
        self.proceedNode.isHidden = false

        let maximumWidth: CGFloat = min(430.0, layout.size.width)
        let _ = self.proceedNode.updateLayout(width: maximumWidth - 32.0, transition: transition)
    }
    
    func activateInput() {
    }
    
    func animateError() {
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return false
    }
}
