import UIKit
import Display
import DivoUIKit
import DivoCore

final class ExperienceView: UIView {
    
    var onEditTapped: (() -> Void)?
    var onDeleteTapped: (() -> Void)?
    
    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 30
        iv.layer.borderWidth = 1
        iv.layer.borderColor = DivoColorPalette.borderWorkHistoryImage.cgColor
        iv.backgroundColor = DivoColorPalette.cardBackground
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let logoEmptyImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.image = DivoImage.emptyImageWork
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let avatarSpinner = DivoSegmentedSpinner()
    
    private let titleLabel: UILabel = {
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
    
    private let optionsButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(DivoImage.moreActionIconBlack, for: .normal)
        btn.tintColor = DivoColorPalette.primaryText
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private var optionsButtonWidthConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupMenu()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 80).isActive = true
        backgroundColor = .white
        
        avatarSpinner.translatesAutoresizingMaskIntoConstraints = false
        avatarSpinner.isHidden = true
        
        addSubview(logoImageView)
        addSubview(avatarSpinner)
        addSubview(logoEmptyImageView)
        
        let textStack = UIStackView(arrangedSubviews: [titleLabel, periodLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textStack)
        
        addSubview(optionsButton)
        
        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            logoImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 60),
            logoImageView.heightAnchor.constraint(equalToConstant: 60),
            
            logoEmptyImageView.centerXAnchor.constraint(equalTo: logoImageView.centerXAnchor),
            logoEmptyImageView.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
            logoEmptyImageView.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            logoEmptyImageView.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: logoImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
            avatarSpinner.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            avatarSpinner.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            textStack.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            textStack.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -DivoDesignTokens.Spacing.s),
            
            optionsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            optionsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            optionsButton.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.l),
            optionsButton.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.l)
        ])
        
        optionsButtonWidthConstraint = optionsButton.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.l)
    }
    
    func configure(with item: WorkExperienceItem, showOptions: Bool, loadImage: Bool = false) {
        logoImageView.layer.removeAllAnimations()
        titleLabel.layer.removeAllAnimations()
        periodLabel.layer.removeAllAnimations()
        
        titleLabel.text = item.companyName
        periodLabel.text = item.period
        optionsButton.isHidden = !showOptions
        optionsButtonWidthConstraint?.isActive = false
        optionsButtonWidthConstraint?.constant = showOptions ? DivoDesignTokens.Spacing.l : 0
        optionsButtonWidthConstraint?.isActive = true
        
        titleLabel.backgroundColor = .clear
        periodLabel.backgroundColor = .clear
        
        logoEmptyImageView.isHidden = true
        
        if loadImage {
            if let url = item.logoURL {
                avatarSpinner.startAnimating()
                avatarSpinner.isHidden = false
                
                ImageLoader.shared.load(url: url) { [weak self] image in
                    guard let self else { return }
                    self.avatarSpinner.stopAnimating()
                    self.avatarSpinner.isHidden = true
                    
                    if let image {
                        self.logoImageView.alpha = 1.0
                        self.logoImageView.image = image
                        self.logoImageView.applyAvatarTopCropIfNeeded(image: image)
                    } else {
                        self.logoEmptyImageView.isHidden = false
                    }
                }
            } else {
                avatarSpinner.stopAnimating()
                avatarSpinner.isHidden = true
                logoEmptyImageView.isHidden = false
            }
        } else {
            avatarSpinner.startAnimating()
            avatarSpinner.isHidden = false
        }
    }
    
    func configureAsShimmer() {
        titleLabel.text = " "
        periodLabel.text = " "
        optionsButton.isHidden = true
        
        logoImageView.backgroundColor = DivoColorPalette.separatorSystem
        titleLabel.backgroundColor = DivoColorPalette.separatorSystem
        periodLabel.backgroundColor = DivoColorPalette.separatorSystem
               
        titleLabel.layer.cornerRadius = 4
        titleLabel.clipsToBounds = true
        periodLabel.layer.cornerRadius = 4
        periodLabel.clipsToBounds = true
    }
    
    private func setupMenu() {
        if #available(iOS 14.0, *) {
            let editAction = UIAction(
                title: DivoStrings.edit,
                image: DivoImage.pencil,
            ) {[weak self] _ in
                self?.onEditTapped?()
            }
            
            let deleteAction = UIAction(
                title: DivoStrings.delete,
                image: DivoImage.basketWork,
                attributes: .destructive
            ) { [weak self] _ in
                self?.onDeleteTapped?()
            }
            
            let menu = UIMenu(title: "", children: [editAction, deleteAction])
            
            optionsButton.menu = menu
            optionsButton.showsMenuAsPrimaryAction = true
        }
    }
}
