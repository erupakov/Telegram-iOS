//
//  ProfileHeaderView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.02.2026.
//

import UIKit
import Display
import TelegramCore

struct UserProfileViewModel {
    enum Job {
        case model
        case agency
        case talent
    }
    
    let name: String
    let age: Int?
    let location: String
    let countryFlag: String
    let role: Role
    let avatarImage: UIImage?
    let isPremium: Bool
    let isOnline: Bool
    
    init(
        name: String,
        age: Int?,
        location: String,
        countryFlag: String,
        role: Role,
        avatarImage: UIImage?,
        isPremium: Bool,
        isOnline: Bool
    ) {
        self.name = name
        self.age = age
        self.location = location
        self.countryFlag = countryFlag
        self.role = role
        self.avatarImage = avatarImage
        self.isPremium = isPremium
        self.isOnline = isOnline
    }
}


class ProfileHeaderView: UIView {
    
    private let ringView: AvatarStrokeView = {
        let view = AvatarStrokeView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.image = UIImage(systemName: "person.crop.circle.fill")
        iv.tintColor = .lightGray
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    /// В обычном `.scaleAspectFill` кроп центрируется. Для портретных фото это часто «съедает» верх (голову).
    /// Поэтому для аватарки мы делаем квадратный кроп с приоритетом верхней части.
    private func applyAvatarContentsRect(for image: UIImage?) {
        // Держим реализацию в одном месте, чтобы поведение совпадало со списками.
        avatarImageView.applyAvatarTopCropIfNeeded(image: image)
    }
    
    private let avatarSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    private let onlineStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.borderColor = UIColor(hex: "E2E2E2").cgColor
        view.layer.borderWidth = 3
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(34)
        label.textColor = .white
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let crownIconView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(bundleImageName: "Profile/CrownPremium")
        iv.tintColor = .white
        iv.contentMode = .center
        iv.backgroundColor = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 0.8)
        iv.layer.borderWidth = 1
        iv.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let tagContainer: GradientTagView = {
        let view = GradientTagView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let tagIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "diamond.fill")
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let tagLabel: PaddedLabel = { 
        let label = PaddedLabel()
        label.textInsets = UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0) 
        label.font = Font.helveticaNeue(10)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(14)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        return label
    }()
    
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let avatarSize: CGFloat = 80
        avatarImageView.layer.cornerRadius = avatarSize / 2
        
        onlineStatusView.layer.cornerRadius = 8
        crownIconView.layer.cornerRadius = 12
        tagContainer.layer.cornerRadius = 12
    }
    
    private func setupViews() {
        addSubview(ringView)
        addSubview(avatarImageView)
        addSubview(avatarSpinner)
        addSubview(onlineStatusView)
        
        addSubview(nameLabel)
        addSubview(crownIconView)
        
        addSubview(tagContainer)
        tagContainer.addSubview(tagIcon)
        tagContainer.addSubview(tagLabel)
        
        addSubview(infoLabel)
    }
    
    private func setupConstraints() {
        let avatarSize: CGFloat = 80
        
        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: avatarSize),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            
            ringView.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            ringView.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            ringView.widthAnchor.constraint(equalToConstant: avatarSize + 10),
            ringView.heightAnchor.constraint(equalToConstant: avatarSize + 10),
            
            onlineStatusView.trailingAnchor.constraint(equalTo: ringView.trailingAnchor, constant: -8),
            onlineStatusView.bottomAnchor.constraint(equalTo: ringView.bottomAnchor, constant: -5),
            onlineStatusView.widthAnchor.constraint(equalToConstant: 16),
            onlineStatusView.heightAnchor.constraint(equalToConstant: 16),
            
            nameLabel.leadingAnchor.constraint(equalTo: ringView.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: crownIconView.leadingAnchor, constant: -8),
            nameLabel.bottomAnchor.constraint(equalTo: tagContainer.topAnchor, constant: -8),

            crownIconView.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            crownIconView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            crownIconView.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            crownIconView.widthAnchor.constraint(equalToConstant: 24),
            crownIconView.heightAnchor.constraint(equalToConstant: 24),
            
            tagContainer.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            tagContainer.heightAnchor.constraint(equalToConstant: 24),
            tagContainer.centerYAnchor.constraint(equalTo: infoLabel.centerYAnchor),
            
            tagIcon.leadingAnchor.constraint(equalTo: tagContainer.leadingAnchor, constant: 4),
            tagIcon.centerYAnchor.constraint(equalTo: tagContainer.centerYAnchor),
            tagIcon.widthAnchor.constraint(equalToConstant: 16),
            tagIcon.heightAnchor.constraint(equalToConstant: 16),
            
            tagLabel.leadingAnchor.constraint(equalTo: tagIcon.trailingAnchor, constant: 3),
            tagLabel.trailingAnchor.constraint(equalTo: tagContainer.trailingAnchor, constant: -6),
            tagLabel.centerYAnchor.constraint(equalTo: tagContainer.centerYAnchor, constant: 1),
            
            tagContainer.topAnchor.constraint(equalTo: crownIconView.bottomAnchor, constant: 10),
            infoLabel.leadingAnchor.constraint(equalTo: tagContainer.trailingAnchor, constant: 10),
            infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
    }
    
    func configure(with viewModel: UserProfileViewModel) {
        let text = viewModel.name.uppercased()
        let paragraphStyle = NSMutableParagraphStyle()
        let lineHeight = Font.helveticaNeue(34).lineHeight * 0.95
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Font.helveticaNeue(34),
            .foregroundColor: UIColor.white,
            .kern: 0.5,
            .paragraphStyle: paragraphStyle,
            .baselineOffset: -2.0
        ]
        nameLabel.attributedText = NSAttributedString(string: text, attributes: attributes)
        tagLabel.text = viewModel.role.title
        switch viewModel.role {
        case .model:
            tagIcon.image = UIImage(bundleImageName: "Profile/Role/Model")
            tagContainer.apply(style: .bronzeGradient)
            tagIcon.tintColor = .white
            tagLabel.textColor = .white
        case .agency:
            tagIcon.image = UIImage(bundleImageName: "Profile/Role/Agency")
            tagContainer.apply(style: .plainWhite)
            tagIcon.tintColor = .black
            tagLabel.textColor = .black
        case .newFace:
            tagIcon.image = UIImage(bundleImageName: "Profile/Role/NewTalent")
            tagContainer.apply(style: .plainWhite)
            tagIcon.tintColor = .black
            tagLabel.textColor = .black
        }
        
        var fullLocationString: String
        if let age = viewModel.age  {
            fullLocationString = "\(DivoStrings.ageString(age)) • \(viewModel.countryFlag) \(viewModel.location)"
        } else {
            fullLocationString = "\(viewModel.countryFlag) \(viewModel.location)"
        }
        infoLabel.text = fullLocationString
        
        onlineStatusView.isHidden = !viewModel.isOnline
        crownIconView.isHidden = !viewModel.isPremium
        
        // Важно: в текущей архитектуре аватар может приезжать отдельно через `changeAvatar(with:)`.
        // В `configure` часто передают `avatarImage: nil`, и если здесь сбрасывать contentsRect,
        // то после повторного открытия экрана можно снова получить «центральный» кроп и обрезание головы.
        // Поэтому:
        // - если image есть -> выставляем и применяем кроп
        // - если image нет -> НЕ трогаем contentsRect (оставляем то, что было выставлено в changeAvatar)
        if let image = viewModel.avatarImage {
            applyAvatarContentsRect(for: image)
            avatarImageView.image = image
        }
    }
    
    func changeAvatar(with image: UIImage?) {
        if let image = image {
            avatarImageView.image = image
            applyAvatarContentsRect(for: image)
        } else {
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
            applyAvatarContentsRect(for: nil)
        }
    }
    
    func toggleSpinner(active: Bool) {
        if active {
            avatarSpinner.startAnimating()
            avatarImageView.alpha = 0.5
        } else {
            avatarSpinner.stopAnimating()
            avatarImageView.alpha = 1.0
        }
    }
}
