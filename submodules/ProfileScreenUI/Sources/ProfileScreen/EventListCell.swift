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
    let originalDate: String? // Оригинальная дата для сортировки
    let eventId: Int? // ID события для редактирования
}

final class EventListCell: UICollectionViewCell {
    static let reuseIdentifier = "EventListCell"
    
    // Callback для нажатия на кнопку
    var onButtonTap: ((Int?) -> Void)?
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

    private var applyButton = DivoButton()
    
    private var isMyProfile: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        applyButton.makeDivoButton(title: DivoStrings.edit, buttonFont: Font.helveticaNeue(14), radius: 18)
        applyButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        
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
        
        // Добавляем action на кнопку
        applyButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 52),
            avatarImageView.heightAnchor.constraint(equalToConstant: 52),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: applyButton.leadingAnchor, constant: -10),

            infoLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            infoLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: applyButton.leadingAnchor, constant: -10),

            applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            applyButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            applyButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    @objc private func buttonTapped() {
        onButtonTap?(currentEventId)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.cancelImageLoad()
        avatarImageView.image = nil
        currentEventId = nil
        onButtonTap = nil
    }

    func configure(with item: EventItem, context: AccountContext, isMyProfile: Bool) {
        self.isMyProfile = isMyProfile
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
        
        let buttonTitle = isMyProfile ? DivoStrings.edit : DivoStrings.apply
        applyButton.makeDivoButton(title: buttonTitle, buttonFont: Font.helveticaNeue(14), radius: 18)
    }
}

