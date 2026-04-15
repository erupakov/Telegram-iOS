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
        iv.layer.cornerRadius = 30
        iv.backgroundColor = DivoColorPalette.imagePlaceholderDark
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
        return label
    }()

    private let premiumBadge: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.crownPremium.withRenderingMode(.alwaysOriginal)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(14)
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
        contentView.backgroundColor = .white

        contentView.addSubview(avatarImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(premiumBadge)
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 60),
            avatarImageView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor),

            premiumBadge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            premiumBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            premiumBadge.widthAnchor.constraint(equalToConstant: 16),
            premiumBadge.heightAnchor.constraint(equalToConstant: 16),

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
        premiumBadge.isHidden = !item.isPremium
        if let urlString = item.customAvatarURL, let url = URL(string: urlString) {
            avatarImageView.loadImage(from: url)
        }
    }
}

