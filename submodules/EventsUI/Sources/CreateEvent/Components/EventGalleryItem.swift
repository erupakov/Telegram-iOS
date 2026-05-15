import Foundation
import UIKit
import Display
import DivoUIKit

final class EventGalleryItem: Equatable {
    let id = UUID().uuidString
    var image: UIImage?
    var isUploading: Bool
    var fileUuid: String?
    
    init(image: UIImage? = nil, isUploading: Bool = true, fileUuid: String? = nil) {
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
    private let spinner = UIActivityIndicatorView(style: .medium)
    
    var onDelete: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        spinner.color = .white
        spinner.hidesWhenStopped = true
        
        contentView.addSubview(imageView)
        contentView.addSubview(spinner)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(with item: EventGalleryItem) {
        imageView.image = item.image
        
        if item.isUploading {
            spinner.startAnimating()
            imageView.alpha = 0.5
        } else {
            spinner.stopAnimating()
            imageView.alpha = 1.0
        }
    }
    
    @objc private func deleteTapped() {
        onDelete?()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = contentView.bounds
        
        spinner.center = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
    }
}
