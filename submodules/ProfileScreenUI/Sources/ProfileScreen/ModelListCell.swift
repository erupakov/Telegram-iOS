import UIKit
import Display
import AccountContext
import TelegramCore
import DivoCore
import DivoUIKit

struct ModelItem {
    let recordId: Int
    let userId: Int
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
    
    private let optionsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(DivoImage.moreActionIconBlack, for: .normal)
        btn.tintColor = DivoColorPalette.primaryText
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private var recordId: Int? = nil
    
    var onDeleteTapped: ((Int?) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupOptionsMenu()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = DivoColorPalette.cardBackground

        let nameStack = UIStackView(arrangedSubviews: [nameLabel, premiumBadgeIcon])
        nameStack.axis = .horizontal
        nameStack.spacing = 4
        nameStack.alignment = .leading
        nameStack.translatesAutoresizingMaskIntoConstraints = false
        
        let infoStack = UIStackView(arrangedSubviews: [nameStack, roleLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 4
        infoStack.alignment = .leading
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(infoStack)
        contentView.addSubview(optionsButton)
        contentView.addSubview(separatorView)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 52),
            avatarImageView.heightAnchor.constraint(equalToConstant: 52),
            
            infoStack.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),
            infoStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            infoStack.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -DivoDesignTokens.Spacing.xs),

            premiumBadgeIcon.widthAnchor.constraint(equalToConstant: 20),
            premiumBadgeIcon.heightAnchor.constraint(equalToConstant: 20),
            

            optionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            optionsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            optionsButton.widthAnchor.constraint(equalToConstant: 24),
            optionsButton.heightAnchor.constraint(equalToConstant: 24),
            
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            separatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
        ])
    }
    
    private func setupOptionsMenu() {
        optionsButton.adjustsImageWhenHighlighted = false
        optionsButton.addDivoPressState(.pill)

        if #available(iOS 14.0, *) {
            let deleteAction = UIAction(
                title: DivoStrings.delete,
                image: nil,
                attributes: .destructive
            ) { [weak self] _ in
                self?.onDeleteTapped?(self?.recordId)
            }
            let menu = UIMenu(title: "", children: [deleteAction])
            optionsButton.menu = menu
            optionsButton.showsMenuAsPrimaryAction = true
        }
    }
    
    func configure(with item: ModelItem, isMyProfile: Bool) {
        self.recordId = item.recordId
        nameLabel.text = item.name
        roleLabel.text = item.role
        premiumBadgeIcon.isHidden = !item.isPremium
        optionsButton.isHidden = !isMyProfile
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
