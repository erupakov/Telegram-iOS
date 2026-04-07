import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import DivoCore
import AccountContext

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
        iv.layer.cornerRadius = 30
        iv.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = .lightGray
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = UIColor(hex: "#222222")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(14)
        label.textColor = UIColor(hex: "#222222").withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var applyButton: UIButton = {
        let button = UIButton()
        button.setTitle(DivoStrings.apply, for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(14)
        button.backgroundColor = UIColor(hex: "#BF7A54")
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 6
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var isMyProfile: Bool = false

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
        contentView.addSubview(infoLabel)
        contentView.addSubview(applyButton)
        
        // Добавляем action на кнопку
        applyButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 60),
            avatarImageView.heightAnchor.constraint(equalToConstant: 60),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: applyButton.leadingAnchor, constant: -10),

            infoLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            infoLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: applyButton.leadingAnchor, constant: -10),

            applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            applyButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            applyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            applyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 68)
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
        
        // Обновляем текст кнопки в зависимости от профиля
        let buttonTitle = isMyProfile ? DivoStrings.edit : DivoStrings.apply
        applyButton.setTitle(buttonTitle, for: .normal)
    }
}

