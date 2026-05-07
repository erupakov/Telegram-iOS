//
//  DescripytionView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

protocol DescriptionViewDelegate: AnyObject {
    func descriptionViewDidUpdateContentHeight(animated: Bool)
}

final class DescriptionView: UIView {
    weak var delegate: DescriptionViewDelegate?
    
    private let maxLinesCollapsed: Int = 3
    private var isExpanded: Bool = false
    
    private var selectedIndex: Int = 0
    private var biographyText: String = ""
    
    private var pagerHeightConstraint: NSLayoutConstraint!
    
    private var bioVerticalStackBottomConstraint: NSLayoutConstraint!
    
    private var dynamicPagerConstraints: [NSLayoutConstraint] = []
    private var activeContainers: [UIView] = []
    private let contentWidthView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - UI Elements

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
    
    private let bioContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let bioInternalContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bioVerticalStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let bioSeeMoreWrapper: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let bioSeeMoreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        button.setTitle(DivoStrings.seeMore, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Init
    
    init(biography: String = "") {
        super.init(frame: .zero)

        setupViews()
        configureActions()
        
        update(biography: biography)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Updates
    
    func update(biography: String?) {
        var newActiveContainers: [UIView] = []
        
        if let biography = biography {
            self.biographyText = biography
            newActiveContainers.append(bioContainer)
        }

        if activeContainers != newActiveContainers {
            activeContainers = newActiveContainers
            rebuildPagerLayout()
        }
        
        updateContent(animated: false)
    }
    
    
    // MARK: - Setup
    
    private func setupViews() {
        addSubview(horizontalPager)
        
        horizontalPager.addSubview(contentWidthView)
        
        bioSeeMoreWrapper.addArrangedSubview(UIView())
        bioSeeMoreWrapper.addArrangedSubview(bioSeeMoreButton)
        
        bioContainer.addSubview(bioInternalContainer)

        bioInternalContainer.addSubview(bioVerticalStack)
        bioVerticalStack.addArrangedSubview(contentLabel)
        bioVerticalStack.addArrangedSubview(bioSeeMoreWrapper)
        
        pagerHeightConstraint = horizontalPager.heightAnchor.constraint(equalToConstant: 50)
        
        bioVerticalStackBottomConstraint = bioVerticalStack.bottomAnchor.constraint(equalTo: bioInternalContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs)

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
            
            bioInternalContainer.topAnchor.constraint(equalTo: bioContainer.topAnchor),
            bioInternalContainer.leadingAnchor.constraint(equalTo: bioContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bioInternalContainer.trailingAnchor.constraint(equalTo: bioContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            bioInternalContainer.bottomAnchor.constraint(equalTo: bioContainer.bottomAnchor),
            
            bioVerticalStack.topAnchor.constraint(equalTo: bioInternalContainer.topAnchor, constant: 12),
            bioVerticalStack.leadingAnchor.constraint(equalTo: bioInternalContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bioVerticalStack.trailingAnchor.constraint(equalTo: bioInternalContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            bioVerticalStackBottomConstraint,
        ])
    }
    
    // Динамическая перестройка страниц скролла
    private func rebuildPagerLayout() {
        NSLayoutConstraint.deactivate(dynamicPagerConstraints)
        dynamicPagerConstraints.removeAll()
        
        bioContainer.removeFromSuperview()
        
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
        bioSeeMoreButton.addTarget(self, action: #selector(seeMoreTapped), for: .touchUpInside)
    }
    
    // MARK: - Logic
    
    private func updateContent(animated: Bool) {
        contentLabel.text = biographyText
        contentLabel.numberOfLines = isExpanded ? 0 : maxLinesCollapsed
        
        var shouldShowBioSeeMore = false
        
        let viewWidth = self.bounds.width > 0 ? self.bounds.width : UIScreen.main.bounds.width
        let labelWidth = viewWidth - 64
        let actualLines = biographyText.lineCount(for: contentLabel.font, width: labelWidth)
        shouldShowBioSeeMore = actualLines > maxLinesCollapsed
        
        bioSeeMoreWrapper.isHidden = !shouldShowBioSeeMore
        
        bioVerticalStackBottomConstraint.constant = shouldShowBioSeeMore ? -DivoDesignTokens.Spacing.xs : -12
        
        let newTitle = isExpanded ? DivoStrings.seeLess : DivoStrings.seeMore
        if animated {
            UIView.transition(with: bioSeeMoreButton, duration: 0.25, options: .transitionCrossDissolve) {
                self.bioSeeMoreButton.setTitle(newTitle, for: .normal)
            }
        } else {
            bioSeeMoreButton.setTitle(newTitle, for: .normal)
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
            self.delegate?.descriptionViewDidUpdateContentHeight(animated: true)
        } else {
            self.layoutIfNeeded()
            self.delegate?.descriptionViewDidUpdateContentHeight(animated: false)
        }
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
