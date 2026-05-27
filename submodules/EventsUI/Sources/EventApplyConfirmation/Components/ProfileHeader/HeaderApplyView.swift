//
//  HeaderApplyView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

class HeaderApplyView: UIView {
    
    static let avatarSize: CGFloat = 68
    
    private let avatarImageView: UIImageView = {
        let avatarImageView = UIImageView()
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.backgroundColor = DivoColorPalette.imagePlaceholderLight
        avatarImageView.layer.cornerRadius = avatarSize / 2
        return avatarImageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(32)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let eventTypeLabelContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.roleBadgeBlue
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let eventTypeLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(11)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let eventMetaLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        let textStack = UIStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 18
        textStack.alignment = .center
        
        textStack.addArrangedSubview(avatarImageView)
        textStack.addArrangedSubview(nameLabel)
        
        let infoStack = UIStackView()
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoStack.axis = .horizontal
        infoStack.spacing = 10
        infoStack.alignment = .center
        infoStack.addArrangedSubview(eventTypeLabelContainer)
        eventTypeLabelContainer.addSubview(eventTypeLabel)
        infoStack.addArrangedSubview(eventMetaLabel)
        
        textStack.addArrangedSubview(infoStack)
        
        addSubview(textStack)
        
        eventTypeLabelContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            textStack.topAnchor.constraint(equalTo: topAnchor),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            
            eventTypeLabelContainer.heightAnchor.constraint(equalToConstant: 22),
            
            eventTypeLabel.leadingAnchor.constraint(equalTo: eventTypeLabelContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            eventTypeLabel.centerYAnchor.constraint(equalTo: eventTypeLabelContainer.centerYAnchor),
            eventTypeLabel.trailingAnchor.constraint(equalTo: eventTypeLabelContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
        ])
        
        textStack.setCustomSpacing(6, after: nameLabel)
    }
    
    func configure(fullUrl: String? = nil, fullName: String? = nil, eventType: String? = nil, eventInfo: String? = nil) {
        nameLabel.text = fullName
        eventTypeLabel.text = eventType
        eventMetaLabel.text = eventInfo
        
        if let avatarURL = CDNURLHelper.convertToCDNURL(fullUrl) {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: avatarURL)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.avatarImageView.image = image
                            self.avatarImageView.applyAvatarTopCropIfNeeded(image: image)
                        }
                    }
                } catch {}
            }
        }
        self.layoutIfNeeded()
    }
}
