import UIKit
import Display
import TelegramCore
import DivoCore

protocol CardCellDelegate: AnyObject {
    func cardCell(_ cell: CardCollectionViewCell, didTapSaveForUserId userId: Int, isSaved: Bool)
    func cardCell(_ cell: CardCollectionViewCell, didTapShareForUserId userId: Int)
}

final class CardCollectionViewCell: UICollectionViewCell {

    weak var delegate: CardCellDelegate?
    private var currentUserId: Int?
    private var currentIsSaved: Bool = false

    var coverImage: UIImage? {
        return mainImageView.image
    }

    // MARK: - Main Image

    private let mainImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        return imageView
    }()

    // MARK: - Glass Blur Overlays

    private let topGlassView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        view.isUserInteractionEnabled = false
        return view
    }()

    private let bottomGlassView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        view.isUserInteractionEnabled = false
        return view
    }()

    private let topGlassMask = CAGradientLayer()
    private let bottomGlassMask = CAGradientLayer()

    // MARK: - Name

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 20) ?? UIFont.boldSystemFont(ofSize: 20)
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    // MARK: - Role Badge

    private let roleBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 34/255.0, green: 98/255.0, blue: 216/255.0, alpha: 1.0)
        view.layer.cornerRadius = 11
        view.layer.masksToBounds = true
        return view
    }()

    private let roleBadgeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "HelveticaNeue", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .regular)
        return label
    }()

    // MARK: - Info Line (age + country)

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "HelveticaNeue", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .regular)
        return label
    }()

    // MARK: - Stat Pills (right side)

    private let statsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        return stack
    }()

    private let likesPill = StatPillView(iconName: "Components/StatLike")
    private let viewsPill = StatPillView(iconName: "Components/StatView")
    private let savesPill: StatPillView = {
        let pill = StatPillView(iconName: "Components/StatSave")
        pill.isUserInteractionEnabled = true
        return pill
    }()

    // MARK: - Saved Toast

    private let savedToastView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.isHidden = true
        return view
    }()

    private let savedToastIcon: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iv.image = UIImage(systemName: "bookmark.fill", withConfiguration: config)
        iv.tintColor = .black
        return iv
    }()

    private let savedToastLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .black
        return label
    }()

    private let savedToastViewButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        button.setTitleColor(UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0), for: .normal)
        return button
    }()

    // MARK: - Preview Gallery

    private let previewScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.clipsToBounds = false
        return sv
    }()

    private let previewStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fill
        stack.spacing = 6
        return stack
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        contentView.layer.cornerRadius = 32
        contentView.layer.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        contentView.addSubview(mainImageView)
        contentView.addSubview(topGlassView)
        contentView.addSubview(bottomGlassView)
        topGlassView.layer.mask = topGlassMask
        bottomGlassView.layer.mask = bottomGlassMask

        contentView.addSubview(nameLabel)
        contentView.addSubview(roleBadgeView)
        roleBadgeView.addSubview(roleBadgeLabel)
        contentView.addSubview(infoLabel)

        contentView.addSubview(statsStackView)
        statsStackView.addArrangedSubview(likesPill)
        statsStackView.addArrangedSubview(viewsPill)
        statsStackView.addArrangedSubview(savesPill)

        let saveTap = UITapGestureRecognizer(target: self, action: #selector(savesPillTapped))
        savesPill.addGestureRecognizer(saveTap)

        contentView.addSubview(previewScrollView)
        previewScrollView.addSubview(previewStackView)

        // Saved toast
        contentView.addSubview(savedToastView)
        savedToastView.addSubview(savedToastIcon)
        savedToastView.addSubview(savedToastLabel)
        savedToastView.addSubview(savedToastViewButton)
        savedToastViewButton.addTarget(self, action: #selector(savedToastViewTapped), for: .touchUpInside)
    }

    @objc private func savesPillTapped() {
        guard let userId = currentUserId else { return }
        currentIsSaved.toggle()
        delegate?.cardCell(self, didTapSaveForUserId: userId, isSaved: currentIsSaved)
        if currentIsSaved {
            showSavedToast()
        } else {
            hideSavedToast()
        }
    }

    @objc private func savedToastViewTapped() {
        // Delegate to show profile — handled by didSelectItem in collection view
    }

    private func showSavedToast() {
        savedToastView.isHidden = false
        savedToastView.alpha = 0
        savedToastView.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: []) {
            self.savedToastView.alpha = 1
            self.savedToastView.transform = .identity
        }
    }

    private func hideSavedToast() {
        UIView.animate(withDuration: 0.2, animations: {
            self.savedToastView.alpha = 0
        }, completion: { _ in
            self.savedToastView.isHidden = true
        })
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let bounds = contentView.bounds
        let sidePadding: CGFloat = 22
        let topPadding: CGFloat = 24

        mainImageView.frame = bounds

        // Glass blur: top (light) + bottom (dark), tight edge transitions
        let topGlassHeight: CGFloat = 120
        topGlassView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: topGlassHeight)
        topGlassMask.frame = topGlassView.bounds
        topGlassMask.startPoint = CGPoint(x: 0.5, y: 0)
        topGlassMask.endPoint = CGPoint(x: 0.5, y: 1)
        topGlassMask.colors = [UIColor.white.cgColor, UIColor.white.cgColor, UIColor(white: 1, alpha: 0).cgColor]
        topGlassMask.locations = [0, 0.3, 1.0]

        let bottomGlassHeight: CGFloat = min(350, bounds.height * 0.55)
        bottomGlassView.frame = CGRect(x: 0, y: bounds.height - bottomGlassHeight, width: bounds.width, height: bottomGlassHeight)
        bottomGlassMask.frame = bottomGlassView.bounds
        bottomGlassMask.startPoint = CGPoint(x: 0.5, y: 0)
        bottomGlassMask.endPoint = CGPoint(x: 0.5, y: 1)
        bottomGlassMask.colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor.white.cgColor, UIColor.white.cgColor]
        bottomGlassMask.locations = [0, 0.75, 1.0]

        // Stats pills (right side) — calculate first to derive name/info widths
        let statsRightPadding: CGFloat = 16
        let statsWidth: CGFloat = 64
        let statsHeight: CGFloat = 30 * 3 + 8 * 2  // 106
        statsStackView.frame = CGRect(
            x: bounds.width - statsRightPadding - statsWidth,
            y: topPadding,
            width: statsWidth,
            height: statsHeight
        )

        // Name
        let maxNameWidth = statsStackView.frame.minX - 10 - sidePadding
        nameLabel.frame = CGRect(x: sidePadding, y: topPadding, width: maxNameWidth, height: 24)

        // Role badge (no icon, text only)
        let badgeY = nameLabel.frame.maxY + 6
        let badgeLabelSize = roleBadgeLabel.sizeThatFits(CGSize(width: 200, height: 22))
        roleBadgeLabel.frame = CGRect(x: 8, y: 0, width: ceil(badgeLabelSize.width), height: 22)
        let badgeWidth = 8 + ceil(badgeLabelSize.width) + 8
        roleBadgeView.frame = CGRect(x: sidePadding, y: badgeY, width: badgeWidth, height: 22)

        // Info label (age + country)
        let infoX = roleBadgeView.frame.maxX + 10
        let infoWidth = statsStackView.frame.minX - 10 - infoX
        infoLabel.frame = CGRect(x: infoX, y: badgeY, width: max(infoWidth, 0), height: 22)

        // Preview images (carousel)
        let hasPreviews = previewStackView.arrangedSubviews.count > 0
        let previewImageWidth: CGFloat = 93
        let previewImageHeight: CGFloat = 100
        let previewLeftPadding: CGFloat = 16
        let previewBottomPadding: CGFloat = 16
        if hasPreviews {
            let previewY = bounds.height - previewBottomPadding - previewImageHeight
            previewScrollView.frame = CGRect(x: previewLeftPadding, y: previewY, width: bounds.width - previewLeftPadding, height: previewImageHeight)
            let imageSpacing: CGFloat = 6
            let count = CGFloat(previewStackView.arrangedSubviews.count)
            let stackWidth = count * previewImageWidth + max(0, count - 1) * imageSpacing
            previewStackView.frame = CGRect(x: 0, y: 0, width: stackWidth, height: previewImageHeight)
            previewScrollView.contentSize = CGSize(width: stackWidth, height: previewImageHeight)
        } else {
            previewScrollView.frame = .zero
            previewStackView.frame = .zero
            previewScrollView.contentSize = .zero
        }

        // Saved toast (bottom of card)
        let toastHeight: CGFloat = 44
        let toastY: CGFloat
        if hasPreviews {
            toastY = previewScrollView.frame.maxY + 8
        } else {
            toastY = bounds.height - toastHeight
        }
        savedToastView.frame = CGRect(x: 0, y: toastY, width: bounds.width, height: toastHeight)
        savedToastIcon.frame = CGRect(x: sidePadding, y: (toastHeight - 18) / 2, width: 18, height: 18)
        savedToastLabel.text = DivoStrings.profileSaved
        savedToastLabel.sizeToFit()
        savedToastLabel.frame = CGRect(x: sidePadding + 24, y: (toastHeight - 20) / 2, width: savedToastLabel.frame.width, height: 20)
        savedToastViewButton.setTitle(DivoStrings.viewAction, for: .normal)
        savedToastViewButton.sizeToFit()
        savedToastViewButton.frame = CGRect(x: bounds.width - sidePadding - savedToastViewButton.frame.width, y: (toastHeight - 20) / 2, width: savedToastViewButton.frame.width, height: 20)
    }

    // MARK: - Configure

    func configure(with model: CardModel, delegate: CardCellDelegate) {
        self.delegate = delegate
        self.currentUserId = model.userId
        self.currentIsSaved = model.isFavorite

        let placeholderColor = UIColor(white: 0.92, alpha: 1.0)

        // Main image
        if let url = model.mainImageURL {
            mainImageView.backgroundColor = placeholderColor
            mainImageView.loadImage(from: url)
        } else if let image = UIImage(named: model.mainImageName) {
            mainImageView.image = image
        } else {
            mainImageView.backgroundColor = placeholderColor
        }

        // Name
        nameLabel.text = model.name

        // Role badge
        let roleText = model.roleLabel ?? model.role ?? ""
        if roleText.isEmpty {
            roleBadgeView.isHidden = true
        } else {
            roleBadgeView.isHidden = false
            roleBadgeLabel.text = roleText.capitalized
        }

        // Info line
        var infoParts: [String] = []
        if let age = model.age, age > 0 {
            infoParts.append("\(age) \(DivoStrings.yearsOld)")
        }
        if let flag = model.countryFlag, let country = model.country {
            infoParts.append("\(flag) \(country)")
        } else if let country = model.country {
            infoParts.append(country)
        }
        infoLabel.text = infoParts.joined(separator: " · ")
        infoLabel.isHidden = infoParts.isEmpty

        // Stats
        likesPill.setValue(Self.formatCount(model.likesCount))
        viewsPill.setValue(Self.formatCount(model.viewsCount))
        savesPill.setValue(Self.formatCount(model.savesCount))

        // Preview images
        previewStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if !model.previewImageURLs.isEmpty {
            for url in model.previewImageURLs {
                let imageView = createPreviewImageView()
                imageView.loadImage(from: url)
                previewStackView.addArrangedSubview(imageView)
            }
        } else {
            for imageName in model.previewImagesName {
                let imageView = createPreviewImage(imageName)
                previewStackView.addArrangedSubview(imageView)
            }
        }
        let hasPreviews = !model.previewImagesName.isEmpty || !model.previewImageURLs.isEmpty
        previewScrollView.isHidden = !hasPreviews
        previewScrollView.contentOffset = .zero

        // Saved toast initial state
        savedToastView.isHidden = !model.isFavorite
        savedToastView.alpha = model.isFavorite ? 1 : 0

        setNeedsLayout()
    }

    // MARK: - Helpers

    private func createPreviewImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = UIColor(white: 0.92, alpha: 1.0)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: 93).isActive = true
        return imageView
    }

    private func createPreviewImage(_ imageName: String) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray
        imageView.image = UIImage(named: imageName)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: 93).isActive = true
        return imageView
    }

    /// Formats count to max 4 characters: 999 → "999", 1K, 288K, 1.5M, 10M, 1.5B
    static func formatCount(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            let value = Double(count) / 1_000_000_000.0
            if value >= 10 {
                return "\(Int(value))B"
            }
            let formatted = String(format: "%.1f", value)
            if formatted.hasSuffix(".0") {
                return "\(Int(value))B"
            }
            return "\(formatted)B"
        } else if count >= 1_000_000 {
            let value = Double(count) / 1_000_000.0
            if value >= 10 {
                return "\(Int(value))M"
            }
            let formatted = String(format: "%.1f", value)
            if formatted.hasSuffix(".0") {
                return "\(Int(value))M"
            }
            return "\(formatted)M"
        } else if count >= 1_000 {
            return "\(count / 1_000)K"
        }
        return "\(count)"
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        mainImageView.cancelImageLoad()
        mainImageView.image = nil
        previewStackView.arrangedSubviews.forEach {
            ($0 as? UIImageView)?.cancelImageLoad()
            $0.removeFromSuperview()
        }
        savedToastView.isHidden = true
        savedToastView.alpha = 0
    }
}

// MARK: - StatPillView

final class StatPillView: UIView {
    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = .white
        return iv
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "HelveticaNeue", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .regular)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        return label
    }()

    init(iconName: String) {
        super.init(frame: .zero)
        backgroundColor = DivoGlassColors.statPillBackground
        layer.cornerRadius = 15
        layer.masksToBounds = true
        layer.borderWidth = 0.5
        layer.borderColor = DivoGlassColors.statPillBorder.cgColor

        iconView.image = UIImage(bundleImageName: iconName)?.withRenderingMode(.alwaysTemplate)

        addSubview(iconView)
        addSubview(countLabel)

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ text: String) {
        countLabel.text = text
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let iconSize: CGFloat = 16
        let iconX: CGFloat = 8
        let iconY: CGFloat = (bounds.height - iconSize) / 2
        iconView.frame = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
        let labelX: CGFloat = iconX + iconSize + 2
        let labelWidth = bounds.width - labelX - 4
        countLabel.frame = CGRect(x: labelX, y: 0, width: max(labelWidth, 0), height: bounds.height)
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: 64, height: 30)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return intrinsicContentSize
    }
}
