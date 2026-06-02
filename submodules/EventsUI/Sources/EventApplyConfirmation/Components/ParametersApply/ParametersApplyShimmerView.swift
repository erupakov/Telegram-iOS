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
        addSubview(cardPlaceholder)
        
        NSLayoutConstraint.activate([
            cardPlaceholder.topAnchor.constraint(equalTo: topAnchor),
            cardPlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardPlaceholder.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardPlaceholder.bottomAnchor.constraint(equalTo: bottomAnchor),
            cardPlaceholder.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])
    }
    
    func startAnimation() {
        [cardPlaceholder].forEach {
            $0.stopShimmering()
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [cardPlaceholder].forEach {
            $0.stopShimmering()
        }
    }
}
