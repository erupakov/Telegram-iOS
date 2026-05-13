//
//  HeaderAvater.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 13.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

class HeaderSettings: UIView {
    
    static let avatarSize: CGFloat = 94
    
    private let avatarImageView: UIImageView = {
        let avatarImageView = UIImageView()
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.backgroundColor = DivoColorPalette.imagePlaceholderLight
        avatarImageView.layer.cornerRadius = avatarSize / 2
        avatarImageView.layer.borderWidth = 1
        avatarImageView.layer.borderColor = DivoColorPalette.cardBackground.cgColor
        return avatarImageView
    }()
    
    private let nameLabel: UILabel = {
        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = Font.medium(18)
        nameLabel.textColor = DivoColorPalette.settingsNameText
        return nameLabel
    }()
    
    private let phoneLabel: UILabel = {
        let phoneLabel = UILabel()
        phoneLabel.translatesAutoresizingMaskIntoConstraints = false
        phoneLabel.font = Font.regular(14)
        phoneLabel.textColor = DivoColorPalette.settingsPhoneText
        return phoneLabel
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
        textStack.spacing = 12
        textStack.alignment = .center
        
        textStack.addArrangedSubview(avatarImageView)
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(phoneLabel)
        
        addSubview(textStack)
        
        NSLayoutConstraint.activate([
            textStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
        ])
        
        textStack.setCustomSpacing(6, after: nameLabel)
    }
    
    func configure(fullUrl: String? = nil, fullName: String? = nil, phone: String? = nil) {
        phoneLabel.isHidden = fullName == nil
        nameLabel.text = fullName
        phoneLabel.isHidden = phone == nil
        phoneLabel.text = phone
        
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
