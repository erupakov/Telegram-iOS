import UIKit
import Display

protocol CardCellDelegate: AnyObject {
    func cardCell(_ cell: CardCollectionViewCell, didTapReaction reaction: ReactionType, for cardName: String, isSelected: Bool)
}

final class CardCollectionViewCell: UICollectionViewCell {
    
    weak var delegate: CardCellDelegate?
    private var currentCardName: String?
    
    private let mainImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let gradientView: GradientView = {
        let view = GradientView()
        let colors: [UIColor] = [
            .clear,
            .clear,
            UIColor.black.withAlphaComponent(0.6)
        ]
        view.configure(colors: colors, direction: .vertical)
        return view
    }()
    
    private let reactionsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 15
        stack.alignment = .center
        return stack
    }()
    
    private func createReactionButton(symbol: String, count: Int, reactionType: ReactionType, isSelected: Bool) -> UIButton {
        
        let button = HighlightableReactionButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.reactionType = reactionType
        button.isCurrentlySelected = isSelected
        button.updateAppearance(forPress: false)
        
        let label = UILabel()
        label.text = symbol
        label.font = UIFont.systemFont(ofSize: 20)
        label.textAlignment = .center
        
        let countLabel = UILabel() //TODO:
        countLabel.text = String(count)
        countLabel.textColor = .white
        countLabel.font = UIFont.boldSystemFont(ofSize: 12)
        countLabel.textAlignment = .center
        
        let stack = UIStackView(arrangedSubviews: [label, countLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 2
        stack.isUserInteractionEnabled = false
        
        button.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
        
        let buttonSize: CGFloat = 40
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 70),
            button.heightAnchor.constraint(equalToConstant: buttonSize)
        ])
        
        button.tag = reactionType.rawValue
        
        button.addTarget(self, action: #selector(reactionButtonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 3
        imageView.layer.borderColor = UIColor.white.cgColor
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = Font.helveticaNeue(34)
        label.numberOfLines = 0
        return label
    }()
    
    private let dmButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        button.layer.cornerRadius = 12
        return button
    }()

    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.backgroundColor = .clear
        
        let image = UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction")
        button.setImage(image, for: .normal)
        
        return button
    }()
    
    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.backgroundColor = .clear
        
        let image = UIImage(bundleImageName: "Instant View/Bookmark")
        button.setImage(image, for: .normal)
        
        return button
    }()
    
    private let secondaryActionsBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()
    
    private let statusLabel: UILabel = {//TODO:
        let label = UILabel()
        label.textColor = .white
        label.text = "♦️ model"
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    private let previewStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 5
        return stack
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        self.layer.cornerRadius = 10
        self.layer.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(mainImageView)
        contentView.addSubview(gradientView)
        contentView.addSubview(reactionsStackView)
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
//        contentView.addSubview(statusLabel)
        
        contentView.addSubview(dmButton)
        contentView.addSubview(secondaryActionsBackgroundView)
        secondaryActionsBackgroundView.addSubview(shareButton)
        secondaryActionsBackgroundView.addSubview(saveButton)
        
        contentView.addSubview(previewStackView)
        
        contentView.addSubview(previewStackView)
        
        setupDmButtonContent()
        reactionsStackView.addArrangedSubview(createReactionButton(symbol: "👍", count: 11, reactionType: .like, isSelected: false))
        reactionsStackView.addArrangedSubview(createReactionButton(symbol: "❤️", count: 8, reactionType: .heart, isSelected: false))
        reactionsStackView.addArrangedSubview(createReactionButton(symbol: "👎", count: 4, reactionType: .dislike, isSelected: false))
        reactionsStackView.addArrangedSubview(createReactionButton(symbol: "🔥", count: 18, reactionType: .fire, isSelected: false))
    }
    
    @objc private func reactionButtonTapped(_ sender: UIButton) {
        guard let reactionButton = sender as? HighlightableReactionButton,
              let reactionType = ReactionType(rawValue: sender.tag),
              let cardName = currentCardName else {
            print("reactionButtonTapped")
            return
        }
        
        let newSelectedState = !reactionButton.isCurrentlySelected
        reactionButton.isCurrentlySelected = newSelectedState
    
        delegate?.cardCell(self, didTapReaction: reactionType, for: cardName, isSelected: newSelectedState)
    }
    
    private func setupDmButtonContent() {//TODO:
        let iconImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.image = UIImage(bundleImageName: "Chat/Context Menu/MessageBubble")
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            return imageView
        }()
        
        let label: UILabel = {
            let label = UILabel()
            label.text = "Send DM"
            label.textColor = .white
            label.font = Font.helveticaNeue(13)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        let stackView: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [iconImageView, label])
            stack.axis = .horizontal
            stack.spacing = 4
            stack.alignment = .center
            stack.isUserInteractionEnabled = false
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        
        dmButton.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: dmButton.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: dmButton.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func createIconActionButton(systemName: String) -> UIButton {
        let button = UIButton(type: .system)
        let image = UIImage(bundleImageName: systemName)
        
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = .clear
        button.layer.cornerRadius = 0
        
        let size: CGFloat = 40
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
        button.widthAnchor.constraint(equalToConstant: size).isActive = true
        
        
        return button
    }
    
    private func createPreviewImage(_ imageName: String) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 5
        imageView.backgroundColor = .systemGray
        imageView.image = UIImage(named: imageName)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let aspectRatioConstraint = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor)
        aspectRatioConstraint.isActive = true
        aspectRatioConstraint.priority = .required
        return imageView
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        mainImageView.frame = contentView.bounds
        gradientView.frame = contentView.bounds
        
        let bounds = contentView.bounds
        let safeRight = bounds.width - 15
        let sidePadding: CGFloat = 15
        let actionsHeight: CGFloat = 40
        let buttonSize: CGFloat = actionsHeight
        let spacing: CGFloat = 10
        let backgroundPadding: CGFloat = 8
        let bottomMargin: CGFloat = 15
        
        let reactionsWidth: CGFloat = 65
        let reactionsHeight: CGFloat = 210
        
        reactionsStackView.frame = CGRect(x: safeRight - reactionsWidth,
                                          y: 20,
                                          width: reactionsWidth,
                                          height: reactionsHeight)
        
        let previewHeight: CGFloat = 100
        previewStackView.frame = CGRect(x: 15,
                                        y: bounds.height - 15 - previewHeight,
                                        width: bounds.width - 30,
                                        height: previewHeight)
        
        var actionsY = previewStackView.frame.minY - actionsHeight - bottomMargin
        
        if previewStackView.subviews.isEmpty {
            actionsY += 120
        }
        
        let dmButtonWidth: CGFloat = 100
        dmButton.frame = CGRect(x: sidePadding,
                                y: actionsY,
                                width: dmButtonWidth,
                                height: actionsHeight)
        
        let backgroundWidth: CGFloat = 100.0
        let backgroundHeight = actionsHeight
        
        secondaryActionsBackgroundView.frame = CGRect(x: bounds.width - sidePadding - backgroundWidth,
                                                      y: actionsY,
                                                      width: backgroundWidth,
                                                      height: backgroundHeight)
        
        shareButton.frame = CGRect(x: backgroundPadding,
                                   y: 0,
                                   width: buttonSize,
                                   height: buttonSize)
        
        saveButton.frame = CGRect(x: backgroundPadding + buttonSize + spacing,
                                  y: 0,
                                  width: buttonSize,
                                  height: buttonSize)
        
        let avatarSize: CGFloat = 80
        avatarImageView.frame = CGRect(x: 15,
                                       y: actionsY - 10 - avatarSize,
                                       width: avatarSize,
                                       height: avatarSize)
        avatarImageView.layer.cornerRadius = avatarSize / 2
        
        let textX = avatarImageView.frame.maxX + 10
        let textWidth = bounds.width - textX - reactionsWidth - 10
        
        nameLabel.frame = CGRect(x: textX,
                                 y: avatarImageView.frame.minY + 15,
                                 width: textWidth,
                                 height: 70)
        
