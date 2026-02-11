import UIKit
import Display

protocol ProfileInfoViewDelegate: AnyObject {
    func profileInfoViewDidUpdateContentHeight()
}

final class ProfileInfoView: UIView {

    weak var delegate: ProfileInfoViewDelegate?
    
    private let maxLinesCollapsed: Int = 3
    private var isExpanded: Bool = false
    private let biographyText: String
    private let appearanceText: String
    
    private let headerHeight: CGFloat = 30
    
    private var selectedIndex: Int = 0 {
        didSet {
            isExpanded = false
            updateContent()
            updateHeaderAppearance()
        }
    }
    
    private var currentText: String {
        switch selectedIndex {
        case 0:
            return biographyText
        case 1:
            return appearanceText
        default:
            return biographyText
        }
    }
    
    private let biographyButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(.white, for: .normal)
        button.setTitle("BIOGRAPHY", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let appearanceButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(.white, for: .normal)
        button.setTitle("APPEARANCE", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black.withAlphaComponent(0.12)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let seeMoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(.white, for: .normal)
        button.setTitle("SEE MORE", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var indicatorLeadingConstraint: NSLayoutConstraint!
    private var indicatorWidthConstraint: NSLayoutConstraint!
    
    init(biography: String, appearance: String) {
        self.biographyText = biography
        self.appearanceText = appearance
        super.init(frame: .zero)
        
        self.backgroundColor = .black.withAlphaComponent(0.15)
        
        setupViews()
        configureActions()
        DispatchQueue.main.async {
            self.updateHeaderAppearance()
            self.updateContent()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        let headerStack = UIStackView(arrangedSubviews: [biographyButton, appearanceButton])
        headerStack.axis = .horizontal
        headerStack.distribution = .fillEqually
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(headerStack)
        headerView.addSubview(indicatorView)
        
        let seeMoreStack = UIStackView(arrangedSubviews: [UIView(), seeMoreButton])
        seeMoreStack.axis = .horizontal
        seeMoreStack.translatesAutoresizingMaskIntoConstraints = false
        
        let mainStack = UIStackView(arrangedSubviews: [contentLabel, seeMoreStack])
        mainStack.axis = .vertical
        mainStack.spacing = 5
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(headerView)
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: self.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerHeight)
        ])
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: headerView.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            headerStack.heightAnchor.constraint(equalToConstant: headerHeight - 3),
            
            indicatorView.topAnchor.constraint(equalTo: headerStack.bottomAnchor),
            indicatorView.heightAnchor.constraint(equalToConstant: 3)
        ])
        
        indicatorLeadingConstraint = indicatorView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16)
        indicatorWidthConstraint = indicatorView.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            indicatorLeadingConstraint,
            indicatorWidthConstraint,
            
            mainStack.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0)
        ])
    }
    
    private func configureActions() {
        biographyButton.addTarget(self, action: #selector(biographyTapped), for: .touchUpInside)
        appearanceButton.addTarget(self, action: #selector(appearanceTapped), for: .touchUpInside)
        seeMoreButton.addTarget(self, action: #selector(seeMoreTapped), for: .touchUpInside)
    }
    
    @objc private func biographyTapped() {
        guard selectedIndex != 0 else { return }
        selectedIndex = 0
    }
    
    @objc private func appearanceTapped() {
        guard selectedIndex != 1 else { return }
        selectedIndex = 1
    }
    
    @objc private func seeMoreTapped() {
        isExpanded.toggle()
        updateContent()
    }
    
    private func updateHeaderAppearance() {
        let selectedColor: UIColor = .white
        let unselectedColor: UIColor = .white.withAlphaComponent(0.6)
        
        biographyButton.setTitleColor(selectedIndex == 0 ? selectedColor : unselectedColor, for: .normal)
        appearanceButton.setTitleColor(selectedIndex == 1 ? selectedColor : unselectedColor, for: .normal)
        
        let selectedButton = selectedIndex == 0 ? biographyButton : appearanceButton
        
        let buttonFrameInHeader = selectedButton.convert(selectedButton.bounds, to: headerView)
        
        UIView.animate(withDuration: 0.3) {
            self.indicatorLeadingConstraint.constant = buttonFrameInHeader.minX
            self.indicatorWidthConstraint.constant = buttonFrameInHeader.width
            self.layoutIfNeeded()
        }
    }
    
    private func updateContent() {
        contentLabel.text = currentText
        contentLabel.numberOfLines = isExpanded ? 0 : maxLinesCollapsed
        
        let contentWidth = self.bounds.width - 32
        let shouldShowSeeMore = currentText.lineCount(for: contentLabel.font, width: contentWidth) > maxLinesCollapsed
        
        if shouldShowSeeMore && !isExpanded {
            seeMoreButton.isHidden = false
            seeMoreButton.setTitle("SEE MORE", for: .normal)
        } else if isExpanded {
            seeMoreButton.isHidden = false
            seeMoreButton.setTitle("SEE LESS", for: .normal)
        } else {
            seeMoreButton.isHidden = true
        }

        delegate?.profileInfoViewDidUpdateContentHeight()
        
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeaderAppearance()
        
        let temporaryIsExpanded = isExpanded
        isExpanded = false
        let contentWidth = self.bounds.width - 32
        let shouldShowSeeMore = currentText.lineCount(for: contentLabel.font, width: contentWidth) > maxLinesCollapsed
        isExpanded = temporaryIsExpanded
        
        if shouldShowSeeMore && !isExpanded {
            seeMoreButton.isHidden = false
            seeMoreButton.setTitle("SEE MORE", for: .normal)
        } else if isExpanded {
            seeMoreButton.isHidden = false
            seeMoreButton.setTitle("SEE LESS", for: .normal)
        } else {
            seeMoreButton.isHidden = true
        }
    }
}

private extension String {
    func lineCount(for font: UIFont, width: CGFloat) -> Int {
        guard width > 0 else { return 0 }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let rect = self.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        
        let lineHeight = font.lineHeight
        let lineCount = Int(ceil(rect.height / lineHeight))
        return lineCount
    }
}
