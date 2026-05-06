import UIKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit

struct AppearanceAttribute {
    let title: String
    let value: String
}

struct ExperienceNode {
    let title: String?
    let period: String?
    let logoURL: URL?
    let delegate: CurrentAgencyViewDelegate?
}

protocol ProfileInfoViewDelegate: AnyObject {
    func profileInfoViewDidUpdateContentHeight(animated: Bool)
}

final class ProfileInfoView: UIView, UIScrollViewDelegate {
    weak var delegate: ProfileInfoViewDelegate?
    
    private let maxLinesCollapsed: Int = 3
    private var isExpanded: Bool = false
    
    private var currentAppearanceExpandedState: Bool? = nil
    
    private var biographyText: String = ""
    private var appearanceData: [AppearanceAttribute] = []
    
    private var selectedIndex: Int = 0
    private var currentTabTitles: [String] = []
    
    private var segmentedControlHeightConstraint: NSLayoutConstraint!
    private var horizontalPagerTopConstraint: NSLayoutConstraint!
    private var pagerHeightConstraint: NSLayoutConstraint!
    
    private var bioVerticalStackBottomConstraint: NSLayoutConstraint!
    private var appearanceVerticalStackBottomConstraint: NSLayoutConstraint!
    

    private var dynamicPagerConstraints: [NSLayoutConstraint] = []
    private var activeContainers: [UIView] = []
    private let contentWidthView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - UI Elements
    
    private let segmentedControlContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var segmentedControl: DivoSegmentedControl?
    
