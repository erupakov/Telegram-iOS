import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle

public enum Role {
    case model
    case newFace
    case agency

    init(apiRole: String?) {
        switch apiRole {
        case "agency_employee": self = .agency
        case "new_face":        self = .newFace
        default:                self = .model
        }
    }

    var title: String {
        switch self {
        case .model: DivoStrings.roleModel
        case .newFace: DivoStrings.roleNewFace
        case .agency: DivoStrings.roleAgency
        }
    }
}

final class PublicProfileScreenNode: ASDisplayNode {
    private static let mockBiographyText = DivoStrings.noBiography
    private static let mockBiographyMyProfileText = DivoStrings.fillInInfoAboutYou
    private let model: ProfileModel
    private var modelRole: Role = .model
    /// myProfile, но НЕ agency (у agency свой набор табов)
    private var isMyModelProfile: Bool {
        model.isMyProfile && modelRole != .agency
    }
    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var navigationBarTitleView: ProfileNavigationBarTitleView?
    private var navigationBarTitleHeightConstraint: NSLayoutConstraint!
    
    // Управление моментом, когда начинаем анимировать title в навбаре
    private var titleVisibilityActivated = false
    
    private var headerHeightConstraint: NSLayoutConstraint!
    private var socialHeightConstraint: NSLayoutConstraint!
    private let iconPlaceholder = "HeartActionIcon"
    private let fixedHeaderHeight: CGFloat = 540.0
    private let fixedProfileHeaderHeight: CGFloat = 240.0
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentViewStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let headerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        return view
    }()
    
    private let blurredHeaderImageView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemChromeMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let headerImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.backgroundColor = .gray
        return iv
    }()

    private let headerSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    var currentPhoto: UIImage? = nil {
        didSet {
            if let currentPhoto = self.currentPhoto {
                profileHeaderView.changeAvatar(with: currentPhoto)
            } else {
                profileHeaderView.changeAvatar(with: nil)
            }
        }
    }
    
    // MARK: - Profile Header Section
    
    private lazy var infoStack: UIStackView = {
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 0
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        return infoStack
    }()
    
    private lazy var profileHeaderView = ProfileHeaderView()
    
    private lazy var profileHeaderShimmerView = ProfileHeaderShimmerView()
    
    
    // MARK: - Actions Section
    
    private lazy var counterActionsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stack
    }()
    
    private let counterActionsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let actionsShimmerView: CounterActionsShimmerView = {
        let actionsShimmerView = CounterActionsShimmerView()
        actionsShimmerView.translatesAutoresizingMaskIntoConstraints = false
        return actionsShimmerView
    }()
    
    private let dmButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .black.withAlphaComponent(0.15)
        button.layer.cornerRadius = 6
        button.layer.borderWidth = 0.0
        button.layer.borderColor = UIColor.clear.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    private enum ActionViewTags {
        static let dmIcon = 9_101
        static let dmLabel = 9_102

        static let counterIcon = 9_201
        static let counterCountLabel = 9_202
        static let counterNameLabel = 9_203
    }
    
    private let likesView: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let viewsView: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let savesView: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    
    // MARK: - Profile Info Section
    
    private let profileInfoContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var profileInfoView: ProfileInfoView = {
        let view = ProfileInfoView(
            biography: model.biography.isEmpty ? Self.mockBiographyText : model.biography,
            appearance: []
        )
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    private let profileInfoShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Current Agency Section
    
    private let currentAgencyContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var currentAgencyView: CurrentAgencyView = {
        let view = CurrentAgencyView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let currentAgencyShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Work History Section
    
    private let addWorkHistoryContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let addWorkHistoryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(DivoStrings.addWorkHistory, for: .normal)
        button.setTitleColor(.white.withAlphaComponent(0.88), for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(13)
        button.titleLabel?.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        button.backgroundColor = .black.withAlphaComponent(0.15)
        button.layer.cornerRadius = 6
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    
    // MARK: - Social Media Section
    
    private let socialMediaContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleEditContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let titleEditStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let editLinksButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.titleLabel?.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        button.setTitleColor(.white, for: .normal)
        button.setTitle(DivoStrings.editLinks, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let editLinksLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(14)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.myLinks
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        return label
    }()
    
    private let socialMediaStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let socialShimmerView: CounterSocialShimmerView = {
        let socialShimmerView = CounterSocialShimmerView()
        socialShimmerView.translatesAutoresizingMaskIntoConstraints = false
        return socialShimmerView
    }()
    
    
    // MARK: - Segmented Bar Section
    
    private lazy var segmentedBar: ProfileSegmentedBar = {
        let view = ProfileSegmentedBar()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        return view
    }()
    
    private let segmentedBarPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var segmentedBarTopConstraint: NSLayoutConstraint?
    private let segmentedBarHeight: CGFloat = 40.0
    
    
    // MARK: - Gallery Collections Section
    
    private let collectionsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()
    
    
    // MARK: - Tabs & Swipe Logic Variables
    
    private var galleryHeightConstraint: NSLayoutConstraint!
    private var videoHeightConstraint: NSLayoutConstraint!
    private var channelHeightConstraint: NSLayoutConstraint!
    private var modelHeightConstraint: NSLayoutConstraint!
    private var eventHeightConstraint: NSLayoutConstraint!
    
    private var currentTabIndex: Int = 0
    private var collectionsContainerHeightConstraint: NSLayoutConstraint!
    
    private let photoTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let videoTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let channelTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let modelTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let eventTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    
    // MARK: - Gallery Section
    
    private var galleryPhotos: [UserPhoto] = []
    private var galleryCurrentOffset: Int = 0
    private var galleryIsLoading: Bool = false
    private var galleryHasMore: Bool = true
    private var galleryInitialized: Bool = false
    private var galleryImageNames: [String] = []
    private var uploadingPhotoImage: UIImage?
    private var uploadingVideoImage: UIImage?
    
    private lazy var galleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "GalleryCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let galleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Video Gallery Pagination
    
    private var videoGalleryInitialized: Bool = false
    private var videoGalleryImageNames: [String] = []
    private var videoGalleryItems: [UserPhoto] = []
    private var videoGalleryTotalCount: Int = 0
    private var videoGalleryCurrentOffset: Int = 0
    private var videoGalleryIsLoading: Bool = false
    private var videoGalleryHasMore: Bool = true
    /// Защита от повторного запроса одной и той же страницы (особенно offset=0)
    private var videoGalleryRequestedOffsets: Set<Int> = []
    /// Последний offset, который мы отправили в запросе. Нужен, чтобы корректно вычислять nextOffset
    /// независимо от того, что означает `pagination.meta.currentOffset` (current vs next).
    private var videoGalleryLastRequestedOffset: Int?
    
    private lazy var videoGalleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(VideoGalleryCell.self, forCellWithReuseIdentifier: VideoGalleryCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let videoGalleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Channels Gallery Section
    
    private var channelGalleryItems: [ProfileChannelItem] = []
    private var channelGalleryInitialized: Bool = false
    
    private lazy var channelGalleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.register(ChannelListCell.self, forCellWithReuseIdentifier: ChannelListCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let channelGalleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Models Gallery Section
    
    private var modelGalleryItems: [ModelItem] = []
    private var modelGalleryInitialized: Bool = false
    
    private lazy var modelGalleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.register(ModelListCell.self, forCellWithReuseIdentifier: ModelListCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let modelGalleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Models Gallery Section
    
    private var eventGalleryItems: [EventItem] = []
    private var eventGalleryInitialized: Bool = false
    
    private lazy var eventGalleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.register(EventListCell.self, forCellWithReuseIdentifier: EventListCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let eventGalleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Similar Profiles Section
    
    private var similarProfiles: [SimilarProfileItem] = []
    private var similarProfilesTotalCount: Int = 0
    private var similarProfilesOffset: Int = 0
    private var similarProfilesHasMore: Bool = true
    private var similarProfilesIsLoading: Bool = false
    
    private let similarProfilesCollectionContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let similarProfilesTitleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.similarProfiles
        label.font = Font.helveticaNeue(18)
        label.textColor = UIColor(hex: "#222222")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        return label
    }()
    
    private lazy var similarProfilesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 6
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(SimilarProfileCell.self, forCellWithReuseIdentifier: SimilarProfileCell.reuseIdentifier)
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    
    // MARK: - Sheet View

    var onLikesTapped: (() -> Void)?
    var onViewsTapped: (() -> Void)?
    var onSavesTapped: (() -> Void)?
    var onEditLinksTapped: (() -> Void)?
    var onAddPhotoTapped: (() -> Void)?
    var onAddVideoTapped: (() -> Void)?
    var onGalleryItemTapped: ((Int, Int) -> Void)? 
    var onSocialLinkTapped: ((String) -> Void)?

    private var socialLinksMap: [UIButton: String] = [:]

    private enum SocialIcon: String {
        case instagram = "Models/instaIcon"
        case tiktok = "Models/TikTokIcon"
        case youtube = "Models/youtubeIcon"
        case telegram = "Models/telegramIcon"
        case website = "Models/webIcon"
        
        static func icon(for urlString: String) -> String {
            let lowercased = urlString.lowercased()
            if lowercased.contains("instagram.com") { return self.instagram.rawValue }
            if lowercased.contains("tiktok.com") { return self.tiktok.rawValue }
            if lowercased.contains("youtube.com") { return self.youtube.rawValue }
            if lowercased.contains("t.me") || lowercased.contains("telegram.me") { return self.telegram.rawValue }
            return self.website.rawValue
        }
    }

    var onAddModelTapped: (() -> Void)?
    private let emptyModelsPlaceholderNode: EmptyModelsPlaceholderNode
    
    
    // MARK: - Init
    
    init(controller: ViewController, context: AccountContext, presentationData: PresentationData, model: ProfileModel) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        self.model = model
        self.emptyModelsPlaceholderNode = EmptyModelsPlaceholderNode(theme: presentationData.theme)

        super.init()
        
        self.view.backgroundColor = .black

        setupContent()
        configureNodes()
        segmentedBar.configure(isAgency: model.role == "agency_employee", isMyProfile: model.isMyProfile, animated: false)
        loadSimilarProfiles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Override
    
    override func layout() {
        super.layout()
        
        guard let (layout, _) = self.containerLayout else { return }
        
        let stackWidth = layout.size.width
        
        contentViewStack.layoutIfNeeded()
        
        let contentHeight = contentViewStack.systemLayoutSizeFitting(
            CGSize(width: stackWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        
        contentViewStack.frame = CGRect(x: 0, y: 0, width: stackWidth, height: contentHeight)
        scrollView.contentSize = CGSize(width: stackWidth, height: contentHeight)
        
        applyGradientBlurMask()
        
        if !profileInfoShimmerView.isHidden {
            profileInfoShimmerView.stopShimmering()
            profileInfoShimmerView.startShimmering()
        }
        
        if !actionsShimmerView.isHidden {
            actionsShimmerView.startAnimation()
        }
        
        if !socialShimmerView.isHidden {
            socialShimmerView.startAnimation()
        }
        
        if !currentAgencyShimmerView.isHidden {
            currentAgencyShimmerView.stopShimmering()
            currentAgencyShimmerView.startShimmering()
        }
        
        updateSegmentedBarPosition()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if model.isMyProfile {
            dmButton.addTarget(self, action: #selector(dmButtonTapped), for: .touchUpInside)
        }
    }
    
    
    // MARK: - Private
    
    private func setupContent() {
        setupHeaderImageView()
        setupBlurredHeaderImageView()
        setupScrollView()
        setupContentViewStack()
        setupSegmentedBar()
        setupContentLayout()
        setupAllCollectionsLayers()
        setupSimilarProfiles()
    }
    
    private func setupHeaderImageView() {
        self.view.addSubview(headerImageView)
        
        NSLayoutConstraint.activate([
            headerImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            headerImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            headerImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            headerImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
    }
    
    private func setupBlurredHeaderImageView() {
        self.view.addSubview(blurredHeaderImageView)
        
        NSLayoutConstraint.activate([
            blurredHeaderImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            blurredHeaderImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            blurredHeaderImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            blurredHeaderImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
    }
    
    private func setupScrollView() {
        self.view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
        
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor)
        navigationBarTitleHeightConstraint.isActive = true
        
        scrollView.delegate = self
    }
    
    private func setupContentViewStack() {
        scrollView.addSubview(contentViewStack)
        
        NSLayoutConstraint.activate([
            contentViewStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentViewStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentViewStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentViewStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentViewStack.widthAnchor.constraint(equalTo: self.view.widthAnchor),
        ])
    }
    
    private func setupSegmentedBar() {
        self.view.addSubview(segmentedBar)
        
        NSLayoutConstraint.activate([
            segmentedBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            segmentedBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            segmentedBar.heightAnchor.constraint(equalToConstant: segmentedBarHeight)
        ])
        
        segmentedBarTopConstraint = segmentedBar.topAnchor.constraint(equalTo: self.view.topAnchor)
        segmentedBarTopConstraint?.isActive = true
    }
    
    private func setupContentLayout() {
        setupHeaderContainer()
        setupCounterActionsContainer()
        setupProfileInfoContainer()
        setupCurrentAgencyContainer()
        setupAddWorkHistoryContainer()
        setupSocialMediaContainer()
        setupSegmentedBarPlaceholder()
    }
    
    private func setupHeaderContainer() {
        contentViewStack.addArrangedSubview(headerContainer)
        headerHeightConstraint = headerContainer.heightAnchor.constraint(equalToConstant: fixedHeaderHeight)
        headerHeightConstraint.isActive = true
        
        headerContainer.addSubview(infoStack)
        headerContainer.addSubview(headerSpinner)
        infoStack.addArrangedSubview(profileHeaderView)
        // Шиммер как overlay поверх profileHeaderView (не arranged subview),
        // чтобы избежать UIStackView-анимации при переключении isHidden
        profileHeaderShimmerView.translatesAutoresizingMaskIntoConstraints = false
        infoStack.addSubview(profileHeaderShimmerView)
        
        NSLayoutConstraint.activate([
            headerContainer.widthAnchor.constraint(equalTo: contentViewStack.widthAnchor),
            
            headerSpinner.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            headerSpinner.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor, constant: -150),

            infoStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            infoStack.heightAnchor.constraint(equalToConstant: 85),
            profileHeaderShimmerView.leadingAnchor.constraint(equalTo: infoStack.leadingAnchor),
            profileHeaderShimmerView.trailingAnchor.constraint(equalTo: infoStack.trailingAnchor),
            profileHeaderShimmerView.topAnchor.constraint(equalTo: infoStack.topAnchor),
            profileHeaderShimmerView.bottomAnchor.constraint(equalTo: infoStack.bottomAnchor),
        ])
    }
    
    private func setupCounterActionsContainer() {
        contentViewStack.addArrangedSubview(counterActionsContainer)
        counterActionsContainer.addSubview(actionsShimmerView)
        counterActionsContainer.addSubview(counterActionsStack)
        
        counterActionsStack.addArrangedSubview(dmButton)
        counterActionsStack.addArrangedSubview(likesView)
        counterActionsStack.addArrangedSubview(viewsView)
        counterActionsStack.addArrangedSubview(savesView)
        
        NSLayoutConstraint.activate([
            counterActionsContainer.topAnchor.constraint(equalTo: infoStack.bottomAnchor, constant: 20),
            counterActionsContainer.heightAnchor.constraint(equalToConstant: 36),
            counterActionsContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            counterActionsContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            
            actionsShimmerView.leadingAnchor.constraint(equalTo: counterActionsContainer.leadingAnchor, constant: 16),
            actionsShimmerView.trailingAnchor.constraint(equalTo: counterActionsContainer.trailingAnchor, constant: -16),
            actionsShimmerView.topAnchor.constraint(equalTo: counterActionsContainer.topAnchor),
            actionsShimmerView.bottomAnchor.constraint(equalTo: counterActionsContainer.bottomAnchor),
            
            counterActionsStack.leadingAnchor.constraint(equalTo: counterActionsContainer.leadingAnchor, constant: 16),
            counterActionsStack.trailingAnchor.constraint(equalTo: counterActionsContainer.trailingAnchor, constant: -16),
            counterActionsStack.topAnchor.constraint(equalTo: counterActionsContainer.topAnchor),
            counterActionsStack.bottomAnchor.constraint(equalTo: counterActionsContainer.bottomAnchor),
        ])
        
        contentViewStack.setCustomSpacing(12, after: counterActionsStack)
        contentViewStack.setCustomSpacing(12, after: actionsShimmerView)
    }
    
    private func setupProfileInfoContainer() {
        contentViewStack.addArrangedSubview(profileInfoContainer)
        profileInfoContainer.addSubview(profileInfoView)
        profileInfoContainer.addSubview(profileInfoShimmerView)
        
        NSLayoutConstraint.activate([
            profileInfoContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            profileInfoContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            
            profileInfoView.leadingAnchor.constraint(equalTo: profileInfoContainer.leadingAnchor, constant: 16),
            profileInfoView.trailingAnchor.constraint(equalTo: profileInfoContainer.trailingAnchor, constant: -16),
            profileInfoView.topAnchor.constraint(equalTo: profileInfoContainer.topAnchor),
            profileInfoView.bottomAnchor.constraint(equalTo: profileInfoContainer.bottomAnchor),
            
            profileInfoShimmerView.leadingAnchor.constraint(equalTo: profileInfoContainer.leadingAnchor, constant: 16),
            profileInfoShimmerView.trailingAnchor.constraint(equalTo: profileInfoContainer.trailingAnchor, constant: -16),
            profileInfoShimmerView.topAnchor.constraint(equalTo: profileInfoContainer.topAnchor),
            profileInfoShimmerView.bottomAnchor.constraint(equalTo: profileInfoContainer.bottomAnchor),
        ])
        
        contentViewStack.setCustomSpacing(20, after: profileInfoView)
    }
    
    private func setupCurrentAgencyContainer() {
        contentViewStack.addArrangedSubview(currentAgencyContainer)
        currentAgencyContainer.addSubview(currentAgencyView)
        currentAgencyContainer.addSubview(currentAgencyShimmerView)
        
        NSLayoutConstraint.activate([
            currentAgencyContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            currentAgencyContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            
            currentAgencyView.leadingAnchor.constraint(equalTo: currentAgencyContainer.leadingAnchor, constant: 16),
            currentAgencyView.trailingAnchor.constraint(equalTo: currentAgencyContainer.trailingAnchor, constant: -16),
            currentAgencyView.topAnchor.constraint(equalTo: currentAgencyContainer.topAnchor),
            currentAgencyView.bottomAnchor.constraint(equalTo: currentAgencyContainer.bottomAnchor),
            
            currentAgencyShimmerView.leadingAnchor.constraint(equalTo: currentAgencyContainer.leadingAnchor, constant: 16),
            currentAgencyShimmerView.trailingAnchor.constraint(equalTo: currentAgencyContainer.trailingAnchor, constant: -16),
            currentAgencyShimmerView.topAnchor.constraint(equalTo: currentAgencyContainer.topAnchor),
            currentAgencyShimmerView.bottomAnchor.constraint(equalTo: currentAgencyContainer.bottomAnchor),
        ])
    }
    
    private func setupAddWorkHistoryContainer() {
        contentViewStack.addArrangedSubview(addWorkHistoryContainer)
        addWorkHistoryContainer.addSubview(addWorkHistoryButton)
        
        NSLayoutConstraint.activate([
            addWorkHistoryContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor, constant: 16),
            addWorkHistoryContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor, constant: -16),
            addWorkHistoryContainer.heightAnchor.constraint(equalToConstant: 36),
            addWorkHistoryButton.leadingAnchor.constraint(equalTo: addWorkHistoryContainer.leadingAnchor),
            addWorkHistoryButton.centerYAnchor.constraint(equalTo: addWorkHistoryContainer.centerYAnchor),
            addWorkHistoryButton.heightAnchor.constraint(equalToConstant: 36),
            addWorkHistoryButton.widthAnchor.constraint(equalToConstant: 160),
        ])
        
        addWorkHistoryButton.addTarget(self, action: #selector(addWorkHistoryTapped), for: .touchUpInside)

        contentViewStack.setCustomSpacing(12, after: addWorkHistoryContainer)
    }

    @objc private func addWorkHistoryTapped() {
        let controller = AddWorkExperienceController(context: self.context)
        self.controller?.push(controller)
    }

    private func setupSocialMediaContainer() {
        contentViewStack.addArrangedSubview(titleEditContainer)
        titleEditContainer.addSubview(titleEditStack)
        titleEditStack.addArrangedSubview(editLinksLabel)
        titleEditStack.addArrangedSubview(UIView())
        titleEditStack.addArrangedSubview(editLinksButton)

        editLinksButton.addTarget(self, action: #selector(editLinksButtonTapped), for: .touchUpInside)
        
        contentViewStack.addArrangedSubview(socialMediaContainer)
        socialMediaContainer.addSubview(socialMediaStack)
        socialMediaContainer.addSubview(socialShimmerView)
        
        NSLayoutConstraint.activate([
            titleEditContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            titleEditContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            
            titleEditStack.leadingAnchor.constraint(equalTo: titleEditContainer.leadingAnchor, constant: 16),
            titleEditStack.trailingAnchor.constraint(equalTo: titleEditContainer.trailingAnchor, constant: -16),
            titleEditStack.topAnchor.constraint(equalTo: titleEditContainer.topAnchor),
            titleEditStack.bottomAnchor.constraint(equalTo: titleEditContainer.bottomAnchor),
            
            socialMediaContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            socialMediaContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            socialMediaStack.leadingAnchor.constraint(equalTo: socialMediaContainer.leadingAnchor, constant: 16),
            socialMediaStack.trailingAnchor.constraint(equalTo: socialMediaContainer.trailingAnchor, constant: -16),
            socialMediaStack.topAnchor.constraint(equalTo: socialMediaContainer.topAnchor),
            socialMediaStack.bottomAnchor.constraint(equalTo: socialMediaContainer.bottomAnchor),
            socialMediaStack.heightAnchor.constraint(equalToConstant: 68),
            
            socialShimmerView.leadingAnchor.constraint(equalTo: socialMediaContainer.leadingAnchor, constant: 16),
            socialShimmerView.trailingAnchor.constraint(equalTo: socialMediaContainer.trailingAnchor, constant: -16),
            socialShimmerView.topAnchor.constraint(equalTo: socialMediaContainer.topAnchor),
            socialShimmerView.bottomAnchor.constraint(equalTo: socialMediaContainer.bottomAnchor),
            socialShimmerView.heightAnchor.constraint(equalToConstant: 68),
        ])
        
        contentViewStack.setCustomSpacing(8, after: socialMediaStack)
        contentViewStack.setCustomSpacing(8, after: socialShimmerView)
        contentViewStack.setCustomSpacing(4, after: titleEditContainer)
        
        socialHeightConstraint = socialMediaStack.heightAnchor.constraint(equalToConstant: 68)
        socialHeightConstraint.isActive = true
    }
    
    private func setupSegmentedBarPlaceholder() {
        contentViewStack.addArrangedSubview(segmentedBarPlaceholder)
        
        NSLayoutConstraint.activate([
            segmentedBarPlaceholder.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor, constant: 0),
            segmentedBarPlaceholder.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor, constant: 0),
            segmentedBarPlaceholder.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        contentViewStack.setCustomSpacing(0, after: segmentedBarPlaceholder)
    }
    
    private func setupAllCollectionsLayers() {
        contentViewStack.addArrangedSubview(collectionsContainer)
        
        collectionsContainerHeightConstraint = collectionsContainer.heightAnchor.constraint(equalToConstant: 160)
        collectionsContainerHeightConstraint.isActive = true
        
        let containers = [photoTabContainer, videoTabContainer, channelTabContainer, modelTabContainer, eventTabContainer]
        for container in containers {
            collectionsContainer.addSubview(container)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: collectionsContainer.topAnchor),
                container.leadingAnchor.constraint(equalTo: collectionsContainer.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: collectionsContainer.trailingAnchor),
                container.bottomAnchor.constraint(equalTo: collectionsContainer.bottomAnchor)
            ])
        }
        
        // --- PHOTO ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        galleryHeightConstraint = galleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        galleryHeightConstraint.isActive = true
        
        photoTabContainer.addSubview(galleryCollectionView)
        photoTabContainer.addSubview(galleryStatusView)

        NSLayoutConstraint.activate([
            galleryCollectionView.topAnchor.constraint(equalTo: photoTabContainer.topAnchor),
            galleryCollectionView.leadingAnchor.constraint(equalTo: photoTabContainer.leadingAnchor),
            galleryCollectionView.trailingAnchor.constraint(equalTo: photoTabContainer.trailingAnchor),

            galleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            galleryStatusView.topAnchor.constraint(equalTo: photoTabContainer.topAnchor),
            galleryStatusView.leadingAnchor.constraint(equalTo: photoTabContainer.leadingAnchor, constant: 16),
            galleryStatusView.trailingAnchor.constraint(equalTo: photoTabContainer.trailingAnchor, constant: -16),
        ])
        galleryCollectionView.isHidden = true
        galleryStatusView.isHidden = false
        galleryStatusView.configure(isLoading: true, text: DivoStrings.uploadingPhotos, isMyProfile: false)
        galleryStatusView.addTarget(self, action: #selector(galleryStatusTapped), for: .touchUpInside)

        // --- VIDEO ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        videoHeightConstraint = videoGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        videoHeightConstraint.isActive = true
        
        videoTabContainer.addSubview(videoGalleryCollectionView)
        videoTabContainer.addSubview(videoGalleryStatusView)

        NSLayoutConstraint.activate([
            videoGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            videoGalleryStatusView.topAnchor.constraint(equalTo: videoTabContainer.topAnchor),
            videoGalleryStatusView.leadingAnchor.constraint(equalTo: videoTabContainer.leadingAnchor, constant: 16),
            videoGalleryStatusView.trailingAnchor.constraint(equalTo: videoTabContainer.trailingAnchor, constant: -16),
            
            videoGalleryCollectionView.topAnchor.constraint(equalTo: videoTabContainer.topAnchor),
            videoGalleryCollectionView.leadingAnchor.constraint(equalTo: videoTabContainer.leadingAnchor),
            videoGalleryCollectionView.trailingAnchor.constraint(equalTo: videoTabContainer.trailingAnchor)
        ])
        videoGalleryCollectionView.isHidden = true
        videoGalleryStatusView.isHidden = false
        videoGalleryStatusView.configure(isLoading: true, text: DivoStrings.uploadingVideos, isMyProfile: false)
        videoGalleryStatusView.addTarget(self, action: #selector(videoGalleryStatusTapped), for: .touchUpInside)

        // --- CHANNELS ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        channelHeightConstraint = channelGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        channelHeightConstraint.isActive = true
        
        channelTabContainer.addSubview(channelGalleryStatusView)
        channelTabContainer.addSubview(channelGalleryCollectionView)
        NSLayoutConstraint.activate([
            channelGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            channelGalleryStatusView.topAnchor.constraint(equalTo: channelTabContainer.topAnchor),
            channelGalleryStatusView.leadingAnchor.constraint(equalTo: channelTabContainer.leadingAnchor, constant: 16),
            channelGalleryStatusView.trailingAnchor.constraint(equalTo: channelTabContainer.trailingAnchor, constant: -16),
            
            channelGalleryCollectionView.topAnchor.constraint(equalTo: channelTabContainer.topAnchor),
            channelGalleryCollectionView.leadingAnchor.constraint(equalTo: channelTabContainer.leadingAnchor),
            channelGalleryCollectionView.trailingAnchor.constraint(equalTo: channelTabContainer.trailingAnchor)
        ])
        channelGalleryCollectionView.isHidden = true
        channelGalleryStatusView.isHidden = false
        channelGalleryStatusView.configure(isLoading: true, text: DivoStrings.loadingChannels, isMyProfile: false)
        
        // --- MODELS ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        modelHeightConstraint = modelGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        modelHeightConstraint.isActive = true
        
        modelTabContainer.addSubview(modelGalleryStatusView)
        modelTabContainer.addSubview(modelGalleryCollectionView)

        emptyModelsPlaceholderNode.view.translatesAutoresizingMaskIntoConstraints = false
        modelTabContainer.addSubview(emptyModelsPlaceholderNode.view)

        NSLayoutConstraint.activate([
            modelGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            modelGalleryStatusView.topAnchor.constraint(equalTo: modelTabContainer.topAnchor),
            modelGalleryStatusView.leadingAnchor.constraint(equalTo: modelTabContainer.leadingAnchor, constant: 16),
            modelGalleryStatusView.trailingAnchor.constraint(equalTo: modelTabContainer.trailingAnchor, constant: -16),
            
            modelGalleryCollectionView.topAnchor.constraint(equalTo: modelTabContainer.topAnchor),
            modelGalleryCollectionView.leadingAnchor.constraint(equalTo: modelTabContainer.leadingAnchor),
            modelGalleryCollectionView.trailingAnchor.constraint(equalTo: modelTabContainer.trailingAnchor),

            emptyModelsPlaceholderNode.view.topAnchor.constraint(equalTo: modelTabContainer.topAnchor),
            emptyModelsPlaceholderNode.view.leadingAnchor.constraint(equalTo: modelTabContainer.leadingAnchor),
            emptyModelsPlaceholderNode.view.trailingAnchor.constraint(equalTo: modelTabContainer.trailingAnchor),
            emptyModelsPlaceholderNode.view.bottomAnchor.constraint(equalTo: modelTabContainer.bottomAnchor),
        ])
        modelGalleryCollectionView.isHidden = true
        emptyModelsPlaceholderNode.isHidden = true
        modelGalleryStatusView.isHidden = false
        modelGalleryStatusView.configure(isLoading: true, text: DivoStrings.loadingModels, isMyProfile: false)
        
        emptyModelsPlaceholderNode.addButton.addTarget(self, action: #selector(addModelBtnTapped), forControlEvents: .touchUpInside)

        // --- EVENTS ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        eventHeightConstraint = eventGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        eventHeightConstraint.isActive = true
        
        eventTabContainer.addSubview(eventGalleryStatusView)
        eventTabContainer.addSubview(eventGalleryCollectionView)
        NSLayoutConstraint.activate([
            eventGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            eventGalleryStatusView.topAnchor.constraint(equalTo: eventTabContainer.topAnchor),
            eventGalleryStatusView.leadingAnchor.constraint(equalTo: eventTabContainer.leadingAnchor, constant: 16),
            eventGalleryStatusView.trailingAnchor.constraint(equalTo: eventTabContainer.trailingAnchor, constant: -16),
            
            eventGalleryCollectionView.topAnchor.constraint(equalTo: eventTabContainer.topAnchor),
            eventGalleryCollectionView.leadingAnchor.constraint(equalTo: eventTabContainer.leadingAnchor),
            eventGalleryCollectionView.trailingAnchor.constraint(equalTo: eventTabContainer.trailingAnchor)
        ])
        eventGalleryCollectionView.isHidden = true
        eventGalleryStatusView.isHidden = false
        eventGalleryStatusView.configure(isLoading: true, text: DivoStrings.loadingEvents, isMyProfile: false)
    }
    
    private func setupSimilarProfiles() {
        contentViewStack.addArrangedSubview(similarProfilesCollectionContainer)
        similarProfilesCollectionContainer.addSubview(similarProfilesTitleLabel)
        similarProfilesCollectionContainer.addSubview(similarProfilesCollectionView)
        
        NSLayoutConstraint.activate([
            similarProfilesTitleLabel.topAnchor.constraint(equalTo: similarProfilesCollectionContainer.topAnchor, constant: 16),
            similarProfilesTitleLabel.leadingAnchor.constraint(equalTo: similarProfilesCollectionContainer.leadingAnchor, constant: 16),
            similarProfilesTitleLabel.trailingAnchor.constraint(equalTo: similarProfilesCollectionContainer.trailingAnchor, constant: -16),
            
            similarProfilesCollectionView.topAnchor.constraint(equalTo: similarProfilesTitleLabel.topAnchor, constant: 16),
            similarProfilesCollectionView.leadingAnchor.constraint(equalTo: similarProfilesCollectionContainer.leadingAnchor),
            similarProfilesCollectionView.trailingAnchor.constraint(equalTo: similarProfilesCollectionContainer.trailingAnchor),
            similarProfilesCollectionView.bottomAnchor.constraint(equalTo: similarProfilesCollectionContainer.bottomAnchor, constant: -30),
            similarProfilesCollectionView.heightAnchor.constraint(equalToConstant: 232)
        ])
        
        contentViewStack.setCustomSpacing(0, after: collectionsContainer)
        
        contentViewStack.setCustomSpacing(0, after: videoGalleryCollectionView)
        contentViewStack.setCustomSpacing(0, after: videoGalleryStatusView)
        
        contentViewStack.setCustomSpacing(0, after: channelGalleryCollectionView)
        contentViewStack.setCustomSpacing(0, after: channelGalleryStatusView)
        
        contentViewStack.setCustomSpacing(0, after: modelGalleryCollectionView)
        contentViewStack.setCustomSpacing(0, after: modelGalleryStatusView)
        
        contentViewStack.setCustomSpacing(0, after: eventGalleryCollectionView)
        contentViewStack.setCustomSpacing(0, after: eventGalleryStatusView)
    }
    
    // Настройка шиммеров
    private func configureNodes() {
        profileHeaderShimmerView.isHidden = false
        profileHeaderView.isHidden = true
        
        actionsShimmerView.isHidden = false
        counterActionsStack.isHidden = true
        
        profileInfoShimmerView.isHidden = false
        
        socialShimmerView.isHidden = false
        
        currentAgencyShimmerView.isHidden = false
        
        if !model.isMyProfile {
            self.addWorkHistoryContainer.removeFromSuperview()
        }
    }
    
    // Убираем шиммеры, после загрузки
    private func stopShimmers() {
        guard !profileHeaderShimmerView.isHidden else { return }

        // Важно: переключение шиммеров на контент должно быть без каких-либо анимаций,
        // иначе некоторые блоки (например Current Agency) визуально «дергаются».
        UIView.performWithoutAnimation {
            // Полностью отключаем все implicit animations
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setAnimationDuration(0.0)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))

            profileHeaderShimmerView.isHidden = true
            profileHeaderView.alpha = 1.0
            profileHeaderView.isHidden = false

            actionsShimmerView.isHidden = true
            counterActionsStack.alpha = 1.0
            counterActionsStack.isHidden = false

            profileInfoShimmerView.isHidden = true

            socialShimmerView.isHidden = true

            currentAgencyShimmerView.isHidden = true

            // Принудительно обновляем layout внутри CATransaction,
            // чтобы изменения фреймов тоже не были анимированы
            self.contentViewStack.setNeedsLayout()
            self.contentViewStack.layoutIfNeeded()
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            CATransaction.commit()
        }
    }
    
    private func applyGradientBlurMask() {
        let blurHeight = blurredHeaderImageView.bounds.height
        guard blurHeight > 0 else { return }
        let blurStartPoint = blurHeight * 0.02
        let blurFullPoint = blurHeight * 0.55
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = blurredHeaderImageView.bounds
        
        let startLocation = blurStartPoint / blurHeight
        let fullLocation = blurFullPoint / blurHeight
        
        let clampedStartLocation = max(0.0, min(1.0, startLocation))
        let clampedFullLocation = max(0.0, min(1.0, fullLocation))
        
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor]
        
        gradientLayer.locations = [NSNumber(value: Double(clampedStartLocation)),
                                   NSNumber(value: Double(clampedFullLocation))]
        
        blurredHeaderImageView.layer.mask = gradientLayer
    }
    
    // Настройка SegmentedBar для прилипания
    private func updateSegmentedBarPosition() {
        guard let (_, navigationBarHeight) = self.containerLayout else { return }
        
        let placeholderFrame = segmentedBarPlaceholder.convert(segmentedBarPlaceholder.bounds, to: self.view)
        
        let naturalY = placeholderFrame.minY
        
        let stickyY = navigationBarHeight
        
        let finalY = max(naturalY, stickyY)
        
        segmentedBarTopConstraint?.constant = finalY
        
        if finalY <= stickyY + 1 {
            segmentedBar.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        } else {
            segmentedBar.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        }
    }
    
    // Настройка кнопки чата/загрузки фотографии
    private func setupDmButtonContent() {
        var iconImageName = "Chat/Context Menu/MessageBubble"
        var labelText = DivoStrings.sendDM
        if model.isMyProfile {
            iconImageName = "Avatar/AddAvatarIconLarge"
            labelText = DivoStrings.uploadYourPhotos
        }

        // Важно: не пересоздаем subviews каждый раз (иначе UI заметно дергается при обновлениях)
        if let iconImageView = dmButton.viewWithTag(ActionViewTags.dmIcon) as? UIImageView,
           let label = dmButton.viewWithTag(ActionViewTags.dmLabel) as? UILabel {
            iconImageView.image = UIImage(bundleImageName: iconImageName)
            label.text = labelText
            return
        }

        dmButton.subviews.forEach { $0.removeFromSuperview() }
        
        let iconImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.image = UIImage(bundleImageName: iconImageName)
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.tag = ActionViewTags.dmIcon
            return imageView
        }()
        
        let label: UILabel = {
            let label = UILabel()
            label.text = labelText
            label.textColor = .white
            label.font = Font.helveticaNeue(13)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.tag = ActionViewTags.dmLabel
            return label
        }()
        
        let stackView: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [iconImageView, label])
            stack.axis = .horizontal
            stack.spacing = 4
            stack.alignment = .center
            stack.isUserInteractionEnabled = false
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        
        dmButton.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: dmButton.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: dmButton.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])
    }

    // Создание кнопок счетчиков (лайки, просмотры, сохраненки)
    private func setupCounterView(_ container: UIControl, count: String, name: String, iconName: String) {
        // Важно: не пересоздаем subviews/constraints каждый раз.
        // Иначе при повторных updateWithUserDetail / refresh будет заметный «рывок».
        if let iconImageView = container.viewWithTag(ActionViewTags.counterIcon) as? UIImageView,
           let countLabel = container.viewWithTag(ActionViewTags.counterCountLabel) as? UILabel,
           let nameLabel = container.viewWithTag(ActionViewTags.counterNameLabel) as? UILabel {
            iconImageView.image = UIImage(bundleImageName: iconName)
            countLabel.text = count
            nameLabel.text = name
            return
        }

        container.subviews.forEach { $0.removeFromSuperview() }
        
        let icon: UIImageView = {
            let imageView = UIImageView()
            imageView.image = UIImage(bundleImageName: iconName)
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
            imageView.tag = ActionViewTags.counterIcon
            return imageView
        }()
        
        let countLabel: UILabel = {
            let label = UILabel()
            label.text = count
            label.font = UIFont.boldSystemFont(ofSize: 14)
            label.textColor = .white
            label.tag = ActionViewTags.counterCountLabel
            return label
        }()
        
        let nameLabel: UILabel = {
            let label = UILabel()
            label.text = name
            label.font = UIFont.systemFont(ofSize: 10)
            label.textColor = .white
            label.tag = ActionViewTags.counterNameLabel
            return label
        }()
        
        let countStack: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [icon, countLabel])
            stack.axis = .horizontal
            stack.spacing = 2
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        
        let mainStack: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [countStack, nameLabel])
            stack.axis = .horizontal
            stack.spacing = 4
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.isUserInteractionEnabled = false
            return stack
        }()
        
        container.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            mainStack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 0),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: 0),
        ])
        
        container.removeTarget(nil, action: nil, for: .allEvents)
        container.addTarget(self, action: #selector(handleTouchDown(_:)), for: [.touchDown, .touchDragEnter])
        container.addTarget(self, action: #selector(handleTouchUp(_:)), for:[.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        
        if container === likesView {
            container.addTarget(self, action: #selector(likesViewDidTap), for: .touchUpInside)
        } else if container === viewsView {
            container.addTarget(self, action: #selector(viewsViewDidTap), for: .touchUpInside)
        } else if container === savesView {
            container.addTarget(self, action: #selector(savesViewDidTap), for: .touchUpInside)
        }
    }
    
    // Создание кнопок социальных сетей
    private func createSocialMediaButton(handle: String, iconName: String, url: String) -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = .black.withAlphaComponent(0.12)
        button.layer.cornerRadius = 6

        socialLinksMap[button] = url
        
        let icon = UIImageView()
        icon.image = UIImage(bundleImageName: iconName)
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        let label = UILabel()
        label.text = handle
        label.font = Font.helveticaNeue(10)
        label.textColor = .white
        
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 5
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        
        button.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
        ])

        button.addTarget(self, action: #selector(socialButtonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    // Создание кнопоки социально сети, если она одна
    private func createSocialOneMediaButton(handle: String, iconName: String, url: String) -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = .black.withAlphaComponent(0.12)
        button.layer.cornerRadius = 6

        socialLinksMap[button] = url
        
        let icon = UIImageView()
        icon.image = UIImage(bundleImageName: iconName)
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        let label = UILabel()
        label.text = handle
        label.font = Font.helveticaNeue(10)
        label.textColor = .white
        
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 5
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false

        button.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])

        button.addTarget(self, action: #selector(socialButtonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    // Добавление коллекции похожих профилей
    private func appendSimilarProfiles(_ profiles: [SimilarProfileItem], totalCount: Int) {
        let previousCount = self.similarProfiles.count
        self.similarProfiles.append(contentsOf: profiles)
        self.similarProfilesTotalCount = totalCount
        self.similarProfilesOffset = self.similarProfiles.count
        self.similarProfilesHasMore = self.similarProfiles.count < totalCount
        
        // debug: removed
        
        if previousCount == 0 {
            similarProfilesCollectionView.reloadData()
        } else {
            let newIndices = (previousCount..<(previousCount + profiles.count)).map { IndexPath(item: $0, section: 0) }
            similarProfilesCollectionView.insertItems(at: newIndices)
        }
    }
    
    // Вычисляем возраст от года рождения
    private func calculateAge(from birthdayString: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let birthday = formatter.date(from: birthdayString) else { return 0 }
        
        let now = Date()
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthday, to: now)
        return ageComponents.year ?? 0
    }
    
    // Создаем список критериев внешнего вида модели
    private func buildAppearanceList(from appearance: UserAppearance?, gender: UserGender?) -> [AppearanceAttribute] {
        
        var items: [AppearanceAttribute] = []
        
        if let gender = gender {
            items.append(.init(title: DivoStrings.attrGender, value: "\(gender.title)"))
        }

        if let appearance = appearance {
            if let height = appearance.height {
                items.append(.init(title: DivoStrings.attrHeight, value: "\(height.clean) \(DivoStrings.unitCm)"))
            }
            if let weight = appearance.weight {
                items.append(.init(title: DivoStrings.attrWeight, value: "\(weight.clean) \(DivoStrings.unitKg)"))
            }
            if let bust = appearance.breastSize {
                items.append(.init(title: DivoStrings.attrBust, value: bust))
            }
            if let waist = appearance.waist {
                items.append(.init(title: DivoStrings.attrWaist, value: "\(waist.clean) \(DivoStrings.unitCm)"))
            }
            if let hips = appearance.hips {
                items.append(.init(title: DivoStrings.attrHips, value: "\(hips.clean) \(DivoStrings.unitCm)"))
            }
            if let shoesSize = appearance.shoesSize {
                items.append(.init(title: DivoStrings.attrShoes, value: "\(shoesSize.clean) \(DivoStrings.unitEU)"))
            }
            if let hairColor = appearance.hairColor?.title {
                items.append(.init(title: DivoStrings.attrHairColor, value: hairColor))
            }
            if let hairLength = appearance.hairLength?.title {
                items.append(.init(title: DivoStrings.attrHairLength, value: hairLength))
            }
            if let eyeColor = appearance.eyeColor?.title {
                items.append(.init(title: DivoStrings.attrEyeColor, value: eyeColor))
            }
            if let skinColor = appearance.skinColor?.title {
                items.append(.init(title: DivoStrings.attrSkinColor, value: skinColor))
            }
        }
        
        return items
    }
    
    // Создаем все кнопки социальный сетей
    private func populateSocialMedia(links: [String]) {
        
        socialMediaStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        socialLinksMap.removeAll()
        
        if !links.isEmpty {
            for link in links {
                let iconName = SocialIcon.icon(for: link)
                let handle = extractHandle(from: link)
                
                if links.count == 1 {
                    socialMediaStack.addArrangedSubview(createSocialOneMediaButton(handle: handle, iconName: iconName, url: link))
                } else {
                    socialMediaStack.addArrangedSubview(createSocialMediaButton(handle: handle, iconName: iconName, url: link))
                }
            }
        }
        
        let shouldBeVisible = !links.isEmpty
        
        if socialMediaContainer.isHidden == shouldBeVisible {
            UIView.animate(withDuration: 0.3, animations: {
                self.socialMediaContainer.isHidden = !shouldBeVisible
                self.contentViewStack.layoutIfNeeded()
            })
        }
    }
        
    // Получаем картинку флага в зависимости от кода страны
    private static func flag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }
    
    // Первоначальная настройка титула NavigationBar
    private func setupNavigationBarTitle(name: String, info: String? = nil) {
        // Проверяем, не создаем ли мы titleView повторно
        if let existingTitleView = self.navigationBarTitleView {
            existingTitleView.configure(name: name, info: info)
        } else {
            let titleView = ProfileNavigationBarTitleView()
            
            titleView.configure(name: name, info: info)
            
            self.navigationBarTitleView = titleView
            
            if let controller = self.controller {
                controller.navigationItem.titleView = titleView
            }
        }

        // Важно: после загрузки titleView НЕ должен появляться мгновенно.
        // Делаем состояние консистентным сразу после конфигурации.
        if !titleVisibilityActivated {
            navigationBarTitleView?.alpha = 0.0
        }
        updateNavigationBarTitleVisibility()
    }
    
    // Обновление титула NavigationBar
    private func updateNavigationBarTitleVisibility() {
        guard let titleView = navigationBarTitleView,
              let (_, navigationBarHeight) = self.containerLayout else { return }

        // Пока мы не активировали механику появления заголовка (после загрузки данных),
        // держим его скрытым — он должен появляться только при скролле.
        guard titleVisibilityActivated else {
            if titleView.alpha != 0.0 {
                titleView.alpha = 0.0
            }
            return
        }
        
        let offsetY = scrollView.contentOffset.y
        
        let headerBottomPoint = fixedProfileHeaderHeight - navigationBarHeight
        
        let startShowingOffset = headerBottomPoint - 40
        let fullyVisibleOffset = headerBottomPoint + 60
        
        var alpha: CGFloat = 0.0
        
        if offsetY < startShowingOffset {
            alpha = 0.0
        } else if offsetY >= fullyVisibleOffset {
            alpha = 1.0
        } else {
            alpha = (offsetY - startShowingOffset) / (fullyVisibleOffset - startShowingOffset)
        }
        
        if titleView.alpha != alpha {
            titleView.alpha = alpha
        }
    }
    
    // Активация анимации заголовка навбара
    private func activateTitleVisibility() {
        guard !titleVisibilityActivated else { return }
        titleVisibilityActivated = true
        
        // Принудительно обновляем layout, чтобы анимация заголовка заработала
        self.setNeedsLayout()
        self.layoutIfNeeded()

        // И сразу же пересчитываем видимость заголовка для текущего offset.
        updateNavigationBarTitleVisibility()
    }
    
    
    // MARK: - Internal

    // Функция для извлечения имени пользователя или домена
    func extractHandle(from urlString: String) -> String {
        let cleaned = urlString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        
        let components = cleaned.split(separator: "/")
        
        if cleaned.starts(with: "t.me"), components.count > 1 {
            return String(components[1])
        }
        
        if let first = components.first, (first.contains("instagram") || first.contains("youtube") || first.contains("tiktok")), components.count > 1 {
            return String(components[1])
        }
        
        return String(components.first ?? "")
    }
    
    func loadSimilarProfiles() {
        guard !similarProfilesIsLoading else { return }
        similarProfilesIsLoading = true

        let currentUserId = model.userId
        let limit = 10

        let requestBody = FeedlineListRequest(
            offset: similarProfilesOffset,
            limit: limit,
            modelsOnly: true
        )

        Task { @MainActor in
            do {
                let response: FeedlineResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/list",
                    method: "POST",
                    body: requestBody
                )
                let items = response.data.items
                let profiles = items.compactMap { item -> SimilarProfileItem? in
                    guard item.user.id != currentUserId else { return nil }
                    let imageURL = CDNURLHelper.convertToCDNURL(
                        item.searchImage?.fullUrl ?? item.files.first?.fullUrl
                    )
                    return SimilarProfileItem(
                        id: item.user.id,
                        name: item.user.fullName,
                        info: item.user.roleLabel,
                        avatarURL: imageURL
                    )
                }
                self.similarProfilesIsLoading = false
                self.similarProfilesHasMore = items.count >= limit
                appendSimilarProfiles(profiles, totalCount: similarProfilesOffset + profiles.count + (similarProfilesHasMore ? 1 : 0))
            } catch {
                print("❌ [SIMILAR] Error loading similar profiles: \(error)")
                self.similarProfilesIsLoading = false
            }
        }
    }
    
    // Обновляем Layout после загрузки контроллера
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        navigationBarTitleHeightConstraint.isActive = false
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: navigationBarHeight)
        navigationBarTitleHeightConstraint.isActive = true
        contentViewStack.setCustomSpacing((-235 - navigationBarHeight), after: headerContainer)
        
        applyGradientBlurMask()
        
        updateAllCollectionViewHeights(layout: layout)
        updateCollectionsContainerHeight(animated: false)
        
        galleryCollectionView.collectionViewLayout.invalidateLayout()
        videoGalleryCollectionView.collectionViewLayout.invalidateLayout()
        channelGalleryCollectionView.collectionViewLayout.invalidateLayout()
        modelGalleryCollectionView.collectionViewLayout.invalidateLayout()
        eventGalleryCollectionView.collectionViewLayout.invalidateLayout()
        
        updateNavigationBarTitleVisibility()
        
        self.layoutIfNeeded()
    }

    func setBackgroundLoading(_ loading: Bool) {
        if loading {
            headerSpinner.startAnimating()
            headerImageView.alpha = 0.5
        } else {
            headerSpinner.stopAnimating()
            headerImageView.alpha = 1.0
        }
    }
    
    func updateBackgroundImage(_ image: UIImage?) {
        if let image = image {
            headerImageView.image = image
        }
    }
    
    // Обновление профиля, после загрузки baseURL/user/userId
    func updateWithUserDetail(_ detail: UserDetail, _ isMyProfile: Bool) {
        var bio: String
        var appearance: [AppearanceAttribute]

        self.modelRole = Role(apiRole: detail.role)

        if self.modelRole == .agency {
            setupNavigationBarTitle(name: detail.agency?.title ?? DivoStrings.noName)
            
            if let photoURLString = detail.agency?.background?.fullUrl, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
                headerImageView.loadImage(from: photoURL)
            }
            
            bio = (detail.agency?.description?.isEmpty == false)
            ? (detail.agency?.description ?? "")
            : Self.mockBiographyText
            
            UIView.performWithoutAnimation {
                profileInfoView.update(biography: bio)
                profileInfoView.layoutIfNeeded()
            }
            currentAgencyContainer.removeFromSuperview()
            segmentedBar.configure(isAgency: true, isMyProfile: isMyProfile)
            self.addWorkHistoryContainer.removeFromSuperview()

            if let avatarURLString = detail.agency?.photo?.fullUrl {
                if let avatarURL = CDNURLHelper.convertToCDNURL(avatarURLString) {
                    ImageLoader.shared.load(url: avatarURL) { [weak self] image in
                        if let image = image {
                            self?.profileHeaderView.changeAvatar(with: image)
                        }
                    }
                }
            }
        } else {
            let age = detail.birthday.flatMap { calculateAge(from: $0) } ?? 0
            setupNavigationBarTitle(name: detail.fullName ?? DivoStrings.noName, info: "\(DivoStrings.ageString(age)) • \(detail.city?.name ?? "")")
            
            if let photoURLString = detail.photo?.fullUrl, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
                headerImageView.loadImage(from: photoURL)
            }
            
            bio = (detail.model?.description?.isEmpty == false)
            ? (detail.model?.description ?? "")
            :  (isMyProfile ? Self.mockBiographyMyProfileText : Self.mockBiographyText)
            
            appearance = buildAppearanceList(from: detail.model?.appearance, gender: detail.gender)
            
            UIView.performWithoutAnimation {
                profileInfoView.update(biography: bio, appearance: appearance)
                profileInfoView.layoutIfNeeded()
            }
            if detail.model?.agency == nil {
                currentAgencyContainer.removeFromSuperview()
            } else {
                let logoURLString = detail.model?.agency?.photo?.fullUrl
                let logoURL = logoURLString != nil ? URL(string: logoURLString!) : nil
                currentAgencyView.configure(name: detail.model?.agency?.title, logoURL: logoURL)
            }
            segmentedBar.configure(isAgency: false, isMyProfile: isMyProfile)

            if let avatarURLString = detail.avatar?.fullUrl {
                if let avatarURL = CDNURLHelper.convertToCDNURL(avatarURLString) {
                    ImageLoader.shared.load(url: avatarURL) { [weak self] image in
                        if let image = image {
                            self?.profileHeaderView.changeAvatar(with: image)
                        }
                    }
                }
            }
        }

        var socialLinks: [String] = []

        // Собираем все непустые ссылки в один массив
        if let tiktok = detail.model?.tiktokUrl, !tiktok.isEmpty { socialLinks.append(tiktok) }
        if let youtube = detail.model?.youtubeUrl, !youtube.isEmpty { socialLinks.append(youtube) }
        if let telegram = detail.model?.telegramUrl, !telegram.isEmpty { socialLinks.append(telegram) }
        if let instagram = detail.model?.instagramUrl, !instagram.isEmpty { socialLinks.append(instagram) }
        if let website = detail.model?.websiteUrl, !website.isEmpty { socialLinks.append(website) }
        
        populateSocialMedia(links: socialLinks)

        if !isMyProfile {
            similarProfilesCollectionContainer.isHidden = false
            dmButton.isHidden = false
            setupDmButtonContent()
            titleEditContainer.removeFromSuperview()
        } else {
            titleEditContainer.isHidden = !socialLinks.isEmpty ? false : true
        }
        
        UIView.performWithoutAnimation {
            if self.modelRole == .agency {
                let viewModel = UserProfileViewModel(
                    name: detail.agency?.title ?? DivoStrings.noName,
                    age: nil,
                    location: detail.agency?.address?.city?.name ?? "",
                    countryFlag: Self.flag(for: detail.agency?.address?.city?.countryCode),
                    role: self.modelRole,
                    avatarImage: nil,
                    isPremium: true,
                    isOnline: true
                )
                profileHeaderView.configure(with: viewModel)
            } else {
                let age = detail.birthday.flatMap { calculateAge(from: $0) } ?? 0
                let viewModel = UserProfileViewModel(
                    name: detail.fullName ?? DivoStrings.noName,
                    age: age,
                    location: detail.city?.name ?? "",
                    countryFlag: Self.flag(for: detail.city?.countryCode),
                    role: self.modelRole,
                    avatarImage: nil,
                    isPremium: true,
                    isOnline: true
                )
                profileHeaderView.configure(with: viewModel)
            }
        }
        stopShimmers()
        activateTitleVisibility()
    }

    func updateEngagementStats(likes: Int, views: Int, saves: Int) {
        setupCounterView(likesView, count: "\(likes)", name: DivoStrings.counterLike, iconName: "Instant View/Favorite")
        setupCounterView(viewsView, count: "\(views)", name: DivoStrings.counterViewed, iconName: "Instant View/Visibility")
        setupCounterView(savesView, count: "\(saves)", name: DivoStrings.counterSave, iconName: "Instant View/Bookmark")
    }
    
    // Добавление фотографий в галерею пагинацией
    func appendGalleryPhotos(_ photos: UserPhotos, isMyProfile: Bool) {
        let newPhotos = photos.items
        let totalCount = photos.pagination.meta.totalCount
        let serverOffset = photos.pagination.meta.currentOffset
        
        if !galleryInitialized {
            self.galleryPhotos = []
            galleryInitialized = true
            // debug: pagination logs removed
        }
        
        let previousCount = self.galleryPhotos.count
        self.galleryPhotos.append(contentsOf: newPhotos)
        
        self.galleryCurrentOffset = serverOffset
        self.galleryHasMore = self.galleryPhotos.count < totalCount
        self.galleryIsLoading = false
        
        // debug: pagination logs removed
        
        if previousCount == 0 {
            let hasPhotos = !self.galleryPhotos.isEmpty
            self.galleryStatusView.isHidden = hasPhotos
            if isMyProfile {
                self.galleryStatusView.configure(isLoading: false, text: DivoStrings.uploadYourPhotos, isMyProfile: true)
            } else {
                self.galleryStatusView.configure(isLoading: false, text: DivoStrings.noVideosYet, isMyProfile: false)
            }
            self.galleryCollectionView.isHidden = !hasPhotos
            self.galleryCollectionView.reloadData()
            
            if let layout = self.containerLayout?.0 {
                self.updateAllCollectionViewHeights(layout: layout)
                if self.currentTabIndex == 0 { self.updateCollectionsContainerHeight(animated: false) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.checkAndLoadMoreGalleryPhotos()
            }
        } else {
            let newIndices = (previousCount..<(previousCount + newPhotos.count)).map { IndexPath(item: $0, section: 0) }
            self.galleryCollectionView.performBatchUpdates({
                self.galleryCollectionView.insertItems(at: newIndices)
                if let layout = self.containerLayout?.0 {
                    self.updateAllCollectionViewHeights(layout: layout)
                    if self.currentTabIndex == 0 { self.updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { [weak self] _ in
                self?.checkAndLoadMoreGalleryPhotos()
            })
        }
    }
    
    // Обновление высоты коллекции галереи
    private func updateGalleryCollectionViewHeight() {
        guard let (layout, _) = self.containerLayout else { return }
        
        let itemsPerRow: CGFloat = 3
        let spacing: CGFloat = 1
        let totalWidth = layout.size.width
        let itemWidth = (totalWidth - 2 * spacing) / itemsPerRow
        
        let totalItems = galleryPhotos.count
        let rows = ceil(CGFloat(totalItems) / itemsPerRow)
        let galleryHeight = rows * itemWidth + (rows - 1) * spacing
        
        galleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
        galleryCollectionView.heightAnchor.constraint(equalToConstant: galleryHeight).isActive = true
        
        galleryCollectionView.layoutIfNeeded()
    }

    // MARK: - Tab Switching

    func switchToTab(_ index: Int) {
        segmentedBar.selectIndex(index)
    }

    // MARK: - Photo Upload with Placeholder

    func startPhotoUpload(image: UIImage) {
        switchToTab(0)
        uploadingPhotoImage = image
        let placeholder = UserPhoto(id: -1, photo: UserFile(fileName: "", fullUrl: nil, fileExtension: "", fileUuid: ""), likesCount: 0, isLikedByUser: false, preview: nil)

        let wasEmpty = galleryPhotos.isEmpty
        galleryPhotos.insert(placeholder, at: 0)
        galleryCurrentOffset += 1

        if wasEmpty {
            galleryStatusView.isHidden = true
            galleryCollectionView.isHidden = false
            galleryCollectionView.reloadData()
            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTabIndex == 0 { updateCollectionsContainerHeight(animated: true) }
            }
        } else {
            galleryCollectionView.performBatchUpdates({
                galleryCollectionView.insertItems(at: [IndexPath(item: 0, section: 0)])
                if let layout = self.containerLayout?.0 {
                    updateAllCollectionViewHeights(layout: layout)
                    if currentTabIndex == 0 { updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { _ in
                self.galleryCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: true)
            })
        }
    }

    func finishPhotoUpload(photo: UserPhoto) {
        uploadingPhotoImage = nil
        if !galleryPhotos.isEmpty && galleryPhotos[0].id == -1 {
            galleryPhotos[0] = photo
            galleryCollectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
        }
    }

    func cancelPhotoUpload() {
        uploadingPhotoImage = nil
        guard !galleryPhotos.isEmpty && galleryPhotos[0].id == -1 else { return }
        galleryPhotos.remove(at: 0)
        galleryCurrentOffset = max(0, galleryCurrentOffset - 1)
        galleryCollectionView.performBatchUpdates({
            galleryCollectionView.deleteItems(at: [IndexPath(item: 0, section: 0)])
            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTabIndex == 0 { updateCollectionsContainerHeight(animated: true) }
            }
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            if self.galleryPhotos.isEmpty {
                self.galleryStatusView.isHidden = false
                self.galleryCollectionView.isHidden = true
            }
        })
    }

    // Добавление одной новой фотографии в начало (после успешной загрузки)
    func insertNewPhoto(_ photo: UserPhoto) {
        let wasEmpty = galleryPhotos.isEmpty

        galleryPhotos.insert(photo, at: 0)

        galleryCurrentOffset += 1

        if wasEmpty {
            galleryStatusView.isHidden = true
            galleryCollectionView.isHidden = false
            galleryCollectionView.reloadData()

            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTabIndex == 0 { updateCollectionsContainerHeight(animated: true) }
            }
        } else {
            galleryCollectionView.performBatchUpdates({
                let indexPath = IndexPath(item: 0, section: 0)
                galleryCollectionView.insertItems(at: [indexPath])

                if let layout = self.containerLayout?.0 {
                    updateAllCollectionViewHeights(layout: layout)
                    if currentTabIndex == 0 { updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { _ in
                self.galleryCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: true)
            })
        }
    }

    func removePhoto(withId id: Int) {
        guard let index = galleryPhotos.firstIndex(where: { $0.id == id }) else { return }
        
        galleryPhotos.remove(at: index)
        galleryCurrentOffset = max(0, galleryCurrentOffset - 1)
        
        let indexPath = IndexPath(item: index, section: 0)
        
        galleryCollectionView.performBatchUpdates({
            galleryCollectionView.deleteItems(at: [indexPath])
            
            // Пересчитываем высоту коллекции, если ряд исчез
            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTabIndex == 0 { updateCollectionsContainerHeight(animated: true) }
            }
        }, completion: {[weak self] _ in
            guard let self = self else { return }
            // Если удалили последнее фото, показываем заглушку
            if self.galleryPhotos.isEmpty {
                self.galleryStatusView.isHidden = false
                self.galleryCollectionView.isHidden = true
            }
        })
    }
    
    // Сброс пагинации галереи
    func resetGalleryPagination() {
        galleryPhotos = []
        galleryCurrentOffset = 0
        galleryIsLoading = false
        galleryHasMore = true
        galleryInitialized = false
        if let controller = self.controller as? PublicProfileScreenController {
            controller.clearGalleryData()
        }
        print("🔄 [PAGINATION] Reset gallery pagination state")
    }
    
    // Флаг загрузки галереи
    func setGalleryLoading(_ loading: Bool, _ uploadNew: Bool = false) {
        galleryIsLoading = loading
        if uploadNew {
            galleryStatusView.isHidden = false
        } else {
            galleryStatusView.isHidden = !galleryPhotos.isEmpty ? true : !loading && galleryPhotos.isEmpty
        }
        galleryStatusView.loadingSpinner(isLoading: loading)
    }
    
    // Проверка, есть ли еще фотографии на бэке для загрузки в галереи
    func checkAndLoadMoreGalleryPhotos() {
        guard galleryHasMore && !galleryIsLoading else { return }
        
        galleryCollectionView.layoutIfNeeded()
        
        let contentHeight = galleryCollectionView.contentSize.height
        let frameHeight = galleryCollectionView.frame.size.height
        
        if contentHeight <= frameHeight {
            loadNextGalleryPage()
        }
    }
    
    // Вызов нового запроса на загрузку фотографий
    func loadNextGalleryPage() {
        guard !galleryIsLoading && galleryHasMore, let userId = model.userId else { return }
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadGalleryPage(userId: userId, offset: galleryCurrentOffset)
        }
    }
    
    // MARK: - Video Gallery Methods
    
    // Загрузка видео галереи
    func loadVideoGallery() {
        guard let userId = model.userId else { return }
        
        videoGalleryIsLoading = true
        videoGalleryRequestedOffsets.insert(0)
        videoGalleryLastRequestedOffset = 0
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadVideoGalleryPage(userId: userId, offset: 0)
        }
    }

    func appendVideoGalleryItems(_ items: [UserVideoItem], pagination: Meta, isMyProfile: Bool) {
        let previousCount = videoGalleryItems.count
        
        let photoItems: [UserPhoto] = items.compactMap { item in
            let videoFile = item.files.first(where: { MediaFormatValidator.isVideo($0.fileExtension) })
            guard let videoFile else { return nil }
            
            let previewFile = item.files.first(where: { MediaFormatValidator.isImage($0.fileExtension) })
            
            let previewUserFile: UserFile? = previewFile.map {
                UserFile(
                    fileName: $0.fileName,
                    fullUrl: $0.fullUrl,
                    fileExtension: $0.fileExtension,
                    fileUuid: $0.fileUuid
                )
            }
            
            return UserPhoto(
                id: item.id,
                photo: UserFile(
                    fileName: videoFile.fileName,
                    fullUrl: videoFile.fullUrl,
                    fileExtension: videoFile.fileExtension,
                    fileUuid: videoFile.fileUuid
                ),
                likesCount: item.likesCount,
                isLikedByUser: item.isLikedByUser,
                preview: previewUserFile
            )
        }
        
        let existingIds = Set(videoGalleryItems.map { $0.id })
        let uniquePhotoItems = photoItems.filter { !existingIds.contains($0.id) }
        
        videoGalleryItems.append(contentsOf: uniquePhotoItems)
        
        videoGalleryTotalCount = pagination.totalCount
        let nextOffset: Int
        if let lastRequested = videoGalleryLastRequestedOffset, pagination.currentOffset == lastRequested {
            nextOffset = pagination.currentOffset + items.count
        } else {
            nextOffset = pagination.currentOffset
        }
        videoGalleryCurrentOffset = nextOffset
        
        videoGalleryHasMore = videoGalleryItems.count < pagination.totalCount
        videoGalleryIsLoading = false
        
        if previousCount == 0 {
            let hasVideos = !self.videoGalleryItems.isEmpty
            self.videoGalleryStatusView.isHidden = hasVideos
            if isMyProfile {
                self.videoGalleryStatusView.configure(isLoading: false, text: DivoStrings.uploadYourVideos, isMyProfile: true)
            } else {
                self.videoGalleryStatusView.configure(isLoading: false, text: DivoStrings.noVideosYet, isMyProfile: false)
            }
            self.videoGalleryCollectionView.isHidden = !hasVideos
            self.videoGalleryCollectionView.reloadData()
            
            if let layout = self.containerLayout?.0 {
                self.updateAllCollectionViewHeights(layout: layout)
                if self.currentTabIndex == 1 { self.updateCollectionsContainerHeight(animated: true) }
            }
        } else if !uniquePhotoItems.isEmpty {
            let newIndices = (previousCount..<(previousCount + uniquePhotoItems.count)).map { IndexPath(item: $0, section: 0) }
            self.videoGalleryCollectionView.performBatchUpdates({
                self.videoGalleryCollectionView.insertItems(at: newIndices)
                if let layout = self.containerLayout?.0 {
                    self.updateAllCollectionViewHeights(layout: layout)
                    if self.currentTabIndex == 1 { self.updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: nil)
        }
    }
    
    // Обновление высоты видео галереи
    func updateVideoGalleryCollectionViewHeight() {
        guard let (layout, _) = self.containerLayout else { return }
        
        let itemsPerRow: CGFloat = 3
        let spacing: CGFloat = 1
        let totalWidth = layout.size.width
        let itemWidth = (totalWidth - 2 * spacing) / itemsPerRow
        
        let totalItems = videoGalleryItems.count
        let rows = ceil(CGFloat(totalItems) / itemsPerRow)
        let galleryHeight = rows * itemWidth + (rows - 1) * spacing
        
        videoGalleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
        videoGalleryCollectionView.heightAnchor.constraint(equalToConstant: galleryHeight).isActive = true
        
        videoGalleryCollectionView.layoutIfNeeded()
    }
    
    // MARK: - Video Upload with Placeholder

    func startVideoUpload(thumbnail: UIImage?) {
        switchToTab(1)
        uploadingVideoImage = thumbnail
        let placeholder = UserPhoto(id: -1, photo: UserFile(fileName: "", fullUrl: nil, fileExtension: "", fileUuid: ""), likesCount: 0, isLikedByUser: false, preview: nil)

        let wasEmpty = videoGalleryItems.isEmpty
        videoGalleryItems.insert(placeholder, at: 0)
        videoGalleryCurrentOffset += 1

        if wasEmpty {
            videoGalleryStatusView.isHidden = true
            videoGalleryCollectionView.isHidden = false
            videoGalleryCollectionView.reloadData()
            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTabIndex == 1 { updateCollectionsContainerHeight(animated: true) }
            }
        } else {
            videoGalleryCollectionView.performBatchUpdates({
                videoGalleryCollectionView.insertItems(at: [IndexPath(item: 0, section: 0)])
                if let layout = self.containerLayout?.0 {
                    updateAllCollectionViewHeights(layout: layout)
                    if currentTabIndex == 1 { updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { _ in
                self.videoGalleryCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: true)
            })
        }
    }

    func finishVideoUpload(video: UserPhoto) {
        uploadingVideoImage = nil
        if !videoGalleryItems.isEmpty && videoGalleryItems[0].id == -1 {
            videoGalleryItems[0] = video
            videoGalleryCollectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
        }
    }

    func cancelVideoUpload() {
        uploadingVideoImage = nil
        guard !videoGalleryItems.isEmpty && videoGalleryItems[0].id == -1 else { return }
        videoGalleryItems.remove(at: 0)
        videoGalleryCurrentOffset = max(0, videoGalleryCurrentOffset - 1)
        videoGalleryCollectionView.performBatchUpdates({
            videoGalleryCollectionView.deleteItems(at: [IndexPath(item: 0, section: 0)])
            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTabIndex == 1 { updateCollectionsContainerHeight(animated: true) }
            }
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            if self.videoGalleryItems.isEmpty {
                self.videoGalleryStatusView.isHidden = false
                self.videoGalleryCollectionView.isHidden = true
            }
        })
    }

    func insertNewVideo(_ video: UserPhoto) {
        let wasEmpty = videoGalleryItems.isEmpty

        videoGalleryItems.insert(video, at: 0)

        videoGalleryCurrentOffset += 1

        if wasEmpty {
            videoGalleryStatusView.isHidden = true
            videoGalleryCollectionView.isHidden = false
            videoGalleryCollectionView.reloadData()

            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTabIndex == 0 { updateCollectionsContainerHeight(animated: true) }
            }
        } else {
            videoGalleryCollectionView.performBatchUpdates({
                let indexPath = IndexPath(item: 0, section: 0)
                videoGalleryCollectionView.insertItems(at: [indexPath])

                if let layout = self.containerLayout?.0 {
                    updateAllCollectionViewHeights(layout: layout)
                    if currentTabIndex == 0 { updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { _ in
                self.videoGalleryCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: true)
            })
        }
    }

    func removeVideo(withId id: Int) {
        guard let index = videoGalleryItems.firstIndex(where: { $0.id == id }) else { return }
        
        videoGalleryItems.remove(at: index)
        videoGalleryCurrentOffset = max(0, videoGalleryCurrentOffset - 1)
        
        let indexPath = IndexPath(item: index, section: 0)
        
        videoGalleryCollectionView.performBatchUpdates({
            videoGalleryCollectionView.deleteItems(at: [indexPath])
            
            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTabIndex == 1 { updateCollectionsContainerHeight(animated: true) }
            }
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            if self.videoGalleryItems.isEmpty {
                self.videoGalleryStatusView.isHidden = false
                self.videoGalleryCollectionView.isHidden = true
            }
        })
    }
    
    // Загрузка следующей страницы видео
    func loadNextVideoGalleryPage() {
        guard !videoGalleryIsLoading && videoGalleryHasMore, let userId = model.userId else { return }
        let offset = videoGalleryCurrentOffset
        guard !videoGalleryRequestedOffsets.contains(offset) else { return }
        videoGalleryRequestedOffsets.insert(offset)
        videoGalleryLastRequestedOffset = offset
        
        videoGalleryIsLoading = true
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadVideoGalleryPage(userId: userId, offset: offset)
        }
    }
    
    /// Вызвать при ошибке запроса, чтобы разрешить повторную попытку загрузки этой страницы.
    func videoGalleryRequestDidFail(offset: Int) {
        videoGalleryIsLoading = false
        videoGalleryRequestedOffsets.remove(offset)
    }
    
    // Сброс пагинации видео галереи
    func resetVideoGalleryPagination() {
        videoGalleryItems = []
        videoGalleryTotalCount = 0
        videoGalleryCurrentOffset = 0
        videoGalleryIsLoading = false
        videoGalleryHasMore = true
        videoGalleryRequestedOffsets.removeAll()
        videoGalleryLastRequestedOffset = nil

        if let controller = self.controller as? PublicProfileScreenController {
            controller.clearGalleryData()
        }
        print("🔄 [VIDEO] Reset video gallery pagination state")
    }
    
    // Флаг загрузки галереи видео
    func setVideoGalleryLoading(_ loading: Bool, _ uploadNew: Bool = false) {
        videoGalleryIsLoading = loading
        if uploadNew {
            videoGalleryStatusView.isHidden = false
        } else {
            videoGalleryStatusView.isHidden = !videoGalleryItems.isEmpty ? true : !loading && videoGalleryItems.isEmpty
        }
        videoGalleryStatusView.loadingSpinner(isLoading: loading)
    }

    // MARK: - Channels Gallery Methods
    
    // Загрузка галереи каналов
    func loadChannelGallery() {
        // guard let userId = model.userId else { return }
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadTelegramChannels()
        }
    }
    
    // Обновление галереи каналов
    func updateChannelsList(_ items: [ProfileChannelItem]) {
        self.channelGalleryItems = items
        let hasItems = !items.isEmpty
        self.channelGalleryStatusView.isHidden = hasItems
        self.channelGalleryCollectionView.isHidden = !hasItems
        if !hasItems {
            self.channelGalleryStatusView.configure(isLoading: false, text: model.isMyProfile ? DivoStrings.addChannel : DivoStrings.noChannelsYet, isMyProfile: model.isMyProfile)
        }
        self.channelGalleryCollectionView.reloadData()
        
        if let layout = self.containerLayout?.0 {
            self.updateAllCollectionViewHeights(layout: layout)
            // Индекс каналов зависит от роли
            let channelIndex = (modelRole == .model) ? 2 : 3
            if self.currentTabIndex == channelIndex { self.updateCollectionsContainerHeight(animated: true) }
        }
    }
    
    // Загрузка высоты галереи каналов
    private func updateChannelsCollectionViewHeight() {
        let channelCellHeight: CGFloat = 76.0
        let channelsHeight = CGFloat(channelGalleryItems.count) * channelCellHeight
        
        channelGalleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
        channelGalleryCollectionView.heightAnchor.constraint(equalToConstant: max(channelsHeight, 1.0)).isActive = true
        channelGalleryCollectionView.layoutIfNeeded()
        
        // debug: removed
    }
    
    
    // MARK: - Models Gallery Methods
    
    // Загрузка галереи моделей
    func loadModelGallery() {
        // guard let userId = model.userId else { return }
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadModels()
        }
    }
    
    // Обновление галереи моделей
    func updateModelsList(_ items:[ModelItem]) {
        self.modelGalleryItems = items
        let hasItems = !items.isEmpty
        
        self.modelGalleryCollectionView.isHidden = !hasItems
        
        if !hasItems && model.isMyProfile && modelRole == .agency {
            self.modelGalleryStatusView.isHidden = true
            self.emptyModelsPlaceholderNode.isHidden = false
        } else {
            self.emptyModelsPlaceholderNode.isHidden = true
            self.modelGalleryStatusView.isHidden = hasItems
            if !hasItems {
                self.modelGalleryStatusView.configure(isLoading: false, text: model.isMyProfile ? "Add model" : "No models yet", isMyProfile: model.isMyProfile)
            }
        }
        
        self.modelGalleryCollectionView.reloadData()
        
        if let layout = self.containerLayout?.0 {
            self.updateAllCollectionViewHeights(layout: layout)
            if self.currentTabIndex == 2 {
                self.updateCollectionsContainerHeight(animated: true)
                
                if !hasItems && model.isMyProfile && modelRole == .agency {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self = self else { return }
                        let bottomOffset = CGPoint(x: 0, y: max(0, self.scrollView.contentSize.height - self.scrollView.bounds.height))
                        self.scrollView.setContentOffset(bottomOffset, animated: true)
                    }
                }
            }
        }
    }
    
    // Загрузка высоты галереи моделей
    private func updateModelsCollectionViewHeight() {
        let modelCellHeight: CGFloat = 76.0
        let modelsHeight = CGFloat(modelGalleryItems.count) * modelCellHeight
        
        modelGalleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
        modelGalleryCollectionView.heightAnchor.constraint(equalToConstant: max(modelsHeight, 1.0)).isActive = true
        modelGalleryCollectionView.layoutIfNeeded()
        
        // debug: removed
    }
    
    
    // MARK: - Events Gallery Methods
    
    // Загрузка галереи событий
    func loadEventGallery() {
        // guard let userId = model.userId else { return }
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.loadEvents()
        }
    }
    
    // Обновление галереи событий
    func updateEventsList(_ items: [EventItem]) {
        self.eventGalleryItems = items
        let hasItems = !items.isEmpty
        self.eventGalleryStatusView.isHidden = hasItems
        self.eventGalleryCollectionView.isHidden = !hasItems
        if !hasItems {
            self.eventGalleryStatusView.configure(isLoading: false, text: model.isMyProfile ? DivoStrings.addEvent : DivoStrings.noEventsYet, isMyProfile: model.isMyProfile)
        }
        self.eventGalleryCollectionView.reloadData()
        
        if let layout = self.containerLayout?.0 {
            self.updateAllCollectionViewHeights(layout: layout)
            if self.currentTabIndex == 4 { self.updateCollectionsContainerHeight(animated: true) }
        }
    }
    
    // Загрузка высоты галереи событий
    private func updateEventsCollectionViewHeight() {
        let eventCellHeight: CGFloat = 76.0
        let eventsHeight = CGFloat(modelGalleryItems.count) * eventCellHeight
        
        eventGalleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
        eventGalleryCollectionView.heightAnchor.constraint(equalToConstant: max(eventsHeight, 1.0)).isActive = true
        eventGalleryCollectionView.layoutIfNeeded()
        
        // debug: removed
    }
    
    
    // MARK: - Dynamic Height Calculation
    
    private func updateAllCollectionViewHeights(layout: ContainerViewLayout) {
        let itemsPerRow: CGFloat = 3
        let spacing: CGFloat = 1
        let totalWidth = layout.size.width
        let itemWidth = (totalWidth - 2 * spacing) / itemsPerRow
        
        // Photo
        let pRows = ceil(CGFloat(galleryPhotos.count) / itemsPerRow)
        let pHeight = pRows * itemWidth + max(0, pRows - 1) * spacing
        galleryHeightConstraint.constant = max(pHeight, 1.0)
        
        // Video
        let vRows = ceil(CGFloat(videoGalleryItems.count) / itemsPerRow)
        let vHeight = vRows * itemWidth + max(0, vRows - 1) * spacing
        videoHeightConstraint.constant = max(vHeight, 1.0)
        
        // Channels
        let cHeight = CGFloat(channelGalleryItems.count) * 76.0
        channelHeightConstraint.constant = max(cHeight, 1.0)
        
        // Models
        let mHeight = CGFloat(modelGalleryItems.count) * 76.0
        modelHeightConstraint.constant = max(mHeight, 1.0)
        
        // Events
        let eHeight = CGFloat(eventGalleryItems.count) * 76.0
        eventHeightConstraint.constant = max(eHeight, 1.0)
    }
    
    private func calculateCollectionsContainerHeight() -> CGFloat {
        guard let (layout, navBarHeight) = self.containerLayout else { return 160 }
        
        let emptyPlaceholderHeight = max(160, layout.size.height - navBarHeight - self.segmentedBarHeight)
        
        func heightFor(isEmpty: Bool, constraint: NSLayoutConstraint, isModelTab: Bool = false) -> CGFloat {
            if isEmpty {
                return (isModelTab && model.isMyProfile && modelRole == .agency) ? emptyPlaceholderHeight : 160
            }
            return constraint.constant
        }
        
        if isMyModelProfile {
            switch currentTabIndex {
            case 0: return heightFor(isEmpty: galleryPhotos.isEmpty, constraint: galleryHeightConstraint)
            case 1: return heightFor(isEmpty: videoGalleryItems.isEmpty, constraint: videoHeightConstraint)
            default: return 160
            }
        } else if (modelRole == .model || modelRole == .newFace) && !model.isMyProfile {
            switch currentTabIndex {
            case 0: return heightFor(isEmpty: galleryPhotos.isEmpty, constraint: galleryHeightConstraint)
            case 1: return heightFor(isEmpty: videoGalleryItems.isEmpty, constraint: videoHeightConstraint)
            case 2: return heightFor(isEmpty: channelGalleryItems.isEmpty, constraint: channelHeightConstraint)
            default: return 160
            }
        } else {
            switch currentTabIndex {
            case 0: return heightFor(isEmpty: galleryPhotos.isEmpty, constraint: galleryHeightConstraint)
            case 1: return heightFor(isEmpty: videoGalleryItems.isEmpty, constraint: videoHeightConstraint)
            case 2: return heightFor(isEmpty: modelGalleryItems.isEmpty, constraint: modelHeightConstraint, isModelTab: true)
            case 3: return heightFor(isEmpty: channelGalleryItems.isEmpty, constraint: channelHeightConstraint)
            case 4: return heightFor(isEmpty: eventGalleryItems.isEmpty, constraint: eventHeightConstraint)
            default: return 160
            }
        }
    }
    
    private func updateCollectionsContainerHeight(animated: Bool = true) {
        collectionsContainerHeightConstraint.constant = calculateCollectionsContainerHeight()
        
        if animated && !scrollView.isDragging && !scrollView.isDecelerating {
            UIView.animate(withDuration: 0.3) {
                self.contentViewStack.layoutIfNeeded()
                self.view.layoutIfNeeded()
                
                // Плавно подтягиваем скролл, если контент стал меньше
                let maxOffset = max(0, self.scrollView.contentSize.height - self.scrollView.bounds.height)
                if self.scrollView.contentOffset.y > maxOffset {
                    self.scrollView.contentOffset.y = maxOffset
                }
            }
        } else {
            UIView.performWithoutAnimation {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.view.layoutIfNeeded()
                CATransaction.commit()
            }
        }
    }
    
    
    // MARK: - @objc

    @objc private func addModelBtnTapped() {
        onAddModelTapped?()
    }
    
    @objc private func dmButtonTapped() {
        
    }
    
    @objc private func handleTouchDown(_ sender: UIControl) {
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.6
        })
    }
    
    @objc private func handleTouchUp(_ sender: UIControl) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            sender.transform = .identity
            sender.alpha = 1.0
        })
    }
    
    @objc private func likesViewDidTap() {
        onLikesTapped?()
    }
    
    @objc private func viewsViewDidTap() {
        onViewsTapped?()
    }
    
    @objc private func savesViewDidTap() {
        onSavesTapped?()
    }

    @objc private func socialButtonTapped(_ sender: UIButton) {
        if let url = socialLinksMap[sender] {
            onSocialLinkTapped?(url)
        }
    }
    
    @objc private func editLinksButtonTapped() {
        onEditLinksTapped?()
    }
    
    @objc private func galleryStatusTapped() {
        onAddPhotoTapped?()
    }

    @objc private func videoGalleryStatusTapped() {
        onAddVideoTapped?()
    }
}


