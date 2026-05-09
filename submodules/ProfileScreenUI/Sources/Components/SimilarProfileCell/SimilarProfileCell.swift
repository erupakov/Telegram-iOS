//
//  SimilarProfileCell.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 08.03.2026.
//

import UIKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit

final class SimilarProfileCell: UICollectionViewCell {
    static let reuseIdentifier = "SimilarProfileCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = DivoDesignTokens.Radius.m
        iv.backgroundColor = DivoColorPalette.imagePlaceholderMedium
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(10)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(10)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.layer.applyDivoShadow(opacity: DivoDesignTokens.Shadow.opacityMedium)

        contentView.backgroundColor = DivoColorPalette.cardBackground
        contentView.layer.cornerRadius = DivoDesignTokens.Radius.l
        contentView.clipsToBounds = true

        contentView.addSubview(imageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(infoLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 3),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -3),
            imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, constant: -43),

            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),

            infoLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            infoLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -DivoDesignTokens.Spacing.s)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.cancelImageLoad()
        imageView.image = nil
        imageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    func configure(with item: SimilarProfileItem) {
        nameLabel.text = item.name?.uppercased()
        let age = item.age.flatMap { calculateAge(from: $0) }
        let flag = Self.flag(for: item.countryCode)
        let city = item.countryName ?? ""
        let agePrefix = age.map { DivoStrings.ageString($0) + " • " } ?? ""
        infoLabel.text = "\(agePrefix)\(flag) \(city)"
        imageView.loadImage(from: item.avatarURL) { [weak self] image in
            self?.imageView.applyAvatarTopCropIfNeeded(image: image)
        }
    }

    private static func flag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }

    private func calculateAge(from birthdayString: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let birthday = formatter.date(from: birthdayString) else { return nil }

        let now = Date()
        let calendar = Calendar.current
        return calendar.dateComponents([.year], from: birthday, to: now).year
    }
}
