//
//  ProfileNavigationBarTitleView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 08.03.2026.
//

import UIKit
import Display
import DivoCore

public final class ProfileNavigationBarTitleView: UIView {
    
    private lazy var containerStack: UIStackView = {
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.alignment = .center
        infoStack.spacing = 2
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        return infoStack
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryText
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    private func setupViews() {
        addSubview(containerStack)
        containerStack.addArrangedSubview(nameLabel)
        containerStack.addArrangedSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            containerStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    public func configure(name: String, info: String? = nil) {
        nameLabel.text = name
        if let info = info {
            infoLabel.text = info
        } else {
            infoLabel.removeFromSuperview()
        }
    }
}
