import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import DivoCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle

final class EventCollectionViewCell: UICollectionViewCell {

    static let reuseIdentifier = "EventCollectionViewCell"

    private let imageView = UIImageView()
    private let overlayView = GradientView()
    private let profileImageView = UIImageView()
    private let profileNameLabel = UILabel()
    private let titleLabel = UILabel()
    private let dateLocationLabel = UILabel()
    private let timeRemainingContainer = UIView()
    private let timeRemainingLabel = UILabel()
    private let applyButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        overlayView.configure(
            colors: [
                UIColor(white: 0.0, alpha: 0.0),
                UIColor(white: 0.0, alpha: 0.15),
                UIColor(white: 0.0, alpha: 0.7)
            ],
            direction: .vertical
        )
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(overlayView)

        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 14
        profileImageView.backgroundColor = UIColor(white: 0.8, alpha: 1.0)
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(profileImageView)

        profileNameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        profileNameLabel.textColor = .white
        profileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(profileNameLabel)

        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .heavy)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 3
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        dateLocationLabel.font = .systemFont(ofSize: 9, weight: .regular)
        dateLocationLabel.textColor = UIColor(white: 0.85, alpha: 1.0)
        dateLocationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dateLocationLabel)

        timeRemainingContainer.backgroundColor = UIColor(white: 1.0, alpha: 0.25)
        timeRemainingContainer.layer.cornerRadius = 10
        timeRemainingContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeRemainingContainer)

        timeRemainingLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        timeRemainingLabel.textColor = .white
        timeRemainingLabel.textAlignment = .center
        timeRemainingLabel.translatesAutoresizingMaskIntoConstraints = false
        timeRemainingContainer.addSubview(timeRemainingLabel)

        applyButton.setTitle(DivoStrings.apply, for: .normal)
        applyButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        applyButton.layer.cornerRadius = 10
        applyButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(applyButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            profileImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            profileImageView.widthAnchor.constraint(equalToConstant: 28),
            profileImageView.heightAnchor.constraint(equalToConstant: 28),

            profileNameLabel.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor),
            profileNameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 5),
            profileNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            profileImageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -6),

            dateLocationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            dateLocationLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            dateLocationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            timeRemainingContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            timeRemainingContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            timeRemainingContainer.heightAnchor.constraint(equalToConstant: 20),

            timeRemainingLabel.topAnchor.constraint(equalTo: timeRemainingContainer.topAnchor),
            timeRemainingLabel.leadingAnchor.constraint(equalTo: timeRemainingContainer.leadingAnchor, constant: 8),
            timeRemainingLabel.trailingAnchor.constraint(equalTo: timeRemainingContainer.trailingAnchor, constant: -8),
            timeRemainingLabel.bottomAnchor.constraint(equalTo: timeRemainingContainer.bottomAnchor),

            applyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            applyButton.heightAnchor.constraint(equalToConstant: 20),

            dateLocationLabel.bottomAnchor.constraint(equalTo: timeRemainingContainer.topAnchor, constant: -6),
        ])
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
        timeRemainingLabel.text = event.timeRemaining
        timeRemainingContainer.isHidden = event.timeRemaining.isEmpty

        let flag = "\u{1F1FA}\u{1F1F8}"
        if !event.location.isEmpty {
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

    func configure(with imageName: String) {
        imageView.image = UIImage(bundleImageName: imageName)
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
