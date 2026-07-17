import UIKit
import Display
import DivoUIKit

struct ProfileChannelItem {
    let title: String
    let subtitle: String?
    let username: String?
    let inviteLink: String?
    let isVerified: Bool
}

final class ChannelListCell: UICollectionViewCell {
    static let reuseIdentifier = "ChannelListCell"

    private static let avatarSize: CGFloat = 52

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = avatarSize / 2
        iv.backgroundColor = DivoColorPalette.imagePlaceholderMedium
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

    private let verifiedIconView: UIImageView = {
        let iv = UIImageView(image: DivoImage.verified)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        return label
    }()

    // Заголовок стоит над центром, когда есть подпись; при отсутствии подписи —
    // центрируется по вертикали (одна строка не должна «висеть» в верхней половине).
    private lazy var titleAboveCenterConstraint = titleLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor)
    private lazy var titleCenteredConstraint = titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)

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
        contentView.addSubview(titleLabel)
        contentView.addSubview(verifiedIconView)
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            titleLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),

            verifiedIconView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            verifiedIconView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            verifiedIconView.widthAnchor.constraint(equalToConstant: 16),
            verifiedIconView.heightAnchor.constraint(equalToConstant: 16),
            verifiedIconView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2)
        ])
        titleAboveCenterConstraint.isActive = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.cancelImageLoad()
        avatarImageView.image = nil
    }

    func configure(with item: ProfileChannelItem) {
        titleLabel.text = item.title
        verifiedIconView.isHidden = !item.isVerified

        let hasSubtitle = !(item.subtitle?.isEmpty ?? true)
        subtitleLabel.text = item.subtitle
        subtitleLabel.isHidden = !hasSubtitle
        titleAboveCenterConstraint.isActive = hasSubtitle
        titleCenteredConstraint.isActive = !hasSubtitle

        // Аватар канала бэк не отдаёт; загрузка через MTProto media-pipeline — отдельный шаг.
        avatarImageView.image = DivoImage.emptyBackgroundAvatar
    }
}
