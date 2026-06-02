//
//  ApplicationsListCell.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 28.05.2026.
//

import UIKit
import Display
import TelegramCore
import AccountContext
import AppBundle
import DivoUIKit
import DivoCore

public enum ApplicationStatus: String, CaseIterable {
    case pending = "pending"
    case shortlisted = "shortlisted"
    case accepted = "accepted"
    case rejected = "rejected"
    
    var title: String {
        switch self {
        case .pending: return DivoStrings.pending
        case .shortlisted: return DivoStrings.shortlisted
        case .accepted: return DivoStrings.accepted
        case .rejected: return DivoStrings.rejected
        }
    }
    
    var color: UIColor {
        switch self {
        case .pending: return DivoColorPalette.pendingStatus
        case .shortlisted: return DivoColorPalette.shortlistedStatus
        case .accepted: return DivoColorPalette.acceptedStatus
        case .rejected: return DivoColorPalette.rejectedStatus
        }
    }
}

public struct ApplicantItem: Equatable {
    public let id: Int
    public let name: String
    public let avatarUrl: String?
    public let isVerified: Bool?
    public let role: String?
    public let dateApplied: String?
    public let status: ApplicationStatus?
    public var isSelected: Bool? = false
    
    public init(id: Int, name: String, avatarUrl: String?, isVerified: Bool?, role: String?, dateApplied: String?, status: ApplicationStatus?, isSelected: Bool? = false) {
        self.id = id
        self.name = name
        self.avatarUrl = avatarUrl
        self.isVerified = isVerified
        self.role = role
        self.dateApplied = dateApplied
        self.status = status
        self.isSelected = isSelected
    }
}

final class ApplicationsListCell: UICollectionViewCell {
    static let reuseIdentifier = "ApplicationsListCell"
    
    private static let avatarSize: CGFloat = 52
    
    var onSelectionTapped: (() -> Void)?
    private var currentApplicantId: Int?

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = avatarSize / 2
        iv.backgroundColor = DivoColorPalette.imagePlaceholderLight
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.primaryText.withAlphaComponent(0.12)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = .clear

        contentView.addSubview(avatarImageView)

        nameStackView.addArrangedSubview(nameLabel)

        let textStack = UIStackView(arrangedSubviews: [nameStackView, metaLabel])
        textStack.axis = .vertical
        textStack.spacing = DivoDesignTokens.Spacing.xs
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        contentView.addSubview(separatorView)

        // Настройка приоритетов сжатия (чтобы длинное имя сжималось, а бейдж статуса справа — нет)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.lineBreakMode = .byTruncatingTail

        metaLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        metaLabel.lineBreakMode = .byTruncatingTail

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            textStack.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            separatorView.leadingAnchor.constraint(equalTo: avatarImageView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: textStack.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    @objc private func checkboxTapped() {
        onSelectionTapped?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.cancelImageLoad()
        avatarImageView.image = nil
        currentApplicantId = nil
        onSelectionTapped = nil
    }

    func configure(with item: ApplicantItem) {
        self.currentApplicantId = item.id
        nameLabel.text = item.name

        var metaParts: [String] = []
        if let role = item.role { metaParts.append(role) }
        if let date = item.dateApplied { metaParts.append(date) }
        metaLabel.text = metaParts.joined(separator: " · ")
        
        if let avatarURL = CDNURLHelper.convertToCDNURL(item.avatarUrl) {
            // ImageLoader сверяет currentLoadingURL перед установкой картинки и
            // отменяется через cancelImageLoad() в prepareForReuse — это снимает
            // гонку, когда ячейку переиспользуют до завершения загрузки аватара.
            avatarImageView.loadImage(from: avatarURL) { [weak self] image in
                self?.avatarImageView.applyAvatarTopCropIfNeeded(image: image)
            }
        } else {
            avatarImageView.cancelImageLoad()
            avatarImageView.image = nil
        }
        self.layoutIfNeeded()
    }
}
