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

final class EventPreviousCollectionViewCell: UICollectionViewCell {
    
    static let reuseIdentifier = "EventPreviousCollectionViewCell"
    
    private let imageView = UIImageView()
    private let overlayView = GradientView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let tagContainer = UIView()
    private let tagLabel = UILabel()
    private let likesButton = UIButton(type: .system)
    private let likesLabel = UILabel()
    private let optionsButton = UIButton(type: .system)

    private let applyButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
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
        
        
        tagContainer.backgroundColor = .white
        tagContainer.layer.cornerRadius = 10.0
        tagContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tagContainer)
        
        tagLabel.font = Font.helveticaNeue(10)
        tagLabel.textColor = .black
        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        tagContainer.addSubview(tagLabel)
        
        
        likesButton.setImage(UIImage(bundleImageName: "Contact List/HeartActionIcon"), for: .normal)
        likesButton.tintColor = .white
        likesButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(likesButton)
        
        likesLabel.font = .systemFont(ofSize: 14, weight: .bold)
        likesLabel.textColor = .white
        likesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(likesLabel)
        
        optionsButton.setImage(UIImage(bundleImageName: "Contact List/moreIcon"), for: .normal)
        optionsButton.tintColor = .white
        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(optionsButton)
        
        titleLabel.font = Font.helveticaNeue(20)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        subtitleLabel.font = .systemFont(ofSize: 10, weight: .regular)
        subtitleLabel.textColor = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.00)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
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
            
            tagContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            tagContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            tagContainer.heightAnchor.constraint(equalToConstant: 20),
            
            tagLabel.centerYAnchor.constraint(equalTo: tagContainer.centerYAnchor, constant: 1),
            tagLabel.leadingAnchor.constraint(equalTo: tagContainer.leadingAnchor, constant: 10),
            tagLabel.trailingAnchor.constraint(equalTo: tagContainer.trailingAnchor, constant: -10),
            
            optionsButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            optionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            optionsButton.widthAnchor.constraint(equalToConstant: 20),
            optionsButton.heightAnchor.constraint(equalToConstant: 20),
            
            likesLabel.centerYAnchor.constraint(equalTo: optionsButton.centerYAnchor),
            likesLabel.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -5),
            
            likesButton.centerYAnchor.constraint(equalTo: optionsButton.centerYAnchor),
            likesButton.trailingAnchor.constraint(equalTo: likesLabel.leadingAnchor, constant: -5),
            likesButton.widthAnchor.constraint(equalToConstant: 20),
            likesButton.heightAnchor.constraint(equalToConstant: 20),
            
            applyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            applyButton.heightAnchor.constraint(equalToConstant: 30),
            applyButton.widthAnchor.constraint(equalToConstant: 40),
            
            subtitleLabel.topAnchor.constraint(equalTo: applyButton.topAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            subtitleLabel.widthAnchor.constraint(equalToConstant: 100),
            
            titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -5),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.widthAnchor.constraint(equalToConstant: 150),
            
        ])
    }
    
    func configure(with event: EventData) {
        imageView.image = UIImage(named: event.imageName)
        titleLabel.text = event.title.uppercased()
        subtitleLabel.text = event.subtitle
        tagLabel.text = event.type
        likesLabel.text = "1K"
    }
}
