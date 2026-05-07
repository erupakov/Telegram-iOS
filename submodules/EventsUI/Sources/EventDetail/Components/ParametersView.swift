import UIKit
import Display
import DivoUIKit
import DivoCore

struct AppearanceAttribute {
    let title: String
    let value: String
}

protocol ParametersViewDelegate: AnyObject {
    func parametersViewDidUpdateContentHeight(animated: Bool)
}

final class ParametersView: UIView {
    weak var delegate: ParametersViewDelegate?
    
    private var isExpanded: Bool = false
    
    private var currentAppearanceExpandedState: Bool? = nil
    
    private var appearanceData: [AppearanceAttribute] = []
    
    private var selectedIndex: Int = 0
    private var currentTabTitles: [String] = []
    
    private var segmentedControlHeightConstraint: NSLayoutConstraint!
    private var horizontalPagerTopConstraint: NSLayoutConstraint!
    private var pagerHeightConstraint: NSLayoutConstraint!
    
    private var bioVerticalStackBottomConstraint: NSLayoutConstraint!
    private var appearanceVerticalStackBottomConstraint: NSLayoutConstraint!
    

    private var dynamicPagerConstraints: [NSLayoutConstraint] = []
    private var activeContainers: [UIView] = []
    private let contentWidthView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - UI Elements
        
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.parametersForApplying
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var horizontalPager: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.clipsToBounds = false
        sv.isScrollEnabled = false
        sv.contentInsetAdjustmentBehavior = .never
        return sv
    }()
    
    private let appearanceContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let appearanceInternalContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let appearanceVerticalStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
        
    private let appearanceStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .top
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let appearanceSeeMoreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        button.setTitle(DivoStrings.seeMore, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let appearanceSeeMoreWrapper: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Init
    
    init(appearance: [AppearanceAttribute] = []) {
        super.init(frame: .zero)

        setupViews()
        configureActions()
        
        update(appearance: appearance)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Updates
    
    func update(appearance: [AppearanceAttribute]) {
        self.appearanceData = appearance
        
        self.currentAppearanceExpandedState = nil
            
        var titles: [String] = [DivoStrings.biographyTitle]
        var newActiveContainers: [UIView] = []
        
        if !appearance.isEmpty {
            titles.append(DivoStrings.appearanceTitle)
            newActiveContainers.append(appearanceContainer)
        }
        
        if currentTabTitles != titles || activeContainers != newActiveContainers {
            currentTabTitles = titles
            activeContainers = newActiveContainers
            rebuildPagerLayout()
        }
        
//        if titles.count <= 1 {
//            segmentedControlHeightConstraint.constant = 0
//            horizontalPagerTopConstraint.constant = 0
//        } else {
//            segmentedControlHeightConstraint.constant = DivoDesignTokens.Spacing.xl
//            horizontalPagerTopConstraint.constant = 10
//        }
        
        if selectedIndex >= titles.count {
            selectedIndex = 0
        }
        
        updateContent(animated: false)
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        addSubview(horizontalPager)
        
        horizontalPager.addSubview(contentWidthView)

        appearanceSeeMoreWrapper.addArrangedSubview(UIView())
        appearanceSeeMoreWrapper.addArrangedSubview(appearanceSeeMoreButton)
        
        appearanceContainer.addSubview(appearanceInternalContainer)

        appearanceInternalContainer.addSubview(titleLabel)
        appearanceInternalContainer.addSubview(appearanceVerticalStack)
        appearanceVerticalStack.addArrangedSubview(appearanceStack)
        appearanceVerticalStack.addArrangedSubview(appearanceSeeMoreWrapper)
        
        pagerHeightConstraint = horizontalPager.heightAnchor.constraint(equalToConstant: 50)

        appearanceVerticalStackBottomConstraint = appearanceVerticalStack.bottomAnchor.constraint(equalTo: appearanceInternalContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs)
        
        NSLayoutConstraint.activate([
            horizontalPager.topAnchor.constraint(equalTo: self.topAnchor),
            horizontalPager.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            horizontalPager.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            horizontalPager.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            pagerHeightConstraint,
            
            contentWidthView.topAnchor.constraint(equalTo: horizontalPager.topAnchor),
            contentWidthView.bottomAnchor.constraint(equalTo: horizontalPager.bottomAnchor),
            contentWidthView.leadingAnchor.constraint(equalTo: horizontalPager.leadingAnchor),
            contentWidthView.trailingAnchor.constraint(equalTo: horizontalPager.trailingAnchor),
            contentWidthView.heightAnchor.constraint(equalTo: horizontalPager.heightAnchor),
            
            appearanceInternalContainer.topAnchor.constraint(equalTo: appearanceContainer.topAnchor),
            appearanceInternalContainer.leadingAnchor.constraint(equalTo: appearanceContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            appearanceInternalContainer.trailingAnchor.constraint(equalTo: appearanceContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            appearanceInternalContainer.bottomAnchor.constraint(equalTo: appearanceContainer.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: appearanceInternalContainer.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: appearanceInternalContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.trailingAnchor.constraint(equalTo: appearanceInternalContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            appearanceVerticalStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            appearanceVerticalStack.leadingAnchor.constraint(equalTo: appearanceInternalContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            appearanceVerticalStack.trailingAnchor.constraint(equalTo: appearanceInternalContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            appearanceVerticalStackBottomConstraint,
        ])
    }
    
    // Динамическая перестройка страниц скролла
    private func rebuildPagerLayout() {
        NSLayoutConstraint.deactivate(dynamicPagerConstraints)
        dynamicPagerConstraints.removeAll()
        
        appearanceContainer.removeFromSuperview()
        
        var previousView: UIView? = nil
        
        for container in activeContainers {
            contentWidthView.addSubview(container)
            
            dynamicPagerConstraints.append(container.topAnchor.constraint(equalTo: contentWidthView.topAnchor))
            dynamicPagerConstraints.append(container.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor))
            
            if let prev = previousView {
                dynamicPagerConstraints.append(container.leadingAnchor.constraint(equalTo: prev.trailingAnchor))
            } else {
                dynamicPagerConstraints.append(container.leadingAnchor.constraint(equalTo: contentWidthView.leadingAnchor))
            }
            
            previousView = container
        }
        
        if let last = previousView {
            dynamicPagerConstraints.append(last.trailingAnchor.constraint(equalTo: contentWidthView.trailingAnchor))
        }
        
        NSLayoutConstraint.activate(dynamicPagerConstraints)
    }
    
    private func configureActions() {
        appearanceSeeMoreButton.addTarget(self, action: #selector(seeMoreTapped), for: .touchUpInside)
    }
    
    // MARK: - Logic
    
    private func setSelectedIndex(_ index: Int, animated: Bool) {
        guard selectedIndex != index else { return }
        selectedIndex = index
        
        isExpanded = false
        
        updateContent(animated: animated)
        
        let offsetX = CGFloat(index) * horizontalPager.bounds.width
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options:[.curveEaseInOut, .allowUserInteraction], animations: {
                self.horizontalPager.contentOffset = CGPoint(x: offsetX, y: 0)
            })
        } else {
            horizontalPager.contentOffset = CGPoint(x: offsetX, y: 0)
        }
    }
    
    private func updateContent(animated: Bool) {
        if currentAppearanceExpandedState != isExpanded {
            currentAppearanceExpandedState = isExpanded
            let dataToShow = isExpanded ? appearanceData : Array(appearanceData.prefix(4))
            rebuildAppearanceGrid(with: dataToShow)
        }
        
        var shouldShowAppSeeMore = false
        
        shouldShowAppSeeMore = appearanceData.count > 4
        
        appearanceSeeMoreWrapper.isHidden = !shouldShowAppSeeMore

        appearanceVerticalStackBottomConstraint.constant = shouldShowAppSeeMore ? -DivoDesignTokens.Spacing.xs : -12
        
        let newTitle = isExpanded ? DivoStrings.seeLess : DivoStrings.seeMore
        if animated {
            UIView.transition(with: appearanceSeeMoreButton, duration: 0.25, options: .transitionCrossDissolve) {
                self.appearanceSeeMoreButton.setTitle(newTitle, for: .normal)
            }
        } else {
            appearanceSeeMoreButton.setTitle(newTitle, for: .normal)
        }
        
        updatePagerHeight(animated: animated)
    }
    
    private func updatePagerHeight(animated: Bool = false) {
        guard selectedIndex < activeContainers.count else { return }
        
        let activeContainer = activeContainers[selectedIndex]
        
        activeContainer.layoutIfNeeded()
        
        let pagerWidth = horizontalPager.bounds.width > 0 ? horizontalPager.bounds.width : UIScreen.main.bounds.width
        
        let targetHeight = activeContainer.systemLayoutSizeFitting(
            CGSize(width: pagerWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        
        if pagerHeightConstraint.constant == targetHeight || targetHeight == 0 { return }
        
        pagerHeightConstraint.constant = targetHeight
        
        if animated {
            self.delegate?.parametersViewDidUpdateContentHeight(animated: true)
        } else {
            self.layoutIfNeeded()
            self.delegate?.parametersViewDidUpdateContentHeight(animated: false)
        }
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
    
    private func createAttributeView(title: String, value: String) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.font = Font.regular(12)
        titleLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        titleLabel.text = title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.font = Font.regular(12)
        valueLabel.textColor = DivoColorPalette.primaryText
        valueLabel.text = value
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let line = UIView()
        line.backgroundColor = DivoColorPalette.primaryText.withAlphaComponent(0.1)
        line.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        container.addSubview(line)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: container.topAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: DivoDesignTokens.Spacing.xs),
            
            line.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.xs),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    @objc private func seeMoreTapped() {
        isExpanded.toggle()
        updateContent(animated: false)
    }
}


// Расширение для подсчета строк
private extension String {
    func lineCount(for font: UIFont, width: CGFloat) -> Int {
        guard width > 0 else { return 0 }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes:[NSAttributedString.Key: Any] = [
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
