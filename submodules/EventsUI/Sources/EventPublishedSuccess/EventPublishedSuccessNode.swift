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
    
    private let navBar = DivoNavigationBar()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let viewEventButton = DivoButton()
    private let manageAppsButton = DivoButton()
    
    init(eventTitle: String) {
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground
        
        navBar.makeNavigationBar(
            title: "",
            backButtonConfiguration: .circle(UIImage(bundleImageName: "Components/SearchCloseIcon")!),
            onBackTapped: { [weak self] in self?.onBackTapped?() }
        )
        
        iconImageView.image = UIImage(bundleImageName: "Components/CalendarCheck") // Иконка с галочкой
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = DivoColorPalette.primaryText
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.text = "YOUR EVENT IS LIVE!"
        titleLabel.font = Font.bold(24)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        subtitleLabel.text = "\(eventTitle) is now\nvisible to all users"
        subtitleLabel.font = Font.regular(16)
        subtitleLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        viewEventButton.makeDivoButton(title: "View event page", buttonFont: Font.helveticaNeue(16), radius: 28)
        viewEventButton.translatesAutoresizingMaskIntoConstraints = false
        viewEventButton.addTarget(self, action: #selector(viewTapped), for: .touchUpInside)
        
        manageAppsButton.makeDivoButton(title: "Manage applications", buttonFont: Font.helveticaNeue(16), radius: 28)
        manageAppsButton.backgroundColor = DivoColorPalette.darkBackground
        manageAppsButton.setTitleColor(.white, for: .normal)
        manageAppsButton.translatesAutoresizingMaskIntoConstraints = false
        manageAppsButton.addTarget(self, action: #selector(manageTapped), for: .touchUpInside)
        
        self.view.addSubview(navBar)
        self.view.addSubview(iconImageView)
        self.view.addSubview(titleLabel)
        self.view.addSubview(subtitleLabel)
        self.view.addSubview(viewEventButton)
        self.view.addSubview(manageAppsButton)
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            
            iconImageView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -100),
            iconImageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -32),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -32),
            
            manageAppsButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            manageAppsButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            manageAppsButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            manageAppsButton.heightAnchor.constraint(equalToConstant: 56),
            
            viewEventButton.bottomAnchor.constraint(equalTo: manageAppsButton.topAnchor, constant: -12),
            viewEventButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            viewEventButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            viewEventButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }
    
    @objc private func viewTapped() { onViewEvent?() }
    @objc private func manageTapped() { onManageApplications?() }
}
