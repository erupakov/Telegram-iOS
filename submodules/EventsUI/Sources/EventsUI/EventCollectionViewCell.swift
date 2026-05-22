import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle

final class EventCollectionViewCell: UICollectionViewCell {

    static let reuseIdentifier = "EventCollectionViewCell"
    
    private let blurMaskLayer = CAGradientLayer()

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = DivoColorPalette.imagePlaceholderMedium
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let blurredHeaderImageView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let profileImageView: UIImageView = {
        let profileImageView = UIImageView()
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 10
        profileImageView.backgroundColor = DivoColorPalette.avatarPlaceholderWarm
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        return profileImageView
    }()
    
    private let badgesStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = DivoDesignTokens.Spacing.xs
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let eventTypeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.roleBadgeBlue
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let eventTypeLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(11)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        return label
    }()
    
    private let paidContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.statPillBackground
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let paidIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.paid.withRenderingMode(.alwaysTemplate)
        iv.tintColor = DivoColorPalette.cardBackground
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let paidLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(11)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.text = DivoStrings.paid
        return label
    }()
    
    private let profileNameLabel: UILabel = {
        let profileNameLabel = UILabel()
        profileNameLabel.font = Font.medium(10)
        profileNameLabel.textColor = DivoColorPalette.primaryTextOnDark
        profileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        return profileNameLabel
    }()
    
    private let profileCheckImageView: UIImageView = {
        let profileCheckImageView = UIImageView()
        profileCheckImageView.contentMode = .scaleAspectFill
        profileCheckImageView.clipsToBounds = true
        profileCheckImageView.translatesAutoresizingMaskIntoConstraints = false
        profileCheckImageView.image = DivoImage.verified
        return profileCheckImageView
    }()
    
    private let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = Font.helveticaNeue(20)
        titleLabel.textColor = DivoColorPalette.primaryTextOnDark
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        return titleLabel
    }()
    
    private let dateLocationLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(10)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        return label
    }()
    
    private let timeRemainingContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.statPillBackground
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let timeRemainingLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(10)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        return label
    }()
        
    private let applyButton: DivoButton = {
        let button = DivoButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let availableSeatsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.statPillBackground
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var availableSeatsBottomConstraint: NSLayoutConstraint!
    
    private let availableSeatsLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(10)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        
        applyButton.makeDivoButton(title: DivoStrings.apply, buttonFont: Font.helveticaNeue(12), radius: 12)
//        applyButton.addTarget(self, action: #selector(dashedUploadTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.layer.cornerRadius = DivoDesignTokens.Spacing.m
        contentView.layer.masksToBounds = true

        contentView.addSubview(imageView)

        contentView.addSubview(blurredHeaderImageView)
        blurredHeaderImageView.layer.mask = blurMaskLayer

        contentView.addSubview(badgesStackView)
        
        badgesStackView.addArrangedSubview(eventTypeContainer)
        badgesStackView.addArrangedSubview(paidContainer)
        
        eventTypeContainer.addSubview(eventTypeLabel)
        paidContainer.addSubview(paidIcon)
        paidContainer.addSubview(paidLabel)
        
        paidLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        eventTypeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        contentView.addSubview(profileImageView)
        contentView.addSubview(profileNameLabel)
        contentView.addSubview(profileCheckImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(dateLocationLabel)

        contentView.addSubview(timeRemainingContainer)
        timeRemainingContainer.addSubview(timeRemainingLabel)
        contentView.addSubview(applyButton)
        
        contentView.addSubview(availableSeatsContainer)
        availableSeatsContainer.addSubview(availableSeatsLabel)

        availableSeatsBottomConstraint = availableSeatsContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            badgesStackView.bottomAnchor.constraint(equalTo: profileImageView.topAnchor, constant: -10),
            badgesStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            badgesStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -10),
            badgesStackView.heightAnchor.constraint(equalToConstant: 22),

            eventTypeLabel.leadingAnchor.constraint(equalTo: eventTypeContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            eventTypeLabel.trailingAnchor.constraint(equalTo: eventTypeContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            eventTypeLabel.bottomAnchor.constraint(equalTo: eventTypeContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs),
            eventTypeLabel.topAnchor.constraint(equalTo: eventTypeContainer.topAnchor, constant: DivoDesignTokens.Spacing.xs),
                     
            paidIcon.leadingAnchor.constraint(equalTo: paidContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.xs),
            paidIcon.bottomAnchor.constraint(equalTo: paidContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs),
            paidIcon.topAnchor.constraint(equalTo: paidContainer.topAnchor, constant: DivoDesignTokens.Spacing.xs),
            
            paidLabel.leadingAnchor.constraint(equalTo: paidIcon.trailingAnchor),
            paidLabel.trailingAnchor.constraint(equalTo: paidContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            paidLabel.bottomAnchor.constraint(equalTo: paidContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs),
            paidLabel.topAnchor.constraint(equalTo: paidContainer.topAnchor, constant: DivoDesignTokens.Spacing.xs),

            profileImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            profileImageView.widthAnchor.constraint(equalToConstant: 20),
            profileImageView.heightAnchor.constraint(equalToConstant: 20),
            profileImageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor),

            profileNameLabel.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor),
            profileNameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 6),
            profileNameLabel.trailingAnchor.constraint(equalTo: profileCheckImageView.leadingAnchor, constant: -4),
            profileNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -10),
            
            profileCheckImageView.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor),
            profileCheckImageView.widthAnchor.constraint(equalToConstant: 12),
            profileCheckImageView.heightAnchor.constraint(equalToConstant: 12),
            profileCheckImageView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -10),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            dateLocationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            dateLocationLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            dateLocationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            dateLocationLabel.bottomAnchor.constraint(equalTo: availableSeatsContainer.topAnchor, constant: -10),

            timeRemainingContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            timeRemainingContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            timeRemainingContainer.heightAnchor.constraint(equalToConstant: 22),
            timeRemainingContainer.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -10),
            
            timeRemainingLabel.leadingAnchor.constraint(equalTo: timeRemainingContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            timeRemainingLabel.trailingAnchor.constraint(equalTo: timeRemainingContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            timeRemainingLabel.bottomAnchor.constraint(equalTo: timeRemainingContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs),
            timeRemainingLabel.topAnchor.constraint(equalTo: timeRemainingContainer.topAnchor, constant: DivoDesignTokens.Spacing.xs),
            
            availableSeatsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            availableSeatsContainer.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -10),
            availableSeatsBottomConstraint,

            availableSeatsLabel.leadingAnchor.constraint(equalTo: availableSeatsContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            availableSeatsLabel.trailingAnchor.constraint(equalTo: availableSeatsContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            availableSeatsLabel.bottomAnchor.constraint(equalTo: availableSeatsContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs),
            availableSeatsLabel.topAnchor.constraint(equalTo: availableSeatsContainer.topAnchor, constant: DivoDesignTokens.Spacing.xs),
            
            applyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            applyButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            applyButton.heightAnchor.constraint(equalToConstant: 24),
            
            blurredHeaderImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blurredHeaderImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            blurredHeaderImageView.topAnchor.constraint(equalTo: eventTypeContainer.topAnchor, constant: -20),
            blurredHeaderImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        contentView.layoutIfNeeded()
        
        let blurBounds = blurredHeaderImageView.bounds
        if blurBounds.height > 0 {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            blurMaskLayer.frame = blurBounds
            
            let fadeDistance: CGFloat = 60.0
            let fadeLocation = min(1.0, fadeDistance / blurBounds.height)
            
            blurMaskLayer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor]
            blurMaskLayer.locations = [0.0, NSNumber(value: Double(fadeLocation))]
            
            CATransaction.commit()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.cancelImageLoad()
        imageView.image = nil
        profileImageView.cancelImageLoad()
        profileImageView.image = nil
    }

    func configure(with event: EventData, context: AccountContext) {
        applyButton.setTitle(DivoStrings.apply, for: .normal)
        profileNameLabel.text = event.profileName
        titleLabel.text = event.title
        
        if let deadlineStr = event.timeRemaining {
            timeRemainingLabel.text = deadlineStr
            timeRemainingContainer.isHidden = false
        } else {
            timeRemainingContainer.isHidden = true
        }
        
        eventTypeLabel.text = event.type
        eventTypeContainer.backgroundColor = EventTypeStyle.color(for: event.typeId)
        
        paidContainer.isHidden = event.paymentTypeId == 2
        
        if let maxAttendees = event.maxAttendees, let appliesCount = event.appliesCount {
            availableSeatsContainer.isHidden = false
            availableSeatsLabel.text = DivoStrings.availableSeatsEvent(maxAttendees - appliesCount)
        } else {
            availableSeatsContainer.isHidden = true
        }

        if !event.location.isEmpty, let flag = event.countryFlag {
            dateLocationLabel.text = "\(event.eventDateFormatted) \u{00B7} \(flag) \(event.location)"
        } else {
            dateLocationLabel.text = event.eventDateFormatted
        }

        if let urlString = event.coverPhotoURL, let url = URL(string: urlString) {
            imageView.loadImage(from: url)
        } else if let image = event.coverPhoto {
            guard let representation = largestImageRepresentation(image.representations) else {
                return
            }
            let resourceData = context.account.postbox.mediaBox.resourceData(representation.resource)
            let _ = (resourceData
                     |> deliverOnMainQueue).start(next: { data in
                if data.complete {
                    if let uiImage = UIImage(contentsOfFile: data.path) {
                        UIView.transition(with: self.imageView,
                                          duration: 0.3,
                                          options: .transitionCrossDissolve,
                                          animations: {
                            self.imageView.image = uiImage
                        }, completion: nil)
                    }
                } else {
                    let _ = context.account.postbox.mediaBox.fetchedResource(representation.resource, parameters: nil).start()
                }
            })
        }
        
        if let urlString = event.profilePhotoURL, let url = URL(string: urlString) {
            profileImageView.loadImage(from: url)
        } else if let image = event.profilePhoto {
            guard let representation = largestImageRepresentation(image.representations) else {
                return
            }
            let resourceData = context.account.postbox.mediaBox.resourceData(representation.resource)
            let _ = (resourceData
                     |> deliverOnMainQueue).start(next: { data in
                if data.complete {
                    if let uiImage = UIImage(contentsOfFile: data.path) {
                        UIView.transition(with: self.profileImageView,
                                          duration: 0.3,
                                          options: .transitionCrossDissolve,
                                          animations: {
                            self.profileImageView.image = uiImage
                        }, completion: nil)
                    }
                } else {
                    let _ = context.account.postbox.mediaBox.fetchedResource(representation.resource, parameters: nil).start()
                }
            })
        }
        
        applyButton.isHidden = event.isCurrentRoleAgency ?? false
        availableSeatsBottomConstraint.constant = event.isCurrentRoleAgency == true ? -12 : -50
        self.layoutIfNeeded()
        self.setNeedsLayout()
    }
}

class ImageGalleryCell: UICollectionViewCell {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        contentView.addSubview(imageView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    func configure(with image: UIImage?) {
        imageView.image = image
    }
}

class GradientView: UIView {

    enum GradientDirection {
        case vertical
        case horizontal
    }

    private var gradientLayer: CAGradientLayer {
        return self.layer as! CAGradientLayer
    }

    override static var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    func configure(colors: [UIColor], direction: GradientDirection) {
        gradientLayer.colors = colors.map { $0.cgColor }
        switch direction {
        case .vertical:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        case .horizontal:
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        }
    }
}

final class ButtonWithIconNode: ASControlNode {
    private let textNode: ASTextNode
    private let iconNode: ASImageNode
    private let spacing: CGFloat
    private let imageSize: CGSize

    init(title: String, icon: UIImage?, theme: PresentationTheme, spacing: CGFloat, imageSize: CGSize) {
        self.spacing = spacing
        self.imageSize = imageSize

        self.textNode = ASTextNode()
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.helveticaNeue(16), textColor: .white)

        self.iconNode = ASImageNode()
        self.iconNode.image = icon
        self.iconNode.contentMode = .scaleAspectFit

        super.init()

        self.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.cornerRadius = 6

        if icon != nil {
            self.addSubnode(self.iconNode)
        }
        self.addSubnode(self.textNode)
    }

    override func layout() {
        super.layout()

        let textSize = self.textNode.measure(self.bounds.size)

        if self.iconNode.image != nil {
            let contentWidth = self.imageSize.width + self.spacing + textSize.width
            let contentOriginX = (self.bounds.width - contentWidth) / 2.0

            self.iconNode.frame = CGRect(x: contentOriginX,
                                         y: (self.bounds.height - self.imageSize.height) / 2.0,
                                         width: self.imageSize.width,
                                         height: self.imageSize.height)

            self.textNode.frame = CGRect(x: contentOriginX + self.imageSize.width + self.spacing,
                                         y: (self.bounds.height - textSize.height) / 2.0,
                                         width: textSize.width,
                                         height: textSize.height)
        } else {
            self.textNode.frame = CGRect(x: (self.bounds.width - textSize.width) / 2.0,
                                         y: (self.bounds.height - textSize.height) / 2.0,
                                         width: textSize.width,
                                         height: textSize.height)
        }
    }

    func setTitle(_ title: String) {
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.helveticaNeue(16), textColor: .white)
        self.setNeedsLayout()
    }
}
