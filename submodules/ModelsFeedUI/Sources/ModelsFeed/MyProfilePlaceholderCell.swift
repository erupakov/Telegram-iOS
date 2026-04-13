import UIKit
import TelegramCore
import DivoCore
import DivoUIKit

final class MyProfilePlaceholderCell: UICollectionViewCell {

    private let label: UILabel = {
        let l = UILabel()
        l.text = DivoStrings.goToMyProfile
        l.textColor = DivoColorPalette.emptyTitleText
        l.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        l.textAlignment = .left
        return l
    }()

    private let arrowLabel: UILabel = {
        let l = UILabel()
        l.text = "→"
        l.textColor = DivoColorPalette.emptySubtitleText
        l.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DivoColorPalette.placeholderCardBackground
        layer.cornerRadius = 14
        clipsToBounds = true

        contentView.addSubview(label)
        contentView.addSubview(arrowLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let arrowSize = CGSize(width: 30, height: 30)
        let arrowX = contentView.bounds.width - arrowSize.width - 24
        let centerY = contentView.bounds.midY - arrowSize.height / 2
        arrowLabel.frame = CGRect(x: arrowX, y: centerY, width: arrowSize.width, height: arrowSize.height)

        let labelWidth = arrowX - 24
        label.frame = CGRect(x: 24, y: 0, width: labelWidth, height: contentView.bounds.height)
    }
}
