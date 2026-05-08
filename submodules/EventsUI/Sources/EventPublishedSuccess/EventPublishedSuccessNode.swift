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

final class EventPublishedSuccessNode: ASDisplayNode {
    var onViewEvent: (() -> Void)?
    var onManageApplications: (() -> Void)?
    var onBackTapped: (() -> Void)?
        
    private let emptyModelsIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.badgeCalendar
        iv.contentMode = .center
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.textInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
        label.font = Font.helveticaNeue(26)
        label.textColor = DivoColorPalette.secondaryButtonPressed
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.titleCreateEvent.uppercased()
        return label
    }()
    
    private let subtitleLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.textInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.subtitleCreateEvent
        return label
    }()
    
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let viewEventButton = DivoButton()
    private let manageAppsButton = DivoButton()
    
    override init() {
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground
            
        viewEventButton.makeDivoButton(title: DivoStrings.viewEventPage, buttonFont: Font.helveticaNeue(20), radius: 28)
        viewEventButton.addTarget(self, action: #selector(viewTapped), for: .touchUpInside)
        
        manageAppsButton.makeDivoButton(title: DivoStrings.manageApplications, buttonFont: Font.helveticaNeue(20), radius: 28, divoButtonStyle: .secondary)
        manageAppsButton.backgroundColor = DivoColorPalette.secondaryButtonBackground
        manageAppsButton.addTarget(self, action: #selector(manageTapped), for: .touchUpInside)
        
        view.addSubview(contentStack)
                
        contentStack.addArrangedSubview(emptyModelsIcon)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        
        contentStack.setCustomSpacing(14, after: emptyModelsIcon)
        contentStack.setCustomSpacing(6, after: titleLabel)
        
        self.view.addSubview(viewEventButton)
        self.view.addSubview(manageAppsButton)
        
        let centerGuide = UILayoutGuide()
        view.addLayoutGuide(centerGuide)
        
        NSLayoutConstraint.activate([
            emptyModelsIcon.widthAnchor.constraint(equalToConstant: 68),
            emptyModelsIcon.heightAnchor.constraint(equalToConstant: 68),
            
            centerGuide.topAnchor.constraint(equalTo: self.view.topAnchor),
            centerGuide.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            centerGuide.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            centerGuide.bottomAnchor.constraint(equalTo: viewEventButton.topAnchor),
            
            contentStack.centerYAnchor.constraint(equalTo: centerGuide.centerYAnchor),
            contentStack.centerXAnchor.constraint(equalTo: centerGuide.centerXAnchor),
            
            contentStack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            contentStack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            manageAppsButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor),
            manageAppsButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            manageAppsButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            manageAppsButton.heightAnchor.constraint(equalToConstant: 56),
            
            viewEventButton.bottomAnchor.constraint(equalTo: manageAppsButton.topAnchor, constant: -10),
            viewEventButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            viewEventButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            viewEventButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }
    
    @objc private func viewTapped() { onViewEvent?() }
    @objc private func manageTapped() { onManageApplications?() }
}
