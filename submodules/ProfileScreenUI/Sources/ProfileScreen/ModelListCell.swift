import UIKit
import Display
import AccountContext
import TelegramCore
import DivoCore
import DivoUIKit

struct ModelItem {
    let id: Int
    let name: String
    let role: String
    let isPremium: Bool
    let customAvatarURL: String?
}

final class ModelListCell: UICollectionViewCell {
    static let reuseIdentifier = "ModelListCell"

    private static let avatarSize: CGFloat = 52
    private static let badgeHeight: CGFloat = 22

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = avatarSize / 2
        iv.backgroundColor = DivoColorPalette.imagePlaceholderDark
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

    private let premiumBadgeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = badgeHeight / 2
        view.layer.borderWidth = 1
        view.layer.borderColor = DivoColorPalette.primaryText.withAlphaComponent(0.1).cgColor
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

    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.primaryText.withAlphaComponent(0.1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = DivoColorPalette.cardBackground

        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(premiumBadgeContainer)
        premiumBadgeContainer.addSubview(premiumBadgeIcon)
        premiumBadgeContainer.addSubview(premiumBadgeLabel)
        contentView.addSubview(roleLabel)
        contentView.addSubview(separatorView)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor),

            premiumBadgeContainer.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            premiumBadgeContainer.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            premiumBadgeContainer.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            premiumBadgeContainer.heightAnchor.constraint(equalToConstant: Self.badgeHeight),

            premiumBadgeIcon.bottomAnchor.constraint(equalTo: premiumBadgeContainer.bottomAnchor, constant: -5),
            premiumBadgeIcon.topAnchor.constraint(equalTo: premiumBadgeContainer.topAnchor, constant: 5),
            premiumBadgeIcon.leadingAnchor.constraint(equalTo: premiumBadgeContainer.leadingAnchor, constant: 6),

            premiumBadgeLabel.bottomAnchor.constraint(equalTo: premiumBadgeContainer.bottomAnchor, constant: -5),
            premiumBadgeLabel.topAnchor.constraint(equalTo: premiumBadgeContainer.topAnchor, constant: 5),
            premiumBadgeLabel.leadingAnchor.constraint(equalTo: premiumBadgeIcon.trailingAnchor, constant: 2),
            premiumBadgeLabel.trailingAnchor.constraint(equalTo: premiumBadgeContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),

            roleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            roleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            separatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    func configure(with item: ModelItem, context: AccountContext) {
        nameLabel.text = item.name
        roleLabel.text = item.role
        premiumBadgeContainer.isHidden = !item.isPremium
        let placeholderColor = DivoColorPalette.imagePlaceholderLight
        if let avatarURLString = item.customAvatarURL,
           let url = CDNURLHelper.convertToCDNURL(avatarURLString) {
            avatarImageView.backgroundColor = placeholderColor
            avatarImageView.loadImage(from: url) { [weak self] image in
                self?.avatarImageView.applyAvatarTopCropIfNeeded(image: image)
            }
        } else {
            avatarImageView.image = nil
            avatarImageView.backgroundColor = placeholderColor
            avatarImageView.applyAvatarTopCropIfNeeded(image: nil)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.cancelImageLoad()
        avatarImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        avatarImageView.image = nil
        avatarImageView.backgroundColor = DivoColorPalette.imagePlaceholderDark
    }
}

