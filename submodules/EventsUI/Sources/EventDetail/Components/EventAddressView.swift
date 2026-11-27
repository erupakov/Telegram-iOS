import UIKit
import Display
import DivoUIKit
import DivoCore

/// Карточка адреса проведения события (паритет с Android AddressCard, коммит 34649ba7c):
/// пин + серый лейбл «Location» + текст адреса (до 3 строк). Вся карточка тапается —
/// узел открывает карты через EventDetailControllerNode.mapsURL.
final class EventAddressView: UIView {

    var onTap: (() -> Void)?

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let pinImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        // Кастомного пина в DivoImage нет — системный символ (прецеденты: EventsController, DivoNavigationBar).
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        if let symbol = UIImage(systemName: "mappin.and.ellipse", withConfiguration: config) {
            iv.image = symbol.withTintColor(DivoColorPalette.primaryText, renderingMode: .alwaysOriginal)
        }
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.location
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let addressLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
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
        addSubview(containerView)
        containerView.addSubview(pinImageView)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, addressLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(textStack)

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            pinImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            pinImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            pinImageView.widthAnchor.constraint(equalToConstant: 22),
            pinImageView.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: pinImageView.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            textStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            textStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
        ])
    }

    func configure(text: String) {
        addressLabel.text = text
    }

    @objc private func handleTap() {
        onTap?()
    }
}
