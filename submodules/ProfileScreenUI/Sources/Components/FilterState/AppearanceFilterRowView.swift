//
//  AppearanceFilterRowView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 09.04.2026.
//

import UIKit
import Display

final class AppearanceFilterRowView: UIView {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = UIColor(hexString: "#222222")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = UIColor(hexString: "#8E8E93")
        label.textAlignment = .right
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var currentItems: [String] = []
    private var emptyTitle: String = ""
    
    init(title: String, isLast: Bool) {
        super.init(frame: .zero)
        
        self.backgroundColor = .clear
        self.translatesAutoresizingMaskIntoConstraints = false
        self.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        titleLabel.text = title
        addSubview(titleLabel)
        addSubview(valueLabel)
        
        let chevronImageView = UIImageView()
        chevronImageView.image = UIImage(bundleImageName: "ChevronRight") ?? UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = UIColor(hexString: "#222222")?.withAlphaComponent(0.8)
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chevronImageView)
        
        if !isLast {
            let separator = UIView()
            separator.backgroundColor = UIColor(hexString: "#E5E5EA")
            separator.translatesAutoresizingMaskIntoConstraints = false
            addSubview(separator)
            
            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                separator.bottomAnchor.constraint(equalTo: bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            chevronImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 20),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20),
            
            valueLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 16)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setItems(_ items: [String], emptyTitle: String) {
        self.currentItems = items
        self.emptyTitle = emptyTitle
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateDisplayedText()
    }
    
    private func updateDisplayedText() {
        guard !currentItems.isEmpty else {
            valueLabel.text = emptyTitle
            return
        }
        
        let titleWidth = titleLabel.intrinsicContentSize.width
        let maxAvailableWidth = self.bounds.width - titleWidth - 76
        
        guard maxAvailableWidth > 0 else { return }
        
        let fullText = currentItems.joined(separator: ", ")
        if textWidth(for: fullText) <= maxAvailableWidth {
            if valueLabel.text != fullText { valueLabel.text = fullText }
            return
        }
        
        var fittingText = ""
        for i in (1..<currentItems.count).reversed() {
            let subset = currentItems.prefix(i)
            let remainingCount = currentItems.count - i
            let testText = subset.joined(separator: ", ") + ", +\(remainingCount)"
            
            if textWidth(for: testText) <= maxAvailableWidth {
                fittingText = testText
                break
            }
        }
        
        if fittingText.isEmpty, let first = currentItems.first {
            let remaining = currentItems.count - 1
            fittingText = remaining > 0 ? "\(first), +\(remaining)" : first
        }
        
        if valueLabel.text != fittingText {
            valueLabel.text = fittingText
        }
    }
    
    private func textWidth(for text: String) -> CGFloat {
        guard let font = valueLabel.font else { return 0 }
        let size = (text as NSString).size(withAttributes: [.font: font])
        return ceil(size.width)
    }
}