// MARK: - UICollectionViewDataSource

extension PublicProfileScreenNode: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == galleryCollectionView {
            return galleryPhotos.count
        } else if collectionView == videoGalleryCollectionView {
            return videoGalleryItems.count
        } else if collectionView == similarProfilesCollectionView {
            return similarProfiles.count
        } else if collectionView == channelGalleryCollectionView {
            return channelGalleryItems.count
        } else if collectionView == modelGalleryCollectionView {
            return modelGalleryItems.count
        } else if collectionView == eventGalleryCollectionView {
            return eventGalleryItems.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == similarProfilesCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SimilarProfileCell.reuseIdentifier, for: indexPath) as? SimilarProfileCell else {
                return UICollectionViewCell()
            }
            let profile = similarProfiles[indexPath.item]
            cell.configure(with: profile)
            return cell
        } else if collectionView == galleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as? GalleryCell else {
                return UICollectionViewCell()
            }
            let photoItem = galleryPhotos[indexPath.item]

            if photoItem.id == -1, let localImage = uploadingPhotoImage {
                cell.configure(with: localImage, isUploading: true)
            } else if let previewUrlString = photoItem.preview?.fullUrl, let url = CDNURLHelper.convertToCDNURL(previewUrlString) {
                cell.configure(with: url)
            } else {
                if let fullUrlString = photoItem.photo.fullUrl, let url = CDNURLHelper.convertToCDNURL(fullUrlString) {
                    cell.configure(with: url)
                }
            }

            return cell
        } else if collectionView == videoGalleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoGalleryCell.reuseIdentifier, for: indexPath) as? VideoGalleryCell else {
                return UICollectionViewCell()
            }
            let videoItem = videoGalleryItems[indexPath.item]

            if videoItem.id == -1, let localImage = uploadingVideoImage {
                cell.configureUploading(thumbnail: localImage)
            } else if let videoUrlString = videoItem.photo.fullUrl {
                let cdnVideoUrl = CDNURLHelper.convertToCDN(videoUrlString) ?? ""
                let previewUrl = videoItem.preview?.fullUrl.flatMap { CDNURLHelper.convertToCDN($0) }
                cell.configure(with: cdnVideoUrl, previewUrl: previewUrl, title: nil)
            }

            return cell
        } else if collectionView == channelGalleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChannelListCell.reuseIdentifier, for: indexPath) as? ChannelListCell else {
                return UICollectionViewCell()
            }
            let item = channelGalleryItems[indexPath.item]
            cell.configure(with: item, context: self.context)
            return cell
        } else if collectionView == modelGalleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ModelListCell.reuseIdentifier, for: indexPath) as? ModelListCell else {
                return UICollectionViewCell()
            }
            let item = modelGalleryItems[indexPath.item]
            cell.configure(with: item, context: self.context)
            return cell
        } else if collectionView == eventGalleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EventListCell.reuseIdentifier, for: indexPath) as? EventListCell else {
                return UICollectionViewCell()
            }
            let item = eventGalleryItems[indexPath.item]
            cell.configure(with: item, context: self.context)
            return cell
        }
        return UICollectionViewCell()
    }
}


