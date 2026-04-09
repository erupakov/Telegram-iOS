import UIKit
import Display
import AccountContext
import TelegramCore
import DivoCore

struct ModelItem {
    let name: String
    let role: String
    let isPremium: Bool
    let customAvatarURL: String?
    let localAvatarName: String?
}

final class ModelListCell: UICollectionViewCell {
    static let reuseIdentifier = "ModelListCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 30
        iv.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = UIColor(hex: "#222222")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
        return label
    }()

    private let premiumBadge: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(bundleImageName: "Profile/CrownPremium")?.withRenderingMode(.alwaysOriginal)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()

    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(14)
        label.textColor = UIColor(hex: "#222222").withAlphaComponent(0.6)
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
        contentView.addSubview(nameLabel)
        contentView.addSubview(premiumBadge)
        contentView.addSubview(roleLabel)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 60),
            avatarImageView.heightAnchor.constraint(equalToConstant: 60),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor),

            premiumBadge.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 6),
            premiumBadge.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            premiumBadge.widthAnchor.constraint(equalToConstant: 16),
            premiumBadge.heightAnchor.constraint(equalToConstant: 16),

            roleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            roleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2)
        ])
    }

    func configure(with item: ModelItem, context: AccountContext) {
        nameLabel.text = item.name
        roleLabel.text = item.role
        premiumBadge.isHidden = !item.isPremium
        let placeholderColor = UIColor(white: 0.92, alpha: 1.0)
        if let avatarURLString = item.customAvatarURL,
           let url = CDNURLHelper.convertToCDNURL(avatarURLString) {
            avatarImageView.backgroundColor = placeholderColor
            avatarImageView.loadImage(from: url) { [weak self] image in
                self?.avatarImageView.applyAvatarTopCropIfNeeded(image: image)
            }
        } else if let localName = item.localAvatarName, let image = UIImage(named: localName) {
            avatarImageView.image = image
            avatarImageView.applyAvatarTopCropIfNeeded(image: image)
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
        avatarImageView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
    }
}

