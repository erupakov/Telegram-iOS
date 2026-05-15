import UIKit
import Display
import DivoUIKit
import DivoCore

final class HeaderSettingsView: UIView {

    static let avatarSize: CGFloat = 94

    /// Горизонтальный отступ для имени/телефона. Совпадает с боковыми отступами карточек.
    private static let horizontalPadding: CGFloat = 18

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
        textStack.spacing = 12
        textStack.alignment = .fill

        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarImageView)

        textStack.addArrangedSubview(avatarContainer)
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(phoneLabel)

        addSubview(textStack)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            avatarImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
        ])

        textStack.setCustomSpacing(6, after: nameLabel)
    }

    func configure(fullUrl: String? = nil, fullName: String? = nil, phone: String? = nil) {
        nameLabel.text = fullName
        nameLabel.isHidden = fullName == nil
        phoneLabel.text = phone
        phoneLabel.isHidden = phone == nil

        avatarImageView.cancelImageLoad()
        let avatarURL = CDNURLHelper.convertToCDNURL(fullUrl)
        avatarImageView.loadImage(from: avatarURL) { [weak avatarImageView] image in
            avatarImageView?.applyAvatarTopCropIfNeeded(image: image)
        }
    }
}
