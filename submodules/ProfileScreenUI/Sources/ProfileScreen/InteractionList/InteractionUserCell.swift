import UIKit
import Display
import TelegramCore
import DivoCore

final class InteractionUserCell: UITableViewCell {
    static let reuseIdentifier = "InteractionUserCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 30
        iv.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = .lightGray
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = UIColor(hexString: "222222")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
        return label
    }()

    private let premiumBadge: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(bundleImageName: "Components/CrownPremium")
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(14)
        label.textColor = UIColor(hexString: "222222")?.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
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
        avatarImageView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
    }

    private func setupViews() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(premiumBadge)
        contentView.addSubview(roleLabel)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 60),
            avatarImageView.heightAnchor.constraint(equalToConstant: 60),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor),

            premiumBadge.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 6),
            premiumBadge.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            premiumBadge.widthAnchor.constraint(equalToConstant: 16),
            premiumBadge.heightAnchor.constraint(equalToConstant: 16),

            roleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            roleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2)
        ])
    }

    func configure(with user: InteractionUser) {
        nameLabel.text = user.name
        roleLabel.text = user.role
        premiumBadge.isHidden = !user.isPremium
        
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
        avatarImageView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
    }
}

