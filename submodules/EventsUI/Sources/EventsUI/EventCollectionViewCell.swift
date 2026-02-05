import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
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
    private let subtitleLabel = UILabel()
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
//        self.layer.cornerRadius = 12.0
        self.layer.masksToBounds = true
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        overlayView.configure(
            colors: [
                UIColor(white: 0.0, alpha: 0.2),
                UIColor.black
            ],
            direction: .vertical
        )
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(overlayView)
        
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 15.0
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(profileImageView)
        
        profileNameLabel.font = .systemFont(ofSize: 15, weight: .regular)
        profileNameLabel.textColor = .white
        profileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(profileNameLabel)
        
        titleLabel.font = Font.helveticaNeue(16)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        subtitleLabel.font = .systemFont(ofSize: 10, weight: .regular)
        subtitleLabel.textColor = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.00)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        timeRemainingContainer.backgroundColor = .white.withAlphaComponent(0.3)
        timeRemainingContainer.layer.cornerRadius = 15.0
        timeRemainingContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeRemainingContainer)
        
        timeRemainingLabel.font = .systemFont(ofSize: 12, weight: .bold)
        timeRemainingLabel.textColor = .white
        timeRemainingLabel.textAlignment = .center
        timeRemainingLabel.translatesAutoresizingMaskIntoConstraints = false
        timeRemainingContainer.addSubview(timeRemainingLabel)
        
        applyButton.setTitle("Apply", for: .normal)
        applyButton.titleLabel?.font = Font.helveticaNeue(11)
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        applyButton.layer.cornerRadius = 6
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
            
            applyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            applyButton.heightAnchor.constraint(equalToConstant: 30),
            applyButton.widthAnchor.constraint(equalToConstant: 40),
            
            subtitleLabel.bottomAnchor.constraint(equalTo: applyButton.topAnchor, constant: -10),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            
            titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -5),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            
            profileImageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -10),
            profileImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            profileImageView.widthAnchor.constraint(equalToConstant: 30),
            profileImageView.heightAnchor.constraint(equalToConstant: 30),
            
            profileNameLabel.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor),
            profileNameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 5),
            
            timeRemainingContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            timeRemainingContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            timeRemainingContainer.heightAnchor.constraint(equalToConstant: 30),
            
            timeRemainingLabel.topAnchor.constraint(equalTo: timeRemainingContainer.topAnchor),
            timeRemainingLabel.leadingAnchor.constraint(equalTo: timeRemainingContainer.leadingAnchor, constant: 10),
            timeRemainingLabel.trailingAnchor.constraint(equalTo: timeRemainingContainer.trailingAnchor, constant: -10),
            timeRemainingLabel.bottomAnchor.constraint(equalTo: timeRemainingContainer.bottomAnchor),
        ])
    }
    
    func configure(with event: EventData, context: AccountContext) {
        profileImageView.image = UIImage(named: event.profileImageName)
        profileNameLabel.text = event.profileName
        titleLabel.text = event.title
        subtitleLabel.text = event.subtitle
        timeRemainingLabel.text = event.timeRemaining
        
        if let image = event.coverPhotoId {
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
        } else {
            imageView.image = UIImage(named: event.imageName)
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
        //        self.layer.borderColor = UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.14).cgColor
        //        self.layer.borderWidth = 1
        
        if icon != nil {
            self.addSubnode(self.iconNode)
        }
        self.addSubnode(self.textNode)
    }
    
    override func layout() {
        super.layout()
        
        let textSize = self.textNode.measure(self.bounds.size)
        
        if self.iconNode.image != nil {
            // Layout with icon
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
            // Layout without icon (center the text)
            self.textNode.frame = CGRect(x: (self.bounds.width - textSize.width) / 2.0,
                                         y: (self.bounds.height - textSize.height) / 2.0,
                                         width: textSize.width,
                                         height: textSize.height)
        }
    }
}
