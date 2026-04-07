//
//  FilterRowView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import Display
import UIKit
import TelegramCore

final class FilterRowView: UIView {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = UIColor(hexString: "#222222")
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(12)
        label.textColor = UIColor(hexString: "#222222")?.withAlphaComponent(0.6)
        label.textAlignment = .right
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    init(title: String) {
        super.init(frame: .zero)
        self.isUserInteractionEnabled = true
        
        self.backgroundColor = .white
        self.layer.cornerRadius = 23
        
        titleLabel.text = title
        
        let chevron = UIImageView(image: UIImage(bundleImageName: "ChevronRight") ?? UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor(hexString: "#222222")?.withAlphaComponent(0.8)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, UIView(), valueLabel, chevron])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 46)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setValue(_ text: String) {
        valueLabel.text = text
    }
}
