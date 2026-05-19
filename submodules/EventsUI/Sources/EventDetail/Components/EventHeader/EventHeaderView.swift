//
//  ProfileHeaderView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.02.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

struct EventViewModel {
    let name: String?
    let date: String?
    let time: String?
    let countryFlag: String?
    let city: String?
    let isFree: Bool?
    let cost: String?
    
    init(
        name: String?,
        date: String?,
        time: String?,
        countryFlag: String?,
        city: String?,
        isFree: Bool?,
        cost: String?
    ) {
        self.name = name
        self.date = date
        self.time = time
        self.countryFlag = countryFlag
        self.city = city
        self.isFree = isFree
        self.cost = cost
    }
}

class EventHeaderView: UIView {
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = DivoColorPalette.cardBackground
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var nameLabelHeightConstraint: NSLayoutConstraint!

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.cardBackground
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
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
    
    private func setupViews() {
        addSubview(nameLabel)
        addSubview(infoLabel)
    }
    
    private func setupConstraints() {
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            infoLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            infoLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            infoLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(with viewModel: EventViewModel) {
        let font = Font.helveticaNeue(32)
        let attributes:[NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: DivoColorPalette.cardBackground,
            .kern: 0.5
        ]
        
        guard let name = viewModel.name else { return }
        nameLabel.attributedText = NSAttributedString(string: name, attributes: attributes)
        
        var fullLocationString: String
        guard let date = viewModel.date,
              let time = viewModel.time,
              let countryFlag = viewModel.countryFlag,
              let city = viewModel.city,
              let isFree = viewModel.isFree
        else { return }
        if let cost = viewModel.cost, !isFree {
            fullLocationString = "\(date) • \(time) • \(countryFlag) \(city) • $ \(cost)"
        } else {
            fullLocationString = "\(date) • \(time) • \(countryFlag) \(city)"
        }
        
        infoLabel.text = fullLocationString

        self.layoutIfNeeded()
    }
}
