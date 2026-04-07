import Foundation
import UIKit
import Display
import TelegramCore
import DivoCore
import AppBundle

struct WorkExperienceItem {
    let id: Int
    let companyName: String
    let period: String
    let logoURL: URL?
}

protocol ExperienceCellDelegate: AnyObject {
    func experienceCell(_ cell: ExperienceCell, didTapOptionsButton button: UIButton)
}

final class ExperienceCell: UICollectionViewCell {

    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let optionsButton = UIButton(type: .custom)

    private let logoShimmer: ShimmerView = {
        let v = ShimmerView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 28
        v.clipsToBounds = true
        v.isHidden = true
        return v
    }()

    private let titleShimmer: ShimmerView = {
        let v = ShimmerView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 4
        v.clipsToBounds = true
        v.isHidden = true
        return v
    }()

    private let dateShimmer: ShimmerView = {
        let v = ShimmerView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 4
        v.clipsToBounds = true
        v.isHidden = true
        return v
    }()

    weak var delegate: ExperienceCellDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.cancelImageLoad()
        iconImageView.image = nil
        logoShimmer.stopShimmer()
        titleShimmer.stopShimmer()
        dateShimmer.stopShimmer()
        logoShimmer.isHidden = true
        titleShimmer.isHidden = true
        dateShimmer.isHidden = true
        iconImageView.isHidden = false
        titleLabel.isHidden = false
        dateLabel.isHidden = false
        optionsButton.isHidden = false
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
        contentView.addSubview(logoShimmer)
        contentView.addSubview(titleShimmer)
        contentView.addSubview(dateShimmer)

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
            optionsButton.heightAnchor.constraint(equalToConstant: 24),

            logoShimmer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            logoShimmer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            logoShimmer.widthAnchor.constraint(equalToConstant: 56),
            logoShimmer.heightAnchor.constraint(equalToConstant: 56),

            titleShimmer.leadingAnchor.constraint(equalTo: logoShimmer.trailingAnchor, constant: 12),
            titleShimmer.topAnchor.constraint(equalTo: logoShimmer.topAnchor, constant: 6),
            titleShimmer.widthAnchor.constraint(equalToConstant: 160),
            titleShimmer.heightAnchor.constraint(equalToConstant: 16),

            dateShimmer.leadingAnchor.constraint(equalTo: titleShimmer.leadingAnchor),
            dateShimmer.topAnchor.constraint(equalTo: titleShimmer.bottomAnchor, constant: 8),
            dateShimmer.widthAnchor.constraint(equalToConstant: 200),
            dateShimmer.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    func configure(with item: WorkExperienceItem, showOptions: Bool = true) {
        titleLabel.text = item.companyName
        dateLabel.text = item.period
        optionsButton.isHidden = !showOptions
        iconImageView.loadImage(from: item.logoURL, placeholder: UIImage(bundleImageName: "Models/DefWork"))
    }

    func configureAsShimmer() {
        iconImageView.isHidden = true
        titleLabel.isHidden = true
        dateLabel.isHidden = true
        optionsButton.isHidden = true

        logoShimmer.isHidden = false
        titleShimmer.isHidden = false
        dateShimmer.isHidden = false
        logoShimmer.startShimmer()
        titleShimmer.startShimmer()
        dateShimmer.startShimmer()
    }

    @objc private func handleOptionsTap(_ sender: UIButton) {
        delegate?.experienceCell(self, didTapOptionsButton: sender)
    }
}
