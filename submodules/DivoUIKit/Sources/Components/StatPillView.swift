import UIKit
import Display
import DivoCore

public final class StatPillView: UIControl {

    private static let pillHeight: CGFloat = 30

    // MARK: - Actions
    
    public var onIconTap: (() -> Void)?
    public var onLabelTap: (() -> Void)?
    public var onAnyTap: (() -> Void)?
    
    // MARK: - UI Elements
    
    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = DivoColorPalette.statPillForeground
        return iv
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.textColor = DivoColorPalette.statPillForeground
        label.font = Font.helveticaNeue(12)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        return label
    }()

    private let normalIcon: UIImage?
    private let filledIcon: UIImage?

    // MARK: - Init
    
    public init(icon: UIImage, filledIcon: UIImage? = nil) {
        self.normalIcon = icon.withRenderingMode(.alwaysTemplate)
        self.filledIcon = filledIcon?.withRenderingMode(.alwaysTemplate)
        super.init(frame: .zero)
        
        backgroundColor = DivoColorPalette.statPillBackground
        layer.cornerRadius = Self.pillHeight / 2
        layer.masksToBounds = true
        layer.borderWidth = 0.5
        layer.borderColor = DivoColorPalette.statPillBorder.cgColor

        iconView.image = normalIcon

        addSubview(iconView)
        addSubview(countLabel)

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: Self.pillHeight).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods
    
    public func setValue(_ text: String) {
        countLabel.text = text
        setNeedsLayout()
    }

    public func setActive(_ active: Bool, animated: Bool = false) {
        let change = {
            if active {
                self.backgroundColor = DivoColorPalette.statPillActiveBackground
                self.layer.borderColor = DivoColorPalette.statPillActiveBackground.cgColor
                self.iconView.tintColor = DivoColorPalette.statPillActiveForeground
                self.countLabel.textColor = DivoColorPalette.statPillActiveForeground
                if let filled = self.filledIcon {
                    self.iconView.image = filled
                }
            } else {
                self.backgroundColor = DivoColorPalette.statPillBackground
                self.layer.borderColor = DivoColorPalette.statPillBorder.cgColor
                self.iconView.tintColor = DivoColorPalette.statPillForeground
                self.countLabel.textColor = DivoColorPalette.statPillForeground
                self.iconView.image = self.normalIcon
            }
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: change)
        } else {
            change()
        }
    }

    public func popIcon() {
        iconView.divoPopAnimate()
    }

    // MARK: - Layout
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        let iconSize: CGFloat = 16
        let iconX: CGFloat = 8
        let iconY: CGFloat = (bounds.height - iconSize) / 2
        iconView.frame = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
        
        let labelX: CGFloat = iconX + iconSize + 4
        let labelWidth = bounds.width - labelX - 4
        countLabel.frame = CGRect(x: labelX, y: 0, width: max(labelWidth, 0), height: bounds.height)
    }

    override public var intrinsicContentSize: CGSize {
        return CGSize(width: 64, height: 30)
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        return intrinsicContentSize
    }
    
    // MARK: - Touch Tracking (Разделение кликов)
    
    override public var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.6 : 1.0
            }
        }
    }
    
    override public func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        return true 
    }
    
    override public func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        
        guard let location = touch?.location(in: self) else { return }
        
        guard bounds.contains(location) else { return }
        
        if onIconTap != nil || onLabelTap != nil {
            
            let iconHitArea = CGRect(x: 0, y: 0, width: countLabel.frame.minX, height: bounds.height)
            
            if iconHitArea.contains(location) {
                onIconTap?()
            } else {
                onLabelTap?()
            }
            
        }
        else if let anyTap = onAnyTap {
            anyTap()
        }
    }
}