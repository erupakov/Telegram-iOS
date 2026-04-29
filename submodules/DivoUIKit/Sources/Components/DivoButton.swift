import UIKit
import Display

public final class DivoButton: UIButton {

    // MARK: - Design tokens

    private static let buttonFont = Font.helveticaNeue(20)
    private static let kern: CGFloat = 18 * 0.005 // 0.5 %
    private static let buttonHeight: CGFloat = 56
    private static let cornerRadius: CGFloat = 28 // TODO: DS alignment — не в шкале Radius
    
    private var normalTitle: String?
    private var loadingTitle: String?
    
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

    // MARK: - Configuration
    
    public func makeDivoButton(title: String, loading: String? = nil, buttonFont: UIFont = Font.helveticaNeue(20), radius: CGFloat? = nil) {
        normalTitle = title
        loadingTitle = loading
        
        applyNormalTitle(buttonFont: buttonFont)
        applyDisabledTitle(buttonFont: buttonFont)
        
        guard let radius = radius else { return }
        layer.cornerRadius = radius
    }
    
    // MARK: - Setup

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = DivoColorPalette.accent
        layer.cornerRadius = Self.cornerRadius

        contentEdgeInsets = UIEdgeInsets(top: 0, left: DivoDesignTokens.Spacing.m, bottom: 0, right:  DivoDesignTokens.Spacing.m)
        
        heightAnchor.constraint(equalToConstant: Self.buttonHeight).isActive = true

        addSubview(spinner)
        addSubview(savingLabel)

        NSLayoutConstraint.activate([
            savingLabel.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 12),
            savingLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: savingLabel.leadingAnchor, constant: -8),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        addDivoPressState(.primary)
    }

    // MARK: - Attributed titles

    private func applyNormalTitle(buttonFont: UIFont) {
        guard let normalTitle = normalTitle else { return }
        let attr: [NSAttributedString.Key: Any] = [
            .font: buttonFont,
            .kern: Self.kern,
            .foregroundColor: DivoColorPalette.primaryTextOnDark,
        ]
        setAttributedTitle(NSAttributedString(string: normalTitle, attributes: attr), for: .normal)
    }

    private func applyDisabledTitle(buttonFont: UIFont) {
        guard let normalTitle = normalTitle else { return }
        let attr: [NSAttributedString.Key: Any] = [
            .font: buttonFont,
            .kern: Self.kern,
            .foregroundColor: DivoColorPalette.disabledText,
        ]
        setAttributedTitle(NSAttributedString(string: normalTitle, attributes: attr), for: .disabled)
    }

    private func savingAttributedString() -> NSAttributedString {
        guard let loadingTitle = loadingTitle else { return NSAttributedString() }
        let attr: [NSAttributedString.Key: Any] = [
            .font: Self.buttonFont,
            .kern: Self.kern,
            .foregroundColor: DivoColorPalette.primaryTextOnDark,
        ]
        return NSAttributedString(string: loadingTitle, attributes: attr)
    }

    // MARK: - Highlight suppression

    override public var isHighlighted: Bool {
        didSet {}
    }

    // MARK: - Enabled / disabled

    override public var isEnabled: Bool {
        didSet {
            guard !isSaving else { return }
            backgroundColor = isEnabled ? DivoColorPalette.accent : DivoColorPalette.buttonDisabledBackground
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
                self.alpha = 0.7
            }

            installBlockingOverlay(on: hostView)
        } else {
            spinner.stopAnimating()

            UIView.animate(withDuration: 0.2) {
                self.titleLabel?.alpha = 1
                self.savingLabel.alpha = 0
                self.alpha = 1.0
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

}
