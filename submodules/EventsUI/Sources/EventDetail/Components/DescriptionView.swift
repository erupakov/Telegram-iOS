//
//  DescriptionView.swift
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
    private var biographyText: String = ""
    
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
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var mainVerticalStackBottomConstraint: NSLayoutConstraint!

    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let seeMoreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Обертка для кнопки, чтобы прижать её вправо
    private let seeMoreWrapper: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .trailing
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Init
    
    init(biography: String = "") {
        super.init(frame: .zero)
        setupViews()
        update(biography: biography)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        addSubview(containerView)
        containerView.addSubview(mainVerticalStack)
        
        mainVerticalStack.addArrangedSubview(contentLabel)
        
        seeMoreWrapper.addArrangedSubview(UIView())
        seeMoreWrapper.addArrangedSubview(seeMoreButton)
        mainVerticalStack.addArrangedSubview(seeMoreWrapper)
        
        seeMoreButton.addTarget(self, action: #selector(seeMoreTapped), for: .touchUpInside)
        mainVerticalStackBottomConstraint = mainVerticalStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: self.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            containerView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            containerView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            mainVerticalStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            mainVerticalStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            mainVerticalStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            mainVerticalStackBottomConstraint,
        ])
    }
    
    // MARK: - Public Updates
    
    func update(biography: String?) {
        guard let biography = biography, !biography.isEmpty else {
            self.isHidden = true
            return
        }
        self.isHidden = false
        self.biographyText = biography
        self.isExpanded = false
        updateContent(animated: false)
    }
    
    // MARK: - Logic
    
    private func updateContent(animated: Bool) {
        contentLabel.text = biographyText
        contentLabel.numberOfLines = isExpanded ? 0 : maxLinesCollapsed
        
        let viewWidth = self.bounds.width > 0 ? self.bounds.width : UIScreen.main.bounds.width
        let labelWidth = viewWidth - (DivoDesignTokens.Spacing.m * 4)
        let actualLines = biographyText.lineCount(for: contentLabel.font, width: labelWidth)
        let shouldShowSeeMore = actualLines > maxLinesCollapsed
        
        seeMoreWrapper.isHidden = !shouldShowSeeMore
        mainVerticalStackBottomConstraint.constant = shouldShowSeeMore ? -DivoDesignTokens.Spacing.xs : -12
        
        let newTitle = isExpanded ? DivoStrings.seeLess : DivoStrings.seeMore
        seeMoreButton.setTitle(newTitle, for: .normal)
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.layoutIfNeeded()
                self.delegate?.descriptionViewDidUpdateContentHeight(animated: true)
            }
        } else {
            self.layoutIfNeeded()
            self.delegate?.descriptionViewDidUpdateContentHeight(animated: false)
        }
    }
    
    @objc private func seeMoreTapped() {
        isExpanded.toggle()
        updateContent(animated: false)
    }
}
