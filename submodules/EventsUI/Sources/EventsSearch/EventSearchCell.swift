//
//  EventSearchCell.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 29.05.2026.
//

import UIKit
import Display
import TelegramCore
import AccountContext
import AppBundle
import DivoUIKit
import DivoCore

struct EventItem {
    let name: String
    let data: String
    let time: String
    let countryFlag: String
    let city: String
    let customAvatarURL: String?
    let originalDate: String?
    let eventId: Int?
    let isApplied: Bool?
    let creatorId: Int?
}

final class EventSearchCell: UITableViewCell {
    
    static let reuseIdentifier = "EventCell"
    
    private static let avatarSize: CGFloat = 40
    
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = avatarSize / 2
        iv.backgroundColor = DivoColorPalette.imagePlaceholderLight
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let arrowIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = DivoImage.searchArrowProfile
        imageView.tintColor = DivoColorPalette.primaryText
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.selectionStyle = .none

        contentView.addSubview(avatarImageView)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, infoLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)
        contentView.addSubview(arrowIcon)

        // Предотвращаем сжатие правой части при длинных именах
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.lineBreakMode = .byTruncatingTail

        infoLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        infoLabel.lineBreakMode = .byTruncatingTail

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            textStack.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: arrowIcon.leadingAnchor, constant: -DivoDesignTokens.Spacing.s),
            
            arrowIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            arrowIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowIcon.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.m),
            arrowIcon.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.m)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.cancelImageLoad()
        avatarImageView.image = nil
    }

    func configure(with item: EventItem) {
        nameLabel.text = item.name

        // Аккуратно собираем мета-строку через точку: "Дата · Время · Флаг Город"
        var infoParts: [String] = []
        if !item.data.isEmpty { infoParts.append(item.data) }
        if !item.time.isEmpty { infoParts.append(item.time) }
        
        let location = [item.countryFlag, item.city].filter { !$0.isEmpty }.joined(separator: " ")
        if !location.isEmpty { infoParts.append(location) }
        
        infoLabel.text = infoParts.joined(separator: " · ")

        if let avatarUrlStr = item.customAvatarURL, let url = URL(string: avatarUrlStr) {
            avatarImageView.loadImage(from: url)
        } else {
            avatarImageView.image = DivoImage.defWork
        }
    }
}
