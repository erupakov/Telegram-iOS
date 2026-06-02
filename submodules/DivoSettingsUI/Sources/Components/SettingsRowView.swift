import UIKit
import Display
import DivoUIKit
import DivoCore

final class SettingsRowView: UIView {

    private enum Layout {
        static let iconContainerSize: CGFloat = 29
        static let iconSize: CGFloat = 20
        static let iconContainerRadius: CGFloat = 6
        static let titleIconSpacing: CGFloat = 10
        static let valueChevronSpacing: CGFloat = 8
        static let chevronSize: CGFloat = 20
        static let separatorHeight: CGFloat = 1
    }

    private let settingsIconContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DivoColorPalette.screenBackground
        view.layer.cornerRadius = Layout.iconContainerRadius
        return view
    }()

    private let settingsIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.textAlignment = .right
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let separator: UIView = {
        let separator = UIView()
        separator.backgroundColor = DivoColorPalette.screenBackground
        separator.translatesAutoresizingMaskIntoConstraints = false
        return separator
    }()

    init(icon: UIImage, title: String, isLast: Bool) {
        super.init(frame: .zero)

        self.backgroundColor = .clear
        self.translatesAutoresizingMaskIntoConstraints = false
        addPressState(alpha: DivoDesignTokens.PressState.alphaOnClear, scale: DivoDesignTokens.PressState.scaleListRow)

        settingsIcon.image = icon
        titleLabel.text = title
        addSubview(settingsIconContainer)
        settingsIconContainer.addSubview(settingsIcon)
        addSubview(titleLabel)
        addSubview(valueLabel)

        let chevronImageView = UIImageView()
        chevronImageView.image = DivoImage.searchChevronRight
        chevronImageView.tintColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chevronImageView)

        if !isLast {
            addSubview(separator)

            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                separator.bottomAnchor.constraint(equalTo: bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: Layout.separatorHeight)
            ])
        }

        NSLayoutConstraint.activate([
            settingsIconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            settingsIconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsIconContainer.heightAnchor.constraint(equalToConstant: Layout.iconContainerSize),
            settingsIconContainer.widthAnchor.constraint(equalToConstant: Layout.iconContainerSize),

            settingsIcon.centerXAnchor.constraint(equalTo: settingsIconContainer.centerXAnchor),
            settingsIcon.centerYAnchor.constraint(equalTo: settingsIconContainer.centerYAnchor),
            settingsIcon.heightAnchor.constraint(equalToConstant: Layout.iconSize),
            settingsIcon.widthAnchor.constraint(equalToConstant: Layout.iconSize),

            titleLabel.leadingAnchor.constraint(equalTo: settingsIcon.trailingAnchor, constant: Layout.titleIconSpacing),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevronImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            chevronImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: Layout.chevronSize),
            chevronImageView.heightAnchor.constraint(equalToConstant: Layout.chevronSize),

            valueLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -Layout.valueChevronSpacing),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: DivoDesignTokens.Spacing.m),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValue(_ text: String) {
        valueLabel.text = text
    }

    func setTitle(_ text: String) {
        titleLabel.text = text
    }

    func setSeparatorHidden(_ isHidden: Bool) {
        separator.isHidden = isHidden
    }
}
