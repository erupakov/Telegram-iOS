import UIKit

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
        label.font = UIFont.systemFont(ofSize: 12)
        return label
    }()
    
    private let statusIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 4
        view.layer.borderColor = UIColor.black.cgColor
        view.layer.borderWidth = 1.5
        view.isHidden = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(statusIndicator)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let avatarSize: CGFloat = 60
        avatarImageView.frame = CGRect(x: (contentView.bounds.width - avatarSize) / 2,
                                       y: 0,
                                       width: avatarSize,
                                       height: avatarSize)
        avatarImageView.layer.cornerRadius = avatarSize / 2
        
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
    
    func configure(with model: StoryModel) {
        if let image = UIImage(named: model.avatarName) {
            if let isAdd = model.isAdd, isAdd {
                avatarImageView.image = image.resized(to: CGSize(width: 30, height: 30))
                avatarImageView.contentMode = .center
            } else {
                avatarImageView.image = image
            }
        } else {
            avatarImageView.backgroundColor = UIColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 1.00)
        }
        
        avatarImageView.backgroundColor = UIColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 1.00)
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
