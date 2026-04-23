//
//  ProfileHeaderView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.02.2026.
//

import UIKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit

struct UserProfileViewModel {
    enum Job {
        case model
        case agency
        case talent
    }
    
    let name: String
    let age: Int?
    let location: String
    let countryFlag: String
    let role: Role
    let avatarImage: UIImage?
    let isPremium: Bool
    let isOnline: Bool
    
    init(
        name: String,
        age: Int?,
        location: String,
        countryFlag: String,
        role: Role,
        avatarImage: UIImage?,
        isPremium: Bool,
        isOnline: Bool
    ) {
        self.name = name
        self.age = age
        self.location = location
        self.countryFlag = countryFlag
        self.role = role
        self.avatarImage = avatarImage
        self.isPremium = isPremium
        self.isOnline = isOnline
    }
}


class ProfileHeaderView: UIView {
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = DivoColorPalette.cardBackground
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var nameLabelHeightConstraint: NSLayoutConstraint!

    private let premiumBadgeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let premiumBadgeIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.premiumIcon
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let premiumBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(11)
        label.textColor = DivoColorPalette.accent
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.premiumLabel
        label.numberOfLines = 1
        return label
    }()
    
    private let roleContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.roleBadgeBlue
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(11)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.cardBackground
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(nameLabel)

        addSubview(premiumBadgeContainer)
        premiumBadgeContainer.addSubview(premiumBadgeIcon)
        premiumBadgeContainer.addSubview(premiumBadgeLabel)
        
        addSubview(roleContainer)
        roleContainer.addSubview(roleLabel)
        
        addSubview(infoLabel)
    }
    
    private func setupConstraints() {
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        premiumBadgeContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        premiumBadgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            premiumBadgeContainer.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            premiumBadgeContainer.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            premiumBadgeContainer.bottomAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs),
            premiumBadgeContainer.heightAnchor.constraint(equalToConstant: 22),

            premiumBadgeIcon.centerYAnchor.constraint(equalTo: premiumBadgeContainer.centerYAnchor),
            premiumBadgeIcon.leadingAnchor.constraint(equalTo: premiumBadgeContainer.leadingAnchor, constant: 6),

            premiumBadgeLabel.centerYAnchor.constraint(equalTo: premiumBadgeContainer.centerYAnchor),
            premiumBadgeLabel.leadingAnchor.constraint(equalTo: premiumBadgeIcon.trailingAnchor, constant: 2),
            premiumBadgeLabel.trailingAnchor.constraint(equalTo: premiumBadgeContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            
            roleContainer.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
            roleContainer.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            roleContainer.heightAnchor.constraint(equalToConstant: 22),
            roleContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            roleLabel.leadingAnchor.constraint(equalTo: roleContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            roleLabel.centerYAnchor.constraint(equalTo: roleContainer.centerYAnchor),
            roleLabel.trailingAnchor.constraint(equalTo: roleContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),

            infoLabel.leadingAnchor.constraint(equalTo: roleContainer.trailingAnchor, constant: 10),
            infoLabel.centerYAnchor.constraint(equalTo: roleContainer.centerYAnchor),
            infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
    }
    
    func configure(with viewModel: UserProfileViewModel) {
        let font = Font.helveticaNeue(32)
        let attributes:[NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: DivoColorPalette.cardBackground,
            .kern: 0.5
        ]
        
        nameLabel.attributedText = NSAttributedString(string: viewModel.name, attributes: attributes)
        
        roleLabel.text = viewModel.role.title

        var fullLocationString: String
        if let age = viewModel.age {
            fullLocationString = "\(DivoStrings.ageString(age)) • \(viewModel.countryFlag) \(viewModel.location)"
        } else {
            fullLocationString = "\(viewModel.countryFlag) \(viewModel.location)"
        }
        infoLabel.text = fullLocationString
        
        premiumBadgeContainer.isHidden = !viewModel.isPremium

        self.layoutIfNeeded()
    }
}
