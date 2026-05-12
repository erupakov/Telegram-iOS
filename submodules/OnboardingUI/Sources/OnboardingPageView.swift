import UIKit
import Display
import DivoUIKit

struct OnboardingPage {
    let image: UIImage?
    let title: String
    let subtitle: String
}

class OnboardingPageView: UIView {
    
    private let backgroundImageView = UIImageView()
    private let gradientLayer = CAGradientLayer()
    
    private let categoryImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(32)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = .white.withAlphaComponent(0.8)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    func configure(image: UIImage?, title: String, subtitle: String) {
        backgroundImageView.image = image
        categoryImageView.image = DivoImage.logo
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
    
    private func setupUI() {
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundImageView)
        
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.1).cgColor,
            UIColor.black.withAlphaComponent(0.6).cgColor,
            UIColor.black.withAlphaComponent(0.9).cgColor
        ]
        gradientLayer.locations = [0.0, 0.6, 1.0]
        layer.insertSublayer(gradientLayer, at: 1)
        
        addSubview(categoryImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -170),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            categoryImageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -DivoDesignTokens.Spacing.xl),
            categoryImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            categoryImageView.heightAnchor.constraint(equalToConstant: 26),
            categoryImageView.widthAnchor.constraint(equalToConstant: 68),
        ])
    }
}
