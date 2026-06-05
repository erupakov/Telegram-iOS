//
//  RosterUserView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 01.06.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

final class RosterUserView: UIView {
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 26
        iv.backgroundColor = DivoColorPalette.imagePlaceholderMedium
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let premiumImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.premiumIcon
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()

    private let nameStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let statusIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let separator = UIView()

    init() {
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.heightAnchor.constraint(equalToConstant: 62).isActive = true
        self.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width - DivoDesignTokens.Spacing.xl).isActive = true
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        addSubview(avatarImageView)
        
        nameStackView.addArrangedSubview(nameLabel)
        nameStackView.addArrangedSubview(premiumImageView)
        addSubview(nameStackView)
        
        statusStackView.addArrangedSubview(statusIconView)
        statusStackView.addArrangedSubview(statusLabel)
        addSubview(statusStackView)

        separator.backgroundColor = DivoColorPalette.separatorSystem
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 52),
            avatarImageView.heightAnchor.constraint(equalToConstant: 52),

            nameStackView.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameStackView.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -1),
            nameStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            premiumImageView.widthAnchor.constraint(equalToConstant: 20),
            premiumImageView.heightAnchor.constraint(equalToConstant: 20),

            statusStackView.leadingAnchor.constraint(equalTo: nameStackView.leadingAnchor),
            statusStackView.topAnchor.constraint(equalTo: centerYAnchor, constant: 3),
            statusStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            statusIconView.widthAnchor.constraint(equalToConstant: 14),
            statusIconView.heightAnchor.constraint(equalToConstant: 14),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    func setupSeparator(isHidden: Bool) {
        separator.isHidden = isHidden
    }

    func configure(with user: RosterSearchUser, searchText: String = "") {
        if !searchText.isEmpty {
            let attributed = NSMutableAttributedString(string: user.name)
            let range = (user.name.lowercased() as NSString).range(of: searchText.lowercased())
            if range.location != NSNotFound {
                attributed.addAttribute(.foregroundColor, value: DivoColorPalette.accent, range: range)
            }
            nameLabel.attributedText = attributed
        } else {
            nameLabel.attributedText = nil
            nameLabel.text = user.name
        }
        
        premiumImageView.isHidden = !user.isPremium

        switch user.status {
        case .available(let handle, let role):
            statusIconView.isHidden = true
            statusLabel.text = "@\(handle) · \(role)"
            statusLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
            avatarImageView.alpha = 1.0

        case .alreadyAdded:
            statusIconView.isHidden = true
            statusLabel.text = DivoStrings.addModelSearchAlreadyAdded
            statusLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.4)
            avatarImageView.alpha = 0.5
        }

        let placeholder = DivoImage.emptyBackgroundAvatar
        if let photoURLString = user.avatarUrl, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
            avatarImageView.loadImage(from: photoURL, placeholder: placeholder, cropAvatarIfNeeded: true)
        } else {
            avatarImageView.image = placeholder
        }
    }
}
