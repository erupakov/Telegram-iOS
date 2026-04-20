import UIKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit

final class InteractionUserCell: UITableViewCell {
    static let reuseIdentifier = "InteractionUserCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 26
        iv.backgroundColor = DivoColorPalette.imagePlaceholderMedium
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = .lightGray
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

    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.image = nil
        avatarImageView.stopShimmering()
        avatarImageView.alpha = 1.0
        avatarImageView.backgroundColor = DivoColorPalette.imagePlaceholderMedium
    }

    private func setupViews() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(premiumBadgeContainer)
        premiumBadgeContainer.addSubview(premiumBadgeIcon)
        premiumBadgeContainer.addSubview(premiumBadgeLabel)
        contentView.addSubview(roleLabel)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 52),
            avatarImageView.heightAnchor.constraint(equalToConstant: 52),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor),

            premiumBadgeContainer.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            premiumBadgeContainer.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            premiumBadgeContainer.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            premiumBadgeContainer.heightAnchor.constraint(equalToConstant: 22),

            premiumBadgeIcon.bottomAnchor.constraint(equalTo: premiumBadgeContainer.bottomAnchor, constant: -5),
            premiumBadgeIcon.topAnchor.constraint(equalTo: premiumBadgeContainer.topAnchor, constant: 5),
            premiumBadgeIcon.leadingAnchor.constraint(equalTo: premiumBadgeContainer.leadingAnchor, constant: 6),

            premiumBadgeLabel.bottomAnchor.constraint(equalTo: premiumBadgeContainer.bottomAnchor, constant: -5),
            premiumBadgeLabel.topAnchor.constraint(equalTo: premiumBadgeContainer.topAnchor, constant: 5),
            premiumBadgeLabel.leadingAnchor.constraint(equalTo: premiumBadgeIcon.trailingAnchor, constant: 2),
            premiumBadgeLabel.trailingAnchor.constraint(equalTo: premiumBadgeContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),

            roleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            roleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2)
        ])
    }

    func configure(with user: InteractionUser) {
        nameLabel.text = user.name
        roleLabel.text = user.role
        premiumBadgeContainer.isHidden = !user.isPremium
        
        avatarImageView.startShimmering()
        
        if let avatarURLString = user.avatarUrl, let avatarURL = CDNURLHelper.convertToCDNURL(avatarURLString) {
            ImageLoader.shared.load(url: avatarURL) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let image = image {
                        self.avatarImageView.alpha = 0
                        self.avatarImageView.image = image
                        self.avatarImageView.backgroundColor = .clear
                        
                        UIView.animate(withDuration: 0.3) {
                            self.avatarImageView.alpha = 1.0
                        }
                    } else {
                        self.setDefaultAvatar()
                    }
                    self.avatarImageView.stopShimmering()
                }
            }
        } else {
            self.avatarImageView.stopShimmering()
            self.setDefaultAvatar()
        }
    }

    private func setDefaultAvatar() {
        avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarImageView.tintColor = .lightGray
        avatarImageView.backgroundColor = DivoColorPalette.imagePlaceholderMedium
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let duration = highlighted ? 0.1 : 0.2
        UIView.animate(withDuration: duration) {
            self.contentView.alpha = highlighted ? 0.6 : 1.0
            self.contentView.transform = highlighted
                ? CGAffineTransform(scaleX: 0.98, y: 0.98)
                : .identity
        }
    }
}

