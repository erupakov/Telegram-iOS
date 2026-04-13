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
        label.textColor = .black
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
        imageView.image = UIImage(bundleImageName: "Components/Search/ArrowProfile") ?? UIImage(systemName: "arrow.up.right")
        imageView.tintColor = DivoColorPalette.systemGray3
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .none
        backgroundColor = .clear
        
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(arrowIcon)
        
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: SearchUserCell.avatarSize),
            avatarView.heightAnchor.constraint(equalToConstant: SearchUserCell.avatarSize),
            
            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: arrowIcon.leadingAnchor, constant: -8),
            
            usernameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            usernameLabel.trailingAnchor.constraint(equalTo: arrowIcon.leadingAnchor, constant: -8),
            
            arrowIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            arrowIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowIcon.widthAnchor.constraint(equalToConstant: 16),
            arrowIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with item: SearchUserDTO, query: String) {
        // У вас в JSON нет Username, поэтому используем title или RoleLabel
        usernameLabel.text = item.description
        

        if let avatarURLString = item.searchImage?.fullUrl,
           let url = CDNURLHelper.convertToCDNURL(avatarURLString) {
            avatarView.loadImage(from: url) { [weak self] image in
                self?.avatarView.applyAvatarTopCropIfNeeded(image: image)
            }
        }
        
        let attributedName = NSMutableAttributedString(string: item.title)
        if !query.isEmpty {
            let range = (item.title.lowercased() as NSString).range(of: query.lowercased())
            if range.location != NSNotFound {
                attributedName.addAttribute(.foregroundColor, value: DivoColorPalette.accentSecondary, range: range)
            }
        }
        nameLabel.attributedText = attributedName
    }
}
