import UIKit
import Display
import DivoUIKit

final class StoryCollectionViewCell: UICollectionViewCell {
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = Font.regular(12.0)
        return label
    }()
    
    private let statusIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = DivoDesignTokens.Radius.xs
        view.layer.borderColor = UIColor.black.cgColor
        view.layer.borderWidth = 1.5
        view.isHidden = true
        return view
    }()

    // Кольцо сторис. Целиком внутри круга аватара (см. inset в layoutSubviews), чтобы маска не срезала штрих.
    // Цвет — по состоянию (см. configure): красный = непросмотрено, серый = просмотрено. Как в профиле DIVO.
    private let unseenRingLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = DivoColorPalette.avatarStrokeRedDeep.cgColor
        layer.lineWidth = 3
        layer.isHidden = true
        return layer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(avatarImageView)
        avatarImageView.layer.addSublayer(unseenRingLayer)
        contentView.addSubview(nameLabel)
        contentView.addSubview(statusIndicator)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Press-state: лёгкий scale + alpha при нажатии (значения из дизайн-системы).
    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            let pressed = isHighlighted
            UIView.animate(withDuration: pressed ? DivoDesignTokens.PressState.pressDuration : DivoDesignTokens.PressState.releaseDuration) {
                let scale = DivoDesignTokens.PressState.scale
                self.contentView.transform = pressed ? CGAffineTransform(scaleX: scale, y: scale) : .identity
                self.contentView.alpha = pressed ? DivoDesignTokens.PressState.alpha : 1.0
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        addOverlay.removeFromSuperview()
        avatarImageView.image = nil
        avatarImageView.backgroundColor = DivoColorPalette.avatarPlaceholderCool
        unseenRingLayer.isHidden = true
        contentView.transform = .identity
        contentView.alpha = 1.0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        let avatarSize: CGFloat = 60
        avatarImageView.frame = CGRect(x: (contentView.bounds.width - avatarSize) / 2,
                                       y: 0,
                                       width: avatarSize,
                                       height: avatarSize)
        avatarImageView.layer.cornerRadius = avatarSize / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        unseenRingLayer.frame = avatarImageView.bounds
        // inset держит штрих (lineWidth 3) целиком внутри круглой маски avatarImageView, иначе внешний край срежется.
        unseenRingLayer.path = UIBezierPath(ovalIn: avatarImageView.bounds.insetBy(dx: 2, dy: 2)).cgPath
        CATransaction.commit()

        nameLabel.frame = CGRect(x: 0,
                                 y: avatarImageView.frame.maxY + 4,
                                 width: contentView.bounds.width,
                                 height: 14)
        
        let indicatorSize: CGFloat = 8
        statusIndicator.frame = CGRect(x: avatarImageView.frame.maxX - indicatorSize - 2,
                                       y: avatarImageView.frame.maxY - indicatorSize - 2,
                                       width: indicatorSize,
                                       height: indicatorSize)
        statusIndicator.layer.cornerRadius = indicatorSize / 2
    }
    
    private lazy var addOverlay: UIView = {
        let circle = UIView()
        circle.backgroundColor = DivoColorPalette.cardBackground
        circle.layer.applyDivoShadow(
            opacity: DivoDesignTokens.Shadow.opacityMedium,
            radius: DivoDesignTokens.Shadow.thumbRadius,
            offset: DivoDesignTokens.Shadow.thumbOffset
        )
        circle.isUserInteractionEnabled = false

        let plusIcon = UIImageView()
        plusIcon.tintColor = DivoColorPalette.primaryText
        plusIcon.contentMode = .scaleAspectFit
        plusIcon.tag = 100
        circle.addSubview(plusIcon)
        return circle
    }()

    func configure(with model: StoryModel) {
        addOverlay.removeFromSuperview()

        if let isAdd = model.isAdd, isAdd {
            // Programmatic circle + plus
            unseenRingLayer.isHidden = true
            avatarImageView.image = nil
            avatarImageView.backgroundColor = .clear
            let size: CGFloat = 54
            addOverlay.frame = CGRect(x: (contentView.bounds.width - size) / 2, y: 0, width: size, height: size)
            addOverlay.layer.cornerRadius = size / 2
            if let plusIcon = addOverlay.viewWithTag(100) as? UIImageView {
                let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                plusIcon.image = UIImage(systemName: "plus", withConfiguration: config)
                let iconSize: CGFloat = 18
                plusIcon.frame = CGRect(x: (size - iconSize) / 2, y: (size - iconSize) / 2, width: iconSize, height: iconSize)
            }
            contentView.addSubview(addOverlay)
        } else {
            // Кольцо у любой сторис-ячейки: красный — есть непросмотренные, серый — все просмотрены (в т.ч. своя).
            unseenRingLayer.isHidden = false
            unseenRingLayer.strokeColor = (model.hasUnseen ? DivoColorPalette.avatarStrokeRedDeep : DivoColorPalette.avatarStrokeQuiet).cgColor
            if let image = model.avatar {
                avatarImageView.image = image
                avatarImageView.contentMode = .scaleAspectFill
            }
            avatarImageView.backgroundColor = DivoColorPalette.avatarPlaceholderCool
        }

        nameLabel.text = model.name
        statusIndicator.isHidden = !model.isLive
    }
}

extension UIImage { // TODO:
    func resized(to targetSize: CGSize) -> UIImage? {
        let rect = CGRect(origin: .zero, size: targetSize)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
