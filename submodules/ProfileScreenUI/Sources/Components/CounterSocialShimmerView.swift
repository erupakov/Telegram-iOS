//
//  CounterSocialShimmerView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.03.2026.
//

import UIKit
import DivoCore
import DivoUIKit

class CounterSocialShimmerView: UIView {
    
    // MARK: - UI Elements
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = DivoDesignTokens.Spacing.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var placeholder1 = createPlaceholder()
    private lazy var placeholder2 = createPlaceholder()
    private lazy var placeholder3 = createPlaceholder()
    private lazy var placeholder4 = createPlaceholder()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        startAnimation()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        addSubview(stackView)
        
        stackView.addArrangedSubview(placeholder1)
        stackView.addArrangedSubview(placeholder2)
        stackView.addArrangedSubview(placeholder3)
        stackView.addArrangedSubview(placeholder4)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    private func createPlaceholder() -> UIView {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    // MARK: - Animation Logic
    
    func startAnimation() {
        [placeholder1, placeholder2, placeholder3, placeholder4].forEach {
            $0.stopShimmering()
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [placeholder1, placeholder2, placeholder3, placeholder4].forEach {
            $0.stopShimmering()
        }
    }
}
