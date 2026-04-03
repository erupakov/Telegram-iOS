import Foundation
import UIKit
import Display

final class EventGalleryItem: Equatable {
    let id = UUID().uuidString
    let image: UIImage
    var isUploading: Bool
    var fileUuid: String?
    
    init(image: UIImage, isUploading: Bool = true, fileUuid: String? = nil) {
        self.image = image
        self.isUploading = isUploading
        self.fileUuid = fileUuid
    }
    
    static func == (lhs: EventGalleryItem, rhs: EventGalleryItem) -> Bool {
        return lhs.id == rhs.id
    }
}

final class EventGalleryCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let deleteButton = UIButton(type: .custom)
    private let spinner = UIActivityIndicatorView(style: .medium)
    
    var onDelete: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        let basketButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Profile/Basket"), color: UIColor(hexString: "#BF7A54") ?? .white)
        deleteButton.setImage(basketButtonImg, for: .normal)
        deleteButton.backgroundColor = .white
        deleteButton.layer.cornerRadius = 14
        deleteButton.clipsToBounds = true
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        
        spinner.color = .white
        spinner.hidesWhenStopped = true
        
        contentView.addSubview(imageView)
        contentView.addSubview(deleteButton)
        contentView.addSubview(spinner)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(with item: EventGalleryItem) {
        imageView.image = item.image
        
        if item.isUploading {
            spinner.startAnimating()
            imageView.alpha = 0.5
            deleteButton.isHidden = true
        } else {
            spinner.stopAnimating()
            imageView.alpha = 1.0
            deleteButton.isHidden = false
        }
    }
    
    @objc private func deleteTapped() {
        onDelete?()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = contentView.bounds
        
        let btnSize: CGFloat = 28.0
        deleteButton.frame = CGRect(x: contentView.bounds.width - btnSize - 6, y: 6, width: btnSize, height: btnSize)
        spinner.center = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
    }
}