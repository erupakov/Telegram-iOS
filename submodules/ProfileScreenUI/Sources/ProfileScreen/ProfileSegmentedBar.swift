import UIKit

enum ProfileTab: Int {
    case photo = 0
    case video = 1
    case models = 2
    case channels = 3
    case events = 4
}

protocol ProfileSegmentedBarDelegate: AnyObject {
    func segmentedBar(_ segmentedBar: ProfileSegmentedBar, didSelectIndex index: Int)
}

final class ProfileSegmentedBar: UIView {
    
    weak var delegate: ProfileSegmentedBarDelegate?
    
    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 0
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 2
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()
    
    private var indicatorCenterXConstraint: NSLayoutConstraint?
    private var indicatorWidthConstraint: NSLayoutConstraint!
    
    private let myProfileIconNames: [String] = [
        "Components/GridIcon",
        "Components/FilmstripIcon"
    ]
    
    private let modelIconNames: [String] = [
        "Components/GridIcon",
        "Components/FilmstripIcon",
        "Components/SaveMedia"
    ]
    
    private let agencyIconNames: [String] = [
        "Components/GridIcon",
        "Components/FilmstripIcon",
        "Components/AssociatedModels",
        "Components/SaveMedia",
        "Components/EventsAgency"
    ]
    
    private var imageViews: [UIImageView] = []
    
    private let indicatorTargetWidth: CGFloat = 44.0
    
    private var selectedIndex: Int = 0 {
        didSet {
            guard oldValue != selectedIndex else { return }
            updateButtonStyles()
            moveIndicator(to: selectedIndex, animated: true)
            delegate?.segmentedBar(self, didSelectIndex: selectedIndex)
        }
    }

    func selectIndex(_ index: Int) {
        guard index >= 0 && index < imageViews.count else { return }
        selectedIndex = index
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        self.backgroundColor = .clear
        
        configure(isAgency: false, isMyProfile: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(buttonStack)
        addSubview(indicatorView)
        
        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: topAnchor),
            buttonStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            buttonStack.heightAnchor.constraint(equalToConstant: 44),
            
            indicatorView.bottomAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: -4),
            indicatorView.heightAnchor.constraint(equalToConstant: 2.0)
        ])
        
        indicatorWidthConstraint = indicatorView.widthAnchor.constraint(equalToConstant: indicatorTargetWidth)
        indicatorWidthConstraint.isActive = true
    }
    
    func configure(isAgency: Bool, isMyProfile: Bool, animated: Bool = true) {
        let icons = isAgency ? agencyIconNames : (isMyProfile ? myProfileIconNames : modelIconNames)
        
        guard imageViews.count != icons.count else { return }
        
        let updateActions = {
            self.buttonStack.arrangedSubviews.forEach {
                self.buttonStack.removeArrangedSubview($0)
                $0.removeFromSuperview()
            }
            self.imageViews.removeAll()
            
            for (index, iconName) in icons.enumerated() {
                let containerView = UIView()
                containerView.translatesAutoresizingMaskIntoConstraints = false
                containerView.tag = index
                
                let iconImageView: UIImageView = {
                    let iv = UIImageView()
                    let iconImage = UIImage(bundleImageName: iconName)?.withRenderingMode(.alwaysTemplate)
                    iv.image = iconImage
                    iv.contentMode = .scaleAspectFit
                    iv.translatesAutoresizingMaskIntoConstraints = false
                    return iv
                }()
                
                containerView.addSubview(iconImageView)
                
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.iconTapped(_:)))
                containerView.addGestureRecognizer(tapGesture)
                containerView.isUserInteractionEnabled = true
                
                NSLayoutConstraint.activate([
                    iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                    iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                    iconImageView.widthAnchor.constraint(equalToConstant: 24),
                    iconImageView.heightAnchor.constraint(equalToConstant: 24)
                ])
                
                self.buttonStack.addArrangedSubview(containerView)
                self.imageViews.append(iconImageView)
            }
            
            self.selectedIndex = 0
            
            self.updateButtonStyles()
            self.setupInitialIndicatorState()
            self.layoutIfNeeded()
        }
        
        if animated && self.window != nil {
            let transition = CATransition()
            transition.duration = 0.2
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            transition.type = .moveIn
            transition.subtype = .fromBottom
            self.layer.add(transition, forKey: "curtainTransition")
            
            updateActions()
            
        } else {
            updateActions()
        }
    }
    
    private func setupInitialIndicatorState() {
        guard !buttonStack.arrangedSubviews.isEmpty else { return }
        
        indicatorCenterXConstraint?.isActive = false
        
        let firstButton = buttonStack.arrangedSubviews[0]
        indicatorCenterXConstraint = indicatorView.centerXAnchor.constraint(equalTo: firstButton.centerXAnchor)
        indicatorCenterXConstraint?.isActive = true
    }
    
    @objc private func iconTapped(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view else { return }
        selectedIndex = view.tag
    }
    
    private func updateButtonStyles() {
        for (index, imageView) in imageViews.enumerated() {
            imageView.tintColor = index == selectedIndex ? .white : .white.withAlphaComponent(0.4)
        }
    }
    
    private func moveIndicator(to index: Int, animated: Bool) {
        guard index >= 0, index < buttonStack.arrangedSubviews.count else { return }
        
        let targetButton = buttonStack.arrangedSubviews[index]
        
        if let existing = indicatorCenterXConstraint {
            existing.isActive = false
        }
        
        let newConstraint = indicatorView.centerXAnchor.constraint(equalTo: targetButton.centerXAnchor)
        newConstraint.isActive = true
        self.indicatorCenterXConstraint = newConstraint
        
        if animated {
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [.curveEaseOut],
                animations: {
                    self.layoutIfNeeded()
                }, completion: nil
            )
        } else {
            self.layoutIfNeeded()
        }
    }
}
