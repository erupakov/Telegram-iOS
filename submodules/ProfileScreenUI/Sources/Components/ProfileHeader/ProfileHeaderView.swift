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

    private let ringView: AvatarStrokeView = {
        let view = AvatarStrokeView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.image = UIImage(systemName: "person.crop.circle.fill")
        iv.tintColor = DivoColorPalette.primaryText
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    /// В обычном `.scaleAspectFill` кроп центрируется. Для портретных фото это часто «съедает» верх (голову).
    /// Поэтому для аватарки мы делаем квадратный кроп с приоритетом верхней части.
    private func applyAvatarContentsRect(for image: UIImage?) {
        // Держим реализацию в одном месте, чтобы поведение совпадало со списками.
        avatarImageView.applyAvatarTopCropIfNeeded(image: image)
    }
    
    private let avatarSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = DivoColorPalette.primaryText
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    private let onlineStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.green
        view.layer.borderColor = DivoColorPalette.avatarStrokeQuiet.cgColor
        view.layer.borderWidth = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = DivoColorPalette.cardBackground
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private static let badgeHeight: CGFloat = 22

    private var nameLabelHeightConstraint: NSLayoutConstraint!

    private let premiumBadgeIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.premiumIcon
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let roleContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.roleBadgeBlue
        view.layer.cornerRadius = badgeHeight / 2
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

    override func layoutSubviews() {
        super.layoutSubviews()
        
        let avatarSize: CGFloat = 54
        avatarImageView.layer.cornerRadius = avatarSize / 2
        
        onlineStatusView.layer.cornerRadius = 6
    }
    
    private func setupViews() {
        addSubview(ringView)
        addSubview(avatarImageView)
        addSubview(avatarSpinner)
        addSubview(onlineStatusView)

        addSubview(nameLabel)
        addSubview(premiumBadgeIcon)
        
        addSubview(roleContainer)
        roleContainer.addSubview(roleLabel)
        
        addSubview(infoLabel)
    }

    
    private func setupConstraints() {
        let avatarSize: CGFloat = 54
        
        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: avatarSize),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            
            ringView.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            ringView.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            ringView.widthAnchor.constraint(equalToConstant: avatarSize + 10),
            ringView.heightAnchor.constraint(equalToConstant: avatarSize + 10),
            
            onlineStatusView.trailingAnchor.constraint(equalTo: ringView.trailingAnchor, constant: -DivoDesignTokens.Spacing.xs),
            onlineStatusView.bottomAnchor.constraint(equalTo: ringView.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs),
            onlineStatusView.widthAnchor.constraint(equalToConstant: 12),
            onlineStatusView.heightAnchor.constraint(equalToConstant: 12),
            
            nameLabel.leadingAnchor.constraint(equalTo: ringView.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: premiumBadgeIcon.leadingAnchor, constant: -8),
            nameLabel.bottomAnchor.constraint(equalTo: roleContainer.topAnchor, constant: -DivoDesignTokens.Spacing.xs),
            
            premiumBadgeIcon.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            premiumBadgeIcon.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            premiumBadgeIcon.bottomAnchor.constraint(equalTo: roleContainer.topAnchor, constant: -6),
            premiumBadgeIcon.widthAnchor.constraint(equalToConstant: 20),
            premiumBadgeIcon.heightAnchor.constraint(equalToConstant: 20),
            
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
        let font = Font.helveticaNeue(24)
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
        
        if let image = viewModel.avatarImage {
            applyAvatarContentsRect(for: image)
            avatarImageView.image = image
        }
        
        premiumBadgeIcon.isHidden = !viewModel.isPremium

        self.layoutIfNeeded()
    }
    
    func changeAvatar(with image: UIImage?) {
        if let image = image {
            avatarImageView.image = image
            applyAvatarContentsRect(for: image)
        } else {
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
            applyAvatarContentsRect(for: nil)
        }
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
}
