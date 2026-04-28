import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import DivoCore
import AccountContext
import DivoUIKit

struct EventItem {
    let name: String
    let data: String
    let time: String
    let countryFlag: String
    let city: String
    let customAvatarURL: String?
    let originalDate: String?
    let eventId: Int?
}

final class EventListCell: UICollectionViewCell {
    static let reuseIdentifier = "EventListCell"
    
    var onEditTapped: ((Int?) -> Void)?
    var onDeleteTapped: ((Int?) -> Void)?
    var openAddModel: (() -> Void)?
    private var currentEventId: Int?

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 26
        iv.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
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

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let optionsButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(DivoImage.moreActionIconBlack, for: .normal)
        btn.tintColor = DivoColorPalette.primaryText
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let applyButton = DivoButton()

    private var optionsButtonWidthConstraint: NSLayoutConstraint?
    private var applyButtonWidthConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupMenu()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = DivoColorPalette.cardBackground

        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(infoLabel)
        contentView.addSubview(optionsButton)
        contentView.addSubview(applyButton)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 52),
            avatarImageView.heightAnchor.constraint(equalToConstant: 52),
            
            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: optionsButton.leadingAnchor, constant: -10),
            
            infoLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            infoLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: optionsButton.leadingAnchor, constant: -10),
            
            optionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            optionsButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            optionsButton.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.l),
            optionsButton.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.l),
            
            applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            applyButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            applyButton.heightAnchor.constraint(equalToConstant: 36)
        ])

        optionsButtonWidthConstraint = optionsButton.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.l)
    }

    private func setupMenu() {
        optionsButton.adjustsImageWhenHighlighted = false
        optionsButton.addDivoPressState(.pill)
        
        if #available(iOS 14.0, *) {
            let editAction = UIAction(
                title: DivoStrings.edit,
                image: DivoImage.pencil,
            ) { [weak self] _ in
                self?.onEditTapped?(self?.currentEventId)
            }
            
            let deleteAction = UIAction(
                title: DivoStrings.delete,
                image: DivoImage.basketWork,
                attributes: .destructive
            ) { [weak self] _ in
                self?.onDeleteTapped?(self?.currentEventId)
            }
            
            let menu = UIMenu(title: "", children: [editAction, deleteAction])
            optionsButton.menu = menu
            optionsButton.showsMenuAsPrimaryAction = true
        }
    }
    
    @objc private func applyButtonTapped() {
        openAddModel?()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.cancelImageLoad()
        avatarImageView.image = nil
        currentEventId = nil
        onEditTapped = nil
        onDeleteTapped = nil
        optionsButton.isHidden = true
        applyButton.isHidden = true
    }
    
    func configure(with item: EventItem, context: AccountContext, isMyProfile: Bool) {
        self.currentEventId = item.eventId
        
        nameLabel.text = item.name
        var infoParts: [String] = []
        if !item.data.isEmpty { infoParts.append(item.data) }
        if !item.time.isEmpty { infoParts.append(item.time) }
        let location = [item.countryFlag, item.city].filter { !$0.isEmpty }.joined(separator: " ")
        if !location.isEmpty { infoParts.append(location) }
        infoLabel.text = infoParts.joined(separator: " · ")
        
        if let urlString = item.customAvatarURL, let url = URL(string: urlString) {
            avatarImageView.loadImage(from: url)
        }
        
        if isMyProfile {
            optionsButton.isHidden = false
            applyButton.isHidden = true
            optionsButtonWidthConstraint?.isActive = true
        } else {
            optionsButton.isHidden = true
            applyButton.isHidden = false
            applyButton.makeDivoButton(title: DivoStrings.apply, buttonFont: Font.helveticaNeue(14), radius: 18)
        }
    }
}
