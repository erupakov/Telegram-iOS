import UIKit
import Display
import TelegramCore
import DivoCore

struct AppearanceAttribute {
    let title: String
    let value: String
}

protocol ProfileInfoViewDelegate: AnyObject {
    func profileInfoViewDidUpdateContentHeight(animated: Bool)
}

final class ProfileInfoView: UIView {
    weak var delegate: ProfileInfoViewDelegate?
    private let maxLinesCollapsed: Int = 3
    private var isExpanded: Bool = false
    private var biographyText: String
    private var appearanceData: [AppearanceAttribute]
    private let headerHeight: CGFloat = 32
    
    private var selectedIndex: Int = 0 {
        didSet {
            isExpanded = false
//            updateContent(animated: true)
            updateContent(animated: false)
            updateHeaderAppearance(animated: true)
        }
    }
    
    private let biographyButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.titleLabel?.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        button.setTitleColor(.white, for: .normal)
        button.setTitle(DivoStrings.biography, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let appearanceButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.titleLabel?.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        button.setTitleColor(.white, for: .normal)
        button.setTitle(DivoStrings.appearance, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
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
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black.withAlphaComponent(0.12)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(12)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let appearanceStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .top
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true
        return stack
    }()
    
    private let seeMoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(.white, for: .normal)
        button.setTitle(DivoStrings.seeMore, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let mainStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let seeMoreStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private var headerHeightConstraint: NSLayoutConstraint!
    private var indicatorLeadingConstraint: NSLayoutConstraint!
    private var indicatorWidthConstraint: NSLayoutConstraint!
    
    init(biography: String, appearance: [AppearanceAttribute]) {
        self.biographyText = biography
        self.appearanceData = appearance
        super.init(frame: .zero)
        self.backgroundColor = .black.withAlphaComponent(0.15)
        setupViews()
        configureActions()
        rebuildAppearanceGrid()
        DispatchQueue.main.async {
            self.updateHeaderAppearance(animated: false)
            self.updateContent(animated: false)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeaderAppearance(animated: false)
    }
    
    func update(biography: String, appearance: [AppearanceAttribute]) {
        self.biographyText = biography
        self.appearanceData = appearance
        rebuildAppearanceGrid()
        updateContent(animated: false)
        setNeedsLayout()
    }
    
    func update(biography: String) {
        self.biographyText = biography
        self.biographyButton.isHidden = true
        self.appearanceButton.isHidden = true
        headerHeightConstraint.isActive = false
        updateContent(animated: false)
        setNeedsLayout()
    }
    
    private func setupViews() {
        let headerStack = UIStackView(arrangedSubviews: [biographyButton, appearanceButton])
        headerStack.axis = .horizontal
        headerStack.distribution = .fillEqually
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(headerStack)
        headerView.addSubview(indicatorView)
        
        seeMoreStack.addArrangedSubview(UIView())
        seeMoreStack.addArrangedSubview(seeMoreButton)
        
        mainStack.addArrangedSubview(contentLabel)
        mainStack.addArrangedSubview(appearanceStack)
        mainStack.addArrangedSubview(seeMoreStack)
        
        appearanceStack.setContentCompressionResistancePriority(.required, for: .vertical)
        appearanceStack.setContentHuggingPriority(.required, for: .vertical)
        
        addSubview(headerView)
        addSubview(mainStack)
        
        headerHeightConstraint = headerView.heightAnchor.constraint(equalToConstant: headerHeight)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: self.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            headerHeightConstraint,
            
            headerStack.topAnchor.constraint(equalTo: headerView.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerStack.heightAnchor.constraint(equalToConstant: headerHeight - 2),
            
            indicatorView.heightAnchor.constraint(equalToConstant: 2),
            indicatorView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            
            mainStack.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -10)
        ])
        
        indicatorLeadingConstraint = indicatorView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 60)
        indicatorWidthConstraint = indicatorView.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            indicatorLeadingConstraint,
            indicatorWidthConstraint
        ])
    }
    
    private func rebuildAppearanceGrid() {
        appearanceStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let leftStack = UIStackView()
        leftStack.axis = .vertical
        leftStack.spacing = 10
        
        let rightStack = UIStackView()
        rightStack.axis = .vertical
        rightStack.spacing = 10
        
        for (index, attr) in appearanceData.enumerated() {
            let itemView = createAttributeView(title: attr.title, value: attr.value)
            if index % 2 == 0 {
                leftStack.addArrangedSubview(itemView)
            } else {
                rightStack.addArrangedSubview(itemView)
            }
        }
        
        appearanceStack.addArrangedSubview(leftStack)
        appearanceStack.addArrangedSubview(rightStack)
    }
    
    private func createAttributeView(title: String, value: String) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 12)
        titleLabel.textColor = .white.withAlphaComponent(0.6)
        titleLabel.text = title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        valueLabel.textColor = .white
        valueLabel.text = value
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let line = UIView()
        line.backgroundColor = .white.withAlphaComponent(0.3)
        line.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        container.addSubview(line)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: container.topAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 4),
            
            line.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func updateContent(animated: Bool) {
        let isBio = selectedIndex == 0
        var shouldShowSeeMore = false

        if isBio {
            contentLabel.text = biographyText
            contentLabel.numberOfLines = isExpanded ? 0 : maxLinesCollapsed

            let viewWidth = self.bounds.width > 0 ? self.bounds.width : UIScreen.main.bounds.width
            let labelWidth = viewWidth - 32
            let actualLines = biographyText.lineCount(for: contentLabel.font, width: labelWidth)
            shouldShowSeeMore = actualLines > maxLinesCollapsed
        } else {
            let dataToShow: [AppearanceAttribute]
            if isExpanded {
                dataToShow = appearanceData
            } else {
                dataToShow = Array(appearanceData.prefix(4))
            }
            rebuildAppearanceGrid(with: dataToShow)
            shouldShowSeeMore = appearanceData.count > 4
        }

        let newTitle = isExpanded ? DivoStrings.seeLess : DivoStrings.seeMore
        if animated {
            UIView.transition(with: seeMoreButton, duration: 0.25, options: .transitionCrossDissolve) {
                self.seeMoreButton.setTitle(newTitle, for: .normal)
            }
        } else {
            seeMoreButton.setTitle(newTitle, for: .normal)
        }

        seeMoreStack.isHidden = !shouldShowSeeMore
        contentLabel.alpha = isBio ? 1 : 0
        contentLabel.isHidden = !isBio
        appearanceStack.alpha = isBio ? 0 : 1
        appearanceStack.isHidden = isBio

        self.delegate?.profileInfoViewDidUpdateContentHeight(animated: false)
    }
    
    private func rebuildAppearanceGrid(with attributes: [AppearanceAttribute]) {
        appearanceStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let leftStack = UIStackView()
        leftStack.axis = .vertical
        leftStack.spacing = 10
        
        let rightStack = UIStackView()
        rightStack.axis = .vertical
        rightStack.spacing = 10
        
        for (index, attr) in attributes.enumerated() {
            let itemView = createAttributeView(title: attr.title, value: attr.value)
            if index % 2 == 0 {
                leftStack.addArrangedSubview(itemView)
            } else {
                rightStack.addArrangedSubview(itemView)
            }
        }
        
        appearanceStack.addArrangedSubview(leftStack)
        appearanceStack.addArrangedSubview(rightStack)
    }
    
    private func updateHeaderAppearance(animated: Bool) {
        let selectedColor: UIColor = .white
        let unselectedColor: UIColor = .white.withAlphaComponent(0.6)
        
        biographyButton.setTitleColor(selectedIndex == 0 ? selectedColor : unselectedColor, for: .normal)
        appearanceButton.setTitleColor(selectedIndex == 1 ? selectedColor : unselectedColor, for: .normal)
        
        let selectedButton = selectedIndex == 0 ? biographyButton : appearanceButton
        
        let label = UILabel()
        label.font = selectedButton.titleLabel?.font
        label.text = selectedButton.title(for: .normal)
        label.sizeToFit()
        
        let newIndicatorWidth = label.frame.width
        
        let newIndicatorX = selectedButton.center.x - (newIndicatorWidth / 2)
        
        let actions = {
            self.indicatorLeadingConstraint.constant = newIndicatorX
            self.indicatorWidthConstraint.constant = newIndicatorWidth
            self.headerView.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [.curveEaseOut],
                animations: actions
            )
        } else {
            indicatorLeadingConstraint.constant = newIndicatorX
            indicatorWidthConstraint.constant = newIndicatorWidth
        }
    }
    
    private func configureActions() {
        biographyButton.addTarget(self, action: #selector(biographyTapped), for: .touchUpInside)
        appearanceButton.addTarget(self, action: #selector(appearanceTapped), for: .touchUpInside)
        seeMoreButton.addTarget(self, action: #selector(seeMoreTapped), for: .touchUpInside)
    }
    
    @objc private func biographyTapped() {
        guard selectedIndex != 0 else { return }
        selectedIndex = 0
    }
    
    @objc private func appearanceTapped() {
        guard selectedIndex != 1 else { return }
        selectedIndex = 1
    }
    
    @objc private func seeMoreTapped() {
        isExpanded.toggle()
        updateContent(animated: true)
    }
}

private extension String {
    func lineCount(for font: UIFont, width: CGFloat) -> Int {
        guard width > 0 else { return 0 }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let rect = self.boundingRect(
            with: size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        
        return Int(ceil(rect.height / font.lineHeight))
    }
}

import UIKit

extension UIView {
    func startShimmering() {
        let gradient = CAGradientLayer()
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        
        let baseColor = UIColor(white: 0.85, alpha: 1.0).cgColor
        let highlightColor = UIColor(white: 0.95, alpha: 1.0).cgColor
        
        gradient.colors = [baseColor, highlightColor, baseColor]
        gradient.locations = [0.0, 0.5, 1.0]
        
        gradient.frame = CGRect(x: -self.bounds.width, y: 0, width: self.bounds.width * 3, height: self.bounds.height)
        
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [0.0, 0.1, 0.2]
        animation.toValue = [0.8, 0.9, 1.0]
        animation.duration = 1.5
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        
        gradient.add(animation, forKey: "shimmer")
        
        self.layer.mask = self.layer.cornerRadius > 0 ? nil : nil
        self.layer.addSublayer(gradient)
        self.layer.masksToBounds = true
    }
    
    func stopShimmering() {
        self.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }
}
