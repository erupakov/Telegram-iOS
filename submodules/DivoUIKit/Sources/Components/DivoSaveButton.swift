import UIKit
import DivoCore

public final class DivoSaveButton: UIButton {

    // MARK: - Design tokens

    private static let buttonFont = UIFont(name: "HelveticaNeue-CondensedBold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
    private static let kern: CGFloat = 18 * 0.005 // 0.5 %
    private static let disabledBackground = UIColor(red: 228/255, green: 228/255, blue: 228/255, alpha: 1) // #E4E4E4
    private static let disabledTextColor = UIColor(red: 175/255, green: 175/255, blue: 177/255, alpha: 1) // #AFAFB1
    private static let buttonHeight: CGFloat = 56
    private static let cornerRadius: CGFloat = 28 // TODO: DS alignment — не в шкале Radius

    // MARK: - Subviews

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = DivoColorPalette.cardBackground
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let savingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alpha = 0
        return label
    }()

    private static let blockingOverlayTag = 928_471

    // MARK: - State

    private(set) var isSaving: Bool = false

    // MARK: - Init

    public init() {
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = DivoColorPalette.accent
        layer.cornerRadius = Self.cornerRadius

        applyNormalTitle()
        applyDisabledTitle()

        heightAnchor.constraint(equalToConstant: Self.buttonHeight).isActive = true

        addSubview(spinner)
        addSubview(savingLabel)

        NSLayoutConstraint.activate([
            savingLabel.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 12),
            savingLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: savingLabel.leadingAnchor, constant: -8),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        addTarget(self, action: #selector(handleTouchDown), for: .touchDown)
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    // MARK: - Attributed titles

    private func applyNormalTitle() {
        let attr: [NSAttributedString.Key: Any] = [
            .font: Self.buttonFont,
            .kern: Self.kern,
            .foregroundColor: DivoColorPalette.primaryTextOnDark,
        ]
        setAttributedTitle(NSAttributedString(string: DivoStrings.save.uppercased(), attributes: attr), for: .normal)
    }

    private func applyDisabledTitle() {
        let attr: [NSAttributedString.Key: Any] = [
            .font: Self.buttonFont,
            .kern: Self.kern,
            .foregroundColor: Self.disabledTextColor,
        ]
        setAttributedTitle(NSAttributedString(string: DivoStrings.save.uppercased(), attributes: attr), for: .disabled)
    }

    private func savingAttributedString() -> NSAttributedString {
        let attr: [NSAttributedString.Key: Any] = [
            .font: Self.buttonFont,
            .kern: Self.kern,
            .foregroundColor: DivoColorPalette.primaryTextOnDark,
        ]
        return NSAttributedString(string: DivoStrings.saving.uppercased(), attributes: attr)
    }

    // MARK: - Enabled / disabled

    override public var isEnabled: Bool {
        didSet {
            guard !isSaving else { return }
            backgroundColor = isEnabled ? DivoColorPalette.accent : Self.disabledBackground
        }
    }

    // MARK: - Saving state

    /// Переключает кнопку в состояние saving и добавляет блокирующий overlay на `hostView`.
    /// При `active == false` — снимает overlay и возвращает кнопку в normal.
    public func setSaving(_ active: Bool, in hostView: UIView) {
        guard active != isSaving else { return }
        isSaving = active
        isUserInteractionEnabled = !active

        if active {
            // Скрыть обычный title, показать spinner + "Saving..."
            savingLabel.attributedText = savingAttributedString()
            spinner.startAnimating()

            UIView.animate(withDuration: 0.2) {
                self.titleLabel?.alpha = 0
                self.savingLabel.alpha = 1
            }

            installBlockingOverlay(on: hostView)
        } else {
            spinner.stopAnimating()

            UIView.animate(withDuration: 0.2) {
                self.titleLabel?.alpha = 1
                self.savingLabel.alpha = 0
            }

            removeBlockingOverlay(from: hostView)
        }
    }

    // MARK: - Blocking overlay

    private func installBlockingOverlay(on hostView: UIView) {
        guard hostView.viewWithTag(Self.blockingOverlayTag) == nil else { return }
        let overlay = UIView()
        overlay.tag = Self.blockingOverlayTag
        overlay.backgroundColor = UIColor(white: 1, alpha: 0.45)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: hostView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),
        ])
        // Кнопка должна быть поверх overlay, чтобы визуально не перекрывалась
        if let parent = self.superview {
            parent.bringSubviewToFront(self)
        }
    }

    private func removeBlockingOverlay(from hostView: UIView) {
        hostView.viewWithTag(Self.blockingOverlayTag)?.removeFromSuperview()
    }

    // MARK: - Press state

    @objc private func handleTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.alpha = 0.6
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    @objc private func handleTouchUp() {
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1.0
            self.transform = .identity
        }
    }
}
