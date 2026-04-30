import UIKit
import Display
import DivoCore
import DivoUIKit

final class EmptyEntityPlaceholderView: UIView {
    
    // MARK: - UI Elements
    
    private let emptyModelsIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.emptyModelsAgency
        iv.contentMode = .center
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.textInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
        label.font = Font.helveticaNeue(26)
        label.textColor = DivoColorPalette.secondaryButtonPressed
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.textInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let addButton = DivoButton()
    
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    var openAddEntity: (() -> Void)?
    
    // MARK: - Init
    
    init(title: String, subtitle: String, buttonTitle: String) {
        super.init(frame: .zero)
        
        titleLabel.text = title.uppercased()
        subtitleLabel.text = subtitle
        
        addButton.makeDivoButton(title: buttonTitle)
        addButton.addTarget(self, action: #selector(addPressed), for: .touchUpInside)
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        self.backgroundColor = DivoColorPalette.screenBackground
        
        addSubview(contentStack)
        addSubview(addButton)
                
        contentStack.addArrangedSubview(emptyModelsIcon)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        
        contentStack.setCustomSpacing(14, after: emptyModelsIcon)
        contentStack.setCustomSpacing(6, after: titleLabel)
        
        let centerGuide = UILayoutGuide()
        addLayoutGuide(centerGuide)
        
        NSLayoutConstraint.activate([
            emptyModelsIcon.widthAnchor.constraint(equalToConstant: 68),
            emptyModelsIcon.heightAnchor.constraint(equalToConstant: 68),
            
            addButton.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            addButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            addButton.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -40),
            
            centerGuide.topAnchor.constraint(equalTo: self.topAnchor),
            centerGuide.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            centerGuide.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            centerGuide.bottomAnchor.constraint(equalTo: addButton.topAnchor),
            
            contentStack.centerYAnchor.constraint(equalTo: centerGuide.centerYAnchor),
            contentStack.centerXAnchor.constraint(equalTo: centerGuide.centerXAnchor),
            
            contentStack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            contentStack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DivoDesignTokens.Spacing.m)
        ])
    }
    
    @objc private func addPressed() { openAddEntity?() }
}
