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

struct WorkExperienceItem {
    let id: Int
    let companyName: String
    let period: String
    let logoName: TelegramMediaImage?
}

protocol ExperienceCellDelegate: AnyObject {
    func experienceCell(_ cell: ExperienceCell, didTapOptionsButton button: UIButton)
}

final class ExperienceCell: UICollectionViewCell {
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let optionsButton = UIButton(type: .custom)
    
    weak var delegate: ExperienceCellDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    private func setupLayout() {
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 28
        iconImageView.clipsToBounds = true
        iconImageView.layer.borderWidth = 1
        iconImageView.layer.borderColor = UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.14).cgColor
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        titleLabel.textColor = .black
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        dateLabel.font = UIFont.systemFont(ofSize: 14)
        dateLabel.textColor = .gray
        dateLabel.numberOfLines = 2
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let moreImage = UIImage(bundleImageName: "Contact List/moreIcon")?.withRenderingMode(.alwaysTemplate)
        optionsButton.setImage(moreImage, for: .normal)
        optionsButton.tintColor = UIColor(rgb: 0x8E8E93)
        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        optionsButton.addTarget(self, action: #selector(handleOptionsTap(_:)), for: .touchUpInside)
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(optionsButton)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 56),
            iconImageView.heightAnchor.constraint(equalToConstant: 56),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 4),
            
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            dateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            optionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            optionsButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            optionsButton.widthAnchor.constraint(equalToConstant: 24),
            optionsButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func configure(with item: WorkExperienceItem, context: AccountContext) {
        titleLabel.text = item.companyName
        dateLabel.text = item.period
        if let logo = item.logoName {
            loadImage(logo, context)
        } else {
            iconImageView.image = UIImage(bundleImageName: "Models/DefWork")
        }
    }
    
    public func loadImage(_ image: TelegramMediaImage, _ context: AccountContext) {
        guard let representation = largestImageRepresentation(image.representations) else { return }
        let resourceData = context.account.postbox.mediaBox.resourceData(representation.resource)
        let _ = (resourceData |> deliverOnMainQueue).start(next: { data in
            if data.complete {
                if let uiImage = UIImage(contentsOfFile: data.path) {
                    UIView.transition(with: self.iconImageView,
                                      duration: 0.3,
                                      options: .transitionCrossDissolve,
                                      animations: {
                        
                        self.iconImageView.image = uiImage
                    }, completion: nil)
                }
            } else {
                let _ = context.account.postbox.mediaBox.fetchedResource(representation.resource, parameters: nil).start()
            }
        })
    }
    
    @objc private func handleOptionsTap(_ sender: UIButton) {
        delegate?.experienceCell(self, didTapOptionsButton: sender)
    }
}
