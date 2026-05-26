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
    
    private static let avatarSize: CGFloat = 52
    
    var onApply: ((Int) -> Void)?
    private var currentEventId: Int?

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = avatarSize / 2
        iv.backgroundColor = DivoColorPalette.imagePlaceholderLight
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

    private let applyButton = DivoButton()

    private var nameLabelTrailingWithButton: NSLayoutConstraint?
    private var nameLabelTrailingWithoutButton: NSLayoutConstraint?

    private var infoLabelTrailingWithButton: NSLayoutConstraint?
    private var infoLabelTrailingWithoutButton: NSLayoutConstraint?

    private var applyButtonWidthConstraint: NSLayoutConstraint?

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
        contentView.addSubview(infoLabel)
        contentView.addSubview(applyButton)

        applyButton.addTarget(self, action: #selector(applyButtonTapped), for: .touchUpInside)

        nameLabelTrailingWithButton = nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: applyButton.leadingAnchor, constant: -10)
        nameLabelTrailingWithoutButton = nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m)
        
        infoLabelTrailingWithButton = infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: applyButton.leadingAnchor, constant: -10)
        infoLabelTrailingWithoutButton = infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 52),
            avatarImageView.heightAnchor.constraint(equalToConstant: 52),
            
            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            infoLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            infoLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            
            applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            applyButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            applyButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    @objc private func applyButtonTapped() {
        guard let eventId = currentEventId else { return }
        onApply?(eventId)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.cancelImageLoad()
        avatarImageView.image = nil
        currentEventId = nil
        applyButton.isHidden = true
        onApply = nil

        nameLabelTrailingWithButton?.isActive = false
        nameLabelTrailingWithoutButton?.isActive = false
        infoLabelTrailingWithButton?.isActive = false
        infoLabelTrailingWithoutButton?.isActive = false
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
            applyButton.isHidden = true
            
            nameLabelTrailingWithButton?.isActive = false
            infoLabelTrailingWithButton?.isActive = false
            
            nameLabelTrailingWithoutButton?.isActive = true
            infoLabelTrailingWithoutButton?.isActive = true
        } else {
            applyButton.isHidden = false
            applyButton.makeDivoButton(title: DivoStrings.apply, buttonFont: Font.helveticaNeue(14), radius: 18)
            
            nameLabelTrailingWithoutButton?.isActive = false
            infoLabelTrailingWithoutButton?.isActive = false
            
            nameLabelTrailingWithButton?.isActive = true
            infoLabelTrailingWithButton?.isActive = true
        }
    }
}
