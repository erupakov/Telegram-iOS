//
//  CurrentAgencyView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

final class OrganizerView: UIView {
        
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.organizer
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 24
        iv.backgroundColor = DivoColorPalette.cardBackground
        iv.layer.borderWidth = 1
        iv.layer.borderColor = DivoColorPalette.borderWorkHistoryImage.cgColor
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = DivoImage.defWork
        return iv
    }()
    
    private let agencyNameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let periodLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let profileCheckImageView: UIImageView = {
        let profileCheckImageView = UIImageView()
        profileCheckImageView.contentMode = .scaleAspectFill
        profileCheckImageView.clipsToBounds = true
        profileCheckImageView.translatesAutoresizingMaskIntoConstraints = false
        profileCheckImageView.image = DivoImage.verified
        return profileCheckImageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(logoImageView)
        
        let nameStack = UIStackView(arrangedSubviews: [agencyNameLabel, profileCheckImageView, UIView()])
        nameStack.axis = .horizontal
        nameStack.spacing = DivoDesignTokens.Spacing.xs
        nameStack.translatesAutoresizingMaskIntoConstraints = false
        
        let textStack = UIStackView(arrangedSubviews: [nameStack, periodLabel])
        textStack.axis = .vertical
        textStack.spacing = DivoDesignTokens.Spacing.xs
        textStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(textStack)

        // periodLabel пока никем не заполняется — прячем, чтобы стек не резервировал
        // под него spacing и одиночное имя точно вставало по центру лого.
        // Когда появится поле «период», достаточно снять isHidden и подать текст.
        periodLabel.isHidden = true
        
        agencyNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            logoImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            logoImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            logoImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            logoImageView.widthAnchor.constraint(equalToConstant: 48),
            logoImageView.heightAnchor.constraint(equalToConstant: 48),
            
            textStack.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 10),
            // Центрируем стек текста относительно лого, а не всей карточки —
            // иначе из-за заголовка «ОРГАНИЗАТОР» сверху единственная строка имени
            // визуально смещается вверх и расходится с серединой логотипа.
            textStack.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            profileCheckImageView.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.m),
            profileCheckImageView.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.m),
        ])
    }
    
    func configure(name: String?, isVerified: Bool?, logoURLString: String?) {
        UIView.performWithoutAnimation {
            self.agencyNameLabel.text = name?.uppercased() ?? DivoStrings.unknownAgency
            self.agencyNameLabel.layer.removeAllAnimations()
            self.layoutIfNeeded()
        }
        
        profileCheckImageView.isHidden = isVerified != true

        let placeholder = DivoImage.emptyBackgroundAvatar
        if let photoURLString = logoURLString, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
            logoImageView.loadImage(from: photoURL, placeholder: placeholder, cropAvatarIfNeeded: true)
        } else {
            logoImageView.image = placeholder
        }
    }
}
