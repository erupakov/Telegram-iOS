import UIKit
import DivoCore
import DivoUIKit
import Display

final class FaceSearchHistoryView: UIView {

    var onSeeAllTapped: (() -> Void)?
    var onItemTapped: ((FaceSearchHistoryItem) -> Void)?

    private var items: [FaceSearchHistoryItem] = []

    // MARK: - Header

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryText
        label.text = DivoStrings.faceSearchHistoryTitle
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let seeAllButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(DivoStrings.faceSearchHistorySeeAll, for: .normal)
        button.setTitleColor(DivoColorPalette.accent, for: .normal)
        button.titleLabel?.font = UIFont(name: "HelveticaNeue", size: 15) ?? UIFont.systemFont(ofSize: 15)
        button.addDivoPressState(.text)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let rowsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(titleLabel)
        addSubview(seeAllButton)
        addSubview(rowsStack)

        seeAllButton.addTarget(self, action: #selector(seeAllPressed), for: .touchUpInside)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),

            seeAllButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            seeAllButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),

            rowsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    // MARK: - Public

    func configure(with items: [FaceSearchHistoryItem]) {
        self.items = items
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, item) in items.enumerated() {
            let row = FaceSearchHistoryRow()
            row.configure(with: item)
            row.tag = index
            row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(rowTapped(_:))))
            rowsStack.addArrangedSubview(row)
        }
    }

    // MARK: - Actions

    @objc private func seeAllPressed() {
        onSeeAllTapped?()
    }

    @objc private func rowTapped(_ gesture: UITapGestureRecognizer) {
        guard let row = gesture.view, row.tag < items.count else { return }
        onItemTapped?(items[row.tag])
    }
}

// MARK: - Row

private final class FaceSearchHistoryRow: UIView {

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 24
        iv.backgroundColor = DivoColorPalette.imagePlaceholderDark
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "HelveticaNeue-Medium", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "HelveticaNeue", size: 14) ?? UIFont.systemFont(ofSize: 14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(avatarImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 62),

            avatarImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            avatarImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 48),
            avatarImageView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            titleLabel.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -1),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: centerYAnchor, constant: 1),
        ])
    }

    func configure(with item: FaceSearchHistoryItem) {
        titleLabel.text = DivoStrings.faceSearchHistoryResultsFound(item.resultsCount)
        subtitleLabel.text = Self.formatDate(item.date)

        let image = FaceSearchHistoryStorage.shared.faceImage(for: item)
        avatarImageView.image = image
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: DivoDesignTokens.PressState.pressDuration) {
            self.alpha = DivoDesignTokens.PressState.alpha
            self.transform = CGAffineTransform(scaleX: DivoDesignTokens.PressState.scaleListRow, y: DivoDesignTokens.PressState.scaleListRow)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: DivoDesignTokens.PressState.releaseDuration) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: DivoDesignTokens.PressState.releaseDuration) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: DivoStrings.current.localeIdentifier)
        formatter.dateFormat = dateFormatTemplate()
        return formatter.string(from: date)
    }

    private static func dateFormatTemplate() -> String {
        switch DivoStrings.current {
        case .en: return "EEEE, d MMM 'at' HH:mm"
        case .ru: return "EEEE, d MMM 'в' HH:mm"
        case .es: return "EEEE, d MMM 'a las' HH:mm"
        case .pt: return "EEEE, d MMM 'às' HH:mm"
        case .zh: return "EEEE, M月d日 HH:mm"
        }
    }
}