//        statusLabel.frame = CGRect(x: textX,
//                                   y: nameLabel.frame.maxY + 2,
//                                   width: textWidth,
//                                   height: 18)
    }
    
    func configure(with model: CardModel, delegate: CardCellDelegate) {
        self.delegate = delegate
        self.currentCardName = model.name
        
        let userReaction = model.userReaction
        
        reactionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if let image = UIImage(named: model.mainImageName) {
            mainImageView.image = image
        } else {
            mainImageView.backgroundColor = .lightGray
        }
        avatarImageView.image = UIImage(named: model.avatarImageName)
        
        avatarImageView.backgroundColor = .white
        
        nameLabel.text = model.name
        
        reactionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        reactionsStackView.addArrangedSubview(createReactionButton(symbol: "👍", count: 11, reactionType: .like, isSelected: userReaction == .like))
        reactionsStackView.addArrangedSubview(createReactionButton(symbol: "❤️", count: 8, reactionType: .heart, isSelected: userReaction == .heart))
        reactionsStackView.addArrangedSubview(createReactionButton(symbol: "👎", count: 4, reactionType: .dislike, isSelected: userReaction == .dislike))
        reactionsStackView.addArrangedSubview(createReactionButton(symbol: "🔥", count: 18, reactionType: .fire, isSelected: userReaction == .fire))
        
        previewStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for imageName in model.previewImagesName {
            let imageView = createPreviewImage(imageName)
            
            previewStackView.addArrangedSubview(imageView)
        }
        let hasPreviews = !model.previewImagesName.isEmpty
        
        previewStackView.isHidden = !hasPreviews
        setNeedsLayout()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        mainImageView.image = nil
        avatarImageView.image = nil
        previewStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
}
