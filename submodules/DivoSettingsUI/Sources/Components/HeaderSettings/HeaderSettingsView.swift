import UIKit
import Display
import DivoUIKit
import DivoCore

final class HeaderSettingsView: UIView {

    static let avatarSize: CGFloat = 94

    /// Горизонтальный отступ для имени/телефона. Совпадает с боковыми отступами карточек.
    private static let horizontalPadding: CGFloat = 18
    /// Отступ аватарки сверху — совпадает с inset'ом загрузочного шиммера (выравнивание при переходе).
    private static let topPadding: CGFloat = 12
    private static let avatarToTextSpacing: CGFloat = 12

    private let avatarImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = DivoColorPalette.imagePlaceholderLight
        view.layer.cornerRadius = avatarSize / 2
        view.layer.borderWidth = 1
        view.layer.borderColor = DivoColorPalette.cardBackground.cgColor
        return view
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Font.medium(18)
        label.textColor = DivoColorPalette.settingsNameText
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.textAlignment = .center
        return label
    }()

    private let phoneLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.settingsPhoneText
        label.lineBreakMode = .byTruncatingTail
        label.textAlignment = .center
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
        let textStack = UIStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.alignment = .fill
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(phoneLabel)

        addSubview(avatarImageView)
        addSubview(textStack)

        // Контент прижат к верху, высота вью — по контенту: без телефона блок короче, а имя остаётся под аватаркой.
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: topAnchor, constant: Self.topPadding),
            avatarImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),

            textStack.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: Self.avatarToTextSpacing),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func configure(fullUrl: String? = nil, fullName: String? = nil, phone: String? = nil) {
        nameLabel.text = fullName
        nameLabel.isHidden = fullName == nil
        phoneLabel.text = phone
        phoneLabel.isHidden = phone == nil

        let placeholder = DivoImage.emptyBackgroundAvatar
        if let photoURLString = fullUrl, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
            avatarImageView.loadImage(from: photoURL, placeholder: placeholder, cropAvatarIfNeeded: true)
        } else {
            avatarImageView.image = placeholder
        }
    }
}
