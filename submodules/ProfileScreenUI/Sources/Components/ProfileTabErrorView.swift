import UIKit
import Display
import DivoCore
import DivoUIKit

/// Заглушка-ошибка для контентных табов профиля (video/channels/models/events).
/// Стиль выровнен с error-стейтом главной ленты, но кнопка не прибита снизу,
/// а лежит сразу под subtitle (отступ 16pt) — ширина по контенту, иконка
/// refresh 20×20 + текст. Используется только когда первая страница таба
/// не загрузилась — для pagination-ошибок отдельной заглушки нет (см. ТЗ).
final class ProfileTabErrorView: UIView {

    private let iconView: UIImageView = {
        let view = UIImageView(image: DivoImage.faceSearchError)
        view.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 20) ?? Font.bold(20)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let retryButton: DivoButton = {
        let button = DivoButton()
        // compact: true задаёт height 40, contentEdgeInsets 18/24, radius 20.
        // Иконка слева + текст справа, gap = Spacing.xs (4pt) — стандартный
        // стиль с иконкой такого же типа, как «Add new photo» в empty-стейтах.
        button.makeDivoButton(
            title: DivoStrings.retry,
            leadingIcon: DivoImage.refresh,
            compact: true
        )
        return button
    }()

    private var onRetry: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DivoColorPalette.cardBackground

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(retryButton)

        // Группа icon → title → subtitle → button уложена цепочкой сверху вниз
        // и центрирована по вертикали через iconView.centerY с offset вверх,
        // чтобы вся группа визуально стояла по центру (offset подобран под
        // typical-высоту title (1 строка) + subtitle (2 строки) + button 56pt).
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -100),
            iconView.widthAnchor.constraint(lessThanOrEqualToConstant: 96),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),

            retryButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor)
            // DivoButton сам ставит heightConstraint (40 при compact: true).
        ])

        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// `networkError == true` → общий текст про интернет.
    /// Иначе — per-tab title («Couldn't load videos» / «...channels» / ...).
    func configure(tab: ProfileTab, networkError: Bool, onRetry: @escaping () -> Void) {
        if networkError {
            titleLabel.text = DivoStrings.profileTabErrorNetworkTitle.uppercased()
        } else {
            titleLabel.text = Self.title(for: tab).uppercased()
        }
        subtitleLabel.text = DivoStrings.profileTabErrorSubtitle
        self.onRetry = onRetry
    }

    private static func title(for tab: ProfileTab) -> String {
        switch tab {
        case .photo:    return DivoStrings.profileTabErrorTitlePhoto
        case .video:    return DivoStrings.profileTabErrorTitleVideo
        case .channels: return DivoStrings.profileTabErrorTitleChannels
        case .models:   return DivoStrings.profileTabErrorTitleModels
        case .events:   return DivoStrings.profileTabErrorTitleEvents
        }
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}
