//
//  SearchUserCell.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.04.2026.
//

import Foundation
import UIKit
import DivoCore
import DivoUIKit

final class SearchUserCell: UITableViewCell {

    private static let avatarSize: CGFloat = 40

    private let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = SearchUserCell.avatarSize / 2
        iv.backgroundColor = DivoColorPalette.imagePlaceholderDark
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let usernameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = DivoColorPalette.secondaryText
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
    
    private var nameTopConstraint: NSLayoutConstraint!
    private var nameCenterYConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .none
        backgroundColor = .clear
        
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(arrowIcon)
        
        nameTopConstraint = nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12)
        nameCenterYConstraint = nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: SearchUserCell.avatarSize),
            avatarView.heightAnchor.constraint(equalToConstant: SearchUserCell.avatarSize),
            
            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameTopConstraint,
            nameLabel.trailingAnchor.constraint(equalTo: arrowIcon.leadingAnchor, constant: -DivoDesignTokens.Spacing.s),
            
            usernameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            usernameLabel.trailingAnchor.constraint(equalTo: arrowIcon.leadingAnchor, constant: -DivoDesignTokens.Spacing.s),
            
            arrowIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            arrowIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowIcon.widthAnchor.constraint(equalToConstant: 16),
            arrowIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with item: SearchUserDTO, query: String) {
        // Backend does not expose a dedicated username field; fall back to description.
        let description = item.description ?? ""
        let hasDescription = !description.isEmpty
        usernameLabel.text = description
        usernameLabel.isHidden = !hasDescription
        nameTopConstraint.isActive = hasDescription
        nameCenterYConstraint.isActive = !hasDescription
        
        let placeholder = DivoImage.emptyBackgroundAvatar
        if let photoURLString = item.searchImage?.fullUrl, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
            avatarView.loadImage(from: photoURL, placeholder: placeholder, cropAvatarIfNeeded: true)
        } else {
            avatarView.image = placeholder
        }
        
        let displayName = item.title ?? item.user?.fullName ?? ""
        let attributedName = NSMutableAttributedString(string: displayName)
        if !query.isEmpty {
            let range = (displayName.lowercased() as NSString).range(of: query.lowercased())
            if range.location != NSNotFound {
                attributedName.addAttribute(.foregroundColor, value: DivoColorPalette.accent, range: range)
            }
        }
        nameLabel.attributedText = attributedName
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let duration = highlighted
            ? DivoDesignTokens.PressState.pressDuration
            : DivoDesignTokens.PressState.releaseDuration
        UIView.animate(withDuration: duration) {
            self.contentView.alpha = highlighted ? DivoDesignTokens.PressState.alpha : 1.0
            let scale = DivoDesignTokens.PressState.scaleListRow
            self.contentView.transform = highlighted
                ? CGAffineTransform(scaleX: scale, y: scale)
                : .identity
        }
    }
}