    private lazy var horizontalPager: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.showsHorizontalScrollIndicator = false
        sv.delegate = self
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.clipsToBounds = false
        sv.isScrollEnabled = false
        sv.contentInsetAdjustmentBehavior = .never
        return sv
    }()
    
    private let bioContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let bioInternalContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let appearanceContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let appearanceInternalContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let experienceContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let experienceInternalContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var currentAgencyView: CurrentAgencyView = {
        let view = CurrentAgencyView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var emptyCurrentAgencyView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var emptyInternalCurrentAgencyView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.roundCorners(.allCorners, radius: DivoDesignTokens.Radius.l)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emptyWorkIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.emptyWorkProfile
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let emptyWorkTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.noWorkExperienceYetProfile.uppercased()
        label.numberOfLines = 2
        return label
    }()
    
    private let addExperienceButton = DivoButton()
    
    private lazy var emptyBioView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var emptyInternalBioView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.roundCorners(.allCorners, radius: DivoDesignTokens.Radius.l)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emptyBioIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.emptyBioProfile
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let emptyBioTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.noBioYetProfile.uppercased()
        label.numberOfLines = 2
        return label
    }()
    
    private let addBioButton = DivoButton()
    
    private lazy var emptyAppearanceView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var emptyInternalAppearanceView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.roundCorners(.allCorners, radius: DivoDesignTokens.Radius.l)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emptyAppearanceIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.emptyAppearanceProfile
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let emptyAppearanceTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.noAppearanceYetProfile.uppercased()
        label.numberOfLines = 2
        return label
    }()
    
    private let addAppearanceButton = DivoButton()

    private let bioVerticalStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let appearanceVerticalStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let appearanceStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .top
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let bioSeeMoreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        button.setTitle(DivoStrings.seeMore, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let appearanceSeeMoreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        button.setTitle(DivoStrings.seeMore, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let bioSeeMoreWrapper: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let appearanceSeeMoreWrapper: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    var openAddWorkExperience: (() -> Void)?
    var openEditBio: (() -> Void)?
    var openEditAppearance: (() -> Void)?
    
    // MARK: - Init
    
    init(biography: String, appearance: [AppearanceAttribute]) {
        super.init(frame: .zero)
        
        addExperienceButton.makeDivoButton(title: DivoStrings.addWorkExperience, buttonFont: Font.helveticaNeue(14), radius: 18)
        addExperienceButton.setImage(DivoImage.whitePlus.withRenderingMode(.alwaysTemplate), for: .normal)
        addExperienceButton.setImage(DivoImage.whitePlus.withRenderingMode(.alwaysTemplate), for: .highlighted)
        addExperienceButton.tintColor = DivoColorPalette.primaryTextOnDark
        addExperienceButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -DivoDesignTokens.Spacing.xs, bottom: 0, right: DivoDesignTokens.Spacing.xs)
        
        addExperienceButton.addTarget(self, action: #selector(addPressed), for: .touchUpInside)
        
        addBioButton.makeDivoButton(title: DivoStrings.addBioProfile, buttonFont: Font.helveticaNeue(14), radius: 18)
        addBioButton.setImage(DivoImage.whitePlus.withRenderingMode(.alwaysTemplate), for: .normal)
        addBioButton.setImage(DivoImage.whitePlus.withRenderingMode(.alwaysTemplate), for: .highlighted)
        addBioButton.tintColor = DivoColorPalette.primaryTextOnDark
        addBioButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -DivoDesignTokens.Spacing.xs, bottom: 0, right: DivoDesignTokens.Spacing.xs)
        
        addBioButton.addTarget(self, action: #selector(addBioPressed), for: .touchUpInside)
        
        addAppearanceButton.makeDivoButton(title: DivoStrings.addAppearanceProfile, buttonFont: Font.helveticaNeue(14), radius: 18)
        addAppearanceButton.setImage(DivoImage.whitePlus.withRenderingMode(.alwaysTemplate), for: .normal)
        addAppearanceButton.setImage(DivoImage.whitePlus.withRenderingMode(.alwaysTemplate), for: .highlighted)
        addAppearanceButton.tintColor = DivoColorPalette.primaryTextOnDark
        addAppearanceButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -DivoDesignTokens.Spacing.xs, bottom: 0, right: DivoDesignTokens.Spacing.xs)   
        
        addAppearanceButton.addTarget(self, action: #selector(addAppearancePressed), for: .touchUpInside)
        
        setupViews()
        configureActions()
        
        update(biography: biography, appearance: appearance, experience: nil, isMyProfile: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Updates
    
    func update(biography: String?, appearance: [AppearanceAttribute], experience: ExperienceNode? = nil, isMyProfile: Bool, isAgency: Bool = false) {
        self.appearanceData = appearance
        
        self.currentAppearanceExpandedState = nil
            
        var titles: [String] = [DivoStrings.biographyTitle]
        var newActiveContainers: [UIView] = []
        
        if let biography = biography {
            self.biographyText = biography
            newActiveContainers.append(bioContainer)
        } else {
            newActiveContainers.append(emptyBioView)
            addBioButton.isHidden = !isMyProfile
            emptyBioIcon.isHidden = isMyProfile
        }
        
        if !appearance.isEmpty {
            titles.append(DivoStrings.appearanceTitle)
            newActiveContainers.append(appearanceContainer)
        } else {
            newActiveContainers.append(emptyAppearanceView)
            addAppearanceButton.isHidden = !isMyProfile
            emptyAppearanceIcon.isHidden = isMyProfile
        }
        
        if !isAgency {
            titles.append(DivoStrings.experienceTitle)
            if let experience = experience {
                self.currentAgencyView.configure(name: experience.title, logoURL: experience.logoURL)
                self.currentAgencyView.delegate = experience.delegate
                newActiveContainers.append(experienceContainer)
            } else {
                newActiveContainers.append(emptyCurrentAgencyView)
                addExperienceButton.isHidden = !isMyProfile
                emptyWorkIcon.isHidden = isMyProfile
            }
        }
        
        if currentTabTitles != titles || activeContainers != newActiveContainers {
            currentTabTitles = titles
            activeContainers = newActiveContainers
            rebuildPagerLayout()
            updateSegmentedControl(with: titles)
        }
        
        if titles.count <= 1 {
            segmentedControlContainer.isHidden = true
            segmentedControlHeightConstraint.constant = 0
            horizontalPagerTopConstraint.constant = 0
        } else {
            segmentedControlContainer.isHidden = false
            segmentedControlHeightConstraint.constant = DivoDesignTokens.Spacing.xl
            horizontalPagerTopConstraint.constant = 10
        }
        
        if selectedIndex >= titles.count {
            selectedIndex = 0
        }
        
        updateContent(animated: false)
    }
    
    func update(biography: String?) {
        update(biography: biography, appearance:[], experience: nil, isMyProfile: false, isAgency: true)
    }
    
    private func updateSegmentedControl(with titles: [String]) {
        segmentedControl?.removeFromSuperview()
        
        let control = DivoSegmentedControl(titles: titles)
        control.translatesAutoresizingMaskIntoConstraints = false
        segmentedControlContainer.addSubview(control)
        
        NSLayoutConstraint.activate([
            control.topAnchor.constraint(equalTo: segmentedControlContainer.topAnchor),
            control.leadingAnchor.constraint(equalTo: segmentedControlContainer.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: segmentedControlContainer.trailingAnchor),
            control.bottomAnchor.constraint(equalTo: segmentedControlContainer.bottomAnchor)
        ])
        
        control.onTabSelected = { [weak self] index in
            self?.setSelectedIndex(index, animated: true)
        }
        
        self.segmentedControl = control
        control.setSelectedIndex(selectedIndex, animated: false)
        control.setIndicatorProgress(CGFloat(selectedIndex))
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        addSubview(segmentedControlContainer)
        addSubview(horizontalPager)
        
        horizontalPager.addSubview(contentWidthView)
        
        bioSeeMoreWrapper.addArrangedSubview(UIView())
        bioSeeMoreWrapper.addArrangedSubview(bioSeeMoreButton)
        
        appearanceSeeMoreWrapper.addArrangedSubview(UIView())
        appearanceSeeMoreWrapper.addArrangedSubview(appearanceSeeMoreButton)
        
        // Внутренние компоненты
        bioContainer.addSubview(bioInternalContainer)
        appearanceContainer.addSubview(appearanceInternalContainer)
        
        experienceContainer.addSubview(experienceInternalContainer)
        emptyCurrentAgencyView.addSubview(emptyInternalCurrentAgencyView)
        
        experienceInternalContainer.addSubview(currentAgencyView)
                
        let emptyWorkStack = UIStackView(arrangedSubviews: [emptyWorkIcon, emptyWorkTitleLabel, addExperienceButton])
        emptyWorkStack.distribution = .fill
        emptyWorkStack.spacing = DivoDesignTokens.Spacing.s
        emptyWorkStack.alignment = .center
        emptyWorkStack.axis = .vertical
        emptyWorkStack.translatesAutoresizingMaskIntoConstraints = false
        
        emptyInternalCurrentAgencyView.addSubview(emptyWorkStack)
        
        bioInternalContainer.addSubview(bioVerticalStack)
        bioVerticalStack.addArrangedSubview(contentLabel)
        bioVerticalStack.addArrangedSubview(bioSeeMoreWrapper)
        
        emptyBioView.addSubview(emptyInternalBioView)
        
        let emptyBioStack = UIStackView(arrangedSubviews: [emptyBioIcon, emptyBioTitleLabel, addBioButton])
        emptyBioStack.distribution = .fill
        emptyBioStack.spacing = DivoDesignTokens.Spacing.s
        emptyBioStack.alignment = .center
        emptyBioStack.axis = .vertical
        emptyBioStack.translatesAutoresizingMaskIntoConstraints = false
        
        emptyInternalBioView.addSubview(emptyBioStack)
        
        appearanceInternalContainer.addSubview(appearanceVerticalStack)
        appearanceVerticalStack.addArrangedSubview(appearanceStack)
        appearanceVerticalStack.addArrangedSubview(appearanceSeeMoreWrapper)
        
        emptyAppearanceView.addSubview(emptyInternalAppearanceView)
        
        let emptyAppearanceStack = UIStackView(arrangedSubviews: [emptyAppearanceIcon, emptyAppearanceTitleLabel, addAppearanceButton])
        emptyAppearanceStack.distribution = .fill
        emptyAppearanceStack.spacing = DivoDesignTokens.Spacing.s
        emptyAppearanceStack.alignment = .center
        emptyAppearanceStack.axis = .vertical
        emptyAppearanceStack.translatesAutoresizingMaskIntoConstraints = false
        
        emptyInternalAppearanceView.addSubview(emptyAppearanceStack)
        
        pagerHeightConstraint = horizontalPager.heightAnchor.constraint(equalToConstant: 50)
        segmentedControlHeightConstraint = segmentedControlContainer.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl)
        horizontalPagerTopConstraint = horizontalPager.topAnchor.constraint(equalTo: segmentedControlContainer.bottomAnchor, constant: 10)
        
        bioVerticalStackBottomConstraint = bioVerticalStack.bottomAnchor.constraint(equalTo: bioInternalContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs)
        appearanceVerticalStackBottomConstraint = appearanceVerticalStack.bottomAnchor.constraint(equalTo: appearanceInternalContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs)
        
        NSLayoutConstraint.activate([
            segmentedControlContainer.topAnchor.constraint(equalTo: self.topAnchor),
            segmentedControlContainer.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            segmentedControlContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            segmentedControlHeightConstraint,
            
            horizontalPagerTopConstraint,
            horizontalPager.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            horizontalPager.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            horizontalPager.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            pagerHeightConstraint,
            
            contentWidthView.topAnchor.constraint(equalTo: horizontalPager.topAnchor),
            contentWidthView.bottomAnchor.constraint(equalTo: horizontalPager.bottomAnchor),
            contentWidthView.leadingAnchor.constraint(equalTo: horizontalPager.leadingAnchor),
            contentWidthView.trailingAnchor.constraint(equalTo: horizontalPager.trailingAnchor),
            contentWidthView.heightAnchor.constraint(equalTo: horizontalPager.heightAnchor),
            
            bioInternalContainer.topAnchor.constraint(equalTo: bioContainer.topAnchor),
            bioInternalContainer.leadingAnchor.constraint(equalTo: bioContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bioInternalContainer.trailingAnchor.constraint(equalTo: bioContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            bioInternalContainer.bottomAnchor.constraint(equalTo: bioContainer.bottomAnchor),
            
            bioVerticalStack.topAnchor.constraint(equalTo: bioInternalContainer.topAnchor, constant: 12),
            bioVerticalStack.leadingAnchor.constraint(equalTo: bioInternalContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bioVerticalStack.trailingAnchor.constraint(equalTo: bioInternalContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            bioVerticalStackBottomConstraint,
            
            appearanceInternalContainer.topAnchor.constraint(equalTo: appearanceContainer.topAnchor),
            appearanceInternalContainer.leadingAnchor.constraint(equalTo: appearanceContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            appearanceInternalContainer.trailingAnchor.constraint(equalTo: appearanceContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            appearanceInternalContainer.bottomAnchor.constraint(equalTo: appearanceContainer.bottomAnchor),
            
            appearanceVerticalStack.topAnchor.constraint(equalTo: appearanceInternalContainer.topAnchor, constant: 12),
            appearanceVerticalStack.leadingAnchor.constraint(equalTo: appearanceInternalContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            appearanceVerticalStack.trailingAnchor.constraint(equalTo: appearanceInternalContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            appearanceVerticalStackBottomConstraint,
            
            experienceInternalContainer.topAnchor.constraint(equalTo: experienceContainer.topAnchor),
            experienceInternalContainer.leadingAnchor.constraint(equalTo: experienceContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            experienceInternalContainer.trailingAnchor.constraint(equalTo: experienceContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            experienceInternalContainer.bottomAnchor.constraint(equalTo: experienceContainer.bottomAnchor),
            
            currentAgencyView.leadingAnchor.constraint(equalTo: experienceInternalContainer.leadingAnchor),
            currentAgencyView.trailingAnchor.constraint(equalTo: experienceInternalContainer.trailingAnchor),
            currentAgencyView.topAnchor.constraint(equalTo: experienceInternalContainer.topAnchor),
            currentAgencyView.bottomAnchor.constraint(equalTo: experienceInternalContainer.bottomAnchor),
            
            emptyInternalCurrentAgencyView.topAnchor.constraint(equalTo: emptyCurrentAgencyView.topAnchor),
            emptyInternalCurrentAgencyView.leadingAnchor.constraint(equalTo: emptyCurrentAgencyView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            emptyInternalCurrentAgencyView.trailingAnchor.constraint(equalTo: emptyCurrentAgencyView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            emptyInternalCurrentAgencyView.bottomAnchor.constraint(equalTo: emptyCurrentAgencyView.bottomAnchor),
            
            emptyWorkStack.topAnchor.constraint(equalTo: emptyInternalCurrentAgencyView.topAnchor, constant: DivoDesignTokens.Spacing.m),
            emptyWorkStack.leadingAnchor.constraint(equalTo: emptyInternalCurrentAgencyView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            emptyWorkStack.trailingAnchor.constraint(equalTo: emptyInternalCurrentAgencyView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            emptyWorkStack.bottomAnchor.constraint(equalTo: emptyInternalCurrentAgencyView.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            addExperienceButton.heightAnchor.constraint(equalToConstant: 36),
            
            emptyInternalBioView.topAnchor.constraint(equalTo: emptyBioView.topAnchor),
            emptyInternalBioView.leadingAnchor.constraint(equalTo: emptyBioView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            emptyInternalBioView.trailingAnchor.constraint(equalTo: emptyBioView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            emptyInternalBioView.bottomAnchor.constraint(equalTo: emptyBioView.bottomAnchor),
            
            emptyBioStack.topAnchor.constraint(equalTo: emptyInternalBioView.topAnchor, constant: DivoDesignTokens.Spacing.m),
            emptyBioStack.leadingAnchor.constraint(equalTo: emptyInternalBioView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            emptyBioStack.trailingAnchor.constraint(equalTo: emptyInternalBioView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            emptyBioStack.bottomAnchor.constraint(equalTo: emptyInternalBioView.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            addBioButton.heightAnchor.constraint(equalToConstant: 36),
            
            emptyInternalAppearanceView.topAnchor.constraint(equalTo: emptyAppearanceView.topAnchor),
            emptyInternalAppearanceView.leadingAnchor.constraint(equalTo: emptyAppearanceView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            emptyInternalAppearanceView.trailingAnchor.constraint(equalTo: emptyAppearanceView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            emptyInternalAppearanceView.bottomAnchor.constraint(equalTo: emptyAppearanceView.bottomAnchor),
            
            emptyAppearanceStack.topAnchor.constraint(equalTo: emptyInternalAppearanceView.topAnchor, constant: DivoDesignTokens.Spacing.m),
            emptyAppearanceStack.leadingAnchor.constraint(equalTo: emptyInternalAppearanceView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            emptyAppearanceStack.trailingAnchor.constraint(equalTo: emptyInternalAppearanceView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            emptyAppearanceStack.bottomAnchor.constraint(equalTo: emptyInternalAppearanceView.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            addAppearanceButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }
    
    // Динамическая перестройка страниц скролла
    private func rebuildPagerLayout() {
        NSLayoutConstraint.deactivate(dynamicPagerConstraints)
        dynamicPagerConstraints.removeAll()
        
        bioContainer.removeFromSuperview()
        appearanceContainer.removeFromSuperview()
        experienceContainer.removeFromSuperview()
        emptyCurrentAgencyView.removeFromSuperview()
        emptyBioView.removeFromSuperview()
        emptyAppearanceView.removeFromSuperview()
        
        var previousView: UIView? = nil
        
        for container in activeContainers {
            contentWidthView.addSubview(container)
            
            dynamicPagerConstraints.append(container.topAnchor.constraint(equalTo: contentWidthView.topAnchor))
            dynamicPagerConstraints.append(container.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor))
            
            if let prev = previousView {
                dynamicPagerConstraints.append(container.leadingAnchor.constraint(equalTo: prev.trailingAnchor))
            } else {
                dynamicPagerConstraints.append(container.leadingAnchor.constraint(equalTo: contentWidthView.leadingAnchor))
            }
            
            previousView = container
        }
        
        if let last = previousView {
            dynamicPagerConstraints.append(last.trailingAnchor.constraint(equalTo: contentWidthView.trailingAnchor))
        }
        
        NSLayoutConstraint.activate(dynamicPagerConstraints)
    }
    
    private func configureActions() {
        bioSeeMoreButton.addTarget(self, action: #selector(seeMoreTapped), for: .touchUpInside)
        appearanceSeeMoreButton.addTarget(self, action: #selector(seeMoreTapped), for: .touchUpInside)
    }
    
    // MARK: - Logic
    
    private func setSelectedIndex(_ index: Int, animated: Bool) {
        guard selectedIndex != index else { return }
        selectedIndex = index
        
        isExpanded = false
        
        updateContent(animated: animated)
        segmentedControl?.setSelectedIndex(index, animated: animated)
        
        let offsetX = CGFloat(index) * horizontalPager.bounds.width
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options:[.curveEaseInOut, .allowUserInteraction], animations: {
                self.horizontalPager.contentOffset = CGPoint(x: offsetX, y: 0)
            })
        } else {
            horizontalPager.contentOffset = CGPoint(x: offsetX, y: 0)
        }
    }
    
    private func updateContent(animated: Bool) {
        contentLabel.text = biographyText
        contentLabel.numberOfLines = isExpanded ? 0 : maxLinesCollapsed

        if currentAppearanceExpandedState != isExpanded {
            currentAppearanceExpandedState = isExpanded
            let dataToShow = isExpanded ? appearanceData : Array(appearanceData.prefix(4))
            rebuildAppearanceGrid(with: dataToShow)
        }
        
        var shouldShowBioSeeMore = false
        var shouldShowAppSeeMore = false
        
        let viewWidth = self.bounds.width > 0 ? self.bounds.width : UIScreen.main.bounds.width
        let labelWidth = viewWidth - 64
        let actualLines = biographyText.lineCount(for: contentLabel.font, width: labelWidth)
        shouldShowBioSeeMore = actualLines > maxLinesCollapsed
        
        shouldShowAppSeeMore = appearanceData.count > 4
        
        bioSeeMoreWrapper.isHidden = !shouldShowBioSeeMore
        appearanceSeeMoreWrapper.isHidden = !shouldShowAppSeeMore
        
        bioVerticalStackBottomConstraint.constant = shouldShowBioSeeMore ? -DivoDesignTokens.Spacing.xs : -12
        appearanceVerticalStackBottomConstraint.constant = shouldShowAppSeeMore ? -DivoDesignTokens.Spacing.xs : -12
        
        let newTitle = isExpanded ? DivoStrings.seeLess : DivoStrings.seeMore
        if animated {
            UIView.transition(with: bioSeeMoreButton, duration: 0.25, options: .transitionCrossDissolve) {
                self.bioSeeMoreButton.setTitle(newTitle, for: .normal)
            }
            UIView.transition(with: appearanceSeeMoreButton, duration: 0.25, options: .transitionCrossDissolve) {
                self.appearanceSeeMoreButton.setTitle(newTitle, for: .normal)
            }
        } else {
            bioSeeMoreButton.setTitle(newTitle, for: .normal)
            appearanceSeeMoreButton.setTitle(newTitle, for: .normal)
        }
        
        updatePagerHeight(animated: animated)
    }
    
    private func updatePagerHeight(animated: Bool = false) {
        guard selectedIndex < activeContainers.count else { return }
        
        let activeContainer = activeContainers[selectedIndex]
        
        activeContainer.layoutIfNeeded()
        
        let pagerWidth = horizontalPager.bounds.width > 0 ? horizontalPager.bounds.width : UIScreen.main.bounds.width
        
        let targetHeight = activeContainer.systemLayoutSizeFitting(
            CGSize(width: pagerWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        
        if pagerHeightConstraint.constant == targetHeight || targetHeight == 0 { return }
        
        pagerHeightConstraint.constant = targetHeight
        
        if animated {
            self.delegate?.profileInfoViewDidUpdateContentHeight(animated: true)
        } else {
            self.layoutIfNeeded()
            self.delegate?.profileInfoViewDidUpdateContentHeight(animated: false)
        }
    }
    
    private func rebuildAppearanceGrid(with attributes: [AppearanceAttribute]) {
        appearanceStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let leftStack = UIStackView()
        leftStack.axis = .vertical
        leftStack.spacing = 10
        
        let rightStack = UIStackView()
        rightStack.axis = .vertical
        rightStack.spacing = 10
        
        for (index, attr) in attributes.enumerated() {
            let itemView = createAttributeView(title: attr.title, value: attr.value)
            if index % 2 == 0 {
                leftStack.addArrangedSubview(itemView)
            } else {
                rightStack.addArrangedSubview(itemView)
            }
        }
        
        appearanceStack.addArrangedSubview(leftStack)
        appearanceStack.addArrangedSubview(rightStack)
    }
    
    private func createAttributeView(title: String, value: String) -> UIView {
        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.font = Font.regular(12)
        titleLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        titleLabel.text = title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.font = Font.regular(12)
        valueLabel.textColor = DivoColorPalette.primaryText
        valueLabel.text = value
        valueLabel.textAlignment = .right
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let line = UIView()
        line.backgroundColor = DivoColorPalette.primaryText.withAlphaComponent(0.1)
        line.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        container.addSubview(line)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: container.topAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: DivoDesignTokens.Spacing.xs),
            
            line.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.xs),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    @objc private func seeMoreTapped() {
        isExpanded.toggle()
        updateContent(animated: false)
    }
    
    @objc private func addPressed() { openAddWorkExperience?() }
    @objc private func addBioPressed() { openEditBio?() }
    @objc private func addAppearancePressed() { openEditAppearance?() }
    
    // MARK: - UIScrollViewDelegate (Синхронизация свайпа)
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == horizontalPager, scrollView.bounds.width > 0 else { return }
        let progress = scrollView.contentOffset.x / scrollView.bounds.width
        segmentedControl?.setIndicatorProgress(progress)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == horizontalPager else { return }
        
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        if selectedIndex != page {
            selectedIndex = page
            isExpanded = false
            updateContent(animated: true)
            segmentedControl?.setSelectedIndex(page, animated: false)
        }
    }
}