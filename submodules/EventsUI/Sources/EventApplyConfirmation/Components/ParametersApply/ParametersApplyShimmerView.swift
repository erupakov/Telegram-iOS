//
//  ParametersApplyShimmerView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.05.2026.
//

import UIKit
import DivoUIKit
import DivoCore

class ParametersApplyShimmerView: UIView {
    private let titlePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let cardPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        startAnimation()
    }
    
    private func setupViews() {
        addSubview(titlePlaceholder)
        addSubview(cardPlaceholder)
        
        NSLayoutConstraint.activate([
            titlePlaceholder.topAnchor.constraint(equalTo: topAnchor),
            titlePlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.xs),
            titlePlaceholder.widthAnchor.constraint(equalToConstant: 160),
            titlePlaceholder.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.m),
            
            cardPlaceholder.topAnchor.constraint(equalTo: titlePlaceholder.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            cardPlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardPlaceholder.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardPlaceholder.bottomAnchor.constraint(equalTo: bottomAnchor),
            cardPlaceholder.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])
    }
    
    func startAnimation() {
        [titlePlaceholder, cardPlaceholder].forEach {
            $0.stopShimmering()
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [titlePlaceholder, cardPlaceholder].forEach {
            $0.stopShimmering()
        }
    }
}
