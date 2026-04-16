import UIKit
import DivoCore

public final class DivoNavigationBar: UIView {

    public var onBackTapped: (() -> Void)?

    public let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 20) ?? UIFont.boldSystemFont(ofSize: 20)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill

        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = UIImage(systemName: "chevron.left", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = DivoColorPalette.primaryText

        button.layer.applyDivoShadow()

        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(backButton)
        addSubview(titleLabel)

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.addDivoPressState(.pill)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 50),

            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    public func setTitle(_ title: String) {
        titleLabel.text = title.uppercased()
    }

    @objc private func backTapped() {
        onBackTapped?()
    }
}
