//
//  WorkHistoryView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.03.2026.
//

import UIKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit

// Делегат для обработки нажатия на кнопку
protocol CurrentAgencyViewDelegate: AnyObject {
    func didTapSeeHistory()
}

final class CurrentAgencyView: UIView {

    private static let logoSize: CGFloat = 60
    
    weak var delegate: CurrentAgencyViewDelegate?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.currentAgency
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = logoSize / 2
        iv.backgroundColor = DivoColorPalette.cardBackground
        iv.layer.borderWidth = 1
        iv.layer.borderColor = DivoColorPalette.borderWorkHistoryImage.cgColor
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    
    private let agencyNameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let periodLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let seeHistoryButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.titleLabel?.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        button.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        button.setTitle(DivoStrings.seeHistory, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var lastLogoURL: URL?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(logoImageView)
        
        let textStack = UIStackView(arrangedSubviews: [agencyNameLabel, periodLabel])
        textStack.axis = .vertical
        textStack.spacing = DivoDesignTokens.Spacing.xs
        textStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(textStack)
        
        containerView.addSubview(seeHistoryButton)
        
        seeHistoryButton.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)
        
        seeHistoryButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        agencyNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            logoImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            logoImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            logoImageView.widthAnchor.constraint(equalToConstant: Self.logoSize),
            logoImageView.heightAnchor.constraint(equalToConstant: Self.logoSize),
            logoImageView.bottomAnchor.constraint(equalTo: seeHistoryButton.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs),
            
            textStack.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            seeHistoryButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            seeHistoryButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs),
        ])
    }
    
    @objc private func historyTapped() {
        delegate?.didTapSeeHistory()
    }
    
    func configure(name: String?, logoURL: URL?) {
        UIView.performWithoutAnimation {
            self.agencyNameLabel.text = name?.uppercased() ?? DivoStrings.unknownAgency
            self.agencyNameLabel.layer.removeAllAnimations()
            self.layoutIfNeeded()
        }

        guard lastLogoURL != logoURL else { return }
        lastLogoURL = logoURL

        guard let url = logoURL else {
            UIView.performWithoutAnimation {
                self.logoImageView.image = nil
                self.layoutIfNeeded()
            }
            return
        }

        ImageLoader.shared.load(url: url) { [weak self] image in
            DispatchQueue.main.async {
                guard let self else { return }
                UIView.performWithoutAnimation {
                    self.logoImageView.image = image
                    self.layoutIfNeeded()
                }
            }
        }
    }
}
