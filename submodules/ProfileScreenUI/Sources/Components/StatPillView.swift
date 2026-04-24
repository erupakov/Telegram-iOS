import UIKit
import DivoCore
import DivoUIKit

final class StatPillView: UIControl {
    
    // MARK: - Actions
    
    var onIconTap: (() -> Void)?
    var onLabelTap: (() -> Void)?
    var onAnyTap: (() -> Void)?
    
    // MARK: - UI Elements
    
    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = .white
        return iv
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "HelveticaNeue", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .regular)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        return label
    }()

    private let normalIcon: UIImage?
    private let filledIcon: UIImage?

    // MARK: - Init
    
    init(icon: UIImage, filledIcon: UIImage? = nil) {
        self.normalIcon = icon.withRenderingMode(.alwaysTemplate)
        self.filledIcon = filledIcon?.withRenderingMode(.alwaysTemplate)
        super.init(frame: .zero)
        
        backgroundColor = DivoColorPalette.statPillBackground
        layer.cornerRadius = 15
        layer.masksToBounds = true
        layer.borderWidth = 0.5
        layer.borderColor = DivoColorPalette.statPillBorder.cgColor

        iconView.image = normalIcon

        addSubview(iconView)
        addSubview(countLabel)

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods
    
    func setValue(_ text: String) {
        countLabel.text = text
        setNeedsLayout()
    }

    func setActive(_ active: Bool, animated: Bool = false) {
        let change = {
            if active {
                self.backgroundColor = .white
                self.layer.borderColor = UIColor.white.cgColor
                self.iconView.tintColor = .black
                self.countLabel.textColor = .black
                if let filled = self.filledIcon {
                    self.iconView.image = filled
                }
            } else {
                self.backgroundColor = DivoColorPalette.statPillBackground
                self.layer.borderColor = DivoColorPalette.statPillBorder.cgColor
                self.iconView.tintColor = .white
                self.countLabel.textColor = .white
                self.iconView.image = self.normalIcon
            }
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: change)
        } else {
            change()
        }
    }

    func popIcon() {
        UIView.animate(withDuration: 0.1, animations: {
            self.iconView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options:[], animations: {
                self.iconView.transform = .identity
            }, completion: nil)
        }
    }

    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let iconSize: CGFloat = 16
        let iconX: CGFloat = 8
        let iconY: CGFloat = (bounds.height - iconSize) / 2
        iconView.frame = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
        
        let labelX: CGFloat = iconX + iconSize + 4
        let labelWidth = bounds.width - labelX - 4
        countLabel.frame = CGRect(x: labelX, y: 0, width: max(labelWidth, 0), height: bounds.height)
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: 64, height: 30)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return intrinsicContentSize
    }
    
    // MARK: - Touch Tracking (Разделение кликов)
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.6 : 1.0
            }
        }
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        return true 
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
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