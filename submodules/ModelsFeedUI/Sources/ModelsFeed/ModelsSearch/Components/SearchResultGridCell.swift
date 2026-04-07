//
//  SearchResultGridCell.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.04.2026.
//

import UIKit
import Display
import TelegramCore

struct FullSearchItem {
    let id = UUID()
    let name: String
    let age: Int
    let countryFlag: String
    let countryCode: String
    let role: String
    let likesCount: String
    let imageName: String
}

final class SearchResultGridCell: UICollectionViewCell {
    
    private let backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let progressiveBlurView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.alpha = 0.0
        blurView.translatesAutoresizingMaskIntoConstraints = false
        return blurView
    }()
    
    private var progressiveBlurTopConstraint: NSLayoutConstraint?
    private var gradientLayer: CAGradientLayer?
    private var isBlurConfigured = false
    
    private let roleContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hexString: "#2262D8")
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let roleIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(bundleImageName: "PersonHeart") ?? UIImage(systemName: "person.fill")
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(11)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let actionsContainer: UIVisualEffectView = {
        let ve = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
        ve.layer.cornerRadius = 12
        ve.clipsToBounds = true
        ve.translatesAutoresizingMaskIntoConstraints = false
        return ve
    }()
    
    private let shareIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "square.and.arrow.up")
        iv.tintColor = .white
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let bookmarkIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "bookmark")
        iv.tintColor = .white
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let likesContainer: UIVisualEffectView = {
        let ve = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
        ve.layer.cornerRadius = 12
        ve.clipsToBounds = true
        ve.translatesAutoresizingMaskIntoConstraints = false
        return ve
    }()
    
    private let heartIcon: UIImageView = {
        let iv = UIImageView()
        return iv
    }()
    
    private let likesLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(10)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(20)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(10)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let blurStartPosition = bounds.height * 0.65
        progressiveBlurTopConstraint?.constant = blurStartPosition
        
        if let gradientLayer = gradientLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gradientLayer.frame = progressiveBlurView.bounds
            CATransaction.commit()
        }
        
        let buttonSize = actionsContainer.bounds.height
        if buttonSize > 0 {
            actionsContainer.layer.cornerRadius = buttonSize / 2
            likesContainer.layer.cornerRadius = buttonSize / 2
        }
    }

    private func animateBlurAppearance() {
        layoutIfNeeded()
        
        guard progressiveBlurView.alpha < 0.1 else { return }
        
        if let gradient = gradientLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gradient.frame = progressiveBlurView.bounds
            CATransaction.commit()
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
            self.progressiveBlurView.alpha = 1.0
        }
    }
    
    private func setupUI() {
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        
        contentView.addSubview(backgroundImageView)
        
        progressiveBlurView.alpha = 0.8
        progressiveBlurView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(progressiveBlurView)
        
        setupProgressiveBlurWithGradient()
        
        contentView.addSubview(roleContainer)
        roleContainer.addSubview(roleIcon)
        roleContainer.addSubview(roleLabel)
        
        contentView.addSubview(actionsContainer)
        
        actionsContainer.contentView.addSubview(shareIcon)
        actionsContainer.contentView.addSubview(bookmarkIcon)
        
        contentView.addSubview(likesContainer)
        
        heartIcon.image = UIImage(systemName: "heart")
        heartIcon.tintColor = .white
        heartIcon.translatesAutoresizingMaskIntoConstraints = false
        likesContainer.contentView.addSubview(heartIcon)
        likesContainer.contentView.addSubview(likesLabel)
        
        contentView.addSubview(nameLabel)
        contentView.addSubview(infoLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        
        progressiveBlurTopConstraint = progressiveBlurView.topAnchor.constraint(equalTo: contentView.topAnchor)
        progressiveBlurTopConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            progressiveBlurView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            progressiveBlurView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            progressiveBlurView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            roleContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            roleContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 9),
            roleContainer.heightAnchor.constraint(equalToConstant: 24),
            
            roleIcon.leadingAnchor.constraint(equalTo: roleContainer.leadingAnchor, constant: 6),
            roleIcon.centerYAnchor.constraint(equalTo: roleContainer.centerYAnchor),
            roleIcon.widthAnchor.constraint(equalToConstant: 16),
            roleIcon.heightAnchor.constraint(equalToConstant: 16),
            
            roleLabel.leadingAnchor.constraint(equalTo: roleIcon.trailingAnchor, constant: 4),
            roleLabel.trailingAnchor.constraint(equalTo: roleContainer.trailingAnchor, constant: -6),
            roleLabel.centerYAnchor.constraint(equalTo: roleContainer.centerYAnchor),
            
            actionsContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            actionsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -9),
            actionsContainer.heightAnchor.constraint(equalToConstant: 24),
            actionsContainer.widthAnchor.constraint(equalToConstant: 54),
            
            shareIcon.leadingAnchor.constraint(equalTo: actionsContainer.contentView.leadingAnchor, constant: 8),
            shareIcon.centerYAnchor.constraint(equalTo: actionsContainer.centerYAnchor),
            shareIcon.widthAnchor.constraint(equalToConstant: 14),
            shareIcon.heightAnchor.constraint(equalToConstant: 14),
            
            bookmarkIcon.trailingAnchor.constraint(equalTo: actionsContainer.contentView.trailingAnchor, constant: -8),
            bookmarkIcon.centerYAnchor.constraint(equalTo: actionsContainer.centerYAnchor),
            bookmarkIcon.widthAnchor.constraint(equalToConstant: 12),
            bookmarkIcon.heightAnchor.constraint(equalToConstant: 14),
            
            likesContainer.topAnchor.constraint(equalTo: actionsContainer.bottomAnchor, constant: 12),
            likesContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -9),
            likesContainer.heightAnchor.constraint(equalToConstant: 24),
            
            heartIcon.leadingAnchor.constraint(equalTo: likesContainer.contentView.leadingAnchor, constant: 6),
            heartIcon.centerYAnchor.constraint(equalTo: likesContainer.centerYAnchor),
            heartIcon.widthAnchor.constraint(equalToConstant: 12),
            heartIcon.heightAnchor.constraint(equalToConstant: 12),
            
            likesLabel.leadingAnchor.constraint(equalTo: heartIcon.trailingAnchor, constant: 4),
            likesLabel.trailingAnchor.constraint(equalTo: likesContainer.contentView.trailingAnchor, constant: -6),
            likesLabel.centerYAnchor.constraint(equalTo: likesContainer.centerYAnchor),
            
            infoLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            nameLabel.bottomAnchor.constraint(equalTo: infoLabel.topAnchor, constant: -4),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        ])
    }
    
    func configure(with item: SearchUserDTO, county: String?) {
        resetBlurState()
        
        setNeedsLayout()
        layoutIfNeeded()
        
        roleLabel.text = item.user?.roleLabel
        
        likesLabel.text = formatLikes(item.likesCount ?? 0)
        nameLabel.text = item.title
        
        if let age = item.user?.age, let county = county  {
            infoLabel.text = "\(age) y.o" + " • " + county
        } else if let age = item.user?.age {
            infoLabel.text = "\(age) y.o"
        } else if let county = county {
            infoLabel.text = county
        }
        
        if let avatarURLString = item.searchImage?.fullUrl,
           let url = CDNURLHelper.convertToCDNURL(avatarURLString) {
            backgroundImageView.loadImage(from: url) { [weak self] image in
                self?.backgroundImageView.applyAvatarTopCropIfNeeded(image: image)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.layoutIfNeeded()
            self?.animateBlurAppearance()
        }
    }
    
    private func resetBlurState() {
        progressiveBlurView.alpha = 0.0
        
        progressiveBlurTopConstraint?.constant = 0
        
        if let gradient = gradientLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gradient.frame = .zero
            CATransaction.commit()
        }
        
        layoutIfNeeded()
    }
    
    private func formatLikes(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        backgroundImageView.cancelImageLoad()
        backgroundImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        backgroundImageView.image = nil
        backgroundImageView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        
        resetBlurState()
    }
    
    private func setupProgressiveBlurWithGradient() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.white.cgColor,
            UIColor.white.cgColor
        ]
        gradient.locations = [0.0, 0.3, 1.0]
        
        gradient.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "frame": NSNull()
        ]
        
        progressiveBlurView.layer.mask = gradient
        gradientLayer = gradient
    }
}