// MARK: - UICollectionViewDelegate

extension PublicProfileScreenNode: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == similarProfilesCollectionView {
            _ = similarProfiles[indexPath.item]
            // debug: removed
            // TODO: Открыть профиль выбранного пользователя
            // handleSimilarProfileTap(profile)
        } else if collectionView == galleryCollectionView {
            guard galleryPhotos[indexPath.item].id != -1 else { return }
            onGalleryItemTapped?(0, indexPath.item)
        } else if collectionView == videoGalleryCollectionView {
            guard videoGalleryItems[indexPath.item].id != -1 else { return }
            onGalleryItemTapped?(1, indexPath.item)
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if collectionView == videoGalleryCollectionView,
           let videoCell = cell as? VideoGalleryCell {
            // Тяжёлый fallback (first-frame) запускаем только для реально видимых ячеек.
            videoCell.willDisplay()
            videoCell.play()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if collectionView == videoGalleryCollectionView,
           let videoCell = cell as? VideoGalleryCell {
            videoCell.stopAndReleasePlayer()
        }
    }
}

// MARK: - Video Thumbnail Retry

extension PublicProfileScreenNode {
    func retryVisibleVideoThumbnails() {
        for cell in videoGalleryCollectionView.visibleCells {
            if let videoCell = cell as? VideoGalleryCell {
                videoCell.willDisplay()
            }
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension PublicProfileScreenNode: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == similarProfilesCollectionView {
            return CGSize(width: 166, height: 200)
        } else if collectionView == galleryCollectionView || collectionView == videoGalleryCollectionView {
            guard let (layout, _) = self.containerLayout else { return .zero }
            let totalSpacing: CGFloat = 2
            let width = (layout.size.width - totalSpacing) / 3.0
            return CGSize(width: width, height: width)
        } else if collectionView == channelGalleryCollectionView
                    || collectionView == modelGalleryCollectionView
                    || collectionView == eventGalleryCollectionView {
            guard let (layout, _) = self.containerLayout else { return .zero }
            return CGSize(width: layout.size.width, height: 74)
        }
        return CGSize()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == similarProfilesCollectionView {
            return 6
        } else if collectionView == galleryCollectionView
                    || collectionView == videoGalleryCollectionView
                    || collectionView == channelGalleryCollectionView
                    || collectionView == modelGalleryCollectionView
                    || collectionView == eventGalleryCollectionView {
            return 1.0
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == similarProfilesCollectionView {
            return 6
        } else if collectionView == galleryCollectionView
                    || collectionView == videoGalleryCollectionView
                    || collectionView == channelGalleryCollectionView
                    || collectionView == modelGalleryCollectionView
                    || collectionView == eventGalleryCollectionView {
            return 1.0
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if collectionView == similarProfilesCollectionView {
            return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        } else if collectionView == galleryCollectionView
                    || collectionView == videoGalleryCollectionView
                    || collectionView == channelGalleryCollectionView
                    || collectionView == modelGalleryCollectionView
                    || collectionView == eventGalleryCollectionView {
            return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}


// MARK: - UIScrollViewDelegate

extension PublicProfileScreenNode: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let offsetY = scrollView.contentOffset.y
        
        // ПРАВИЛЬНЫЙ РАСЧЕТ ПАГИНАЦИИ (относительно основного скролла)
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.bounds.height
        
        // Триггер: за 500 пикселей до конца экрана
        let threshold = contentHeight - frameHeight - 500
        
        if offsetY > threshold {
            triggerLoadMoreForActiveTab()
        }
        
        updateSegmentedBarPosition()
        updateNavigationBarTitleVisibility()
        
        // Защита от скролла ниже контента
        let maxScrollY = scrollView.contentSize.height - scrollView.bounds.height
        let bottomLimit = max(0, maxScrollY)
        
        if scrollView.contentOffset.y > bottomLimit {
            scrollView.contentOffset.y = bottomLimit
        }
    }
    
    // Менеджер загрузки для текущей вкладки
    private func triggerLoadMoreForActiveTab() {
        if isMyModelProfile {
            switch currentTabIndex {
            case 0:
                if galleryHasMore && !galleryIsLoading { loadNextGalleryPage() }
            case 1:
                if videoGalleryHasMore && !videoGalleryIsLoading { loadNextVideoGalleryPage() }
            default: break
            }
        } else if (modelRole == .model || modelRole == .newFace) && !model.isMyProfile {
            switch currentTabIndex {
            case 0:
                if galleryHasMore && !galleryIsLoading { loadNextGalleryPage() }
            case 1:
                if videoGalleryHasMore && !videoGalleryIsLoading { loadNextVideoGalleryPage() }
            default: break
            }
        } else {
            switch currentTabIndex {
            case 0:
                if galleryHasMore && !galleryIsLoading { loadNextGalleryPage() }
            case 1:
                if videoGalleryHasMore && !videoGalleryIsLoading { loadNextVideoGalleryPage() }
                // Модели, каналы, эвенты - добавить пагинацию по аналогии
            default: break
            }
        }
    }
}


// MARK: - ProfileInfoViewDelegate

extension PublicProfileScreenNode: ProfileInfoViewDelegate {
    func profileInfoViewDidUpdateContentHeight(animated: Bool) {
        UIView.performWithoutAnimation {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
}


// MARK: - ProfileSegmentedBarDelegate

extension PublicProfileScreenNode: ProfileSegmentedBarDelegate {
    
    private func getTabContainer(for index: Int) -> UIView {
        if isMyModelProfile {
            switch index {
            case 0: return photoTabContainer
            case 1: return videoTabContainer
            default: return photoTabContainer
            }
        } else if (modelRole == .model || modelRole == .newFace) && !model.isMyProfile {
            switch index {
            case 0: return photoTabContainer
            case 1: return videoTabContainer
            case 2: return channelTabContainer
            default: return photoTabContainer
            }
        } else {
            switch index {
            case 0: return photoTabContainer
            case 1: return videoTabContainer
            case 2: return modelTabContainer
            case 3: return channelTabContainer
            case 4: return eventTabContainer
            default: return photoTabContainer
            }
        }
    }
    
    func segmentedBar(_ segmentedBar: ProfileSegmentedBar, didSelectIndex index: Int) {
        guard index != currentTabIndex else { return }
        
        let isSlidingLeft = index > currentTabIndex
        let screenWidth = self.view.bounds.width
        let offset = isSlidingLeft ? screenWidth : -screenWidth
        
        let oldContainer = getTabContainer(for: currentTabIndex)
        let newContainer = getTabContainer(for: index)
        
        newContainer.transform = CGAffineTransform(translationX: offset, y: 0)
        newContainer.isHidden = false
        
        loadDataForTab(index: index)
        
        currentTabIndex = index
        
        // 1. Устанавливаем новую высоту (вычисляем через наш новый метод)
        collectionsContainerHeightConstraint.constant = calculateCollectionsContainerHeight()
        
        // 2. Анимируем всё вместе: сдвиг, изменение высоты и корректировку скролла
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseInOut, animations: {
            oldContainer.transform = CGAffineTransform(translationX: -offset, y: 0)
            newContainer.transform = .identity
            
            // Плавно применяем новую высоту к Layout
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            
            // Если новый таб короче, и мы находились в самом низу, скролл должен плавно подняться
            let maxOffset = max(0, self.scrollView.contentSize.height - self.scrollView.bounds.height)
            if self.scrollView.contentOffset.y > maxOffset {
                self.scrollView.contentOffset.y = maxOffset
            }
            
        }, completion: {[weak self] _ in
            guard let self = self else { return }
            oldContainer.isHidden = true
            oldContainer.transform = .identity
            
            // Логика автоматического скролла вниз для ПУСТОГО окна добавления моделей
            let hasItems = !self.modelGalleryItems.isEmpty
            if index == 2 && self.model.isMyProfile && self.modelRole == .agency && !hasItems {
                let bottomOffset = CGPoint(x: 0, y: max(0, self.scrollView.contentSize.height - self.scrollView.bounds.height))
                self.scrollView.setContentOffset(bottomOffset, animated: true)
            }
        })
    }
    
    private func loadDataForTab(index: Int) {
        if isMyModelProfile {
            if index == 1 && !videoGalleryInitialized { videoGalleryInitialized = true; loadVideoGallery() }
        } else if (modelRole == .model || modelRole == .newFace) && !model.isMyProfile {
            if index == 1 && !videoGalleryInitialized { videoGalleryInitialized = true; loadVideoGallery() }
            else if index == 2 && !channelGalleryInitialized { channelGalleryInitialized = true; loadChannelGallery() }
        } else {
            if index == 1 && !videoGalleryInitialized { videoGalleryInitialized = true; loadVideoGallery() }
            else if index == 2 && !modelGalleryInitialized { modelGalleryInitialized = true; loadModelGallery() }
            else if index == 3 && !channelGalleryInitialized { channelGalleryInitialized = true; loadChannelGallery() }
            else if index == 4 && !eventGalleryInitialized { eventGalleryInitialized = true; loadEventGallery() }
        }
    }
}


// MARK: - CurrentAgencyViewDelegate

extension PublicProfileScreenNode: CurrentAgencyViewDelegate {
    func didTapSeeHistory() {
        let historyController = WorkExperienceController(context: self.context, model: self.model)
        self.controller?.push(historyController)
    }
}
