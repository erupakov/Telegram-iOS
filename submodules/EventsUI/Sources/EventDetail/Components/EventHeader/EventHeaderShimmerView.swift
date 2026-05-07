//
//  ProfileHeaderShimmerView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.03.2026.
//

import UIKit
import DivoUIKit
import DivoCore

class EventHeaderShimmerView: UIView {
    
    // MARK: - UI Elements (Placeholders)
    
    private let namePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.s
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let infoPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
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
    
    private func setupViews() {
        addSubview(namePlaceholder)
        addSubview(infoPlaceholder)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            namePlaceholder.topAnchor.constraint(equalTo: topAnchor),
            namePlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            namePlaceholder.widthAnchor.constraint(equalToConstant: 200),
            namePlaceholder.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            infoPlaceholder.topAnchor.constraint(equalTo: namePlaceholder.bottomAnchor, constant: 6),
            infoPlaceholder.bottomAnchor.constraint(equalTo: bottomAnchor),
            infoPlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            infoPlaceholder.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            infoPlaceholder.widthAnchor.constraint(equalToConstant: 160),
            infoPlaceholder.heightAnchor.constraint(equalToConstant: 20),
        ])
    }
    
    // MARK: - Animation
    
    func startAnimation() {
        [namePlaceholder, infoPlaceholder].forEach {
            $0.stopShimmering()
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [namePlaceholder, infoPlaceholder].forEach {
            $0.stopShimmering()
        }
    }
}
