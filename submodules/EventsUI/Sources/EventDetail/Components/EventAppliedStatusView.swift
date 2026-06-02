//
//  EventAppliedStatusView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

final class EventAppliedStatusView: UIView {
    var onWithdrawTapped: (() -> Void)?
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let withdrawButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(DivoStrings.withdrawApplication.uppercased(), for: .normal)
        button.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = DivoColorPalette.cardBackground
        layer.borderColor = DivoColorPalette.applyBorder.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = DivoDesignTokens.Radius.l
        clipsToBounds = true
        
        addSubview(statusLabel)
        addSubview(withdrawButton)
        
        withdrawButton.addTarget(self, action: #selector(withdrawTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            withdrawButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            withdrawButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            withdrawButton.leadingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor, constant: 10)
        ])
        
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        withdrawButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        withdrawButton.setContentHuggingPriority(.required, for: .horizontal)
    }
    
    @objc private func withdrawTapped() {
        onWithdrawTapped?()
    }
    
    func configure(appliedDateText: String) {
        statusLabel.text = DivoStrings.youAppliedOn(appliedDateText)
    }
    
    func setWithdrawLoading(_ active: Bool) {
        withdrawButton.isEnabled = !active
    }
}
