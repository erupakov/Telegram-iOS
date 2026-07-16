import UIKit
import Display
import DivoCore

public struct SearchCardViewModel {
    public enum Variant {
        case search
        case faceMatch(percent: Double)
    }

    public let variant: Variant
    public let feedId: Int?
    public let userId: Int?
    public let name: String?
    public let infoText: String?
    public let roleLabel: String?
    public let likesCount: Int
    public let isLikedByUser: Bool
    public let isFavoriteByUser: Bool
    public let imageURL: URL?

    public init(
        variant: Variant,
        feedId: Int?,
        userId: Int?,
        name: String?,
        infoText: String?,
        roleLabel: String?,
        likesCount: Int,
        isLikedByUser: Bool,
        isFavoriteByUser: Bool,
        imageURL: URL?
    ) {
        self.variant = variant
        self.feedId = feedId
        self.userId = userId
        self.name = name
        self.infoText = infoText
        self.roleLabel = roleLabel
        self.likesCount = likesCount
        self.isLikedByUser = isLikedByUser
        self.isFavoriteByUser = isFavoriteByUser
        self.imageURL = imageURL
    }
}

public final class SearchResultGridCell: UICollectionViewCell {

    private let backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = DivoColorPalette.imagePlaceholderLight
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let progressiveBlurView: UIVisualEffectView = {
        // Dark material — пока фото не загрузилось, чтобы дать scrim
        // для белого текста на светлом placeholder. После загрузки фото
        // переключаемся на `.light` — прежний визуал blur поверх фото
        // (см. configure).
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
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

    private let matchPercentContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let matchPercentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "HelveticaNeue-Bold", size: 11) ?? UIFont.boldSystemFont(ofSize: 11)
        label.textColor = DivoColorPalette.accent
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bottomRoleContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.roleBadgeBlue
        view.layer.cornerRadius = DivoDesignTokens.Radius.m
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let bottomRoleLabel: UILabel = {
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

    private var currentUserId: Int?
    private var currentIsLiked: Bool = false
    private var currentIsSaved: Bool = false
    private var currentLikesCount: Int = 0

    public var onLikeTapped: ((Int, Bool) -> Void)?
    public var onSaveTapped: ((Int, Bool) -> Void)?
    public var onShareTapped: (() -> Void)?

    public var coverImage: UIImage? {
        backgroundImageView.image
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: isHighlighted ? 0.25 : 0.4, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            })
        }
    }

    override public func layoutSubviews() {
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

        progressiveBlurView.alpha = 0.0
        progressiveBlurView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(progressiveBlurView)

        setupProgressiveBlurWithGradient()

        contentView.addSubview(roleContainer)
        roleContainer.addSubview(roleLabel)

        contentView.addSubview(matchPercentContainer)
        matchPercentContainer.addSubview(matchPercentLabel)

        contentView.addSubview(bottomRoleContainer)
        bottomRoleContainer.addSubview(bottomRoleLabel)

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

            matchPercentContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            matchPercentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 9),
            matchPercentContainer.heightAnchor.constraint(equalToConstant: 22),

            matchPercentLabel.leadingAnchor.constraint(equalTo: matchPercentContainer.leadingAnchor, constant: 8),
            matchPercentLabel.trailingAnchor.constraint(equalTo: matchPercentContainer.trailingAnchor, constant: -8),
            matchPercentLabel.centerYAnchor.constraint(equalTo: matchPercentContainer.centerYAnchor),

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
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            bottomRoleContainer.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -6),
            bottomRoleContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            bottomRoleContainer.heightAnchor.constraint(equalToConstant: 24),

            bottomRoleLabel.leadingAnchor.constraint(equalTo: bottomRoleContainer.leadingAnchor, constant: 6),
            bottomRoleLabel.trailingAnchor.constraint(equalTo: bottomRoleContainer.trailingAnchor, constant: -6),
            bottomRoleLabel.centerYAnchor.constraint(equalTo: bottomRoleContainer.centerYAnchor)
        ])
    }

    public func configure(with item: SearchUserDTO, county: String?) {
        let infoText: String?
        if let age = item.user?.age, let county = county {
            infoText = DivoStrings.ageString(age) + " • " + county
        } else if let age = item.user?.age {
            infoText = DivoStrings.ageString(age)
        } else {
            infoText = county
        }

        let imageURL = item.searchImage?.fullUrl.flatMap { CDNURLHelper.convertToCDNURL($0) }

        let viewModel = SearchCardViewModel(
            variant: .search,
            feedId: item.feedId,
            userId: item.user?.id,
            name: item.title,
            infoText: infoText,
            roleLabel: item.user?.roleLabel,
            likesCount: item.likesCount ?? 0,
            isLikedByUser: item.isLikedByUser ?? false,
            isFavoriteByUser: item.isFavoriteByUser ?? false,
            imageURL: imageURL
        )
        configure(with: viewModel)
    }

    public func configure(with viewModel: SearchCardViewModel) {
        resetBlurState()

        setNeedsLayout()
        layoutIfNeeded()

        currentUserId = viewModel.userId
        currentIsLiked = viewModel.isLikedByUser
        currentIsSaved = viewModel.isFavoriteByUser
        currentLikesCount = viewModel.likesCount

        nameLabel.text = viewModel.name
        infoLabel.text = viewModel.infoText
        likesLabel.text = formatLikes(currentLikesCount)

        updateLikeVisual()
        updateSaveVisual()

        applyVariant(viewModel.variant, role: viewModel.roleLabel)

        let placeholder = DivoImage.emptyBackgroundModelProfile
        if let url = viewModel.imageURL {
            applyDarkTextStyle(false)
            // Blur показываем сразу — на dark material даёт scrim для
            // белого текста на placeholder. Когда фото загрузится —
            // переключаем material на `.light` (прежний визуал поверх фото).
            progressiveBlurView.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            animateBlurAppearance()
            backgroundImageView.loadImage(from: url, placeholder: placeholder) { [weak self] image in
                guard let self, image != nil else { return }
                self.progressiveBlurView.effect = UIBlurEffect(style: .light)
            }
        } else {
            backgroundImageView.image = placeholder
            applyDarkTextStyle(true)
        }
    }

    private func applyDarkTextStyle(_ isDark: Bool) {
        let textColor = isDark ? DivoColorPalette.primaryText : DivoColorPalette.primaryTextOnDark
        nameLabel.textColor = textColor
        infoLabel.textColor = textColor
        progressiveBlurView.isHidden = isDark
    }

    private func applyVariant(_ variant: SearchCardViewModel.Variant, role: String?) {
        switch variant {
        case .search:
            roleLabel.text = role
            roleContainer.isHidden = (role == nil)
            matchPercentContainer.isHidden = true
            bottomRoleContainer.isHidden = true
            actionsContainer.isHidden = false
            likesContainer.isHidden = false

        case .faceMatch(let percent):
            roleContainer.isHidden = true
            actionsContainer.isHidden = false
            likesContainer.isHidden = false

            let percentInt = Int((percent * 100).rounded())
            let isHighMatch = percentInt >= 90
            matchPercentLabel.text = DivoStrings.faceSearchMatchPercentBadge(percentInt)
            matchPercentLabel.textColor = isHighMatch ? DivoColorPalette.accent : DivoColorPalette.matchPercentMuted
            matchPercentContainer.isHidden = false
            if isHighMatch {
                matchPercentContainer.layer.borderWidth = 2
                matchPercentContainer.layer.borderColor = DivoColorPalette.accent.cgColor
            } else {
                matchPercentContainer.layer.borderWidth = 0
                matchPercentContainer.layer.borderColor = nil
            }

            bottomRoleLabel.text = role
            bottomRoleContainer.isHidden = (role == nil)
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
        // Лайк адресуется по userId (/user/like, DIVI-64) — как save. feedId в FR отсутствует, userId есть везде.
        guard let userId = currentUserId else { return }
        currentIsLiked.toggle()
        currentLikesCount = max(0, currentLikesCount + (currentIsLiked ? 1 : -1))
        updateLikeVisual()
        likesLabel.text = formatLikes(currentLikesCount)
        heartIcon.divoPopAnimate()
        onLikeTapped?(userId, currentIsLiked)
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

    public func rollbackLike(isLiked: Bool, likesCount: Int) {
        currentIsLiked = isLiked
        currentLikesCount = likesCount
        updateLikeVisual()
        likesLabel.text = formatLikes(currentLikesCount)
        heartIcon.divoPopAnimate()
    }

    public func rollbackSave(isSaved: Bool) {
        currentIsSaved = isSaved
        updateSaveVisual()
        bookmarkIcon.divoPopAnimate()
    }

    override public func prepareForReuse() {
        super.prepareForReuse()

        backgroundImageView.cancelImageLoad()
        backgroundImageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        backgroundImageView.image = nil
        backgroundImageView.backgroundColor = DivoColorPalette.imagePlaceholderLight

        onLikeTapped = nil
        onSaveTapped = nil
        onShareTapped = nil

        progressiveBlurView.isHidden = false
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
