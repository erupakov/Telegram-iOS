import UIKit
import Display

struct AppearanceAttribute {
    let title: String
    let value: String
}

protocol ProfileInfoViewDelegate: AnyObject {
    func profileInfoViewDidUpdateContentHeight()
}

final class ProfileInfoView: UIView {
    weak var delegate: ProfileInfoViewDelegate?
    private let maxLinesCollapsed: Int = 3
    private var isExpanded: Bool = false
    private var biographyText: String
    private var appearanceData: [AppearanceAttribute]
    private let headerHeight: CGFloat = 30
    
    private var selectedIndex: Int = 0 {
        didSet {
            isExpanded = false
            updateContent(animated: true)
            updateHeaderAppearance(animated: true)
        }
    }
    
    private let biographyButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(.white, for: .normal)
        button.setTitle("BIOGRAPHY", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let appearanceButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(.white, for: .normal)
        button.setTitle("APPEARANCE", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
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
        label.font = UIFont.systemFont(ofSize: 12)
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
        button.setTitle("SEE MORE", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeaderAppearance(animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(biography: String, appearance: [AppearanceAttribute]) {
        self.biographyText = biography
        self.appearanceData = appearance
        rebuildAppearanceGrid()
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
        
        let seeMoreStack = UIStackView(arrangedSubviews: [UIView(), seeMoreButton])
        seeMoreStack.axis = .horizontal
        seeMoreStack.translatesAutoresizingMaskIntoConstraints = false
        
        let mainStack = UIStackView(arrangedSubviews: [contentLabel, appearanceStack, seeMoreStack])
        mainStack.axis = .vertical
        mainStack.spacing = 5
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        appearanceStack.setContentCompressionResistancePriority(.required, for: .vertical)
        appearanceStack.setContentHuggingPriority(.required, for: .vertical)
        
        addSubview(headerView)
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: self.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerHeight),
            
            headerStack.topAnchor.constraint(equalTo: headerView.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            headerStack.heightAnchor.constraint(equalToConstant: headerHeight - 3),
            
            indicatorView.topAnchor.constraint(equalTo: headerStack.bottomAnchor),
            indicatorView.heightAnchor.constraint(equalToConstant: 3),
            
            mainStack.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -10)
        ])
        
        indicatorLeadingConstraint = indicatorView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16)
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
        
        if isBio {
            contentLabel.text = biographyText
            contentLabel.numberOfLines = isExpanded ? 0 : maxLinesCollapsed
            let contentWidth = bounds.width - 32
            let lineCount = biographyText.lineCount(for: contentLabel.font, width: contentWidth)
            updateSeeMoreButton(visible: lineCount > maxLinesCollapsed)
        } else {
            updateSeeMoreButton(visible: false)
        }
        
        let changes = {
            self.contentLabel.alpha = isBio ? 1 : 0
            self.appearanceStack.alpha = isBio ? 0 : 1
        }
        
        let completion: (Bool) -> Void = { _ in
            self.contentLabel.isHidden = !isBio
            self.appearanceStack.isHidden = isBio
            
            self.delegate?.profileInfoViewDidUpdateContentHeight()
        }
        
        if animated {
            UIView.animate(withDuration: 0.05, animations: changes, completion: completion)
        } else {
            changes()
            contentLabel.isHidden = !isBio
            appearanceStack.isHidden = isBio
            delegate?.profileInfoViewDidUpdateContentHeight()
        }
    }
    
    private func updateSeeMoreButton(visible: Bool) {
        if visible {
            seeMoreButton.isHidden = false
            seeMoreButton.setTitle(isExpanded ? "SEE LESS" : "SEE MORE", for: .normal)
        } else {
            seeMoreButton.isHidden = true
        }
    }
    
    private func updateHeaderAppearance(animated: Bool) {
        let selectedColor: UIColor = .white
        let unselectedColor: UIColor = .white.withAlphaComponent(0.6)
        
        biographyButton.setTitleColor(selectedIndex == 0 ? selectedColor : unselectedColor, for: .normal)
        appearanceButton.setTitleColor(selectedIndex == 1 ? selectedColor : unselectedColor, for: .normal)
        
        let selectedButton = selectedIndex == 0 ? biographyButton : appearanceButton
        guard selectedButton.frame.width > 0 else { return }
        
        let buttonFrameInHeader = selectedButton.convert(selectedButton.bounds, to: headerView)
        
        let actions = {
            self.indicatorLeadingConstraint.constant = buttonFrameInHeader.minX
            self.indicatorWidthConstraint.constant = buttonFrameInHeader.width
            self.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(withDuration: 0.25, animations: actions)
        } else {
            UIView.performWithoutAnimation(actions)
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
