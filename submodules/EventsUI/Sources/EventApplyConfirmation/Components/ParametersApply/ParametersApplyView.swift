//
//  ParametersApplyView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

class ParametersApplyView: UIView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.parametersApplying
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let cardContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let rowsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let warningLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.warningApply
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(cardContainer)
        cardContainer.addSubview(titleLabel)
        cardContainer.addSubview(rowsStackView)
        cardContainer.addSubview(warningLabel)
        
        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: topAnchor),
            cardContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            rowsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            rowsStackView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            rowsStackView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            warningLabel.topAnchor.constraint(equalTo: rowsStackView.bottomAnchor, constant: 12),
            warningLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            warningLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            warningLabel.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.m)
        ])
    }
    
    func configure(matches: [ParameterMatch], hasMismatch: Bool, isMultipleMismatches: Bool, singleMismatch: ParameterMatch?) {
        rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (index, match) in matches.enumerated() {
            let rowContainer = UIView()
            rowContainer.translatesAutoresizingMaskIntoConstraints = false
            
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.alignment = .center
            rowStack.spacing = 6
            rowStack.translatesAutoresizingMaskIntoConstraints = false
            rowContainer.addSubview(rowStack)
            
            let pTitleLabel = UILabel()
            pTitleLabel.text = match.title
            pTitleLabel.font = Font.regular(12)
            pTitleLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
            
            let pValueLabel = UILabel()
            pValueLabel.text = match.value
            pValueLabel.font = Font.regular(12)
            pValueLabel.textColor = DivoColorPalette.primaryText
            pValueLabel.textAlignment = .right
            
            let statusImageView = UIImageView()
            statusImageView.contentMode = .scaleAspectFit
            statusImageView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                statusImageView.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.m),
                statusImageView.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.m)
            ])
            
            if match.isMatched {
                statusImageView.image = DivoImage.greenCheckmark
            } else {
                statusImageView.image = DivoImage.warning
            }
            
            rowStack.addArrangedSubview(pTitleLabel)
            rowStack.addArrangedSubview(pValueLabel)
            rowStack.addArrangedSubview(statusImageView)
            
            NSLayoutConstraint.activate([
                rowStack.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor),
                rowStack.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor),
                rowStack.topAnchor.constraint(equalTo: rowContainer.topAnchor, constant: 10),
                rowStack.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor, constant: -10)
            ])
            
            // Тонкая разделительная линия между ячейками
            if index < matches.count - 1 {
                let separator = UIView()
                separator.backgroundColor = DivoColorPalette.primaryText.withAlphaComponent(0.12)
                separator.translatesAutoresizingMaskIntoConstraints = false
                rowContainer.addSubview(separator)
                
                NSLayoutConstraint.activate([
                    separator.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor),
                    separator.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor),
                    separator.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor),
                    separator.heightAnchor.constraint(equalToConstant: 1)
                ])
            }
            
            rowsStackView.addArrangedSubview(rowContainer)
        }
        
        if hasMismatch {
            warningLabel.isHidden = false
            if isMultipleMismatches {
                warningLabel.text = DivoStrings.fewParametersDont
            } else if let single = singleMismatch {
                warningLabel.text = DivoStrings.oneParameterDont(single.title.lowercased())
            } else {
                warningLabel.text = DivoStrings.fewParametersDont
            }
        } else {
            warningLabel.text = DivoStrings.allParametersSuccess
        }
        
        self.layoutIfNeeded()
    }
}
