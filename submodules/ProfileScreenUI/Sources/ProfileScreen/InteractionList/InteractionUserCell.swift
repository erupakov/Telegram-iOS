import UIKit
import Display
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
        avatarImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
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

    func configure(with user: InteractionUser, searchText: String = "") {
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
        roleLabel.text = user.role
        premiumBadgeContainer.isHidden = !user.isPremium
        
        let placeholder = DivoImage.emptyBackgroundAvatar
        if let photoURLString = user.avatarUrl, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
            avatarImageView.loadImage(from: photoURL, placeholder: placeholder, cropAvatarIfNeeded: true)
        } else {
            avatarImageView.image = placeholder
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        applyDivoListHighlight(highlighted)
    }
}

