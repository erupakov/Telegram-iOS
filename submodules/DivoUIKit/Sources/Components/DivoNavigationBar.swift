import UIKit
import DivoCore
import Display

public enum BackButtonConfiguration {
    case circle(UIImage)
    case circleWithText
}

public enum RightButtonConfiguration {
    case circle(UIColor, UIColor, UIImage, DivoButtonStyle)
    case text(String)
    case onlyText(String)
}

public final class DivoNavigationBar: UIView {
    
    private var onBackTapped: (() -> Void)?
    private var onCircleRightTapped: (() -> Void)?
    private var onCircleTextTapped: (() -> Void)?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill

        button.layer.applyDivoShadow()
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let backTextButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = UIImage(systemName: "chevron.left", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = DivoColorPalette.primaryText
        
        button.setTitle(DivoStrings.back, for: .normal)
        button.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        button.titleLabel?.font = Font.medium(15)
        
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 20)
        
        button.layer.applyDivoShadow()
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let circleRightButton: UIButton = {
        let button = UIButton(type: .custom)
        button.adjustsImageWhenHighlighted = false
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        
        button.layer.applyDivoShadow()
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let textRightButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitleColor(DivoColorPalette.accent, for: .normal)
        btn.setTitleColor(DivoColorPalette.disabledText, for: .disabled)
        btn.titleLabel?.font = Font.regular(15)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let textRightLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(15)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
        
        addSubview(backTextButton)
        addSubview(backButton)
        addSubview(titleLabel)
        addSubview(circleRightButton)
        addSubview(textRightButton)
        addSubview(textRightLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 50),
            
            backTextButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            backTextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backTextButton.heightAnchor.constraint(equalToConstant: 40),
            
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            circleRightButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            circleRightButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            circleRightButton.widthAnchor.constraint(equalToConstant: 40),
            circleRightButton.heightAnchor.constraint(equalToConstant: 40),
            
            textRightButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            textRightButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            textRightButton.heightAnchor.constraint(equalToConstant: 40),
            
            textRightLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            textRightLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            textRightLabel.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    public func setTitle(_ title: String) {
        titleLabel.text = title.uppercased()
    }

    public func setEnableRightButton(_ isEnabled: Bool) {
        textRightButton.isEnabled = isEnabled
    }
    
    public func setRightTitle(_ title: String) {
        textRightLabel.text = title
    }

    /// Обновляет заголовок text-right кнопки. performWithoutAnimation + layoutIfNeeded —
    /// UIButton иногда не перерисовывает title сразу при вызове из notification observer'а.
    public func setRightButtonTitle(_ title: String) {
        UIView.performWithoutAnimation {
            textRightButton.setTitle(title, for: .normal)
            textRightButton.layoutIfNeeded()
        }
    }
    
    public func makeNavigationBar(
        title: String? = nil,
        font: UIFont? = Font.helveticaNeue(20),
        backButtonConfiguration: BackButtonConfiguration? = nil,
        rightButtonConfiguration: RightButtonConfiguration? = nil,
        onBackTapped: (() -> Void)? = nil,
        onCircleRightTapped: (() -> Void)? = nil,
        onCircleTextTapped: (() -> Void)? = nil,
        menu: UIMenu? = nil
    ) {
        self.titleLabel.text = title
        self.titleLabel.font = font
        switch backButtonConfiguration {
        case .circle(let image):
            backButton.isHidden = false
            backTextButton.isHidden = true

            backButton.setImage(image, for: .normal)
            backButton.tintColor = DivoColorPalette.primaryText

            backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
            backButton.addDivoPressState(.pill)
            
        case .circleWithText:
            backButton.isHidden = true
            backTextButton.isHidden = false
            backTextButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
            backTextButton.addDivoPressState(.pill)
        case .none:
            backButton.isHidden = true
            backTextButton.isHidden = true
        }
        switch rightButtonConfiguration {
        case .circle(let backgroundColor, let titleColor, let image, let style):
            circleRightButton.isHidden = false
            textRightButton.isHidden = true
            textRightLabel.isHidden = true
            
            circleRightButton.setImage(image, for: .normal)
            circleRightButton.setImage(image, for: .highlighted)
            circleRightButton.tintColor = titleColor
            circleRightButton.backgroundColor = backgroundColor

            circleRightButton.addTarget(self, action: #selector(circleRightTapped), for: .touchUpInside)
            circleRightButton.addDivoPressState(style)

            if #available(iOS 14.0, *) {
                if let menu = menu {
                    circleRightButton.adjustsImageWhenHighlighted = false
                    circleRightButton.menu = menu
                    circleRightButton.showsMenuAsPrimaryAction = true
                }
            }
        case .text(let title):
            circleRightButton.isHidden = true
            textRightButton.isHidden = false
            textRightLabel.isHidden = true
            textRightButton.setTitle(title, for: .normal)

            textRightButton.addTarget(self, action: #selector(circleTextTapped), for: .touchUpInside)
            textRightButton.addDivoPressState(.text)
        case .onlyText(let title):
            circleRightButton.isHidden = true
            textRightButton.isHidden = true
            textRightLabel.isHidden = false
            textRightLabel.text = title
        case .none:
            circleRightButton.isHidden = true
            textRightButton.isHidden = true
            textRightLabel.isHidden = true
        }
        self.onBackTapped = onBackTapped
        self.onCircleRightTapped = onCircleRightTapped
        self.onCircleTextTapped = onCircleTextTapped
    }
    
    @objc private func backTapped() {
        onBackTapped?()
    }

    @objc private func circleRightTapped() {
        onCircleRightTapped?()
    }
    
    @objc private func circleTextTapped() {
        onCircleTextTapped?()
    }
}
