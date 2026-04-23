import UIKit
import DivoCore
import DivoUIKit
import Display

final class AgencySearchCell: UITableViewCell {

    static let reuseIdentifier = "AgencySearchCell"
    private static let avatarSize: CGFloat = 48

    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = AgencySearchCell.avatarSize / 2
        iv.layer.borderWidth = 1
        iv.layer.borderColor = DivoColorPalette.borderWorkHistoryImage.cgColor
        iv.backgroundColor = DivoColorPalette.cardBackground
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let logoEmptyImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.image = DivoImage.emptyImageWork
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.semibold(16)
        label.textColor = DivoColorPalette.primaryText
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let usernameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let checkmarkImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "checkmark")?.withRenderingMode(.alwaysTemplate)
        iv.tintColor = DivoColorPalette.accent
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()

    private var titleTopConstraint: NSLayoutConstraint!
    private var titleCenterYConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(logoImageView)
        contentView.addSubview(logoEmptyImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(checkmarkImageView)

        titleTopConstraint = titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12)
        titleCenterYConstraint = titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)

        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            logoImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: AgencySearchCell.avatarSize),
            logoImageView.heightAnchor.constraint(equalToConstant: AgencySearchCell.avatarSize),

            logoEmptyImageView.centerXAnchor.constraint(equalTo: logoImageView.centerXAnchor),
            logoEmptyImageView.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
            logoEmptyImageView.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            logoEmptyImageView.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),

            titleLabel.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -DivoDesignTokens.Spacing.s),

            usernameLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            usernameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            usernameLabel.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -DivoDesignTokens.Spacing.s),

            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: AgencyItem, query: String, isSelected: Bool) {
        let hasUsername = item.username != nil && !item.username!.isEmpty
        let displayUsername = hasUsername ? "@\(item.username!)" : nil

        usernameLabel.text = displayUsername
        usernameLabel.isHidden = !hasUsername
        titleTopConstraint.isActive = hasUsername
        titleCenterYConstraint.isActive = !hasUsername

        checkmarkImageView.isHidden = !isSelected

        logoImageView.image = nil
        logoEmptyImageView.isHidden = false

        if let urlString = item.photo?.fullUrl, let url = URL(string: urlString) {
            logoImageView.loadImage(from: url) { [weak self] _ in
                self?.logoEmptyImageView.isHidden = true
            }
        }

        let attributedTitle = NSMutableAttributedString(
            string: item.title,
            attributes: [
                .font: Font.semibold(16),
                .foregroundColor: DivoColorPalette.primaryText
            ]
        )
        if !query.isEmpty {
            let range = (item.title.lowercased() as NSString).range(of: query.lowercased())
            if range.location != NSNotFound {
                attributedTitle.addAttribute(.foregroundColor, value: DivoColorPalette.accent, range: range)
            }
        }
        titleLabel.attributedText = attributedTitle

        if hasUsername {
            let attributedUsername = NSMutableAttributedString(
                string: displayUsername!,
                attributes: [
                    .font: Font.regular(14),
                    .foregroundColor: DivoColorPalette.secondaryText
                ]
            )
            if !query.isEmpty {
                let range = (displayUsername!.lowercased() as NSString).range(of: query.lowercased())
                if range.location != NSNotFound {
                    attributedUsername.addAttribute(.foregroundColor, value: DivoColorPalette.accent, range: range)
                }
            }
            usernameLabel.attributedText = attributedUsername
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let duration = highlighted ? DivoDesignTokens.PressState.pressDuration : DivoDesignTokens.PressState.releaseDuration
        UIView.animate(withDuration: duration) {
            self.contentView.alpha = highlighted ? DivoDesignTokens.PressState.alpha : 1.0
            let scale = DivoDesignTokens.PressState.scaleListRow
            self.contentView.transform = highlighted
                ? CGAffineTransform(scaleX: scale, y: scale)
                : .identity
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        logoImageView.image = nil
        logoEmptyImageView.isHidden = false
        titleLabel.attributedText = nil
        usernameLabel.attributedText = nil
        checkmarkImageView.isHidden = true
    }
}
