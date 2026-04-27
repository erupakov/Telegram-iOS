import UIKit
import Display
import TelegramCore
import DivoCore
import AccountContext
import DivoUIKit

struct ProfileChannelItem {
    let peer: String
    let title: String
    let followersCount: Int
    let isPremium: Bool
    let customAvatarURL: String?
}

final class ChannelListCell: UICollectionViewCell {
    static let reuseIdentifier = "ChannelListCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 26
        iv.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
        return label
    }()

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

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = DivoColorPalette.screenBackground

        contentView.addSubview(avatarImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(premiumBadgeContainer)
        premiumBadgeContainer.addSubview(premiumBadgeIcon)
        premiumBadgeContainer.addSubview(premiumBadgeLabel)
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 52),
            avatarImageView.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor),

            premiumBadgeContainer.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            premiumBadgeContainer.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            premiumBadgeContainer.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            premiumBadgeContainer.heightAnchor.constraint(equalToConstant: 22),

            premiumBadgeIcon.bottomAnchor.constraint(equalTo: premiumBadgeContainer.bottomAnchor, constant: -5),
            premiumBadgeIcon.topAnchor.constraint(equalTo: premiumBadgeContainer.topAnchor, constant: 5),
            premiumBadgeIcon.leadingAnchor.constraint(equalTo: premiumBadgeContainer.leadingAnchor, constant: 6),

            premiumBadgeLabel.bottomAnchor.constraint(equalTo: premiumBadgeContainer.bottomAnchor, constant: -5),
            premiumBadgeLabel.topAnchor.constraint(equalTo: premiumBadgeContainer.topAnchor, constant: 5),
            premiumBadgeLabel.leadingAnchor.constraint(equalTo: premiumBadgeIcon.trailingAnchor, constant: 2),
            premiumBadgeLabel.trailingAnchor.constraint(equalTo: premiumBadgeContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.cancelImageLoad()
        avatarImageView.image = nil
    }

    func configure(with item: ProfileChannelItem, context: AccountContext) {
        titleLabel.text = item.title
        subtitleLabel.text = DivoStrings.followersString(item.followersCount)
        premiumBadgeContainer.isHidden = !item.isPremium
        if let urlString = item.customAvatarURL, let url = URL(string: urlString) {
            avatarImageView.loadImage(from: url)
        }
    }
}
