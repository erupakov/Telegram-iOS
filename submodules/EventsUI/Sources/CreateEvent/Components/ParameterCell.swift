import UIKit
import Display

final class ParameterCell: UITableViewCell {
    static let reuseId = "ParameterCell"
    
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let accentColor = UIColor(hexString: "#BF7A54") ?? .orange
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = .clear
        selectionStyle = .none
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        nameLabel.font = Font.medium(14)
        nameLabel.textColor = UIColor(hexString: "#17181C")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),
        
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(title: String, isSelected: Bool) {
        nameLabel.text = title
        
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let imageName = isSelected ? "checkmark.square.fill" : "square"
        iconImageView.image = UIImage(systemName: imageName, withConfiguration: config)
        iconImageView.tintColor = isSelected ? accentColor : .gray
    }
}
