import UIKit
import DivoUIKit

enum ProfileTab: Int, CaseIterable {
    case photo = 0
    case video = 1
    case models = 2
    case channels = 3
    case events = 4
}

protocol ProfileSegmentedBarDelegate: AnyObject {
    func segmentedBar(_ segmentedBar: ProfileSegmentedBar, didSelectIndex index: Int)
}

public final class ProfileSegmentedBar: UIView {
    
    weak var delegate: ProfileSegmentedBarDelegate?
    
    public private(set) var selectedIndex: Int = 0
    
    private let itemWidth: CGFloat = 54.0 
    private let padding: CGFloat = 1.0   
    
    public override var intrinsicContentSize: CGSize {
        let count = CGFloat(max(1, tabButtons.count))
        let totalWidth = (count * itemWidth) + (padding * 2)
        return CGSize(width: totalWidth, height: UIView.noIntrinsicMetric)
    }
    
    // MARK: - UI Elements
    
    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.masksToBounds = true
        return view
    }()
    
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.layer.masksToBounds = true
        return view
    }()
    
    private var tabButtons: [UIButton] = []
    
    // MARK: - Data
    
    private let modelIcons: [UIImage] = [
        DivoImage.photoIcon,
        DivoImage.videoIcon,
        DivoImage.channelIcon
    ]

    private let agencyIcons: [UIImage] = [
        DivoImage.photoIcon,
        DivoImage.videoIcon,
        DivoImage.associatedModels,
        DivoImage.channelIcon,
        DivoImage.eventsAgency
    ]
    
    private var currentIcons: [UIImage] = []

    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setup() {
        addSubview(backgroundView)
        backgroundView.addSubview(indicatorView)
    }
    
    // MARK: - Configuration
    
    func configure(isAgency: Bool, isMyProfile: Bool, animated: Bool = true) {
        // myProfile/нет: для модели всегда 3 таба, для агентства всегда 5.
        let newIcons = isAgency ? agencyIcons : modelIcons
        
        guard currentIcons != newIcons else { return }
        currentIcons = newIcons

        let updateActions = {
            self.tabButtons.forEach { $0.removeFromSuperview() }
            self.tabButtons.removeAll()

            for (index, icon) in newIcons.enumerated() {
                let button = UIButton(type: .custom)
                button.setImage(icon, for: .normal)
                button.tag = index
                button.addTarget(self, action: #selector(self.tabTapped(_:)), for: .touchUpInside)
                
                self.backgroundView.addSubview(button)
                self.tabButtons.append(button)
            }
            
            self.selectedIndex = 0
            self.invalidateIntrinsicContentSize()
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
        
        if animated && self.window != nil {
            UIView.transition(with: self, duration: 0.25, options: .transitionCrossDissolve, animations: updateActions, completion: nil)
        } else {
            updateActions()
        }
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.frame = bounds
        backgroundView.layer.cornerRadius = bounds.height / 2
        layoutIndicator()
        applyPillShadow()
    }

    // Лёгкая тень под пилюлей сегмент-бара. Нужна, чтобы на эмпти-табах
    // (где зона вокруг пилюли становится белой) пилюля не сливалась с фоном.
    // Тень рисуется на самом self.layer, потому что у backgroundView
    // masksToBounds=true (для корректного клиппинга индикатора по скруглению).
    private func applyPillShadow() {
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2)
        layer.shadowPath = path.cgPath
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        layer.masksToBounds = false
    }

    private func layoutIndicator() {
        guard selectedIndex < tabButtons.count, !tabButtons.isEmpty else { return }
        
        let tabCount = CGFloat(tabButtons.count)
        let padding: CGFloat = 2
        let segmentWidth = (bounds.width - padding * 2) / tabCount
        let indicatorX = padding + CGFloat(selectedIndex) * segmentWidth
        let indicatorHeight = bounds.height - padding * 2

        indicatorView.frame = CGRect(x: indicatorX, y: padding, width: segmentWidth, height: indicatorHeight)
        indicatorView.layer.cornerRadius = indicatorHeight / 2

        for (i, button) in tabButtons.enumerated() {
            button.frame = CGRect(x: padding + CGFloat(i) * segmentWidth, y: 0, width: segmentWidth, height: bounds.height)
        }
    }

    // MARK: - User Tap

    @objc private func tabTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedIndex else { return }
        selectedIndex = index

        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        UIView.animate(withDuration: 0.30, delay: 0, options: [.curveEaseOut]) {
            self.layoutIndicator()
        }
        delegate?.segmentedBar(self, didSelectIndex: index)
    }

    // MARK: - Programmatic Selection

    public func selectIndex(_ index: Int, animated: Bool = true) {
        guard index != selectedIndex, index >= 0, index < tabButtons.count else { return }
        selectedIndex = index

        if animated {
            UIView.animate(withDuration: 0.30, delay: 0, options: [.curveEaseOut]) {
                self.layoutIndicator()
            }
        } else {
            layoutIndicator()
        }
    }

    /// Позволяет индикатору двигаться плавно при свайпе в UIScrollView
    public func setIndicatorProgress(_ progress: CGFloat) {
        guard bounds.width > 0, !tabButtons.isEmpty else { return }
        let tabCount = CGFloat(tabButtons.count)
        let padding: CGFloat = 2
        let segmentWidth = (bounds.width - padding * 2) / tabCount
        let indicatorX = padding + progress * segmentWidth
        indicatorView.frame.origin.x = indicatorX
    }
}
