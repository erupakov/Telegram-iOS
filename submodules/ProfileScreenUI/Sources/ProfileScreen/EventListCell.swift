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
    let isApplied: Bool?
    let isMyRoleAgency: Bool?
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
    
    private let applyStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 2
        stackView.alignment = .trailing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isHidden = true
        return stackView
    }()
    
    private let iconBadgeApply: UIImageView = {
        let iv = UIImageView(image: DivoImage.blackCheckmark)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let labelBadgeApply: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(14)
        label.textColor = DivoColorPalette.primaryText
        label.text = DivoStrings.applied
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
        
        let rigthStack = UIStackView()
        rigthStack.axis = .horizontal
        rigthStack.spacing = 0
        rigthStack.alignment = .trailing
        rigthStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(rigthStack)
        rigthStack.addArrangedSubview(applyButton)
        rigthStack.addArrangedSubview(applyStackView)
        
        applyStackView.addArrangedSubview(iconBadgeApply)
        applyStackView.addArrangedSubview(labelBadgeApply)
        
        applyButton.addTarget(self, action: #selector(applyButtonTapped), for: .touchUpInside)
        
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.lineBreakMode = .byTruncatingTail
        
        let mediumCompressionPriority = UILayoutPriority(500)
        applyButton.setContentCompressionResistancePriority(mediumCompressionPriority, for: .horizontal)
        applyStackView.setContentCompressionResistancePriority(mediumCompressionPriority, for: .horizontal)
        iconBadgeApply.setContentCompressionResistancePriority(mediumCompressionPriority, for: .horizontal)
        labelBadgeApply.setContentCompressionResistancePriority(mediumCompressionPriority, for: .horizontal)
        rigthStack.setContentCompressionResistancePriority(mediumCompressionPriority, for: .horizontal)
        
        infoLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        infoLabel.lineBreakMode = .byTruncatingTail
        
        nameLabelTrailingWithButton = nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: rigthStack.leadingAnchor, constant: -10)
        nameLabelTrailingWithoutButton = nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m)
        
        infoLabelTrailingWithButton = infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: rigthStack.leadingAnchor, constant: -10)
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
            
            rigthStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            rigthStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            applyButton.heightAnchor.constraint(equalToConstant: 36),
            
            iconBadgeApply.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.m),
            iconBadgeApply.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.m),
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
        
        let placeholder = DivoImage.emptyBackgroundEventSmall
        if let photoURLString = item.customAvatarURL, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
            avatarImageView.loadImage(from: photoURL, placeholder: placeholder, cropAvatarIfNeeded: true)
        } else {
            avatarImageView.image = placeholder
        }
        
        if isMyProfile || (item.isMyRoleAgency == true) {
            applyButton.isHidden = true
            
            nameLabelTrailingWithButton?.isActive = false
            infoLabelTrailingWithButton?.isActive = false
            
            nameLabelTrailingWithoutButton?.isActive = true
            infoLabelTrailingWithoutButton?.isActive = true
        } else {
            if item.isApplied == true {
                applyButton.isHidden = true
                applyStackView.isHidden = false
            } else {
                applyStackView.isHidden = true
                applyButton.isHidden = false
                applyButton.makeDivoButton(title: DivoStrings.apply, buttonFont: Font.helveticaNeue(14), radius: 18)
            }
            
            nameLabelTrailingWithoutButton?.isActive = false
            infoLabelTrailingWithoutButton?.isActive = false
            
            nameLabelTrailingWithButton?.isActive = true
            infoLabelTrailingWithButton?.isActive = true
        }
    }
}
