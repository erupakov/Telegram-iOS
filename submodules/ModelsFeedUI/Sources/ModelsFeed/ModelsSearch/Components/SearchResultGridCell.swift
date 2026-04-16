//
//  SearchResultGridCell.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.04.2026.
//

import UIKit
import Display
import DivoCore
import DivoUIKit

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
        view.backgroundColor = DivoColorPalette.roleBadgeBlue
        view.layer.cornerRadius = DivoDesignTokens.Radius.m
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(11)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let actionsContainer: UIVisualEffectView = {
        let ve = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
        ve.layer.cornerRadius = DivoDesignTokens.Radius.m
        ve.clipsToBounds = true
        ve.translatesAutoresizingMaskIntoConstraints = false
        return ve
    }()
    
    private let shareIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "square.and.arrow.up")
        iv.tintColor = DivoColorPalette.primaryTextOnDark
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let bookmarkIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.statSave.withRenderingMode(.alwaysTemplate)
        iv.contentMode = .scaleAspectFit
        iv.tintColor = DivoColorPalette.primaryTextOnDark
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let likesContainer: UIVisualEffectView = {
        let ve = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
        ve.layer.cornerRadius = DivoDesignTokens.Radius.m
        ve.clipsToBounds = true
        ve.translatesAutoresizingMaskIntoConstraints = false
        return ve
    }()
    
    private let heartIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private let likesLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(10)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(20)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(10)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - State & Callbacks

    private var currentFeedId: Int?
    private var currentUserId: Int?
    private var currentIsLiked: Bool = false
    private var currentIsSaved: Bool = false
    private var currentLikesCount: Int = 0

    var onLikeTapped: ((Int, Bool) -> Void)?
    var onSaveTapped: ((Int, Bool) -> Void)?
    var onShareTapped: (() -> Void)?

    var coverImage: UIImage? {
        backgroundImageView.image
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: isHighlighted ? 0.25 : 0.4, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            })
        }
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
        contentView.layer.cornerRadius = DivoDesignTokens.Radius.l
        contentView.clipsToBounds = true
        
        contentView.addSubview(backgroundImageView)
        
        progressiveBlurView.alpha = 0.8
        progressiveBlurView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(progressiveBlurView)
        
        setupProgressiveBlurWithGradient()
        
        contentView.addSubview(roleContainer)
        roleContainer.addSubview(roleLabel)
        
        contentView.addSubview(actionsContainer)
        
        actionsContainer.contentView.addSubview(shareIcon)
        actionsContainer.contentView.addSubview(bookmarkIcon)
        
        contentView.addSubview(likesContainer)
        
        heartIcon.image = DivoImage.statLike.withRenderingMode(.alwaysTemplate)
        heartIcon.tintColor = DivoColorPalette.primaryTextOnDark
        heartIcon.translatesAutoresizingMaskIntoConstraints = false
        likesContainer.contentView.addSubview(heartIcon)
        likesContainer.contentView.addSubview(likesLabel)
        
        contentView.addSubview(nameLabel)
        contentView.addSubview(infoLabel)
        
        setupConstraints()

        let likeTap = UITapGestureRecognizer(target: self, action: #selector(likeTapped))
        likesContainer.addGestureRecognizer(likeTap)

        bookmarkIcon.isUserInteractionEnabled = true
        let saveTap = UITapGestureRecognizer(target: self, action: #selector(saveTapped))
        bookmarkIcon.addGestureRecognizer(saveTap)

        shareIcon.isUserInteractionEnabled = true
        let shareTap = UITapGestureRecognizer(target: self, action: #selector(shareTapped))
        shareIcon.addGestureRecognizer(shareTap)
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
            
            roleLabel.leadingAnchor.constraint(equalTo: roleContainer.leadingAnchor, constant: 6),
            roleLabel.trailingAnchor.constraint(equalTo: roleContainer.trailingAnchor, constant: -6),
            roleLabel.centerYAnchor.constraint(equalTo: roleContainer.centerYAnchor),
            
            actionsContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            actionsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -9),
            actionsContainer.heightAnchor.constraint(equalToConstant: 24),
            actionsContainer.widthAnchor.constraint(equalToConstant: 54),
            
            shareIcon.leadingAnchor.constraint(equalTo: actionsContainer.contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            shareIcon.centerYAnchor.constraint(equalTo: actionsContainer.centerYAnchor),
            shareIcon.widthAnchor.constraint(equalToConstant: 16),
            shareIcon.heightAnchor.constraint(equalToConstant: 16),

            bookmarkIcon.trailingAnchor.constraint(equalTo: actionsContainer.contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            bookmarkIcon.centerYAnchor.constraint(equalTo: actionsContainer.centerYAnchor),
            bookmarkIcon.widthAnchor.constraint(equalToConstant: 16),
            bookmarkIcon.heightAnchor.constraint(equalToConstant: 16),
            
            likesContainer.topAnchor.constraint(equalTo: actionsContainer.bottomAnchor, constant: 12),
            likesContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -9),
            likesContainer.heightAnchor.constraint(equalToConstant: 24),
            
            heartIcon.leadingAnchor.constraint(equalTo: likesContainer.contentView.leadingAnchor, constant: 6),
            heartIcon.centerYAnchor.constraint(equalTo: likesContainer.centerYAnchor),
            heartIcon.widthAnchor.constraint(equalToConstant: 16),
            heartIcon.heightAnchor.constraint(equalToConstant: 16),
            
            likesLabel.leadingAnchor.constraint(equalTo: heartIcon.trailingAnchor, constant: 4),
            likesLabel.trailingAnchor.constraint(equalTo: likesContainer.contentView.trailingAnchor, constant: -6),
            likesLabel.centerYAnchor.constraint(equalTo: likesContainer.centerYAnchor),
            
            infoLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
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

        currentFeedId = item.feedId
        currentUserId = item.user?.id
        currentIsLiked = item.isLikedByUser ?? false
        currentIsSaved = item.isFavoriteByUser ?? false
        currentLikesCount = item.likesCount ?? 0

        roleLabel.text = item.user?.roleLabel

        likesLabel.text = formatLikes(currentLikesCount)
        nameLabel.text = item.title

        updateLikeVisual()
        updateSaveVisual()
        
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

    // MARK: - Visual State

    private func updateLikeVisual() {
        heartIcon.image = (currentIsLiked ? DivoImage.statLikeFilled : DivoImage.statLike).withRenderingMode(.alwaysTemplate)
    }

    private func updateSaveVisual() {
        bookmarkIcon.image = (currentIsSaved ? DivoImage.statSaveFilled : DivoImage.statSave).withRenderingMode(.alwaysTemplate)
    }

    // MARK: - Actions

    @objc private func likeTapped() {
        guard let feedId = currentFeedId else { return }
        currentIsLiked.toggle()
        currentLikesCount = max(0, currentLikesCount + (currentIsLiked ? 1 : -1))
        updateLikeVisual()
        likesLabel.text = formatLikes(currentLikesCount)
        heartIcon.divoPopAnimate()
        onLikeTapped?(feedId, currentIsLiked)
    }

    @objc private func saveTapped() {
        guard let userId = currentUserId else { return }
        currentIsSaved.toggle()
        updateSaveVisual()
        bookmarkIcon.divoPopAnimate()
        onSaveTapped?(userId, currentIsSaved)
    }

    @objc private func shareTapped() {
        onShareTapped?()
    }

    // MARK: - Rollback

    func rollbackLike(isLiked: Bool, likesCount: Int) {
        currentIsLiked = isLiked
        currentLikesCount = likesCount
        updateLikeVisual()
        likesLabel.text = formatLikes(currentLikesCount)
        heartIcon.divoPopAnimate()
    }

    func rollbackSave(isSaved: Bool) {
        currentIsSaved = isSaved
        updateSaveVisual()
        bookmarkIcon.divoPopAnimate()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        backgroundImageView.cancelImageLoad()
        backgroundImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        backgroundImageView.image = nil
        backgroundImageView.backgroundColor = DivoColorPalette.imagePlaceholderDark

        onLikeTapped = nil
        onSaveTapped = nil
        onShareTapped = nil

        resetBlurState()
    }
    
    private func setupProgressiveBlurWithGradient() {
        // Градиент используется как alpha-маска progressiveBlurView (.clear → opaque),
        // цвет не виден на UI, поэтому DivoColorPalette здесь неприменим.
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
