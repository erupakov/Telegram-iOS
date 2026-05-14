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
    private var appearanceData: [AppearanceAttribute] = []
    
    // MARK: - UI Elements
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let mainVerticalStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
        
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.parametersForApplying
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let appearanceGridStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .top
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let seeMoreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let seeMoreWrapper: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .trailing
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Init
    
    init(appearance: [AppearanceAttribute] = []) {
        super.init(frame: .zero)
        setupViews()
        update(appearance: appearance)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        addSubview(containerView)
        containerView.addSubview(mainVerticalStack)
        
        mainVerticalStack.addArrangedSubview(titleLabel)
        mainVerticalStack.addArrangedSubview(appearanceGridStack)
        
        seeMoreWrapper.addArrangedSubview(UIView())
        seeMoreWrapper.addArrangedSubview(seeMoreButton)
        mainVerticalStack.addArrangedSubview(seeMoreWrapper)
        
        seeMoreButton.addTarget(self, action: #selector(seeMoreTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: self.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            containerView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            containerView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            mainVerticalStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            mainVerticalStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            mainVerticalStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            mainVerticalStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs)
        ])
    }
    
    // MARK: - Public Updates
    
    func update(appearance: [AppearanceAttribute]) {
        self.appearanceData = appearance
        self.isExpanded = false
        updateContent(animated: false)
    }
    
    // MARK: - Logic
    
    private func updateContent(animated: Bool) {
        let dataToShow = isExpanded ? appearanceData : Array(appearanceData.prefix(4))
        rebuildAppearanceGrid(with: dataToShow)
        
        let shouldShowSeeMore = appearanceData.count > 4
        seeMoreWrapper.isHidden = !shouldShowSeeMore
        
        let newTitle = isExpanded ? DivoStrings.seeLess : DivoStrings.seeMore
        seeMoreButton.setTitle(newTitle, for: .normal)
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.layoutIfNeeded()
                self.delegate?.parametersViewDidUpdateContentHeight(animated: true)
            }
        } else {
            self.layoutIfNeeded()
            self.delegate?.parametersViewDidUpdateContentHeight(animated: false)
        }
    }
    
    @objc private func seeMoreTapped() {
        isExpanded.toggle()
        updateContent(animated: false)
    }
    
    // MARK: - Grid Builder
    
    private func rebuildAppearanceGrid(with attributes: [AppearanceAttribute]) {
        appearanceGridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
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
        
        if attributes.count % 2 != 0 {
            rightStack.addArrangedSubview(UIView())
        }
        
        appearanceGridStack.addArrangedSubview(leftStack)
        appearanceGridStack.addArrangedSubview(rightStack)
    }
    
    private func createAttributeView(title: String, value: String) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.font = Font.regular(12)
        titleLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        titleLabel.text = title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
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
}
