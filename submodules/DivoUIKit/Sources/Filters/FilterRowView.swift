//
//  FilterRowView.swift
//  DivoUIKit
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import Display
import UIKit
import DivoCore

public final class FilterRowView: UIView {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.textAlignment = .right
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private var currentItems: [String] = []
    private var emptyTitle: String = ""

    public init(title: String) {
        super.init(frame: .zero)
        self.isUserInteractionEnabled = true

        self.backgroundColor = .white
        self.layer.cornerRadius = 23 // TODO: DS alignment — не в шкале Radius (border inset от card=24)

        titleLabel.text = title

        let chevron = UIImageView(image: UIImage(bundleImageName: "Components/Search/ChevronRight") ?? UIImage(systemName: "chevron.right"))
        chevron.tintColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.frame = CGRect(x: 0, y: 0, width: 20, height: 20)

        let stack = UIStackView(arrangedSubviews:[titleLabel, UIView(), valueLabel, chevron])
        stack.axis = .horizontal
        stack.spacing = DivoDesignTokens.Spacing.s
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    public func setItems(_ items: [String], emptyTitle: String) {
        self.currentItems = items
        self.emptyTitle = emptyTitle
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateDisplayedText()
    }

    private func updateDisplayedText() {
        guard !currentItems.isEmpty else {
            valueLabel.text = emptyTitle
            return
        }

        let titleWidth = titleLabel.intrinsicContentSize.width
        let maxAvailableWidth = self.bounds.width - titleWidth - 86

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
            if remaining > 0 {
                fittingText = "\(first), +\(remaining)"
            } else {
                fittingText = first
            }
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
