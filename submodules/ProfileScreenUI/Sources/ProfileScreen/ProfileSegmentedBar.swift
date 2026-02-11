import UIKit

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
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var indicatorLeadingConstraint: NSLayoutConstraint!
    private var indicatorWidthConstraint: NSLayoutConstraint!

    private let iconNames: [String] = [
        "Models/GridIcon",
        "Models/FilmstripIcon",
        "Models/SaveMedia"
    ]
    
    private var imageViews: [UIImageView] = []
    
    private var selectedIndex: Int = 0 {
        didSet {
            guard oldValue != selectedIndex else { return }
            updateButtonStyles()
            animateIndicator(to: selectedIndex)
            delegate?.segmentedBar(self, didSelectIndex: selectedIndex)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        updateButtonStyles()
        self.backgroundColor = .black.withAlphaComponent(0.15)
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

            indicatorView.bottomAnchor.constraint(equalTo: buttonStack.bottomAnchor),
            indicatorView.heightAnchor.constraint(equalToConstant: 2.0)
        ])

        setupImageActions()
        
        indicatorWidthConstraint = indicatorView.widthAnchor.constraint(equalToConstant: 0)
        indicatorLeadingConstraint = indicatorView.leadingAnchor.constraint(equalTo: leadingAnchor)
        
        NSLayoutConstraint.activate([indicatorWidthConstraint, indicatorLeadingConstraint])
    }

    private func setupImageActions() {
        for (index, iconName) in iconNames.enumerated() {
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
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(iconTapped(_:)))
            containerView.addGestureRecognizer(tapGesture)
            containerView.isUserInteractionEnabled = true
            
            NSLayoutConstraint.activate([
                iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                iconImageView.widthAnchor.constraint(equalToConstant: 24),
                iconImageView.heightAnchor.constraint(equalToConstant: 24)
            ])
            
            buttonStack.addArrangedSubview(containerView)
            imageViews.append(iconImageView)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        positionIndicator(for: selectedIndex, animated: false)
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
    
    private func positionIndicator(for index: Int, animated: Bool) {
        guard index >= 0, index < buttonStack.arrangedSubviews.count,
              let selectedContainer = buttonStack.arrangedSubviews[index] as UIView?
        else {
            return
        }

        indicatorLeadingConstraint.isActive = false
        indicatorWidthConstraint.isActive = false

        indicatorWidthConstraint = indicatorView.widthAnchor.constraint(equalToConstant: selectedContainer.frame.width)
        indicatorLeadingConstraint = indicatorView.leadingAnchor.constraint(equalTo: selectedContainer.leadingAnchor)

        NSLayoutConstraint.activate([indicatorWidthConstraint, indicatorLeadingConstraint])
        
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut], animations: {
                self.layoutIfNeeded()
            }, completion: nil)
        } else {
            layoutIfNeeded()
        }
    }
    
    private func animateIndicator(to newIndex: Int) {
        positionIndicator(for: newIndex, animated: true)
    }
}
