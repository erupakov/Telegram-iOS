import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import DivoCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import DivoUIKit
import DivoGallery

// MARK: - Screen state types
//
// Один источник правды для loading-стейта экрана. API-колбэки выставляют
// новый стейт, applyState() атомарно расставляет все view'шки. Это
// исключает рассинхрон, который раньше получался из-за дюжины разрозненных
// флагов (galleryInitialized, similarProfilesIsLoading, ...).

/// Стадия загрузки всего экрана (= стадия профильного запроса).
enum ScreenLoadPhase: Equatable {
    case loading    // профильные шиммеры (header/info/social/segment) видны, scroll/swipe залочены
    case ready      // профиль загружен, шиммеры сняты, скролл/свайп активны
    case failed     // ошибка загрузки профиля (заглушка + снекбар)
}

/// Стейт фото-таба. Управляется отдельно: профиль может быть `.ready`,
/// а фото ещё в `.loading` (фото-шиммер показан в photoTabContainer).
enum PhotoTabPhase: Equatable {
    case loading    // photoGalleryShimmerView (2 ряда)
    case content    // galleryCollectionView с реальными фото
    case empty      // photoEmptyView (центрированный плейсхолдер)
    case failed(networkError: Bool)  // ProfileTabErrorView, retry
}

/// Унифицированный стейт контентных табов (video / channels / models / events).
/// Семантика идентичная для всех четырёх — используем общий тип.
/// `.failed` показывает `ProfileTabErrorView` поверх таба с retry-кнопкой.
enum ContentTabPhase: Equatable {
    case loading    // shimmer-сетка / список
    case content    // collectionView с реальными items
    case empty      // emptyView (профильный плейсхолдер)
    case failed(networkError: Bool)  // ProfileTabErrorView, retry
}

/// Стейт карусели similar внутри photo-таба. Шиммер не показываем — данные
/// приходят редко, поэтому контейнер либо скрыт, либо виден с реальными карточками.
enum SimilarPhase: Equatable {
    case hidden     // similarProfilesCollectionContainer.isHidden = true
    case visible    // показан с данными из similarProfiles
}

final class PublicProfileScreenNode: ASDisplayNode {
    private static let mockBiographyText = DivoStrings.noBiography
    private static let mockBiographyMyProfileText = DivoStrings.fillInInfoAboutYou
    private let model: ProfileModel
    private var modelDetail: UserDetail?
    private var modelRole: Role = .model
    private var isMyRoleAgency: Bool
    private var avatarImage: UIImage?

    // MARK: - Screen state (см. enum'ы выше)

    /// Стадия профиля. didSet → applyState() атомарно расставляет всё.
    private var screenPhase: ScreenLoadPhase = .loading {
        didSet { if oldValue != screenPhase { applyState() } }
    }
    /// Стадия photo-таба.
    private var photoPhase: PhotoTabPhase = .loading {
        didSet { if oldValue != photoPhase { applyState() } }
    }
    /// Стадии остальных контентных табов. Каждый управляется независимо
    /// (data-запросы идут параллельно с профильным).
    private var videoPhase: ContentTabPhase = .loading {
        didSet { if oldValue != videoPhase { applyState() } }
    }
    private var channelsPhase: ContentTabPhase = .loading {
        didSet { if oldValue != channelsPhase { applyState() } }
    }
    private var modelsPhase: ContentTabPhase = .loading {
        didSet { if oldValue != modelsPhase { applyState() } }
    }
    private var eventsPhase: ContentTabPhase = .loading {
        didSet { if oldValue != eventsPhase { applyState() } }
    }
    /// Стадия similar-карусели (внутри photo-таба).
    private var similarPhase: SimilarPhase = .hidden {
        didSet { if oldValue != similarPhase { applyState() } }
    }

    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var navigationBarTitleView: ProfileNavigationBarTitleView?
    private var navigationBarTitleHeightConstraint: NSLayoutConstraint!
    
    // Управление моментом, когда начинаем анимировать title в навбаре
    private var titleVisibilityActivated = false
    /// Установлен ли начальный contentOffset под contentInset.top — нужно один
    /// раз на первый layout, чтобы контент сразу встал под navbar.
    private var hasInitialContentOffsetApplied = false
    private var isPerformingLayout = false
    
    private var headerHeightConstraint: NSLayoutConstraint!
    private var socialHeightConstraint: NSLayoutConstraint!
    private let iconPlaceholder = "HeartActionIcon"
    private let fixedHeaderHeight: CGFloat = 570.0
    private let fixedProfileHeaderHeight: CGFloat = 240.0
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = false
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
        // .systemUltraThinMaterialDark — самое тонкое тёмное стекло.
        // На пёстром/тёмном фото практически сливается с фотографией;
        // на светлом однотонном (голубой / белый header) даёт лёгкий
        // scrim для читаемости логотипа и имени, без «стеклянной плашки»
        // с резкой границей, которую давал .regular.
        // Mask настраивается в `applyGradientBlurMask` 3-stop gradient'ом
        // (те же параметры что bottom glass карточек ModelsFeed): top of
        // view прозрачно, bottom — solid blur, fade ~75% высоты.
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
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


    private let headerSpinner: DivoSegmentedSpinner = {
        let spinner = DivoSegmentedSpinner(color: DivoColorPalette.cardBackground)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isUserInteractionEnabled = false
        spinner.isHidden = true
        return spinner
    }()
    
    // MARK: - Profile Header Section

    private let profileHeaderWrapper: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var infoStack: UIStackView = {
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.alignment = .fill
        infoStack.spacing = 0
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        return infoStack
    }()
    
    private lazy var profileHeaderView = ProfileHeaderView()
    
    private lazy var profileHeaderShimmerView = ProfileHeaderShimmerView()


    // MARK: - Actions Section
    
    private lazy var counterActionsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 10
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

    private let sendShareContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = false
        return view
    }()

    private lazy var dmShareStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fill 
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true
        return stack
    }()

    private lazy var dmShareShimmerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fill 
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let shareButton: UIButton = {
        let button = UIButton(type: .custom)
        let image = DivoImage.share
        button.setImage(image, for: .normal)
        button.tintColor = DivoColorPalette.cardBackground

        button.backgroundColor = DivoColorPalette.statPillBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        button.layer.masksToBounds = true
        button.layer.borderWidth = 0.5
        button.layer.borderColor = DivoColorPalette.statPillBorder.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let shareShimmerButton: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.statPillForeground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let dmButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.statPillBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        button.layer.masksToBounds = true
        button.layer.borderWidth = 0.5
        button.layer.borderColor = DivoColorPalette.statPillBorder.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let dmShimmerButton: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.statPillForeground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private enum ActionViewTags {
        static let dmIcon = 9_101
        static let dmLabel = 9_102

        static let counterIcon = 9_201
        static let counterCountLabel = 9_202
        static let counterNameLabel = 9_203
    }

    private let likesView: StatPillView = {
        let pill = StatPillView(icon: DivoImage.statLike, filledIcon: DivoImage.statLikeFilled)
        pill.isUserInteractionEnabled = true
        return pill
    }()
    private let viewsView = StatPillView(icon: DivoImage.statView)
    private let savesView: StatPillView = {
        let pill = StatPillView(icon: DivoImage.statSave, filledIcon: DivoImage.statSaveFilled)
        pill.isUserInteractionEnabled = true
        return pill
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
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    private let profileInfoShimmerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let profileSegmentedInfoShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let profileScrollInfoShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
        button.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        button.setTitle(DivoStrings.editLinks, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let editLinksLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
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
        return view
    }()
    
    private let segmentedBarContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let segmentedBarPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let segmentedBarShimmer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var segmentedBarTopConstraint: NSLayoutConstraint?
    private let segmentedBarHeight: CGFloat = 32.0

    // MARK: - Gallery Collections Section
    
    private let collectionsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
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

    private var currentTab: ProfileTab = .photo
    private var collectionsContainerHeightConstraint: NSLayoutConstraint!

    // Горизонтальный paging-скролл для табов: 1 страница = 1 таб.
    // Свайп — нативный, тап на дальний таб делается через snapshot+fade
    // с мгновенным contentOffset (без промежуточных слайдов).
    private let tabsPager: UIScrollView = {
        let scroll = UIScrollView()
        scroll.isPagingEnabled = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.bounces = false
        scroll.contentInsetAdjustmentBehavior = .never
        // Белый — единый фон под всеми табами (см. updateContainerBackgrounds).
        scroll.backgroundColor = DivoColorPalette.profileEmptyBackground
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    // У каждого таб-контейнера своя высота — благодаря этому центрированный
    // эмпти-стейт центрируется в собственной фиксированной высоте таба
    // и не «подъезжает» при смене высоты `collectionsContainer`.
    private var photoTabHeightConstraint: NSLayoutConstraint!
    private var videoTabHeightConstraint: NSLayoutConstraint!
    private var channelTabHeightConstraint: NSLayoutConstraint!
    private var modelTabHeightConstraint: NSLayoutConstraint!
    private var eventTabHeightConstraint: NSLayoutConstraint!

    // Констрейнты, которые перестраиваются при смене набора видимых табов
    // (зависит от роли — см. `orderedTabs`).
    private var pagerLayoutConstraints: [NSLayoutConstraint] = []

    // Защита от вторичных анимаций высоты во время переключения таба:
    // когда async-загрузка прилетает в фоне, мы не дёргаем layout анимировано.
    private var isTabSwitching: Bool = false

    // Ширина шиммера сегмент-бара зависит от роли (3 таба vs 5).
    private var segmentShimmerWidthConstraint: NSLayoutConstraint?

    
    private let photoTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let videoTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let channelTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let modelTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let eventTabContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    // MARK: - Gallery Section
    
    private var galleryPhotos: [UserPhoto] = []
    private var galleryCurrentOffset: Int = 0
    private var galleryIsLoading: Bool = false
    private var galleryHasMore: Bool = true
    private var galleryInitialized: Bool = false
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
        collectionView.backgroundColor = DivoColorPalette.cardBackground
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
        collectionView.backgroundColor = DivoColorPalette.cardBackground
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
        collectionView.backgroundColor = DivoColorPalette.cardBackground
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
    
    
    // MARK: - Bottom Spacer

    private let bottomSpacer: UIView = {
        let view = UIView()
        // Белый — единый фон со всеми контейнерами таба. На практике
        // bottomSpacer всегда hidden (см. updateBottomSpacerVisibility),
        // bg оставлен для консистентности на случай возврата видимости.
        view.backgroundColor = DivoColorPalette.profileEmptyBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private lazy var bottomSpacerHeightConstraint: NSLayoutConstraint = bottomSpacer.heightAnchor.constraint(equalToConstant: 46)


    // MARK: - Similar Profiles Section

    private var similarProfiles: [SimilarProfileItem] = []
    private var similarProfilesIsLoading: Bool = false
    
    private let similarProfilesCollectionContainer: UIView = {
        let view = UIView()
        // Белый — единый фон под всеми табами (см. updateContainerBackgrounds).
        view.backgroundColor = DivoColorPalette.profileEmptyBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let similarProfilesTitleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.similarProfiles
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
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
        cv.register(SimilarProfileShimmerCell.self, forCellWithReuseIdentifier: SimilarProfileShimmerCell.reuseIdentifier)
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
    var onAddEventTapped: (() -> Void)?
    var onGalleryItemTapped: ((ProfileTab, Int) -> Void)?
    var onSocialLinkTapped: ((String) -> Void)?
    var onEventButtonTapped: ((Int) -> Void)?
    var onEventDeleteButtonTapped: ((Int) -> Void)?
    var onBackTapped: (() -> Void)?
    var onGridShareTapped: ((UserDetail?, UIImage?) -> Void)?
    
    var onFaceScanTapped: (() -> Void)?
    var onReportProfileTapped: (() -> Void)?
    var onBlockTapped: (() -> Void)?

    var onEditProfileTapped: ((Int) -> Void)?
    var onChangeBackgroundTapped: (() -> Void)?
    var onEditSocialLinksTapped: (() -> Void)?
    var onManageWorkExperienceTapped: (() -> Void)?
    var onAddModelTapped: (() -> Void)?
    var onCreateEventTapped: (() -> Void)?
    var onAddVideoTapped: ((Bool) -> Void)?
    var onAddPhotoTapped: ((Bool) -> Void)?
    var onAddChannelTapped: (() -> Void)?

    var storiesButtonTapped: (() -> Void)?
    var onAddWorkExperienceTapped: (() -> Void)?
    var onSimilarProfileTapped: ((SimilarProfileItem) -> Void)?
    var onModelAgencyTapped: ((ModelItem) -> Void)?
    var onEventTapped: ((EventItem) -> Void)?

    var onModelDeleteTapped: ((Int?) -> Void)?

    private var socialLinksMap: [UIButton: String] = [:]

    private enum SocialIcon {
        case instagram
        case tiktok
        case youtube
        case website

        var image: UIImage {
            switch self {
            case .instagram: return DivoImage.instaIcon
            case .tiktok: return DivoImage.tikTokIcon
            case .youtube: return DivoImage.youtubeIcon
            case .website: return DivoImage.webIcon
            }
        }

        static func icon(for urlString: String) -> UIImage {
            let lowercased = urlString.lowercased()
            if lowercased.contains("instagram.com") { return self.instagram.image }
            if lowercased.contains("tiktok.com") { return self.tiktok.image }
            if lowercased.contains("youtube.com") { return self.youtube.image }
            return self.website.image
        }
    }

    // MARK: - Profile tab empty states

    private let photoEmptyView: DivoEmptyStateView = {
        let view = DivoEmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // Скелетон во время первичной загрузки фото-таба (3-колоночная сетка
    // шиммер-ячеек). Заменяет старый galleryStatusView со starburst-спиннером.
    private let photoGalleryShimmerView: PhotoGalleryShimmerView = {
        let view = PhotoGalleryShimmerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Обёртка для зоны фото-сетки внутри photoTabContainer. Внутри неё
    // overlap'ятся galleryCollectionView, galleryStatusView, photoEmptyView,
    // photoGalleryShimmerView. Снаружи (но всё ещё в photoTabContainer)
    // ниже неё ставится similarProfilesCollectionContainer.
    private let galleryAreaWrapper: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var galleryAreaHeightConstraint: NSLayoutConstraint!
    private var similarSectionHeightConstraint: NSLayoutConstraint!

    // Шиммеры остальных табов (заменяют их starburst-спиннеры в *GalleryStatusView).
    // video — 3-колоночная сетка (как photo). channels/models/events — список
    // 66pt-рядов с rounded corners.
    private let videoGalleryShimmerView: PhotoGalleryShimmerView = {
        let view = PhotoGalleryShimmerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let channelGalleryShimmerView: GalleryListShimmerView = {
        let view = GalleryListShimmerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let modelGalleryShimmerView: GalleryListShimmerView = {
        let view = GalleryListShimmerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let eventGalleryShimmerView: GalleryListShimmerView = {
        let view = GalleryListShimmerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let videoEmptyView: DivoEmptyStateView = {
        let view = DivoEmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let channelsEmptyView: DivoEmptyStateView = {
        let view = DivoEmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let modelsEmptyView: DivoEmptyStateView = {
        let view = DivoEmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let eventsEmptyView: DivoEmptyStateView = {
        let view = DivoEmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // Error-заглушки контентных табов. Создаются on-demand в момент первой
    // ошибки (см. ensureTabError(...)) — для большинства сессий вообще
    // не аллоцируются, потому что api-запросы успешны.
    private var photoErrorView: ProfileTabErrorView?
    private var videoErrorView: ProfileTabErrorView?
    private var channelsErrorView: ProfileTabErrorView?
    private var modelsErrorView: ProfileTabErrorView?
    private var eventsErrorView: ProfileTabErrorView?

    // MARK: - NavigationBar
    
    private let customNavBar: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        let image = DivoImage.searchChevronLeft
        button.setImage(image, for: .normal)
        button.setImage(image, for: .highlighted)
        button.tintColor = DivoColorPalette.cardBackground

        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        button.layer.masksToBounds = true
        button.layer.borderWidth = 0.5
        button.layer.borderColor = DivoColorPalette.statPillBorder.cgColor

        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let rightButtonContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.layer.masksToBounds = true
        view.layer.borderWidth = 0.5
        view.layer.borderColor = DivoColorPalette.statPillBorder.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let rightButtonsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = DivoDesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let storiesButton: UIButton = {
        let button = UIButton(type: .custom)
        let image = DivoImage.stories
        button.setImage(image, for: .normal)
        button.setImage(image, for: .highlighted)
        button.tintColor = DivoColorPalette.cardBackground
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let editButton: UIButton = {
        let button = UIButton(type: .custom)
        let image = DivoImage.profileEditAction
        button.setImage(image, for: .normal)
        button.setImage(image, for: .highlighted)
        button.tintColor = DivoColorPalette.cardBackground
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let moreButton: UIButton = {
        let button = UIButton(type: .custom)
        let image = DivoImage.moreActionIcon
        button.setImage(image, for: .normal)
        button.setImage(image, for: .highlighted)
        button.tintColor = DivoColorPalette.cardBackground
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let whiteSheetBackground: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let floatingAddButton: DivoButton = {
        let button = DivoButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.applyDivoShadow(opacity: DivoDesignTokens.Shadow.opacityMedium)
        button.isHidden = true
        return button
    }()

    private var currentLikesCount: Int = 0
    private var currentIsLiked: Bool = false
    private var isLikingProcess: Bool = false
    
    private var currentSavesCount: Int = 0
    private var currentIsSaved: Bool = false
    private var isSavingProcess: Bool = false

    private let navBarBlurView: UIVisualEffectView = {
        // .systemChromeMaterialLight — толстое frosted "стекло", аналог
        // toolbar на macOS / native UINavigationBar в iOS Telegram. Светло-
        // серое полупрозрачное полотно, пропускает оттенки фона. Доступен
        // с iOS 13.
        let effect = UIBlurEffect(style: .systemChromeMaterialLight)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0.0
        view.isUserInteractionEnabled = false
        return view
    }()

    private let navBarWhiteGradientLayer = CAGradientLayer()

    // Полноэкранный контейнер для перехвата нажатий
    private let uploadOverlayContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.alpha = 0.0
        return view
    }()
    
    private let uploadOverlayView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let uploadOverlaySpinner: DivoSegmentedSpinner = {
        let spinner = DivoSegmentedSpinner()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isUserInteractionEnabled = false
        return spinner
    }()
    
    private let uploadOverlayLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(10)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()


    // MARK: - Init
    
    init(controller: ViewController, context: AccountContext, presentationData: PresentationData, model: ProfileModel, isMyRoleAgency: Bool) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        self.model = model
        self.isMyRoleAgency = isMyRoleAgency

        super.init()

        // Белый фон вью — fallback на случай прозрачных зон.
        self.view.backgroundColor = DivoColorPalette.profileEmptyBackground

        setupContent()
        segmentedBar.configure(isAgency: model.role == "agency_employee", isMyProfile: model.isMyProfile, animated: false)
        rebuildTabsPagerLayout()
        // Initial state: screenPhase = .loading + photoPhase = .loading + similarPhase = .hidden
        // (значения по умолчанию у stored properties). applyState() расставит
        // шиммеры, заблокирует scroll/swipe.
        applyState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Override
    
    override func layout() {
        super.layout()

        guard !isPerformingLayout else { return }
        isPerformingLayout = true
        defer { isPerformingLayout = false }

        guard let (layout, navigationBarHeight) = self.containerLayout else { return }

        let stackWidth = layout.size.width

        contentViewStack.layoutIfNeeded()

        var contentHeight = contentViewStack.systemLayoutSizeFitting(
            CGSize(width: stackWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        let scrollViewHeight = layout.size.height - navigationBarHeight
        let collapseOffset = segmentedBarContainer.frame.minY
        if collapseOffset > 0, scrollViewHeight > 0 {
            let minContentHeight = collapseOffset + scrollViewHeight
            let currentSpacerHeight = bottomSpacer.isHidden ? 0 : bottomSpacerHeightConstraint.constant
            let contentWithoutSpacer = contentHeight - currentSpacerHeight
            let bottomSafeInset = layout.intrinsicInsets.bottom
            // Минимум = safeArea + 4 — последний элемент стоит чуть над home
            // indicator (не перегораживается им). Для короткого контента
            // spacer ещё больше — добивает белым до view.bottom.
            let neededSpacerHeight = max(bottomSafeInset + 4, minContentHeight - contentWithoutSpacer)
            if !bottomSpacer.isHidden, abs(neededSpacerHeight - currentSpacerHeight) > 1.0 {
                bottomSpacerHeightConstraint.constant = neededSpacerHeight
                contentHeight = contentWithoutSpacer + neededSpacerHeight
            }
        }

        contentViewStack.frame = CGRect(x: 0, y: 0, width: stackWidth, height: contentHeight)
        scrollView.contentSize = CGSize(width: stackWidth, height: contentHeight)

        applyGradientBlurMask()
        updateNavBarBlurMask()
        
        if !profileInfoShimmerView.isHidden {
            profileSegmentedInfoShimmerView.stopShimmering()
            profileScrollInfoShimmerView.stopShimmering()
            profileSegmentedInfoShimmerView.startShimmering()
            profileScrollInfoShimmerView.startShimmering()
        }
        
        if !actionsShimmerView.isHidden {
            actionsShimmerView.startAnimation()
        }
        
        if !socialShimmerView.isHidden {
            socialShimmerView.startAnimation()
        }

        if !segmentedBarShimmer.isHidden {
            segmentedBarShimmer.stopShimmering()
            segmentedBarShimmer.startShimmering()
        }
        
        if !dmShareShimmerStack.isHidden {
            dmShimmerButton.stopShimmering()
            dmShimmerButton.startShimmering()
            shareShimmerButton.stopShimmering()
            shareShimmerButton.startShimmering()
        }
        
        updateSegmentedBarPosition()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if !model.isMyProfile {
            dmButton.addTarget(self, action: #selector(dmButtonTapped), for: .touchUpInside)
        }
    }
    
    
    // MARK: - Private
    
    private func setupContent() {
        setupHeaderImageView()
        setupScrollView()        
        setupTopBlur()            
        setupCustomNavBar()        
        setupContentViewStack()
        setupSegmentedBar()      
        setupContentLayout()
        setupAllCollectionsLayers()
        setupSimilarProfiles()
    }
    
    private func setupTopBlur() {
        view.addSubview(navBarBlurView)
        
        NSLayoutConstraint.activate([
            navBarBlurView.topAnchor.constraint(equalTo: view.topAnchor),
            navBarBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBarBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBarBlurView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 280)
        ])
    }
    
    private func updateNavBarBlurMask() {
        let bounds = navBarBlurView.bounds
        guard bounds.height > 0 else { return }
        guard let (_, navHeight) = self.containerLayout else { return }

        // Точка отсечения = collectionsContainer.top в sticky-state
        // (= navHeight + segmentBarHeight + 10). Считаем долю от bounds.height
        // динамически — иначе на разных safeArea.top mask промахивается мимо
        // tab content.
        let cutoffPt = navHeight + segmentedBarHeight + 10
        let cutoff = max(0.30, min(0.95, cutoffPt / bounds.height))
        let glassEnd = max(0.0, cutoff - 0.18)        // glass на customNavBar
        let fadeMid = max(glassEnd, cutoff - 0.06)     // быстрый фейд

        if navBarWhiteGradientLayer.superlayer == nil {
            navBarBlurView.contentView.layer.insertSublayer(navBarWhiteGradientLayer, at: 0)
        }
        navBarWhiteGradientLayer.frame = bounds
        // Clear сверху (виден chrome glass) → solid white к cutoff
        // (бесшовный стык с белым tab content).
        navBarWhiteGradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(1.0).cgColor,
            UIColor.white.withAlphaComponent(1.0).cgColor
        ]
        navBarWhiteGradientLayer.locations = [
            0.0,
            glassEnd as NSNumber,
            cutoff as NSNumber,
            1.0
        ]

        let maskLayer = CAGradientLayer()
        maskLayer.frame = bounds
        maskLayer.colors = [
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor,
            UIColor.clear.cgColor
        ]
        maskLayer.locations = [
            0.0,
            glassEnd as NSNumber,
            fadeMid as NSNumber,
            cutoff as NSNumber
        ]

        navBarBlurView.layer.mask = maskLayer
    }


    private func addPillBlur(to view: UIView) {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false
        view.insertSubview(blur, at: 0)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: view.topAnchor),
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        if let button = view as? UIButton, let imageView = button.imageView {
            button.bringSubviewToFront(imageView)
        }
    }

    private func setupCustomNavBar() {
        view.addSubview(customNavBar)

        customNavBar.addSubview(closeButton)
        customNavBar.addSubview(rightButtonContainer)

        addPillBlur(to: closeButton)
        addPillBlur(to: rightButtonContainer)

        rightButtonContainer.addSubview(rightButtonsStack)
        rightButtonsStack.addArrangedSubview(storiesButton)
        rightButtonsStack.addArrangedSubview(editButton)
        rightButtonsStack.addArrangedSubview(moreButton)
        
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.addDivoPressState(.pill)
        
        storiesButton.addTarget(self, action: #selector(storiesTapped), for: .touchUpInside)
        storiesButton.addDivoPressState(.pill)
        
        NSLayoutConstraint.activate([
            customNavBar.topAnchor.constraint(equalTo: view.topAnchor),
            customNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customNavBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52),
            
            closeButton.leadingAnchor.constraint(equalTo: customNavBar.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            closeButton.centerYAnchor.constraint(equalTo: customNavBar.bottomAnchor, constant: -25),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            rightButtonContainer.trailingAnchor.constraint(equalTo: customNavBar.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            rightButtonContainer.centerYAnchor.constraint(equalTo: customNavBar.bottomAnchor, constant: -25),
            rightButtonContainer.heightAnchor.constraint(equalToConstant: 40),
            
            rightButtonsStack.leadingAnchor.constraint(equalTo: rightButtonContainer.leadingAnchor),
            rightButtonsStack.trailingAnchor.constraint(equalTo: rightButtonContainer.trailingAnchor),
            rightButtonsStack.topAnchor.constraint(equalTo: rightButtonContainer.topAnchor),
            rightButtonsStack.bottomAnchor.constraint(equalTo: rightButtonContainer.bottomAnchor),
            
            storiesButton.widthAnchor.constraint(equalToConstant: 40),
            storiesButton.heightAnchor.constraint(equalToConstant: 40),
            
            editButton.widthAnchor.constraint(equalToConstant: 40),
            editButton.heightAnchor.constraint(equalToConstant: 40),
            
            moreButton.widthAnchor.constraint(equalToConstant: 40),
            moreButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        if !model.isMyProfile {
            storiesButton.isHidden = true
            editButton.isHidden = true
        } else {
            moreButton.isHidden = true
        }
    }

    private func setupMoreMenu() {
        moreButton.adjustsImageWhenHighlighted = false
        moreButton.addDivoPressState(.pill)

        if #available(iOS 14.0, *) {
            let faceScanAction = UIAction(
                title: DivoStrings.findSimilar,
                image: DivoImage.faceScanBlack,
            ) {[weak self] _ in
                self?.onFaceScanTapped?()
            }

            let reportAction = UIAction(
                title: DivoStrings.reportProfile,
                image: DivoImage.report,
            ) { [weak self] _ in
                self?.onReportProfileTapped?()
            }
            
            let blockAction = UIAction(
                title: DivoStrings.blockUser,
                image: DivoImage.block,
                attributes: .destructive
            ) { [weak self] _ in
                self?.onBlockTapped?()
            }
            
            if modelRole == .agency {
                let menu = UIMenu(title: "", children: [reportAction, blockAction])
                moreButton.menu = menu
            } else {
                let menu = UIMenu(title: "", children: [faceScanAction, reportAction, blockAction])
                moreButton.menu = menu
            }
            
            moreButton.showsMenuAsPrimaryAction = true
        }
    }

    private func setupEditMenu(isMyProfile: Bool) {
        editButton.adjustsImageWhenHighlighted = false
        editButton.addDivoPressState(.pill)

        if #available(iOS 14.0, *) {
            let editProfileAction = UIAction(
                title: DivoStrings.editProfile,
                image: nil,
            ) {[weak self] _ in
                self?.onEditProfileTapped?(0)
            }
            
            let changeBackgroundAction = UIAction(
                title: DivoStrings.changeBackground,
                image: nil,
            ) { [weak self] _ in
                self?.onChangeBackgroundTapped?()
            }

            let editSocialLinksAction = UIAction(
                title: DivoStrings.editSocialLinksMenu,
                image: nil,
            ) { [weak self] _ in
                self?.onEditSocialLinksTapped?()
            }

            let manageWorkExperienceAction = UIAction(
                title: DivoStrings.manageWorkExperience,
                image: nil,
            ) { [weak self] _ in
                self?.onManageWorkExperienceTapped?()
            }

            guard isMyProfile else { return }

            if modelRole == .agency {
                let menu = UIMenu(title: "", children: [editProfileAction, changeBackgroundAction, editSocialLinksAction])
                editButton.menu = menu
            } else {
                let menu = UIMenu(title: "", children: [editProfileAction, changeBackgroundAction, editSocialLinksAction, manageWorkExperienceAction])
                editButton.menu = menu
            }

            editButton.showsMenuAsPrimaryAction = true
        }
    }

    private func animateNavBarButton(_ button: UIButton) {
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
            button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            button.alpha = 0.6
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                button.transform = .identity
                button.alpha = 1.0
            })
        }
    }

    private func setupHeaderImageView() {
        self.view.addSubview(headerImageView)
        self.view.addSubview(headerSpinner)

        NSLayoutConstraint.activate([
            headerImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            headerImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            headerImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            headerImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            headerSpinner.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            headerSpinner.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 200),
            headerSpinner.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            headerSpinner.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
        ])
    }
    
    private func setupScrollView() {
        self.view.addSubview(scrollView)

        scrollView.addSubview(whiteSheetBackground)

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
            segmentedBar.centerXAnchor.constraint(equalTo: contentViewStack.centerXAnchor),
            segmentedBar.heightAnchor.constraint(equalToConstant: segmentedBarHeight),
        ])

        segmentedBarTopConstraint = segmentedBar.topAnchor.constraint(equalTo: self.view.topAnchor)
        segmentedBarTopConstraint?.isActive = true
    }
    
    private func setupContentLayout() {
        setupCounterActionsContainer()
        setupProfileHeaderContainer()
        setupSendShareContainer()
        setupProfileInfoContainer()
        setupSocialMediaContainer()
        setupSegmentedBarPlaceholder()
        setupMovingBlur()
        setupFloatingButton()
        setupUploadOverlay()
    }

    private func setupMovingBlur() {
        scrollView.insertSubview(blurredHeaderImageView, at: 0)

        NSLayoutConstraint.activate([
            blurredHeaderImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            blurredHeaderImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),

            blurredHeaderImageView.topAnchor.constraint(equalTo: profileHeaderWrapper.topAnchor, constant: -40),
            blurredHeaderImageView.bottomAnchor.constraint(equalTo: profileInfoContainer.topAnchor, constant: -20)
        ])
    }


    private func setupCounterActionsContainer() {
        contentViewStack.addArrangedSubview(counterActionsContainer)
        counterActionsContainer.addSubview(actionsShimmerView)
        counterActionsContainer.addSubview(counterActionsStack)
        
        counterActionsStack.addArrangedSubview(likesView)
        counterActionsStack.addArrangedSubview(viewsView)
        counterActionsStack.addArrangedSubview(savesView)

        for pill in [likesView, viewsView, savesView] {
            pill.backgroundColor = .clear
            addPillBlur(to: pill)
        }

        likesView.widthAnchor.constraint(equalToConstant: 70).isActive = true
        viewsView.widthAnchor.constraint(equalToConstant: 70).isActive = true
        savesView.widthAnchor.constraint(equalToConstant: 70).isActive = true
        
        NSLayoutConstraint.activate([
            // Убрали жесткую высоту и topAnchor! Стек сам решит, какого он размера.
            counterActionsContainer.topAnchor.constraint(equalTo: contentViewStack.topAnchor, constant: DivoDesignTokens.Spacing.m),
            counterActionsContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            counterActionsContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            
            actionsShimmerView.trailingAnchor.constraint(equalTo: counterActionsContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            actionsShimmerView.topAnchor.constraint(equalTo: counterActionsContainer.topAnchor),
            actionsShimmerView.bottomAnchor.constraint(equalTo: counterActionsContainer.bottomAnchor),
            actionsShimmerView.widthAnchor.constraint(equalToConstant: 70),
            
            counterActionsStack.trailingAnchor.constraint(equalTo: counterActionsContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            counterActionsStack.topAnchor.constraint(equalTo: counterActionsContainer.topAnchor),
            counterActionsStack.bottomAnchor.constraint(equalTo: counterActionsContainer.bottomAnchor),
        ])
        
        // Расстояние между счетчиками и Именем
        contentViewStack.setCustomSpacing(60, after: counterActionsContainer)

        if model.isMyProfile {
            likesView.onAnyTap = { [weak self] in
                self?.likesViewDidTap()
            }
            savesView.onAnyTap = { [weak self] in
                self?.savesViewDidTap()
            }
            
        } else {
            likesView.onIconTap = { [weak self] in
                self?.likesPillTapped()
            }
            likesView.onLabelTap = { [weak self] in
                self?.likesViewDidTap()
            }
            savesView.onIconTap = { [weak self] in
                self?.savesPillTapped()
            }
            savesView.onLabelTap = { [weak self] in
                self?.savesViewDidTap()
            }
        }
        viewsView.onAnyTap = { [weak self] in
            self?.viewsViewDidTap()
        }
    }

    // Раньше это был setupHeaderContainer, мы избавились от него полностью!
    private func setupProfileHeaderContainer() {
        // 1. Добавляем обертку в главный стек
        contentViewStack.addArrangedSubview(profileHeaderWrapper)
        
        // 2. В обертку кладем infoStack
        profileHeaderWrapper.addSubview(infoStack)
        infoStack.addArrangedSubview(profileHeaderView)
        
        profileHeaderShimmerView.translatesAutoresizingMaskIntoConstraints = false
        infoStack.addSubview(profileHeaderShimmerView)
        
        NSLayoutConstraint.activate([
            // 3. Безопасно делаем отступы от краев обертки
            infoStack.topAnchor.constraint(equalTo: profileHeaderWrapper.topAnchor),
            infoStack.bottomAnchor.constraint(equalTo: profileHeaderWrapper.bottomAnchor),
            infoStack.leadingAnchor.constraint(equalTo: profileHeaderWrapper.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            infoStack.trailingAnchor.constraint(equalTo: profileHeaderWrapper.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            profileHeaderShimmerView.leadingAnchor.constraint(equalTo: infoStack.leadingAnchor),
            profileHeaderShimmerView.trailingAnchor.constraint(equalTo: infoStack.trailingAnchor),
            profileHeaderShimmerView.topAnchor.constraint(equalTo: infoStack.topAnchor),
            profileHeaderShimmerView.bottomAnchor.constraint(equalTo: infoStack.bottomAnchor),
        ])
        
        // Расстояние между именем и кнопками (обрати внимание, отступ делаем после WRAPPER)
        contentViewStack.setCustomSpacing(20, after: profileHeaderWrapper)
        contentViewStack.setCustomSpacing(20, after: profileHeaderShimmerView)
    }

    private func setupSendShareContainer() {
        contentViewStack.addArrangedSubview(sendShareContainer)
        sendShareContainer.addSubview(dmShareStack)
        
        dmShareStack.addArrangedSubview(dmButton)
        dmButton.addDivoPressState(.pill)
        
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        dmShareStack.addArrangedSubview(spacer)
        
        dmShareStack.addArrangedSubview(shareButton)
        shareButton.addDivoPressState(.pill)

        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)

        sendShareContainer.addSubview(dmShareShimmerStack)
        dmShareShimmerStack.addArrangedSubview(dmShimmerButton)
        
        let spacerShimmer = UIView()
        spacerShimmer.translatesAutoresizingMaskIntoConstraints = false
        spacerShimmer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        dmShareShimmerStack.addArrangedSubview(spacerShimmer)
        
        dmShareShimmerStack.addArrangedSubview(shareShimmerButton)
        
        NSLayoutConstraint.activate([
            // Высота контейнера
            sendShareContainer.heightAnchor.constraint(equalToConstant: 44),
            sendShareContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            sendShareContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            
            // Отступы стека от краев экрана
            dmShareStack.leadingAnchor.constraint(equalTo: sendShareContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            dmShareStack.trailingAnchor.constraint(equalTo: sendShareContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            dmShareStack.topAnchor.constraint(equalTo: sendShareContainer.topAnchor),
            dmShareStack.bottomAnchor.constraint(equalTo: sendShareContainer.bottomAnchor),
            
            dmButton.heightAnchor.constraint(equalToConstant: 40),
            
            shareButton.widthAnchor.constraint(equalToConstant: 40),
            shareButton.heightAnchor.constraint(equalToConstant: 40),

            // Отступы стека от краев экрана
            dmShareShimmerStack.leadingAnchor.constraint(equalTo: sendShareContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            dmShareShimmerStack.trailingAnchor.constraint(equalTo: sendShareContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            dmShareShimmerStack.topAnchor.constraint(equalTo: sendShareContainer.topAnchor),
            dmShareShimmerStack.bottomAnchor.constraint(equalTo: sendShareContainer.bottomAnchor),
            
            dmShimmerButton.heightAnchor.constraint(equalToConstant: 40),
            dmShimmerButton.widthAnchor.constraint(equalToConstant: 100),
            
            shareShimmerButton.widthAnchor.constraint(equalToConstant: 40),
            shareShimmerButton.heightAnchor.constraint(equalToConstant: 40),
        ])

        contentViewStack.setCustomSpacing(44, after: sendShareContainer)
    }
    
    private func setupProfileInfoContainer() {
        contentViewStack.addArrangedSubview(profileInfoContainer)
        profileInfoContainer.addSubview(profileInfoView)
        profileInfoContainer.addSubview(profileInfoShimmerView)
        profileInfoShimmerView.addSubview(profileSegmentedInfoShimmerView)
        profileInfoShimmerView.addSubview(profileScrollInfoShimmerView)
        
        
        NSLayoutConstraint.activate([
            whiteSheetBackground.topAnchor.constraint(equalTo: profileInfoContainer.topAnchor, constant: -20),
            whiteSheetBackground.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            whiteSheetBackground.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            // bottomAnchor с collectionsContainer.topAnchor добавлен ниже, в setupAllCollectionsLayers,
            // когда collectionsContainer уже в иерархии scrollView

            profileInfoContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            profileInfoContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            
            profileInfoView.leadingAnchor.constraint(equalTo: profileInfoContainer.leadingAnchor),
            profileInfoView.trailingAnchor.constraint(equalTo: profileInfoContainer.trailingAnchor),
            profileInfoView.topAnchor.constraint(equalTo: profileInfoContainer.topAnchor),
            profileInfoView.bottomAnchor.constraint(equalTo: profileInfoContainer.bottomAnchor),
            
            profileInfoShimmerView.leadingAnchor.constraint(equalTo: profileInfoContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            profileInfoShimmerView.trailingAnchor.constraint(equalTo: profileInfoContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            profileInfoShimmerView.topAnchor.constraint(equalTo: profileInfoContainer.topAnchor),
            profileInfoShimmerView.bottomAnchor.constraint(equalTo: profileInfoContainer.bottomAnchor),
            profileInfoShimmerView.heightAnchor.constraint(equalToConstant: 126),
            
            profileSegmentedInfoShimmerView.leadingAnchor.constraint(equalTo: profileInfoShimmerView.leadingAnchor),
            profileSegmentedInfoShimmerView.trailingAnchor.constraint(equalTo: profileInfoShimmerView.trailingAnchor),
            profileSegmentedInfoShimmerView.topAnchor.constraint(equalTo: profileInfoShimmerView.topAnchor),
            profileSegmentedInfoShimmerView.bottomAnchor.constraint(equalTo: profileScrollInfoShimmerView.topAnchor, constant: -10),
            profileSegmentedInfoShimmerView.heightAnchor.constraint(equalToConstant: 32),
            
            profileScrollInfoShimmerView.leadingAnchor.constraint(equalTo: profileInfoShimmerView.leadingAnchor),
            profileScrollInfoShimmerView.trailingAnchor.constraint(equalTo: profileInfoShimmerView.trailingAnchor),
            profileScrollInfoShimmerView.bottomAnchor.constraint(equalTo: profileInfoShimmerView.bottomAnchor),
            profileSegmentedInfoShimmerView.heightAnchor.constraint(equalToConstant: 84),
        ])
        
        contentViewStack.setCustomSpacing(12, after: profileInfoView)
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
            
            titleEditStack.leadingAnchor.constraint(equalTo: titleEditContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleEditStack.trailingAnchor.constraint(equalTo: titleEditContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            titleEditStack.topAnchor.constraint(equalTo: titleEditContainer.topAnchor),
            titleEditStack.bottomAnchor.constraint(equalTo: titleEditContainer.bottomAnchor),
            
            socialMediaContainer.leadingAnchor.constraint(equalTo: contentViewStack.leadingAnchor),
            socialMediaContainer.trailingAnchor.constraint(equalTo: contentViewStack.trailingAnchor),
            socialMediaStack.leadingAnchor.constraint(equalTo: socialMediaContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            socialMediaStack.trailingAnchor.constraint(equalTo: socialMediaContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            socialMediaStack.topAnchor.constraint(equalTo: socialMediaContainer.topAnchor),
            socialMediaStack.bottomAnchor.constraint(equalTo: socialMediaContainer.bottomAnchor),
            
            socialShimmerView.leadingAnchor.constraint(equalTo: socialMediaContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            socialShimmerView.trailingAnchor.constraint(equalTo: socialMediaContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
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
        contentViewStack.addArrangedSubview(segmentedBarContainer)
        segmentedBarContainer.addSubview(segmentedBarPlaceholder)
        segmentedBarContainer.addSubview(segmentedBarShimmer)
        
        NSLayoutConstraint.activate([
            segmentedBarContainer.centerXAnchor.constraint(equalTo: contentViewStack.centerXAnchor),
            segmentedBarContainer.heightAnchor.constraint(equalToConstant: 32),
            
            segmentedBarPlaceholder.centerXAnchor.constraint(equalTo: segmentedBarContainer.centerXAnchor),
            segmentedBarPlaceholder.heightAnchor.constraint(equalToConstant: 32),
            
            segmentedBarShimmer.centerXAnchor.constraint(equalTo: segmentedBarContainer.centerXAnchor),
            segmentedBarShimmer.heightAnchor.constraint(equalToConstant: 32),
        ])

        // Ширина шиммера сегмента под роль: 3 таба для модели, 5 для агентства.
        // Изначально берём из raw model.role (до updateWithUserDetail
        // typed modelRole ещё дефолтный); после прихода данных
        // applySegmentShimmerWidth(isAgency:) обновит при необходимости.
        segmentShimmerWidthConstraint = segmentedBarShimmer.widthAnchor.constraint(
            equalToConstant: segmentShimmerWidth(isAgency: model.role == "agency_employee")
        )
        segmentShimmerWidthConstraint?.isActive = true

        contentViewStack.setCustomSpacing(10, after: segmentedBarContainer)
    }

    private func segmentShimmerWidth(isAgency: Bool) -> CGFloat {
        // Согласовано визуально с шириной реальной пилюли сегмент-бара.
        // 3 таба ≈ 172pt (раньше прописано константой); 5 табов — пропорционально.
        return isAgency ? 287 : 172
    }

    private func applySegmentShimmerWidth(isAgency: Bool) {
        let w = segmentShimmerWidth(isAgency: isAgency)
        guard segmentShimmerWidthConstraint?.constant != w else { return }
        segmentShimmerWidthConstraint?.constant = w
    }
    
    private func setupAllCollectionsLayers() {
        contentViewStack.addArrangedSubview(collectionsContainer)

        // whiteSheetBackground — серая подложка под bio/social, за сегмент-
        // баром И в 10pt gap. В non-sticky даёт серую полоску под пилюлёй,
        // как ты просила. В sticky-стейте перекрывается navBarBlurView сверху
        // (chrome-стекло + gradient к solid white в нижней части).
        whiteSheetBackground.bottomAnchor.constraint(equalTo: collectionsContainer.topAnchor).isActive = true

        collectionsContainerHeightConstraint = collectionsContainer.heightAnchor.constraint(equalToConstant: 160)
        collectionsContainerHeightConstraint.isActive = true

        // Горизонтальный paging-скролл — хост табов. Высота пейджера = высоте
        // collectionsContainer, ширина страницы = ширине пейджера. У каждого
        // таб-контейнера внутри своя высота (см. *TabHeightConstraint),
        // поэтому центрированный эмпти-стейт стабилен на screen-Y и не
        // «подъезжает» при изменении высоты соседних табов.
        collectionsContainer.addSubview(tabsPager)
        NSLayoutConstraint.activate([
            tabsPager.topAnchor.constraint(equalTo: collectionsContainer.topAnchor),
            tabsPager.leadingAnchor.constraint(equalTo: collectionsContainer.leadingAnchor),
            tabsPager.trailingAnchor.constraint(equalTo: collectionsContainer.trailingAnchor),
            tabsPager.bottomAnchor.constraint(equalTo: collectionsContainer.bottomAnchor),
        ])
        tabsPager.delegate = self

        photoTabHeightConstraint = photoTabContainer.heightAnchor.constraint(equalToConstant: 1)
        videoTabHeightConstraint = videoTabContainer.heightAnchor.constraint(equalToConstant: 1)
        channelTabHeightConstraint = channelTabContainer.heightAnchor.constraint(equalToConstant: 1)
        modelTabHeightConstraint = modelTabContainer.heightAnchor.constraint(equalToConstant: 1)
        eventTabHeightConstraint = eventTabContainer.heightAnchor.constraint(equalToConstant: 1)
        NSLayoutConstraint.activate([
            photoTabHeightConstraint,
            videoTabHeightConstraint,
            channelTabHeightConstraint,
            modelTabHeightConstraint,
            eventTabHeightConstraint,
        ])
        
        // --- PHOTO ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        galleryHeightConstraint = galleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        galleryHeightConstraint.isActive = true
        
        // photoTabContainer теперь делится на 2 секции:
        //   1) galleryAreaWrapper — gallery + status + empty + shimmer (overlap'ятся)
        //   2) similarProfilesCollectionContainer — переехал из contentViewStack
        // Между ними 0pt: similar ставится сразу под gallery без зазора.
        // Ниже в этом методе (после блока EVENTS) фактически переносим similar.

        photoTabContainer.addSubview(galleryAreaWrapper)
        galleryAreaWrapper.addSubview(galleryCollectionView)
        galleryAreaWrapper.addSubview(galleryStatusView)
        galleryAreaWrapper.addSubview(photoEmptyView)
        galleryAreaWrapper.addSubview(photoGalleryShimmerView)

        galleryAreaHeightConstraint = galleryAreaWrapper.heightAnchor.constraint(equalToConstant: 1)
        galleryAreaHeightConstraint.isActive = true

        NSLayoutConstraint.activate([
            galleryAreaWrapper.topAnchor.constraint(equalTo: photoTabContainer.topAnchor),
            galleryAreaWrapper.leadingAnchor.constraint(equalTo: photoTabContainer.leadingAnchor),
            galleryAreaWrapper.trailingAnchor.constraint(equalTo: photoTabContainer.trailingAnchor),

            galleryCollectionView.topAnchor.constraint(equalTo: galleryAreaWrapper.topAnchor),
            galleryCollectionView.leadingAnchor.constraint(equalTo: galleryAreaWrapper.leadingAnchor),
            galleryCollectionView.trailingAnchor.constraint(equalTo: galleryAreaWrapper.trailingAnchor),

            galleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            galleryStatusView.topAnchor.constraint(equalTo: galleryAreaWrapper.topAnchor),
            galleryStatusView.leadingAnchor.constraint(equalTo: galleryAreaWrapper.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            galleryStatusView.trailingAnchor.constraint(equalTo: galleryAreaWrapper.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            photoEmptyView.topAnchor.constraint(equalTo: galleryAreaWrapper.topAnchor),
            photoEmptyView.leadingAnchor.constraint(equalTo: galleryAreaWrapper.leadingAnchor),
            photoEmptyView.trailingAnchor.constraint(equalTo: galleryAreaWrapper.trailingAnchor),
            photoEmptyView.bottomAnchor.constraint(equalTo: galleryAreaWrapper.bottomAnchor),

            photoGalleryShimmerView.topAnchor.constraint(equalTo: galleryAreaWrapper.topAnchor),
            photoGalleryShimmerView.leadingAnchor.constraint(equalTo: galleryAreaWrapper.leadingAnchor),
            photoGalleryShimmerView.trailingAnchor.constraint(equalTo: galleryAreaWrapper.trailingAnchor),
            photoGalleryShimmerView.bottomAnchor.constraint(equalTo: galleryAreaWrapper.bottomAnchor),
        ])
        galleryCollectionView.isHidden = true
        // На первичной загрузке показываем skeleton-shimmer, а не starburst-спиннер.
        // galleryStatusView оставляем для пользовательских upload-сценариев
        // (включается в setGalleryLoading, когда galleryInitialized == true).
        galleryStatusView.isHidden = true
        photoGalleryShimmerView.isHidden = false
        galleryStatusView.configure(isLoading: true, text: DivoStrings.uploadingPhotos, isMyProfile: false)
        galleryStatusView.addTarget(self, action: #selector(galleryStatusTapped), for: .touchUpInside)

        // --- VIDEO ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        videoHeightConstraint = videoGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        videoHeightConstraint.isActive = true
        
        videoTabContainer.addSubview(videoGalleryCollectionView)
        videoTabContainer.addSubview(videoGalleryStatusView)
        videoTabContainer.addSubview(videoEmptyView)
        videoTabContainer.addSubview(videoGalleryShimmerView)

        NSLayoutConstraint.activate([
            videoGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            videoGalleryStatusView.topAnchor.constraint(equalTo: videoTabContainer.topAnchor),
            videoGalleryStatusView.leadingAnchor.constraint(equalTo: videoTabContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            videoGalleryStatusView.trailingAnchor.constraint(equalTo: videoTabContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            videoGalleryCollectionView.topAnchor.constraint(equalTo: videoTabContainer.topAnchor),
            videoGalleryCollectionView.leadingAnchor.constraint(equalTo: videoTabContainer.leadingAnchor),
            videoGalleryCollectionView.trailingAnchor.constraint(equalTo: videoTabContainer.trailingAnchor),

            videoEmptyView.topAnchor.constraint(equalTo: videoTabContainer.topAnchor),
            videoEmptyView.leadingAnchor.constraint(equalTo: videoTabContainer.leadingAnchor),
            videoEmptyView.trailingAnchor.constraint(equalTo: videoTabContainer.trailingAnchor),
            videoEmptyView.bottomAnchor.constraint(equalTo: videoTabContainer.bottomAnchor),

            videoGalleryShimmerView.topAnchor.constraint(equalTo: videoTabContainer.topAnchor),
            videoGalleryShimmerView.leadingAnchor.constraint(equalTo: videoTabContainer.leadingAnchor),
            videoGalleryShimmerView.trailingAnchor.constraint(equalTo: videoTabContainer.trailingAnchor),
            videoGalleryShimmerView.bottomAnchor.constraint(equalTo: videoTabContainer.bottomAnchor),
        ])
        videoGalleryCollectionView.isHidden = true
        // status-view со starburst-спиннером скрыт по дефолту, его заменяет
        // skeleton-shimmer. Останется только для пользовательских upload-сценариев.
        videoGalleryStatusView.isHidden = true
        videoGalleryShimmerView.isHidden = false
        videoGalleryStatusView.configure(isLoading: true, text: DivoStrings.uploadingVideos, isMyProfile: false)
        videoGalleryStatusView.addTarget(self, action: #selector(videoGalleryStatusTapped), for: .touchUpInside)

        // --- CHANNELS ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        channelHeightConstraint = channelGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        channelHeightConstraint.isActive = true
        
        channelTabContainer.addSubview(channelGalleryStatusView)
        channelTabContainer.addSubview(channelGalleryCollectionView)
        channelTabContainer.addSubview(channelsEmptyView)
        channelTabContainer.addSubview(channelGalleryShimmerView)
        NSLayoutConstraint.activate([
            channelGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            channelGalleryStatusView.topAnchor.constraint(equalTo: channelTabContainer.topAnchor),
            channelGalleryStatusView.leadingAnchor.constraint(equalTo: channelTabContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            channelGalleryStatusView.trailingAnchor.constraint(equalTo: channelTabContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            channelGalleryCollectionView.topAnchor.constraint(equalTo: channelTabContainer.topAnchor),
            channelGalleryCollectionView.leadingAnchor.constraint(equalTo: channelTabContainer.leadingAnchor),
            channelGalleryCollectionView.trailingAnchor.constraint(equalTo: channelTabContainer.trailingAnchor),

            channelsEmptyView.topAnchor.constraint(equalTo: channelTabContainer.topAnchor),
            channelsEmptyView.leadingAnchor.constraint(equalTo: channelTabContainer.leadingAnchor),
            channelsEmptyView.trailingAnchor.constraint(equalTo: channelTabContainer.trailingAnchor),
            channelsEmptyView.bottomAnchor.constraint(equalTo: channelTabContainer.bottomAnchor),

            channelGalleryShimmerView.topAnchor.constraint(equalTo: channelTabContainer.topAnchor),
            channelGalleryShimmerView.leadingAnchor.constraint(equalTo: channelTabContainer.leadingAnchor),
            channelGalleryShimmerView.trailingAnchor.constraint(equalTo: channelTabContainer.trailingAnchor),
            channelGalleryShimmerView.bottomAnchor.constraint(equalTo: channelTabContainer.bottomAnchor),
        ])
        channelGalleryCollectionView.isHidden = true
        channelGalleryStatusView.isHidden = true
        channelGalleryShimmerView.isHidden = false
        channelGalleryStatusView.configure(isLoading: true, text: DivoStrings.loadingChannels, isMyProfile: false)
        
        // --- MODELS ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        modelHeightConstraint = modelGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        modelHeightConstraint.isActive = true
        
        modelTabContainer.addSubview(modelGalleryStatusView)
        modelTabContainer.addSubview(modelGalleryCollectionView)
        modelTabContainer.addSubview(modelsEmptyView)
        modelTabContainer.addSubview(modelGalleryShimmerView)

        NSLayoutConstraint.activate([
            modelGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            modelGalleryStatusView.topAnchor.constraint(equalTo: modelTabContainer.topAnchor),
            modelGalleryStatusView.leadingAnchor.constraint(equalTo: modelTabContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            modelGalleryStatusView.trailingAnchor.constraint(equalTo: modelTabContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            modelGalleryCollectionView.topAnchor.constraint(equalTo: modelTabContainer.topAnchor),
            modelGalleryCollectionView.leadingAnchor.constraint(equalTo: modelTabContainer.leadingAnchor),
            modelGalleryCollectionView.trailingAnchor.constraint(equalTo: modelTabContainer.trailingAnchor),

            modelsEmptyView.topAnchor.constraint(equalTo: modelTabContainer.topAnchor),
            modelsEmptyView.leadingAnchor.constraint(equalTo: modelTabContainer.leadingAnchor),
            modelsEmptyView.trailingAnchor.constraint(equalTo: modelTabContainer.trailingAnchor),
            modelsEmptyView.bottomAnchor.constraint(equalTo: modelTabContainer.bottomAnchor),

            modelGalleryShimmerView.topAnchor.constraint(equalTo: modelTabContainer.topAnchor),
            modelGalleryShimmerView.leadingAnchor.constraint(equalTo: modelTabContainer.leadingAnchor),
            modelGalleryShimmerView.trailingAnchor.constraint(equalTo: modelTabContainer.trailingAnchor),
            modelGalleryShimmerView.bottomAnchor.constraint(equalTo: modelTabContainer.bottomAnchor),
        ])
        modelGalleryCollectionView.isHidden = true
        modelGalleryStatusView.isHidden = true
        modelGalleryShimmerView.isHidden = false
        modelGalleryStatusView.configure(isLoading: true, text: DivoStrings.loadingModels, isMyProfile: false)

        // --- EVENTS ---
        // ЗАМЕНА: Сохраняем констрейнт высоты
        eventHeightConstraint = eventGalleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        eventHeightConstraint.isActive = true
        
        eventTabContainer.addSubview(eventGalleryStatusView)
        eventTabContainer.addSubview(eventGalleryCollectionView)
        eventTabContainer.addSubview(eventsEmptyView)
        eventTabContainer.addSubview(eventGalleryShimmerView)

        NSLayoutConstraint.activate([
            eventGalleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            eventGalleryStatusView.topAnchor.constraint(equalTo: eventTabContainer.topAnchor),
            eventGalleryStatusView.leadingAnchor.constraint(equalTo: eventTabContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            eventGalleryStatusView.trailingAnchor.constraint(equalTo: eventTabContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            eventGalleryCollectionView.topAnchor.constraint(equalTo: eventTabContainer.topAnchor),
            eventGalleryCollectionView.leadingAnchor.constraint(equalTo: eventTabContainer.leadingAnchor),
            eventGalleryCollectionView.trailingAnchor.constraint(equalTo: eventTabContainer.trailingAnchor),

            eventsEmptyView.topAnchor.constraint(equalTo: eventTabContainer.topAnchor),
            eventsEmptyView.leadingAnchor.constraint(equalTo: eventTabContainer.leadingAnchor),
            eventsEmptyView.trailingAnchor.constraint(equalTo: eventTabContainer.trailingAnchor),
            eventsEmptyView.bottomAnchor.constraint(equalTo: eventTabContainer.bottomAnchor),

            eventGalleryShimmerView.topAnchor.constraint(equalTo: eventTabContainer.topAnchor),
            eventGalleryShimmerView.leadingAnchor.constraint(equalTo: eventTabContainer.leadingAnchor),
            eventGalleryShimmerView.trailingAnchor.constraint(equalTo: eventTabContainer.trailingAnchor),
            eventGalleryShimmerView.bottomAnchor.constraint(equalTo: eventTabContainer.bottomAnchor),
        ])
        eventGalleryCollectionView.isHidden = true
        eventGalleryStatusView.isHidden = true
        eventGalleryShimmerView.isHidden = false
        eventGalleryStatusView.configure(isLoading: true, text: DivoStrings.loadingEvents, isMyProfile: false)

        rebuildTabsPagerLayout()
    }

    // MARK: - Tabs Pager

    // Правило: model — всегда 3 таба, agency — всегда 5.
    // На момент init() modelRole ещё дефолтный, поэтому проверяем и raw
    // model.role (строка из ProfileModel) — до updateWithUserDetail
    // ориентируемся по ней, после — по типизированному `.agency`.
    private var orderedTabs: [ProfileTab] {
        let isAgencyRole = modelRole == .agency || model.role == "agency_employee"
        if isAgencyRole {
            return [.photo, .video, .models, .channels, .events]
        }
        return [.photo, .video, .channels]
    }

    private func heightConstraint(for tab: ProfileTab) -> NSLayoutConstraint {
        switch tab {
        case .photo: return photoTabHeightConstraint
        case .video: return videoTabHeightConstraint
        case .channels: return channelTabHeightConstraint
        case .models: return modelTabHeightConstraint
        case .events: return eventTabHeightConstraint
        }
    }

    private func tabContainer(for tab: ProfileTab) -> UIView {
        switch tab {
        case .photo: return photoTabContainer
        case .video: return videoTabContainer
        case .models: return modelTabContainer
        case .channels: return channelTabContainer
        case .events: return eventTabContainer
        }
    }

    /// Таб «без контента» — любая фаза кроме `.content` (loading / empty / failed).
    /// Используется для расчётов высоты и фона.
    private func isEmpty(_ tab: ProfileTab) -> Bool {
        switch tab {
        case .photo:    return photoPhase != .content
        case .video:    return videoPhase != .content
        case .channels: return channelsPhase != .content
        case .models:   return modelsPhase != .content
        case .events:   return eventsPhase != .content
        }
    }

    /// Истинно «пустой» — данные пришли и оказались пустыми. До прихода данных
    /// таб в `.loading` (шиммер) или `.failed` (error-view), а не в `.empty`.
    private func isShowingEmptyPlaceholder(_ tab: ProfileTab) -> Bool {
        switch tab {
        case .photo:    return photoPhase == .empty
        case .video:    return videoPhase == .empty
        case .channels: return channelsPhase == .empty
        case .models:   return modelsPhase == .empty
        case .events:   return eventsPhase == .empty
        }
    }

    // Высота таба: всегда `max(natural, floor)`. Floor = viewport под
    // segment-баром + 10pt; pager занимает всю эту зону → горизонтальный
    // свайп между табами ловится во всей видимой области, в т.ч. под
    // коротким контентом (1 фото, 0 каналов и т.п.). bottomSpacer при
    // этом не нужен — pager сам заполняет вьюпорт до home indicator.
    private func tabHeight(for tab: ProfileTab) -> CGFloat {
        let floor = fullScreenAvailableHeight()
        if tab == .photo {
            let natural = photoGalleryAreaHeight() + similarSectionTargetHeight()
            return max(natural, floor)
        }
        if isEmpty(tab) { return floor }
        switch tab {
        case .photo: return max(galleryHeightConstraint.constant, floor)
        case .video: return max(videoHeightConstraint.constant, floor)
        case .channels: return max(channelHeightConstraint.constant, floor)
        case .models: return max(modelHeightConstraint.constant, floor)
        case .events: return max(eventHeightConstraint.constant, floor)
        }
    }

    /// Высота `galleryAreaWrapper` внутри photoTabContainer — зависит
    /// от стейта photo-таба.
    private func photoGalleryAreaHeight() -> CGFloat {
        switch photoPhase {
        case .loading: return photoShimmerTabHeight()        // 2 ряда шиммер-сетки
        case .content: return galleryHeightConstraint.constant // высота сетки фото
        case .empty:
            // Заполняем весь viewport под similar (если она есть) — placeholder
            // центрируется в видимой зоне под sticky-баром.
            return max(160, fullScreenAvailableHeight() - similarSectionTargetHeight())
        case .failed:
            return fullScreenAvailableHeight()
        }
    }

    /// Высота секции similar внутри photo-таба. 0 — если контейнер скрыт
    /// (нет данных, идёт загрузка), иначе дизайнерская высота карусели.
    private func similarSectionTargetHeight() -> CGFloat {
        return similarProfilesCollectionContainer.isHidden ? 0 : similarSectionVisibleHeight
    }
    private let similarSectionVisibleHeight: CGFloat = 250

    /// Высота 2 рядов шиммер-сетки — ровно столько занимает
    /// `PhotoGalleryShimmerView` под `maxRows = 2`. Должно быть в синхроне
    /// с константой `columns`/`cellSpacing` в самом шиммер-вью.
    private func photoShimmerTabHeight() -> CGFloat {
        guard let (layout, _) = self.containerLayout else { return 270 }
        let columns: CGFloat = 3
        let spacing: CGFloat = 1
        let cellSide = (layout.size.width - (columns - 1) * spacing) / columns
        let rows: CGFloat = 2
        return rows * cellSide + (rows - 1) * spacing
    }

    private func fullScreenAvailableHeight() -> CGFloat {
        guard let (layout, navBarHeight) = self.containerLayout else { return 160 }
        // Стабильный 10pt отступ под сегмент-баром во всех стейтах
        // (см. spacing в updateCollectionsContainerHeight). Без этого
        // при empty-стейте contentSize получает +10pt оверскролла.
        return max(160, layout.size.height - navBarHeight - self.segmentedBarHeight - 10)
    }


    // Перестраивает chain-констрейнты пейджера под orderedTabs.
    // Вызывается после первичной настройки и при смене роли — мы вызываем
    // её сразу после segmentedBar.configure (см. updateProfileInfoView).
    private func rebuildTabsPagerLayout() {
        NSLayoutConstraint.deactivate(pagerLayoutConstraints)
        pagerLayoutConstraints.removeAll()

        let allContainers: [(ProfileTab, UIView)] = [
            (.photo, photoTabContainer),
            (.video, videoTabContainer),
            (.models, modelTabContainer),
            (.channels, channelTabContainer),
            (.events, eventTabContainer),
        ]
        let visibleSet = Set(orderedTabs)
        for (tab, container) in allContainers {
            if visibleSet.contains(tab) {
                if container.superview !== tabsPager {
                    container.removeFromSuperview()
                    tabsPager.addSubview(container)
                }
            } else if container.superview != nil {
                container.removeFromSuperview()
            }
        }

        let visibleContainers = orderedTabs.map { tabContainer(for: $0) }
        guard !visibleContainers.isEmpty else { return }

        let contentGuide = tabsPager.contentLayoutGuide
        let frameGuide = tabsPager.frameLayoutGuide

        var constraints: [NSLayoutConstraint] = []
        var previousTrailing: NSLayoutXAxisAnchor = contentGuide.leadingAnchor

        for container in visibleContainers {
            constraints.append(container.topAnchor.constraint(equalTo: contentGuide.topAnchor))
            constraints.append(container.leadingAnchor.constraint(equalTo: previousTrailing))
            constraints.append(container.widthAnchor.constraint(equalTo: frameGuide.widthAnchor))
            previousTrailing = container.trailingAnchor
        }
        constraints.append(visibleContainers.last!.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor))
        // Привязываем contentGuide.height к frameGuide — пейджер не должен
        // скроллиться вертикально, его высота диктуется collectionsContainer.
        constraints.append(contentGuide.heightAnchor.constraint(equalTo: frameGuide.heightAnchor))

        NSLayoutConstraint.activate(constraints)
        pagerLayoutConstraints = constraints

        // После ребилда выровняем offset на текущий таб — иначе при смене
        // роли пейджер может остаться на «чужой» странице.
        DispatchQueue.main.async { [weak self] in
            self?.snapPagerToCurrentTab(animated: false)
        }
    }

    private func pageIndex(for tab: ProfileTab) -> Int? {
        return orderedTabs.firstIndex(of: tab)
    }

    private func snapPagerToCurrentTab(animated: Bool) {
        guard let idx = pageIndex(for: currentTab) else { return }
        let pageWidth = tabsPager.bounds.width
        guard pageWidth > 0 else { return }
        let target = CGPoint(x: CGFloat(idx) * pageWidth, y: 0)
        if abs(tabsPager.contentOffset.x - target.x) > 0.5 {
            tabsPager.setContentOffset(target, animated: animated)
        }
    }

    private func emptyView(for tab: ProfileTab) -> DivoEmptyStateView {
        switch tab {
        case .photo: return photoEmptyView
        case .video: return videoEmptyView
        case .channels: return channelsEmptyView
        case .models: return modelsEmptyView
        case .events: return eventsEmptyView
        }
    }

    private func currentTabIsEmpty() -> Bool {
        switch currentTab {
        case .photo: return galleryPhotos.isEmpty
        case .video: return videoGalleryItems.isEmpty
        case .channels: return channelGalleryItems.isEmpty
        case .models: return modelGalleryItems.isEmpty
        case .events: return eventGalleryItems.isEmpty
        }
    }

    private func updateScreenBackgroundForCurrentTab() {
        // Подход: основной фон экрана — белый, а серая «подложка» лежит под
        // профильной био-секцией (см. profileInfoContainer.backgroundColor).
        UIView.performWithoutAnimation {
            self.view.backgroundColor = DivoColorPalette.profileEmptyBackground
        }
    }

    private func configureProfileEmptyView(for tab: ProfileTab, isMyProfile: Bool) {
        let icon: UIImage
        let title: String
        let subtitle: String
        let cta: String
        let action: () -> Void

        switch tab {
        case .photo:
            icon = DivoImage.photoIcon
            title = DivoStrings.profileEmptyPhotosTitle
            subtitle = isMyProfile ? DivoStrings.profileEmptyPhotosSubtitleOwn : DivoStrings.profileEmptyPhotosSubtitleOther
            cta = DivoStrings.profileEmptyPhotosCTA
            action = { [weak self] in self?.onAddPhotoTapped?(false) }
        case .video:
            icon = DivoImage.videoIcon
            title = DivoStrings.profileEmptyVideosTitle
            subtitle = isMyProfile ? DivoStrings.profileEmptyVideosSubtitleOwn : DivoStrings.profileEmptyVideosSubtitleOther
            cta = DivoStrings.profileEmptyVideosCTA
            action = { [weak self] in self?.onAddVideoTapped?(false) }
        case .channels:
            icon = DivoImage.channelIcon
            title = DivoStrings.profileEmptyChannelsTitle
            subtitle = isMyProfile ? DivoStrings.profileEmptyChannelsSubtitleOwn : DivoStrings.profileEmptyChannelsSubtitleOther
            cta = DivoStrings.profileEmptyChannelsCTA
            action = { [weak self] in self?.onAddChannelTapped?() }
        case .models:
            icon = DivoImage.associatedModels
            title = DivoStrings.profileEmptyModelsTitle
            subtitle = isMyProfile ? DivoStrings.profileEmptyModelsSubtitleOwn : DivoStrings.profileEmptyModelsSubtitleOther
            cta = DivoStrings.profileEmptyModelsCTA
            action = { [weak self] in self?.onAddModelTapped?() }
        case .events:
            icon = DivoImage.eventsAgency
            title = DivoStrings.profileEmptyEventsTitle
            subtitle = isMyProfile ? DivoStrings.profileEmptyEventsSubtitleOwn : DivoStrings.profileEmptyEventsSubtitleOther
            cta = DivoStrings.profileEmptyEventsCTA
            action = { [weak self] in self?.onAddEventTapped?() }
        }

        emptyView(for: tab).configure(.init(
            style: .smallOnLight(icon: icon),
            title: title,
            subtitle: subtitle,
            ctaTitle: isMyProfile ? cta : nil,
            ctaLeadingIcon: isMyProfile ? DivoImage.plus : nil,
            onCTATapped: isMyProfile ? action : nil
        ))
    }

    private func setupSimilarProfiles() {
        // similar — часть фото-таба: ставим внутрь photoTabContainer прямо
        // под galleryAreaWrapper с 0pt gap. На остальных табах similar
        // структурно отсутствует (никакого toggling видимости по табу).
        photoTabContainer.addSubview(similarProfilesCollectionContainer)
        similarProfilesCollectionContainer.addSubview(similarProfilesTitleLabel)
        similarProfilesCollectionContainer.addSubview(similarProfilesCollectionView)

        // Высота секции similar внутри фото-таба: 0pt, когда контейнер
        // скрыт (нет данных или загрузка), либо ~250pt, когда показан.
        // Управляется в applySimilarSectionHeight().
        similarSectionHeightConstraint = similarProfilesCollectionContainer.heightAnchor.constraint(equalToConstant: 0)
        similarSectionHeightConstraint.isActive = true

        NSLayoutConstraint.activate([
            similarProfilesCollectionContainer.topAnchor.constraint(equalTo: galleryAreaWrapper.bottomAnchor),
            similarProfilesCollectionContainer.leadingAnchor.constraint(equalTo: photoTabContainer.leadingAnchor),
            similarProfilesCollectionContainer.trailingAnchor.constraint(equalTo: photoTabContainer.trailingAnchor),

            similarProfilesTitleLabel.topAnchor.constraint(equalTo: similarProfilesCollectionContainer.topAnchor, constant: DivoDesignTokens.Spacing.m),
            similarProfilesTitleLabel.leadingAnchor.constraint(equalTo: similarProfilesCollectionContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            similarProfilesTitleLabel.trailingAnchor.constraint(equalTo: similarProfilesCollectionContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            similarProfilesCollectionView.topAnchor.constraint(equalTo: similarProfilesTitleLabel.topAnchor, constant: DivoDesignTokens.Spacing.m),
            similarProfilesCollectionView.leadingAnchor.constraint(equalTo: similarProfilesCollectionContainer.leadingAnchor),
            similarProfilesCollectionView.trailingAnchor.constraint(equalTo: similarProfilesCollectionContainer.trailingAnchor),
            similarProfilesCollectionView.bottomAnchor.constraint(equalTo: similarProfilesCollectionContainer.bottomAnchor, constant: -12),
            similarProfilesCollectionView.heightAnchor.constraint(equalToConstant: 180)
        ])

        contentViewStack.addArrangedSubview(bottomSpacer)
        bottomSpacerHeightConstraint.isActive = true

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

    private func updateBottomSpacerVisibility() {
        // Spacer нужен только когда контент таба длиннее viewport
        // (natural > floor): он добавляет ~safeArea+4 отступ под последним
        // элементом, чтобы тот не перекрывался home indicator при max scroll.
        //
        // Для short/non-content tab (height == floor) pager сам заполняет
        // viewport под segment-баром, spacer лишний — давал бы overscroll
        // за sticky pin (~safeArea+4 «уезжания» шиммера/empty за пилюлю).
        let floor = fullScreenAvailableHeight()
        bottomSpacer.isHidden = tabHeight(for: currentTab) <= floor + 0.5
    }

    private func setupFloatingButton() {
        self.view.addSubview(floatingAddButton)
        
        NSLayoutConstraint.activate([
            floatingAddButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            floatingAddButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            floatingAddButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        floatingAddButton.addTarget(self, action: #selector(floatingAddButtonTapped), for: .touchUpInside)
    }

    private func setupUploadOverlay() {
        self.view.addSubview(uploadOverlayContainer)
        uploadOverlayContainer.addSubview(uploadOverlayView)
        uploadOverlayView.addSubview(uploadOverlaySpinner)
        uploadOverlayView.addSubview(uploadOverlayLabel)
        
        NSLayoutConstraint.activate([
            uploadOverlayContainer.topAnchor.constraint(equalTo: self.view.topAnchor),
            uploadOverlayContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            uploadOverlayContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            uploadOverlayContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            
            uploadOverlayView.centerXAnchor.constraint(equalTo: uploadOverlayContainer.centerXAnchor),
            uploadOverlayView.centerYAnchor.constraint(equalTo: uploadOverlayContainer.centerYAnchor),
            uploadOverlayView.widthAnchor.constraint(greaterThanOrEqualToConstant: 114),
            uploadOverlayView.heightAnchor.constraint(equalToConstant: 74),
            
            uploadOverlaySpinner.centerXAnchor.constraint(equalTo: uploadOverlayView.centerXAnchor),
            uploadOverlaySpinner.topAnchor.constraint(equalTo: uploadOverlayView.topAnchor, constant: 12),
            uploadOverlaySpinner.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            uploadOverlaySpinner.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            uploadOverlayLabel.topAnchor.constraint(equalTo: uploadOverlaySpinner.bottomAnchor, constant: 12),
            uploadOverlayLabel.centerXAnchor.constraint(equalTo: uploadOverlayView.centerXAnchor),
            uploadOverlayLabel.leadingAnchor.constraint(equalTo: uploadOverlayView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            uploadOverlayLabel.trailingAnchor.constraint(equalTo: uploadOverlayView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m)
        ])
    }
    
    // Настройка шиммеров (= initial state, screenPhase == .loading).
    // Дальнейшие переходы — через applyState().
    private func configureNodes() {
        profileHeaderShimmerView.isHidden = false
        profileHeaderView.isHidden = true

        actionsShimmerView.isHidden = false
        counterActionsStack.isHidden = true

        profileInfoShimmerView.isHidden = false
        profileInfoView.isHidden = true

        socialShimmerView.isHidden = false

        // Во время загрузки профиля показываем шиммер-плейсхолдер сегмент-бара
        // (его ширина под роль обновляется в applySegmentShimmerWidth()).
        // Реальный сегмент покажется в applyScreenPhase(.ready) после
        // прихода данных через stopShimmers().
        segmentedBarShimmer.isHidden = false
        segmentedBarPlaceholder.isHidden = true
        segmentedBar.isHidden = true
    }

    // MARK: - State application
    //
    // Один путь: меняем screenPhase / photoPhase / similarPhase → didSet
    // вызывает applyState() → атомарно расставляются ВСЕ view'шки.
    // API-колбэки только меняют стейт, view'шки напрямую не дёргают.

    private func applyState() {
        applyScreenPhase()
        applyPhotoPhase()
        applyVideoPhase()
        applyChannelsPhase()
        applyModelsPhase()
        applyEventsPhase()
        applySimilarPhase()
        applyInteractionEnabled()
        applyHeights()
        updateContainerBackgrounds()
    }

    private func applyScreenPhase() {
        switch screenPhase {
        case .loading, .failed:
            // .failed визуально не отличается от .loading — остаёмся в
            // шиммерах (без stopShimmers), скролл/свайп залочен. Сверху
            // контроллер кладёт persistent-snackbar с кнопкой Retry.
            configureNodes()
        case .ready:
            stopShimmers()
        }
    }

    private func applyPhotoPhase() {
        switch photoPhase {
        case .loading:
            photoGalleryShimmerView.isHidden = false
            galleryStatusView.isHidden = true
            photoEmptyView.isHidden = true
            galleryCollectionView.isHidden = true
            photoErrorView?.isHidden = true
        case .content:
            photoGalleryShimmerView.stopAnimation()
            photoGalleryShimmerView.isHidden = true
            galleryStatusView.isHidden = true
            photoEmptyView.isHidden = true
            galleryCollectionView.isHidden = false
            photoErrorView?.isHidden = true
        case .empty:
            photoGalleryShimmerView.stopAnimation()
            photoGalleryShimmerView.isHidden = true
            galleryStatusView.isHidden = true
            galleryCollectionView.isHidden = true
            photoEmptyView.isHidden = false
            configureProfileEmptyView(for: .photo, isMyProfile: model.isMyProfile)
            photoErrorView?.isHidden = true
        case .failed(let isNetwork):
            photoGalleryShimmerView.stopAnimation()
            photoGalleryShimmerView.isHidden = true
            galleryStatusView.isHidden = true
            galleryCollectionView.isHidden = true
            photoEmptyView.isHidden = true
            let errorView = ensureTabError(&photoErrorView, in: photoTabContainer)
            errorView.configure(tab: .photo, networkError: isNetwork) { [weak self] in
                self?.retryPhotoLoad()
            }
        }
    }

    private func applyVideoPhase() {
        switch videoPhase {
        case .loading:
            videoGalleryShimmerView.isHidden = false
            videoGalleryShimmerView.startAnimation()
            videoGalleryStatusView.isHidden = true
            videoEmptyView.isHidden = true
            videoGalleryCollectionView.isHidden = true
            videoErrorView?.isHidden = true
        case .content:
            videoGalleryShimmerView.stopAnimation()
            videoGalleryShimmerView.isHidden = true
            videoGalleryStatusView.isHidden = true
            videoEmptyView.isHidden = true
            videoGalleryCollectionView.isHidden = false
            videoErrorView?.isHidden = true
        case .empty:
            videoGalleryShimmerView.stopAnimation()
            videoGalleryShimmerView.isHidden = true
            videoGalleryStatusView.isHidden = true
            videoGalleryCollectionView.isHidden = true
            videoEmptyView.isHidden = false
            configureProfileEmptyView(for: .video, isMyProfile: model.isMyProfile)
            videoErrorView?.isHidden = true
        case .failed(let isNetwork):
            videoGalleryShimmerView.stopAnimation()
            videoGalleryShimmerView.isHidden = true
            videoGalleryStatusView.isHidden = true
            videoGalleryCollectionView.isHidden = true
            videoEmptyView.isHidden = true
            let errorView = ensureTabError(&videoErrorView, in: videoTabContainer)
            errorView.configure(tab: .video, networkError: isNetwork) { [weak self] in
                self?.retryVideoLoad()
            }
        }
    }

    private func applyChannelsPhase() {
        switch channelsPhase {
        case .loading:
            channelGalleryShimmerView.isHidden = false
            channelGalleryShimmerView.startAnimation()
            channelGalleryStatusView.isHidden = true
            channelsEmptyView.isHidden = true
            channelGalleryCollectionView.isHidden = true
            channelsErrorView?.isHidden = true
        case .content:
            channelGalleryShimmerView.stopAnimation()
            channelGalleryShimmerView.isHidden = true
            channelGalleryStatusView.isHidden = true
            channelsEmptyView.isHidden = true
            channelGalleryCollectionView.isHidden = false
            channelsErrorView?.isHidden = true
        case .empty:
            channelGalleryShimmerView.stopAnimation()
            channelGalleryShimmerView.isHidden = true
            channelGalleryStatusView.isHidden = true
            channelGalleryCollectionView.isHidden = true
            channelsEmptyView.isHidden = false
            configureProfileEmptyView(for: .channels, isMyProfile: model.isMyProfile)
            channelsErrorView?.isHidden = true
        case .failed(let isNetwork):
            channelGalleryShimmerView.stopAnimation()
            channelGalleryShimmerView.isHidden = true
            channelGalleryStatusView.isHidden = true
            channelGalleryCollectionView.isHidden = true
            channelsEmptyView.isHidden = true
            let errorView = ensureTabError(&channelsErrorView, in: channelTabContainer)
            errorView.configure(tab: .channels, networkError: isNetwork) { [weak self] in
                self?.retryChannelsLoad()
            }
        }
    }

    private func applyModelsPhase() {
        switch modelsPhase {
        case .loading:
            modelGalleryShimmerView.isHidden = false
            modelGalleryShimmerView.startAnimation()
            modelGalleryStatusView.isHidden = true
            modelsEmptyView.isHidden = true
            modelGalleryCollectionView.isHidden = true
            modelsErrorView?.isHidden = true
        case .content:
            modelGalleryShimmerView.stopAnimation()
            modelGalleryShimmerView.isHidden = true
            modelGalleryStatusView.isHidden = true
            modelsEmptyView.isHidden = true
            modelGalleryCollectionView.isHidden = false
            modelsErrorView?.isHidden = true
        case .empty:
            modelGalleryShimmerView.stopAnimation()
            modelGalleryShimmerView.isHidden = true
            modelGalleryStatusView.isHidden = true
            modelGalleryCollectionView.isHidden = true
            modelsEmptyView.isHidden = false
            configureProfileEmptyView(for: .models, isMyProfile: model.isMyProfile)
            modelsErrorView?.isHidden = true
        case .failed(let isNetwork):
            modelGalleryShimmerView.stopAnimation()
            modelGalleryShimmerView.isHidden = true
            modelGalleryStatusView.isHidden = true
            modelGalleryCollectionView.isHidden = true
            modelsEmptyView.isHidden = true
            let errorView = ensureTabError(&modelsErrorView, in: modelTabContainer)
            errorView.configure(tab: .models, networkError: isNetwork) { [weak self] in
                self?.retryModelsLoad()
            }
        }
    }

    private func applyEventsPhase() {
        switch eventsPhase {
        case .loading:
            eventGalleryShimmerView.isHidden = false
            eventGalleryShimmerView.startAnimation()
            eventGalleryStatusView.isHidden = true
            eventsEmptyView.isHidden = true
            eventGalleryCollectionView.isHidden = true
            eventsErrorView?.isHidden = true
        case .content:
            eventGalleryShimmerView.stopAnimation()
            eventGalleryShimmerView.isHidden = true
            eventGalleryStatusView.isHidden = true
            eventsEmptyView.isHidden = true
            eventGalleryCollectionView.isHidden = false
            eventsErrorView?.isHidden = true
        case .empty:
            eventGalleryShimmerView.stopAnimation()
            eventGalleryShimmerView.isHidden = true
            eventGalleryStatusView.isHidden = true
            eventGalleryCollectionView.isHidden = true
            eventsEmptyView.isHidden = false
            configureProfileEmptyView(for: .events, isMyProfile: model.isMyProfile)
            eventsErrorView?.isHidden = true
        case .failed(let isNetwork):
            eventGalleryShimmerView.stopAnimation()
            eventGalleryShimmerView.isHidden = true
            eventGalleryStatusView.isHidden = true
            eventGalleryCollectionView.isHidden = true
            eventsEmptyView.isHidden = true
            let errorView = ensureTabError(&eventsErrorView, in: eventTabContainer)
            errorView.configure(tab: .events, networkError: isNetwork) { [weak self] in
                self?.retryEventsLoad()
            }
        }
    }

    /// Возвращает (создавая лениво) error-view для указанного таба и
    /// прикрепляет его на всю площадь контейнера. Используется только в
    /// `.failed` ветках applyXxxPhase — для табов без ошибок остаётся nil.
    private func ensureTabError(_ slot: inout ProfileTabErrorView?, in container: UIView) -> ProfileTabErrorView {
        if let view = slot {
            view.isHidden = false
            return view
        }
        let view = ProfileTabErrorView()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        slot = view
        return view
    }

    // MARK: - Tab retry handlers
    //
    // Сбрасываем фазу таба обратно в .loading (шиммер) и перезапускаем
    // соответствующий API-запрос. Pagination-state video-таба сбрасываем
    // полностью, потому что первая страница не пришла.

    private func retryPhotoLoad() {
        resetGalleryPagination()
        if let controller = self.controller as? PublicProfileScreenController {
            controller.clearGalleryData()
        }
        photoPhase = .loading
        loadNextGalleryPage()
    }

    private func retryVideoLoad() {
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
        videoPhase = .loading
        loadNextVideoGalleryPage()
    }

    private func retryChannelsLoad() {
        channelsPhase = .loading
        loadChannelGallery()
    }

    private func retryModelsLoad() {
        modelsPhase = .loading
        loadModelGallery()
    }

    private func retryEventsLoad() {
        eventsPhase = .loading
        loadEventGallery()
    }

    /// Фоны контейнеров:
    ///  • `whiteSheetBackground` — цвет анимируется в `updateNavigationBarTitleVisibility`
    ///    по `titleAlpha`: серый в non-sticky (под bio + segment + 10pt gap),
    ///    белый в sticky (бесшовный стык с белым tab content). Здесь не трогаем.
    ///  • `tabsPager` и `bottomSpacer` — всегда белые. Под контент любого таба
    ///    (content / empty / error / shimmer) единый белый фон.
    private func updateContainerBackgrounds() {
        tabsPager.backgroundColor = DivoColorPalette.profileEmptyBackground
        bottomSpacer.backgroundColor = DivoColorPalette.profileEmptyBackground
    }

    private func applySimilarPhase() {
        switch similarPhase {
        case .hidden:
            similarProfilesCollectionContainer.isHidden = true
        case .visible:
            similarProfilesCollectionContainer.isHidden = false
            similarProfilesCollectionView.reloadData()
        }
    }

    private func applyInteractionEnabled() {
        // Скролл и горизонтальный свайп активны только когда профиль
        // загружен. В .loading и .failed (шиммер + retry-снекбар) залочено.
        let interactive = (screenPhase == .ready)
        scrollView.isScrollEnabled = interactive
        tabsPager.isScrollEnabled = interactive
    }

    private func applyHeights() {
        guard let layout = containerLayout?.0 else { return }
        updateAllCollectionViewHeights(layout: layout)
        if currentTab == .photo {
            updateCollectionsContainerHeight(animated: false)
        }
        updateBottomSpacerVisibility()
    }

    // MARK: - Public state mutators (для controller'а)

    /// Контроллер вызывает в error-ветке fetchUserProfile.
    func markProfileDetailFailed() {
        screenPhase = .failed
    }

    /// Контроллер вызывает в error-ветке loadGalleryPage первой страницы.
    /// `networkError` определяет текст в `ProfileTabErrorView`: true →
    /// «Нет подключения к интернету», false → «Не удалось загрузить фото».
    func markPhotoGalleryFailed(networkError: Bool) {
        photoPhase = .failed(networkError: networkError)
    }

    /// Контроллер вызывает в error-ветках первой страницы соответствующего
    /// таба. `networkError` определяет текст в `ProfileTabErrorView`:
    /// true → «Нет подключения к интернету», false → «Не удалось загрузить».
    func markVideoGalleryFailed(networkError: Bool) {
        videoPhase = .failed(networkError: networkError)
    }

    func markChannelsFailed(networkError: Bool) {
        channelsPhase = .failed(networkError: networkError)
    }

    func markModelsFailed(networkError: Bool) {
        modelsPhase = .failed(networkError: networkError)
    }

    func markEventsFailed(networkError: Bool) {
        eventsPhase = .failed(networkError: networkError)
    }

    /// Сброс в начальное loading-состояние — для retry после failed.
    /// Возвращает экран в шиммер, чтобы при повторном запросе пользователь
    /// видел тот же скелетон, что и при первом открытии.
    func resetToInitialLoading() {
        screenPhase = .loading
        photoPhase = .loading
        videoPhase = .loading
        channelsPhase = .loading
        modelsPhase = .loading
        eventsPhase = .loading
        similarPhase = .hidden
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
            profileInfoShimmerView.removeFromSuperview()
            profileInfoView.alpha = 1.0
            profileInfoView.isHidden = false
            
            socialShimmerView.isHidden = true

            segmentedBarShimmer.isHidden = true
            segmentedBarPlaceholder.isHidden = false
            segmentedBar.isHidden = false

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

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = blurredHeaderImageView.bounds

        // Те же параметры что для bottom glass на карточках ModelsFeed
        // (см. CardCollectionViewCell). Direction совпадает: top of view —
        // прозрачно (фото читается чисто), bottom — solid blur (плавный
        // scrim перед bio). Ширина fade ~75% высоты + 25% solid внизу —
        // tight transition, не «тинт» на всю площадь.
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.cgColor,
            UIColor.white.cgColor
        ]
        gradientLayer.locations = [0.0, 0.75, 1.0]

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

        // whiteSheetBackground меняет цвет gray↔white в зависимости от близости
        // сегмента к sticky-позиции. Bio к этому моменту уже выше viewport,
        // поэтому потеря серого фона за ней визуально не заметна. Транзишн —
        // последние 30pt подъёма к navHeight: progress 0→1 даёт плавное
        // перетекание серого в белый. В sticky фон под пилюлёй и в 10pt gap
        // становится белым → бесшовный стык с tab content.
        let transitionRange: CGFloat = 30
        let progress = max(0, min(1, (stickyY + transitionRange - naturalY) / transitionRange))
        whiteSheetBackground.backgroundColor = DivoColorPalette.screenBackground.blend(
            with: DivoColorPalette.profileEmptyBackground,
            alpha: progress
        )

        updateFloatingButton(for: currentTab)
    }
    
    // Настройка кнопки чата/загрузки фотографии
    private func setupDmButtonContent() {
        if let iconImageView = dmButton.viewWithTag(ActionViewTags.dmIcon) as? UIImageView,
           let label = dmButton.viewWithTag(ActionViewTags.dmLabel) as? UILabel {
            iconImageView.image = DivoImage.sendDM
            label.text = DivoStrings.sendDM
            return
        }

        dmButton.subviews.forEach { $0.removeFromSuperview() }
        
        let iconImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.image = DivoImage.sendDM
            imageView.tintColor = DivoColorPalette.primaryTextOnDark
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.tag = ActionViewTags.dmIcon
            return imageView
        }()
        
        let label: UILabel = {
            let label = UILabel()
            label.text = DivoStrings.sendDM
            label.textColor = DivoColorPalette.primaryTextOnDark
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
            
            stackView.leadingAnchor.constraint(equalTo: dmButton.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: dmButton.trailingAnchor, constant: -12),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            // label.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])
    }
    
    // Создание кнопок социальных сетей
    private func createSocialMediaButton(handle: String, icon iconImage: UIImage, url: String) -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.l

        socialLinksMap[button] = url

        let icon = UIImageView()
        icon.image = iconImage.withRenderingMode(.alwaysTemplate)
        icon.tintColor = DivoColorPalette.primaryText
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        let label = UILabel()
        label.text = handle
        label.font = Font.regular(10)
        label.textColor = DivoColorPalette.primaryText
        
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        
        button.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: DivoDesignTokens.Spacing.xs),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -DivoDesignTokens.Spacing.xs),
        ])

        button.addTarget(self, action: #selector(socialButtonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    // Создание кнопоки социально сети, если она одна
    private func createSocialOneMediaButton(handle: String, icon iconImage: UIImage, url: String) -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.l

        socialLinksMap[button] = url

        let icon = UIImageView()
        icon.image = iconImage.withRenderingMode(.alwaysTemplate)
        icon.tintColor = DivoColorPalette.primaryText
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        let label = UILabel()
        label.text = handle
        label.font = Font.regular(10)
        label.textColor = DivoColorPalette.primaryText
        
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = DivoDesignTokens.Spacing.s
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false

        button.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])

        button.addTarget(self, action: #selector(socialButtonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    // Добавление коллекции похожих профилей
    func setSimilarProfilesLoading(_ loading: Bool) {
        similarProfilesIsLoading = loading
        // Шиммер для similar НЕ показываем — данные приходят редко, лишний
        // плейсхолдер только мерцает. Контейнер появится через
        // similarPhase = .visible в appendSimilarProfiles, когда придёт
        // непустой массив. Если ответ пуст и не загружается — .hidden.
        if !loading && similarProfiles.isEmpty {
            similarPhase = .hidden
        }
    }
    
    // Заполняет коллекцию реальными данными
    func appendSimilarProfiles(_ profiles: [SimilarProfileItem]) {
        let previousCount = self.similarProfiles.count
        self.similarProfiles.append(contentsOf: profiles)
        self.similarProfilesIsLoading = false
        
        if previousCount == 0 {
            similarProfilesCollectionView.reloadData()
        } else if !profiles.isEmpty {
            let newIndices = (previousCount..<(previousCount + profiles.count)).map { IndexPath(item: $0, section: 0) }
            similarProfilesCollectionView.performBatchUpdates({
                self.similarProfilesCollectionView.insertItems(at: newIndices)
            }, completion: nil)
        }
        
        // applyState() в didSet расставит isHidden + reloadData + пересчёт высот.
        similarPhase = self.similarProfiles.isEmpty ? .hidden : .visible
    }
    
    // Вычисляем возраст от года рождения
    private func calculateAge(from birthdayString: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let birthday = formatter.date(from: birthdayString) else { return nil }

        let now = Date()
        let calendar = Calendar.current
        return calendar.dateComponents([.year], from: birthday, to: now).year
    }
    
    // Создаем список критериев внешнего вида модели
    private func buildAppearanceList(from appearance: UserAppearance?, gender: UserGender?, age: Int?) -> [AppearanceAttribute] {

        func titleWithUnit(_ title: String, _ unit: String) -> String {
            "\(title) (\(unit))"
        }

        var items: [AppearanceAttribute] = []

        if let gender = gender {
            items.append(.init(title: DivoStrings.attrGender, value: gender.title))
        }
        if let age = age {
            items.append(.init(title: titleWithUnit(DivoStrings.attrAge, DivoStrings.unitYo), value: "\(age)"))
        }

        if let appearance = appearance {
            if let height = appearance.height {
                items.append(.init(title: titleWithUnit(DivoStrings.attrHeight, DivoStrings.unitCm), value: height.clean))
            }
            if let waist = appearance.waist {
                items.append(.init(title: titleWithUnit(DivoStrings.attrWaist, DivoStrings.unitCm), value: waist.clean))
            }
            if let weight = appearance.weight {
                items.append(.init(title: titleWithUnit(DivoStrings.attrWeight, DivoStrings.unitKg), value: weight.clean))
            }
            if let bust = appearance.breastSize {
                items.append(.init(title: DivoStrings.attrBust, value: bust))
            }
            if let hips = appearance.hips {
                items.append(.init(title: titleWithUnit(DivoStrings.attrHips, DivoStrings.unitCm), value: hips.clean))
            }
            if let shoesSize = appearance.shoesSize {
                items.append(.init(title: titleWithUnit(DivoStrings.attrShoes, DivoStrings.unitEU), value: shoesSize.clean))
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
                let icon = SocialIcon.icon(for: link)
                let handle = extractHandle(from: link)

                if links.count == 1 {
                    socialMediaStack.addArrangedSubview(createSocialOneMediaButton(handle: handle, icon: icon, url: link))
                    socialHeightConstraint.isActive = false
                    socialHeightConstraint.constant = 48
                    socialHeightConstraint.isActive = true
                } else {
                    socialMediaStack.addArrangedSubview(createSocialMediaButton(handle: handle, icon: icon, url: link))
                    socialHeightConstraint.isActive = false
                    socialHeightConstraint.constant = 68
                    socialHeightConstraint.isActive = true
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

    /// Собирает строку для маленького navBar-заголовка из непустых частей.
    /// Разделитель между смысловыми группами — " • "; между названием города и флагом — " ".
    private static func navbarInfo(rolePrefix: String, middle: String?, cityName: String?, countryCode: String?) -> String {
        let flag = Self.flag(for: countryCode)
        let location = [cityName, flag.isEmpty ? nil : flag]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return [rolePrefix, middle, location.isEmpty ? nil : location]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    /// Грузит аватар в шапку. Спиннер гарантированно гасится на всех путях:
    /// nil-URL, ошибка конвертации, ошибка загрузки, успех.
    private func loadHeaderAvatar(urlString: String?) {
        guard
            let urlString,
            let avatarURL = CDNURLHelper.convertToCDNURL(urlString)
        else {
            self.profileHeaderView.toggleSpinner(active: false)
            return
        }

        ImageLoader.shared.load(url: avatarURL) { [weak self] image in
            guard let self else { return }
            self.profileHeaderView.toggleSpinner(active: false)
            if let image {
                self.profileHeaderView.changeAvatar(with: image)
            }
        }
    }
    
    // Первоначальная настройка титула NavigationBar
    private func setupNavigationBarTitle(name: String, info: String? = nil) {
        if let existingTitleView = self.navigationBarTitleView {
            existingTitleView.configure(name: name, info: info)
        } else {
            let titleView = ProfileNavigationBarTitleView()
            titleView.translatesAutoresizingMaskIntoConstraints = false
            titleView.configure(name: name, info: info)
            
            self.navigationBarTitleView = titleView
            
            self.customNavBar.addSubview(titleView)
            
            NSLayoutConstraint.activate([
                titleView.centerXAnchor.constraint(equalTo: customNavBar.centerXAnchor),
                titleView.centerYAnchor.constraint(equalTo: customNavBar.bottomAnchor, constant: -25),
                titleView.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 12),
                titleView.trailingAnchor.constraint(lessThanOrEqualTo: rightButtonContainer.leadingAnchor, constant: -12)
            ])
        }

        if !titleVisibilityActivated {
            navigationBarTitleView?.alpha = 0.0
        }
        updateNavigationBarTitleVisibility()
    }
    
    private func updateNavigationBarTitleVisibility() {
        guard let titleView = navigationBarTitleView,
            let (_, navigationBarHeight) = self.containerLayout else { return }

        guard titleVisibilityActivated else {
            if titleView.alpha != 0.0 { titleView.alpha = 0.0 }
            navBarBlurView.alpha = 0
            customNavBar.backgroundColor = .clear
            return
        }
        
        let offsetY = scrollView.contentOffset.y
        
        // =========================================================
        // ФАЗА 1: Исчезновение Имени -> Появление титула и цвета НавБара
        // =========================================================
        let nameY = infoStack.frame.minY > 0 ? infoStack.frame.minY : 360.0
        
        let titleStartShowingOffset = nameY - navigationBarHeight - 40
        let titleFullyVisibleOffset = nameY - navigationBarHeight + 20
        
        var titleAlpha: CGFloat = 0.0
        if offsetY < titleStartShowingOffset { titleAlpha = 0.0 }
        else if offsetY >= titleFullyVisibleOffset { titleAlpha = 1.0 }
        else { titleAlpha = (offsetY - titleStartShowingOffset) / (titleFullyVisibleOffset - titleStartShowingOffset) }
        
        if titleView.alpha != titleAlpha {
            titleView.alpha = titleAlpha
        }
        
        // =========================================================
        // ПРИМЕНЕНИЕ ФАЗ К UI
        // =========================================================

        // 1. Блюр поднимается ДО того, как натуральный title начнёт заходить
        // в зону navbar (= до titleStartShowingOffset). Иначе title «висит в
        // воздухе» без фона за собой в момент перехода. Fade-in за 30pt до
        // того места, где title начинает fade-in (titleAlpha = 0).
        let blurFullOffset = titleStartShowingOffset
        let blurStartOffset = blurFullOffset - 30
        let blurAlpha: CGFloat
        if offsetY < blurStartOffset {
            blurAlpha = 0
        } else if offsetY >= blurFullOffset {
            blurAlpha = 1
        } else {
            blurAlpha = (offsetY - blurStartOffset) / (blurFullOffset - blurStartOffset)
        }
        navBarBlurView.alpha = blurAlpha

        // 2. Иконки кнопок
        let maxProgress = titleAlpha
        let iconColor = DivoColorPalette.primaryTextOnDark.blend(with: DivoColorPalette.primaryText, alpha: maxProgress)
        closeButton.tintColor = iconColor
        storiesButton.tintColor = iconColor
        editButton.tintColor = iconColor
        moreButton.tintColor = iconColor
        
        // 3. Фон кнопок: в non-sticky полупрозрачный белый поверх фото (как
        // pill'ы стандартного UIKit). В sticky — серый screenBackground, чтобы
        // pill'ы выделялись на белой части навбара (которая внизу gradient'a).
        let bgStartColor = DivoColorPalette.statPillBackground
        let bgEndColor = DivoColorPalette.screenBackground
        let currentBgColor = bgStartColor.blend(with: bgEndColor, alpha: maxProgress)

        closeButton.backgroundColor = currentBgColor
        rightButtonContainer.backgroundColor = currentBgColor
        
        // 4. Границы прячем
        let borderStartColor = DivoColorPalette.statPillBorder.cgColor
        let borderEndColor = UIColor.clear.cgColor
        closeButton.layer.borderColor = maxProgress > 0.5 ? borderEndColor : borderStartColor
        rightButtonContainer.layer.borderColor = maxProgress > 0.5 ? borderEndColor : borderStartColor

        // 5. Fade-out stat pills — relative от точки покоя (с учётом
        // contentInset.top). При scrolled > 0 (любой скролл вверх от rest)
        // запускаем fade в 60pt range. Иначе stat-пилюли наезжают на
        // навбарные кнопки.
        let scrolled = offsetY + navigationBarHeight
        if scrolled > 0 {
            let pillAlpha = max(0, 1.0 - scrolled / 60.0)
            counterActionsStack.alpha = pillAlpha
            actionsShimmerView.alpha = pillAlpha
        } else {
            counterActionsStack.alpha = 1.0
            actionsShimmerView.alpha = 1.0
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

    // Вызывается при старте загрузки
    func showUploadOverlay(isPhoto: Bool) {
        uploadOverlayLabel.text = isPhoto ? DivoStrings.uploadingPhotos : DivoStrings.uploadingVideos
        uploadOverlayContainer.isHidden = false
        uploadOverlaySpinner.startAnimating()
        
        UIView.animate(withDuration: 0.3) {
            self.uploadOverlayContainer.alpha = 1.0
            self.floatingAddButton.alpha = 0.0
            self.floatingAddButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }
    }
    
    func hideUploadOverlay() {
        UIView.animate(withDuration: 0.3, animations: {
            self.uploadOverlayContainer.alpha = 0.0
            self.floatingAddButton.alpha = 1.0
            self.floatingAddButton.transform = .identity
        }) { _ in
            self.uploadOverlayContainer.isHidden = true
            self.uploadOverlaySpinner.stopAnimating()
        }
    }
    
    func showUploadStatusView(isPhoto: Bool) {
        if isPhoto {
            galleryStatusView.isHidden = false
            galleryStatusView.configure(isLoading: true, text: DivoStrings.uploadingPhotos, isMyProfile: false)
        } else {
            videoGalleryStatusView.isHidden = false
            videoGalleryStatusView.configure(isLoading: true, text: DivoStrings.uploadingVideos, isMyProfile: false)
        }
    }
    
    func hideUploadStatusView(isPhoto: Bool) {
        if isPhoto {
            galleryStatusView.isHidden = true
        } else {
            videoGalleryStatusView.isHidden = true
        }
    }

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
    
    // Обновляем Layout после загрузки контроллера
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)

        navigationBarTitleHeightConstraint.isActive = false
        // scrollView.top = view.top (рамка во весь экран), но contentInset.top
        // = navigationBarHeight — контент изначально стоит под navbar (как
        // раньше с фиксированным отступом), но при скролле УХОДИТ ВЫШЕ под
        // navbar/status bar, давая native-Telegram эффект.
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor)
        navigationBarTitleHeightConstraint.isActive = true
        scrollView.contentInset = UIEdgeInsets(top: navigationBarHeight, left: 0, bottom: 0, right: 0)
        scrollView.scrollIndicatorInsets = scrollView.contentInset

        // Один раз на первый layout стартуем contentOffset = -navigationBarHeight,
        // чтобы контент стоял под navbar при первом показе. После этого
        // оставляем как есть — пользователь свободно скроллит.
        if !hasInitialContentOffsetApplied {
            scrollView.contentOffset = CGPoint(x: 0, y: -navigationBarHeight)
            hasInitialContentOffsetApplied = true
        }

        // Стартовая высота bottomSpacer = safeArea + 4, чтобы при max scroll
        // последний элемент стоял чуть над home indicator. layout() добавит
        // больше для короткого контента.
        bottomSpacerHeightConstraint.constant = layout.intrinsicInsets.bottom + 4

        applyGradientBlurMask()
        updateNavBarBlurMask()

        updateAllCollectionViewHeights(layout: layout)
        updateCollectionsContainerHeight(animated: false)

        galleryCollectionView.collectionViewLayout.invalidateLayout()
        videoGalleryCollectionView.collectionViewLayout.invalidateLayout()
        channelGalleryCollectionView.collectionViewLayout.invalidateLayout()
        modelGalleryCollectionView.collectionViewLayout.invalidateLayout()
        eventGalleryCollectionView.collectionViewLayout.invalidateLayout()

        updateNavigationBarTitleVisibility()

        self.layoutIfNeeded()

        // После любого layout-апдейта (стартового и при ротации) выровняем
        // пейджер на текущую страницу — иначе offset остаётся в старой
        // системе координат и выглядит как «таб уехал в сторону».
        snapPagerToCurrentTab(animated: false)
    }

    func setBackgroundLoading(_ loading: Bool) {
        if loading {
            headerSpinner.startAnimating()
            headerSpinner.isHidden = false
            headerImageView.alpha = 0.5
        } else {
            headerSpinner.stopAnimating()
            headerSpinner.isHidden = true
            headerImageView.alpha = 1.0
        }
    }
    
    func updateBackgroundImage(_ image: UIImage?) {
        if let image = image {
            headerImageView.image = image
        }
    }

    func faceSearchSeedImage() -> UIImage? {
        return avatarImage ?? headerImageView.image
    }
    
    // Обновление профиля, после загрузки baseURL/user/userId
    func updateWithUserDetail(_ detail: UserDetail, _ isMyProfile: Bool) {
        self.profileHeaderView.toggleSpinner(active: true)
        self.modelDetail = detail
        var bio: String?
        var appearance: [AppearanceAttribute]

        self.modelRole = Role(apiRole: detail.role)
        self.updateScreenBackgroundForCurrentTab()

        if self.modelRole == .agency {
            setupNavigationBarTitle(
                name: detail.agency?.title ?? DivoStrings.noName,
                info: Self.navbarInfo(
                    rolePrefix: self.modelRole.title,
                    middle: nil,
                    cityName: detail.agency?.address?.city?.name,
                    countryCode: detail.agency?.address?.city?.countryCode
                )
            )

            if let photoURLString = detail.photo?.fullUrl, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
                headerImageView.loadImage(from: photoURL)
            }

            bio = (detail.agency?.description?.isEmpty == false)
            ? (detail.agency?.description ?? "")
            : Self.mockBiographyText

            UIView.performWithoutAnimation {
                profileInfoView.update(biography: bio)
                profileInfoView.layoutIfNeeded()
            }
            // animated: false — иначе иконки "прилетают" поверх шиммера
            // в момент перехода screenPhase = .ready (см. applyScreenPhase).
            segmentedBar.configure(isAgency: true, isMyProfile: isMyProfile, animated: false)
            rebuildTabsPagerLayout()

            loadHeaderAvatar(urlString: detail.agency?.photo?.fullUrl)
        } else {
            let age = detail.birthday.flatMap { calculateAge(from: $0) }
            setupNavigationBarTitle(
                name: detail.fullName ?? DivoStrings.noName,
                info: Self.navbarInfo(
                    rolePrefix: self.modelRole.title,
                    middle: age.map { DivoStrings.ageString($0) },
                    cityName: detail.city?.name,
                    countryCode: detail.city?.countryCode
                )
            )

            if let photoURLString = detail.photo?.fullUrl, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
                headerImageView.loadImage(from: photoURL)
            }

            bio = (detail.model?.description?.isEmpty == false)
            ? (detail.model?.description ?? "")
            :  nil

            appearance = buildAppearanceList(from: detail.model?.appearance, gender: detail.gender, age: age)

            var experience: ExperienceNode? = nil
            if detail.model?.agency != nil {
                let logoURLString = detail.model?.agency?.photo?.fullUrl
                let logoURL = logoURLString != nil ? URL(string: logoURLString!) : nil
                experience = ExperienceNode(title: detail.model?.agency?.title, period: detail.model?.agency?.title, logoURL: logoURL, delegate: self)
            }
            UIView.performWithoutAnimation {
                profileInfoView.update(biography: bio, appearance: appearance, experience: experience, isMyProfile: isMyProfile)
                profileInfoView.openAddWorkExperience = { [weak self] in
                    self?.onEditProfileTapped?(2)
                }
                profileInfoView.openEditBio = { [weak self] in
                    self?.onEditProfileTapped?(0)
                }
                profileInfoView.openEditAppearance = { [weak self] in
                    self?.onEditProfileTapped?(1)
                }
                profileInfoView.layoutIfNeeded()
            }
            // animated: false — см. комментарий выше про agency-ветку.
            segmentedBar.configure(isAgency: false, isMyProfile: isMyProfile, animated: false)
            rebuildTabsPagerLayout()

            loadHeaderAvatar(urlString: detail.avatar?.fullUrl)
        }

        setupMoreMenu()
        setupEditMenu(isMyProfile: isMyProfile)

        var socialLinks: [String] = []

        // Собираем все непустые ссылки в один массив
        if let tiktok = detail.model?.tiktokUrl, !tiktok.isEmpty { socialLinks.append(tiktok) }
        if let youtube = detail.model?.youtubeUrl, !youtube.isEmpty { socialLinks.append(youtube) }
        if let instagram = detail.model?.instagramUrl, !instagram.isEmpty { socialLinks.append(instagram) }
        if let website = detail.model?.websiteUrl, !website.isEmpty { socialLinks.append(website) }
        
        populateSocialMedia(links: socialLinks)

        if !isMyProfile {
            // similarPhase = .hidden по дефолту; .visible выставится только
            // в appendSimilarProfiles при непустом ответе. Для agency запрос
            // similar вообще не делается (см. контроллер), карусель навсегда скрыта.
            sendShareContainer.isHidden = false
            dmShareStack.isHidden = false
            dmShareShimmerStack.isHidden = true
            setupDmButtonContent()
            titleEditContainer.removeFromSuperview()
        } else {
            sendShareContainer.isHidden = true
            titleEditContainer.isHidden = !socialLinks.isEmpty ? false : true
            contentViewStack.setCustomSpacing(44, after: profileHeaderWrapper)
        }
        
        // FIXME DIVO: isOnline захардкожен — API пока не возвращает это поле
        UIView.performWithoutAnimation {
            if self.modelRole == .agency {
                let viewModel = UserProfileViewModel(
                    name: detail.agency?.title ?? DivoStrings.noName,
                    age: nil,
                    location: detail.agency?.address?.city?.name ?? "",
                    countryFlag: Self.flag(for: detail.agency?.address?.city?.countryCode),
                    role: self.modelRole,
                    avatarImage: nil,
                    isPremium: detail.isPremium ?? false,
                    isOnline: true
                )
                profileHeaderView.configure(with: viewModel)
            } else {
                let age = detail.birthday.flatMap { calculateAge(from: $0) }
                let viewModel = UserProfileViewModel(
                    name: detail.fullName ?? DivoStrings.noName,
                    age: age,
                    location: detail.city?.name ?? "",
                    countryFlag: Self.flag(for: detail.city?.countryCode),
                    role: self.modelRole,
                    avatarImage: nil,
                    isPremium: detail.isPremium ?? false,
                    isOnline: true
                )
                profileHeaderView.configure(with: viewModel)
            }
        }
        // Профиль загружен — переходим в .ready. applyState() атомарно
        // снимет шиммеры (через stopShimmers), активирует scroll/swipe.
        screenPhase = .ready
        activateTitleVisibility()
    }

    func updateEngagementStats(likes: Int, views: Int, saves: Int, isLiked: Bool = false, isSaved: Bool = false) {
        self.currentLikesCount = likes
        self.currentIsLiked = isLiked
        
        self.currentSavesCount = saves
        self.currentIsSaved = isSaved
        
        likesView.setValue(Self.formatCount(likes))
        likesView.setActive(isLiked, animated: false)
        
        viewsView.setValue(Self.formatCount(views))
        
        savesView.setValue(Self.formatCount(saves))
        savesView.setActive(isSaved, animated: false)
    }

    /// Formats count to max 4 characters: 999 → "999", 1K, 288K, 1.5M, 10M, 1.5B
    static func formatCount(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            let value = Double(count) / 1_000_000_000.0
            if value >= 10 {
                return "\(Int(value))B"
            }
            let formatted = String(format: "%.1f", value)
            if formatted.hasSuffix(".0") {
                return "\(Int(value))B"
            }
            return "\(formatted)B"
        } else if count >= 1_000_000 {
            let value = Double(count) / 1_000_000.0
            if value >= 10 {
                return "\(Int(value))M"
            }
            let formatted = String(format: "%.1f", value)
            if formatted.hasSuffix(".0") {
                return "\(Int(value))M"
            }
            return "\(formatted)M"
        } else if count >= 1_000 {
            return "\(count / 1_000)K"
        }
        return "\(count)"
    }
    
    // Добавление фотографий в галерею пагинацией
    func appendGalleryPhotos(_ photos: UserPhotos, isMyProfile: Bool) {
        let newPhotos = photos.items
        let totalCount = photos.pagination.meta.totalCount
        let serverOffset = photos.pagination.meta.currentOffset
        
        if !galleryInitialized {
            self.galleryPhotos = []
            galleryInitialized = true
        }
        
        let existingIds = Set(self.galleryPhotos.map { $0.id })
        let uniqueNewPhotos = newPhotos.filter { !existingIds.contains($0.id) }
        
        let previousCount = self.galleryPhotos.count
        self.galleryPhotos.append(contentsOf: uniqueNewPhotos)
        
        self.galleryCurrentOffset = serverOffset
        self.galleryHasMore = self.galleryPhotos.count < totalCount
        self.galleryIsLoading = false
        
        if previousCount == 0 {
            // Первая страница пришла — переключаем стейт фото-таба.
            // applyState() атомарно расставит видимость collection/empty/shimmer
            // и пересчитает высоты.
            self.galleryCollectionView.reloadData()
            self.updateScreenBackgroundForCurrentTab()
            self.photoPhase = self.galleryPhotos.isEmpty ? .empty : .content

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.checkAndLoadMoreGalleryPhotos()
            }
        } else if !uniqueNewPhotos.isEmpty {
            let newIndices = (previousCount..<(previousCount + uniqueNewPhotos.count)).map { IndexPath(item: $0, section: 0) }
            self.galleryCollectionView.performBatchUpdates({
                self.galleryCollectionView.insertItems(at: newIndices)
                if let layout = self.containerLayout?.0 {
                    self.updateAllCollectionViewHeights(layout: layout)
                    if self.currentTab == .photo { self.updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { [weak self] _ in
                self?.checkAndLoadMoreGalleryPhotos()
            })
        }
        updateFloatingButton(for: currentTab)
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
            galleryCollectionView.reloadData()
            photoPhase = .content
            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTab == .photo { updateCollectionsContainerHeight(animated: true) }
            }
        } else {
            galleryCollectionView.performBatchUpdates({
                galleryCollectionView.insertItems(at: [IndexPath(item: 0, section: 0)])
                if let layout = self.containerLayout?.0 {
                    updateAllCollectionViewHeights(layout: layout)
                    if currentTab == .photo { updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { _ in
                self.galleryCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: true)
            })
        }
        updateFloatingButton(for: currentTab)
    }

    func finishPhotoUpload(photo: UserPhoto) {
        uploadingPhotoImage = nil
        galleryStatusView.isHidden = true
        if !galleryPhotos.isEmpty && galleryPhotos[0].id == -1 {
            galleryPhotos[0] = photo
            galleryCollectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
        }
        updateFloatingButton(for: currentTab)
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
                if currentTab == .photo { updateCollectionsContainerHeight(animated: true) }
            }
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            if self.galleryPhotos.isEmpty {
                self.galleryStatusView.isHidden = true
                self.photoPhase = .empty
            }
        })
        updateFloatingButton(for: currentTab)
    }

    // Добавление одной новой фотографии в начало (после успешной загрузки)
    func insertNewPhoto(_ photo: UserPhoto) {
        let wasEmpty = galleryPhotos.isEmpty

        galleryPhotos.insert(photo, at: 0)

        galleryCurrentOffset += 1

        if wasEmpty {
            galleryStatusView.isHidden = true
            galleryCollectionView.reloadData()
            photoPhase = .content

            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTab == .photo { updateCollectionsContainerHeight(animated: true) }
            }
        } else {
            galleryCollectionView.performBatchUpdates({
                let indexPath = IndexPath(item: 0, section: 0)
                galleryCollectionView.insertItems(at: [indexPath])

                if let layout = self.containerLayout?.0 {
                    updateAllCollectionViewHeights(layout: layout)
                    if currentTab == .photo { updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { _ in
                self.galleryCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: true)
            })
        }
        updateFloatingButton(for: currentTab)
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
                if currentTab == .photo { updateCollectionsContainerHeight(animated: true) }
            }
        }, completion: {[weak self] _ in
            guard let self = self else { return }
            // Если удалили последнее фото, показываем заглушку
            if self.galleryPhotos.isEmpty {
                self.galleryStatusView.isHidden = true
                self.photoPhase = .empty
            }
        })
        updateFloatingButton(for: currentTab)
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
        divoLog("[PAGINATION] Reset gallery pagination state")
    }
    
    // Флаг загрузки галереи
    func setGalleryLoading(_ loading: Bool, _ uploadNew: Bool = false) {
        galleryIsLoading = loading
        // Первичная загрузка — её показывает photoGalleryShimmerView (skeleton),
        // galleryStatusView не трогаем. Только после `galleryInitialized = true`
        // (т.е. при пользовательских upload-сценариях) галерейный статус-вью
        // снова в игре.
        guard galleryInitialized else { return }
        // Если уже есть фото — лоадер скрыт всегда. Показываем только когда галерея пустая и идёт загрузка.
        galleryStatusView.isHidden = !galleryPhotos.isEmpty || !loading
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
        updateFloatingButton(for: currentTab)
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
            // Первая страница пришла — переключаем фазу видео-таба.
            // applyState() атомарно расставит видимость shimmer/empty/content
            // и обновит фон. Высоту пейджера для активного таба обновляем
            // отдельно, потому что applyHeights() пересчитывает container
            // только для photo.
            let hasVideos = !self.videoGalleryItems.isEmpty
            self.videoGalleryCollectionView.reloadData()
            self.videoPhase = hasVideos ? .content : .empty
            if let layout = self.containerLayout?.0 {
                self.updateAllCollectionViewHeights(layout: layout)
                if self.currentTab == .video { self.updateCollectionsContainerHeight(animated: true) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.checkAndLoadMoreVideoGallery()
            }
        } else if !uniquePhotoItems.isEmpty {
            let newIndices = (previousCount..<(previousCount + uniquePhotoItems.count)).map { IndexPath(item: $0, section: 0) }
            self.videoGalleryCollectionView.performBatchUpdates({
                self.videoGalleryCollectionView.insertItems(at: newIndices)
                if let layout = self.containerLayout?.0 {
                    self.updateAllCollectionViewHeights(layout: layout)
                    if self.currentTab == .video { self.updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { [weak self] _ in
                self?.checkAndLoadMoreVideoGallery()
            })
        }
        updateFloatingButton(for: currentTab)
    }
    
    func checkAndLoadMoreVideoGallery() {
        guard videoGalleryHasMore && !videoGalleryIsLoading else { return }

        videoGalleryCollectionView.layoutIfNeeded()

        let contentHeight = videoGalleryCollectionView.contentSize.height
        let frameHeight = videoGalleryCollectionView.frame.size.height

        if contentHeight <= frameHeight {
            loadNextVideoGalleryPage()
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
            videoGalleryCollectionView.reloadData()
            videoPhase = .content
            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTab == .video { updateCollectionsContainerHeight(animated: true) }
            }
        } else {
            videoGalleryCollectionView.performBatchUpdates({
                videoGalleryCollectionView.insertItems(at: [IndexPath(item: 0, section: 0)])
                if let layout = self.containerLayout?.0 {
                    updateAllCollectionViewHeights(layout: layout)
                    if currentTab == .video { updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { _ in
                self.videoGalleryCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: true)
            })
        }
        updateFloatingButton(for: currentTab)
    }

    func finishVideoUpload(video: UserPhoto) {
        uploadingVideoImage = nil
        videoGalleryStatusView.isHidden = true
        if !videoGalleryItems.isEmpty && videoGalleryItems[0].id == -1 {
            videoGalleryItems[0] = video
            videoGalleryCollectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
        }
        updateFloatingButton(for: currentTab)
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
                if currentTab == .video { updateCollectionsContainerHeight(animated: true) }
            }
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            if self.videoGalleryItems.isEmpty {
                self.videoPhase = .empty
            }
        })
        updateFloatingButton(for: currentTab)
    }

    func insertNewVideo(_ video: UserPhoto) {
        let wasEmpty = videoGalleryItems.isEmpty

        videoGalleryItems.insert(video, at: 0)

        videoGalleryCurrentOffset += 1

        if wasEmpty {
            videoGalleryCollectionView.reloadData()
            videoPhase = .content

            if let layout = self.containerLayout?.0 {
                updateAllCollectionViewHeights(layout: layout)
                if currentTab == .video { updateCollectionsContainerHeight(animated: true) }
            }
        } else {
            videoGalleryCollectionView.performBatchUpdates({
                let indexPath = IndexPath(item: 0, section: 0)
                videoGalleryCollectionView.insertItems(at: [indexPath])

                if let layout = self.containerLayout?.0 {
                    updateAllCollectionViewHeights(layout: layout)
                    if currentTab == .photo { updateCollectionsContainerHeight(animated: true) }
                }
            }, completion: { _ in
                self.videoGalleryCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: true)
            })
        }
        updateFloatingButton(for: currentTab)
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
                if currentTab == .video { updateCollectionsContainerHeight(animated: true) }
            }
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            if self.videoGalleryItems.isEmpty {
                self.videoPhase = .empty
            }
        })
        updateFloatingButton(for: currentTab)
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
        divoLog("[VIDEO] Reset video gallery pagination state")
    }
    
    // Флаг загрузки галереи видео
    func setVideoGalleryLoading(_ loading: Bool, _ uploadNew: Bool = false) {
        videoGalleryIsLoading = loading
        // Если уже есть видео — лоадер скрыт всегда. Показываем только когда галерея пустая и идёт загрузка.
        videoGalleryStatusView.isHidden = !videoGalleryItems.isEmpty || !loading
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
        self.channelGalleryCollectionView.reloadData()
        // applyState() расставит видимость shimmer/empty/content и фон.
        self.channelsPhase = items.isEmpty ? .empty : .content

        if let layout = self.containerLayout?.0 {
            self.updateAllCollectionViewHeights(layout: layout)
            if self.currentTab == .channels { self.updateCollectionsContainerHeight(animated: false) }
        }
    }
    
    // Загрузка высоты галереи каналов
    private func updateChannelsCollectionViewHeight() {
        let channelCellHeight: CGFloat = 66.0
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
    func updateModelsList(_ items: [ModelItem]) {
        self.modelGalleryItems = items
        self.modelGalleryCollectionView.reloadData()
        self.modelsPhase = items.isEmpty ? .empty : .content

        if let layout = self.containerLayout?.0 {
            self.updateAllCollectionViewHeights(layout: layout)
            if self.currentTab == .models {
                self.updateCollectionsContainerHeight(animated: false)
            }
        }
    }
    
    // Загрузка высоты галереи моделей
    private func updateModelsCollectionViewHeight() {
        let modelCellHeight: CGFloat = 66.0
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

    func startLoadEventsList() {
        self.eventsPhase = .loading

        if let layout = self.containerLayout?.0 {
            self.updateAllCollectionViewHeights(layout: layout)
            if self.currentTab == .events {
                self.updateCollectionsContainerHeight(animated: false)
            }
        }
    }
    
    // Обновление галереи событий
    func updateEventsList(_ items: [EventItem]) {
        self.eventGalleryItems = items
        self.eventGalleryCollectionView.reloadData()
        self.eventsPhase = items.isEmpty ? .empty : .content

        if let layout = self.containerLayout?.0 {
            self.updateAllCollectionViewHeights(layout: layout)
            if self.currentTab == .events {
                self.updateCollectionsContainerHeight(animated: false)
            }
        }
    }
    
    // Загрузка высоты галереи событий
    private func updateEventsCollectionViewHeight() {
        let eventCellHeight: CGFloat = 66.0
        let eventsHeight = CGFloat(eventGalleryItems.count) * eventCellHeight
        
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

        let pRows = ceil(CGFloat(galleryPhotos.count) / itemsPerRow)
        galleryHeightConstraint.constant = max(pRows * itemWidth + max(0, pRows - 1) * spacing, 1.0)

        let vRows = ceil(CGFloat(videoGalleryItems.count) / itemsPerRow)
        videoHeightConstraint.constant = max(vRows * itemWidth + max(0, vRows - 1) * spacing, 1.0)

        channelHeightConstraint.constant = max(CGFloat(channelGalleryItems.count) * 66.0, 1.0)
        modelHeightConstraint.constant = max(CGFloat(modelGalleryItems.count) * 66.0, 1.0)
        eventHeightConstraint.constant = max(CGFloat(eventGalleryItems.count) * 66.0, 1.0)

        // Высота gallery-зоны фото-таба (внутри неё overlap'ятся grid /
        // empty / shimmer / status). Зависит от стейта photo-таба.
        galleryAreaHeightConstraint.constant = photoGalleryAreaHeight()

        // Высота секции similar внутри photo-таба: 0 если контейнер скрыт,
        // дизайнерская высота если виден.
        similarSectionHeightConstraint.constant = similarSectionTargetHeight()

        // Подтягиваем высоту каждого таб-контейнера в пейджере к актуальной.
        for tab in ProfileTab.allCases {
            heightConstraint(for: tab).constant = tabHeight(for: tab)
        }
    }

    private func calculateCollectionsContainerHeight() -> CGFloat {
        return tabHeight(for: currentTab)
    }
    
    private func updateCollectionsContainerHeight(animated: Bool = true) {
        collectionsContainerHeightConstraint.constant = calculateCollectionsContainerHeight()

        // Стабильный отступ 10pt под сегмент-баром во всех стейтах
        // (включая empty и shimmer) — placeholder/контент не липнут к пилюле.
        // Серая полоска не образуется, потому что цвет whiteSheet под этим
        // отступом подстраивается в updateContainerBackgrounds().
        contentViewStack.setCustomSpacing(10, after: segmentedBarContainer)

        updateBottomSpacerVisibility()

        // Скролл/свайп управляется централизованно из applyInteractionEnabled()
        // на основе screenPhase. Здесь не трогаем.

        // segmentedBarContainer оставляем `.clear` всегда — фон под ним даёт
        // whiteSheetBackground, который перекрашивается в updateContainerBackgrounds().

        // Если в этот момент идёт переключение таба — async-загрузка не должна
        // запускать собственную анимацию высоты поверх. Финализация tab-switch
        // сама приведёт layout к нужному состоянию.
        let shouldAnimate = animated
            && !scrollView.isDragging
            && !scrollView.isDecelerating
            && !isTabSwitching

        if shouldAnimate {
            UIView.animate(withDuration: 0.30, delay: 0, options: [.curveEaseOut]) {
                self.contentViewStack.layoutIfNeeded()
                self.view.layoutIfNeeded()

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

    // Метод, который меняет внешний вид кнопки в зависимости от таба
    private func updateFloatingButton(for tab: ProfileTab) {
        guard model.isMyProfile else {
            if !floatingAddButton.isHidden {
                floatingAddButton.isHidden = true
            }
            return
        }
        
        var title = ""
        var icon = UIImage()
        var isVisible = true
        
        switch tab {
        case .photo:
            title = DivoStrings.addPhoto
            icon = DivoImage.addPhotoIcon
            isVisible = !galleryPhotos.isEmpty
            
        case .video:
            title = DivoStrings.addVideo
            icon = DivoImage.videoIconButton
            isVisible = !videoGalleryItems.isEmpty
            
        case .models:
            if modelRole == .agency {
                title = DivoStrings.addModel
                icon = DivoImage.whitePlus
                isVisible = !modelGalleryItems.isEmpty
            } else {
                isVisible = false
            }
            
        case .events:
            title = DivoStrings.createEvent
            icon = DivoImage.whitePlus
            isVisible = !eventGalleryItems.isEmpty
            
        case .channels:
            isVisible = false
        }
        
        if isVisible {
            floatingAddButton.makeDivoButton(title: title, leadingIcon: icon, buttonFont: Font.helveticaNeue(16), radius: 20)
            
            if floatingAddButton.isHidden || floatingAddButton.alpha < 1.0 {
                floatingAddButton.layer.removeAllAnimations()
                
                if floatingAddButton.isHidden {
                    floatingAddButton.alpha = 0
                    floatingAddButton.isHidden = false
                }
                
                UIView.animate(withDuration: 0.3) {
                    self.floatingAddButton.alpha = 1.0
                }
            } else {
                UIView.transition(with: floatingAddButton, duration: 0.2, options: .transitionCrossDissolve, animations: nil, completion: nil)
            }
        } else {
            if !floatingAddButton.isHidden {
                UIView.animate(withDuration: 0.3, animations: {
                    self.floatingAddButton.alpha = 0.0
                }) { finished in
                    if finished {
                        self.floatingAddButton.isHidden = true
                    }
                }
            }
        }
    }

    // Точечное обновление состояния ячейки события (Задачи 1 и 2)
    public func updateEventLocally(eventId: Int, isApplied: Bool) {
        guard let index = self.eventGalleryItems.firstIndex(where: { $0.eventId == eventId }) else { return }
        
        let oldItem = self.eventGalleryItems[index]
        let newItem = EventItem(
            name: oldItem.name,
            data: oldItem.data,
            time: oldItem.time,
            countryFlag: oldItem.countryFlag,
            city: oldItem.city,
            customAvatarURL: oldItem.customAvatarURL,
            originalDate: oldItem.originalDate,
            eventId: oldItem.eventId,
            isApplied: isApplied,
            isMyRoleAgency: self.isMyRoleAgency
        )
        self.eventGalleryItems[index] = newItem
        
        let indexPath = IndexPath(item: index, section: 0)
        self.eventGalleryCollectionView.reloadItems(at: [indexPath])
    }

    
    // MARK: - @objc

    @objc private func likesPillTapped() {
        guard let userId = model.userId, !isLikingProcess else { return }
        
        isLikingProcess = true
        
        currentIsLiked.toggle()
        currentLikesCount = max(0, currentLikesCount + (currentIsLiked ? 1 : -1))
        
        likesView.setActive(currentIsLiked, animated: true)
        likesView.setValue(Self.formatCount(currentLikesCount))
        likesView.popIcon()
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.toggleLikeProfile(userId: userId, isLiked: currentIsLiked) {[weak self] success in
                guard let self = self else { return }
                self.isLikingProcess = false
                
                if !success {
                    self.currentIsLiked.toggle()
                    self.currentLikesCount = max(0, self.currentLikesCount + (self.currentIsLiked ? 1 : -1))
                    
                    self.likesView.setActive(self.currentIsLiked, animated: true)
                    self.likesView.setValue(Self.formatCount(self.currentLikesCount))
                }
            }
        }
    }
    
    @objc private func savesPillTapped() {
        guard let userId = model.userId, !isSavingProcess else { return }
        
        isSavingProcess = true
        
        currentIsSaved.toggle()
        currentSavesCount = max(0, currentSavesCount + (currentIsSaved ? 1 : -1))
        
        savesView.setActive(currentIsSaved, animated: true)
        savesView.setValue(Self.formatCount(currentSavesCount))
        savesView.popIcon()
        
        if let controller = self.controller as? PublicProfileScreenController {
            controller.toggleSaveProfile(userId: userId, isSaved: currentIsSaved) { [weak self] success in
                guard let self = self else { return }
                self.isSavingProcess = false
                
                if !success {
                    self.currentIsSaved.toggle()
                    self.currentSavesCount = max(0, self.currentSavesCount + (self.currentIsSaved ? 1 : -1))
                    
                    self.savesView.setActive(self.currentIsSaved, animated: true)
                    self.savesView.setValue(Self.formatCount(self.currentSavesCount))
                }
            }
        }
    }

    // Метод, который вызывает нужный Action в зависимости от открытого таба
    @objc private func floatingAddButtonTapped() {
        let maxScrollY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.scrollView.contentOffset = CGPoint(x: 0, y: maxScrollY)
        }) { _ in
            switch self.currentTab {
            case .photo:
                self.onAddPhotoTapped?(true)
            case .video:
                self.onAddVideoTapped?(true)
            case .models:
                self.onAddModelTapped?()
            case .events:
                self.onAddEventTapped?()
            case .channels:
                break
            }
        }
    }

    @objc private func addModelBtnTapped() {
        onAddModelTapped?()
    }
    
    @objc private func dmButtonTapped() {
        // FIXME DIVO: implement send DM action (open chat with user)
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
        onAddPhotoTapped?(false)
    }

    @objc private func videoGalleryStatusTapped() {
        onAddVideoTapped?(false)
    }

    @objc private func eventGalleryStatusTapped() {
        onAddEventTapped?()
    }

    @objc private func shareTapped() {
        onGridShareTapped?(modelDetail, avatarImage)
    }

    @objc private func closeTapped() {
        onBackTapped?()
    }

    @objc private func storiesTapped() {
        storiesButtonTapped?()
    }


    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: DivoDesignTokens.Spacing.m,
            bottomAnchor: view.safeAreaLayoutGuide.bottomAnchor,
            retryTitle: retryAction != nil ? DivoStrings.retry : nil,
            retryAction: retryAction,
            persistent: persistent
        )
    }

    func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
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
            if similarProfilesIsLoading && similarProfiles.isEmpty {
                return 6
            }
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
            if similarProfilesIsLoading && similarProfiles.isEmpty {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SimilarProfileShimmerCell.reuseIdentifier, for: indexPath) as? SimilarProfileShimmerCell else {
                    return UICollectionViewCell()
                }
                cell.startAnimation()
                return cell
            }
            
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
            cell.configure(with: item, isMyProfile: self.model.isMyProfile)
            cell.onDeleteTapped = { [weak self] recordId in
                self?.onModelDeleteTapped?(recordId)
            }
            return cell
        } else if collectionView == eventGalleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EventListCell.reuseIdentifier, for: indexPath) as? EventListCell else {
                return UICollectionViewCell()
            }
            let item = eventGalleryItems[indexPath.item]
            cell.configure(with: item, context: self.context, isMyProfile: self.model.isMyProfile)
            cell.onApply = { [weak self] eventId in
                self?.onEventButtonTapped?(eventId)
            }
            return cell
        }
        return UICollectionViewCell()
    }
}


// MARK: - UICollectionViewDelegate

extension PublicProfileScreenNode: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == similarProfilesCollectionView {
            guard !similarProfilesIsLoading || !similarProfiles.isEmpty else { return }
            let user = similarProfiles[indexPath.item]
            onSimilarProfileTapped?(user)
        } else if collectionView == galleryCollectionView {
            guard galleryPhotos[indexPath.item].id != -1 else { return }
            onGalleryItemTapped?(.photo, indexPath.item)
        } else if collectionView == videoGalleryCollectionView {
            guard videoGalleryItems[indexPath.item].id != -1 else { return }
            onGalleryItemTapped?(.video, indexPath.item)
        } else if collectionView == modelGalleryCollectionView {
            guard !modelGalleryItems.isEmpty else { return }
            let user = modelGalleryItems[indexPath.item]
            onModelAgencyTapped?(user)
        } else if collectionView == eventGalleryCollectionView {
            guard !eventGalleryItems.isEmpty else { return }
            let event = eventGalleryItems[indexPath.item]
            onEventTapped?(event)
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
            return CGSize(width: 133, height: 145)
        } else if collectionView == galleryCollectionView || collectionView == videoGalleryCollectionView {
            guard let (layout, _) = self.containerLayout else { return .zero }
            let totalSpacing: CGFloat = 2
            let width = (layout.size.width - totalSpacing) / 3.0
            return CGSize(width: width, height: width)
        } else if collectionView == channelGalleryCollectionView
                    || collectionView == modelGalleryCollectionView
                    || collectionView == eventGalleryCollectionView {
            guard let (layout, _) = self.containerLayout else { return .zero }
            return CGSize(width: layout.size.width, height: 66)
        }
        return CGSize()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == similarProfilesCollectionView {
            return 6
        } else if collectionView == galleryCollectionView
                    || collectionView == videoGalleryCollectionView {
            return 1.0
        } else if collectionView == channelGalleryCollectionView
                    || collectionView == eventGalleryCollectionView
                    || collectionView == modelGalleryCollectionView {
            return 0.0
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == similarProfilesCollectionView {
            return 6
        } else if collectionView == galleryCollectionView
                    || collectionView == videoGalleryCollectionView {
            return 1.0
        } else if collectionView == channelGalleryCollectionView
                    || collectionView == eventGalleryCollectionView
                    || collectionView == modelGalleryCollectionView {
            return 0.0
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if collectionView == similarProfilesCollectionView {
            return UIEdgeInsets(top: DivoDesignTokens.Spacing.m, left: DivoDesignTokens.Spacing.m, bottom: DivoDesignTokens.Spacing.m, right: DivoDesignTokens.Spacing.m)
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
        if scrollView === tabsPager {
            // Горизонтальный пейджер — двигаем индикатор сегмент-бара вместе
            // с пальцем (в т.ч. при программном setContentOffset для соседнего
            // таба). Никаких других побочных эффектов.
            let pageWidth = scrollView.bounds.width
            guard pageWidth > 0 else { return }
            let progress = scrollView.contentOffset.x / pageWidth
            segmentedBar.setIndicatorProgress(progress)
            return
        }

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

        let maxScrollY = scrollView.contentSize.height - scrollView.bounds.height
        let bottomLimit = max(0, maxScrollY)

        if scrollView.contentOffset.y > bottomLimit {
            scrollView.contentOffset.y = bottomLimit
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView === tabsPager else { return }
        // Свайп начался — pre-grow collectionsContainer до max соседних высот,
        // чтобы оба соседних таба полностью попадали в viewport пейджера во
        // время drag'а (особенно важно, когда сосед выше текущего: иначе
        // его центрированный плейсхолдер срежется снизу).
        isTabSwitching = true

        guard let currentIdx = pageIndex(for: currentTab) else { return }
        var maxHeight = tabHeight(for: currentTab)
        if currentIdx > 0 {
            maxHeight = max(maxHeight, tabHeight(for: orderedTabs[currentIdx - 1]))
        }
        if currentIdx + 1 < orderedTabs.count {
            maxHeight = max(maxHeight, tabHeight(for: orderedTabs[currentIdx + 1]))
        }
        if abs(collectionsContainerHeightConstraint.constant - maxHeight) > 0.5 {
            collectionsContainerHeightConstraint.constant = maxHeight
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.contentViewStack.layoutIfNeeded()
                self.view.layoutIfNeeded()
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === tabsPager else { return }
        finalizeAfterPagerSettle()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === tabsPager else { return }
        finalizeAfterPagerSettle()
    }

    private func finalizeAfterPagerSettle() {
        let pageWidth = tabsPager.bounds.width
        guard pageWidth > 0 else { return }
        let idx = Int((tabsPager.contentOffset.x / pageWidth).rounded())
        guard idx >= 0, idx < orderedTabs.count else { return }
        finalizeTabSwitch(to: orderedTabs[idx], animated: true)
    }

    // Менеджер загрузки для текущей вкладки
    private func triggerLoadMoreForActiveTab() {
        switch currentTab {
        case .photo:
            if galleryHasMore && !galleryIsLoading { loadNextGalleryPage() }
        case .video:
            if videoGalleryHasMore && !videoGalleryIsLoading { loadNextVideoGalleryPage() }
        // TODO: добавить пагинацию по аналогии
        case .models: break
        case .channels: break
        case .events: break
        }
    }
}


// MARK: - ProfileInfoViewDelegate

extension PublicProfileScreenNode: ProfileInfoViewDelegate {
    func profileInfoViewDidUpdateContentHeight(animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.contentViewStack.layoutIfNeeded()
                self.view.layoutIfNeeded()
            }
        } else {
            UIView.performWithoutAnimation {
                self.contentViewStack.layoutIfNeeded()
                self.view.layoutIfNeeded()
            }
        }
    }
}


// MARK: - ProfileSegmentedBarDelegate

extension PublicProfileScreenNode: ProfileSegmentedBarDelegate {
    
    private func profileTab(forSegmentIndex index: Int) -> ProfileTab? {
        guard index >= 0 && index < orderedTabs.count else { return nil }
        return orderedTabs[index]
    }

    func segmentedBar(_ segmentedBar: ProfileSegmentedBar, didSelectIndex index: Int) {
        guard let newTab = profileTab(forSegmentIndex: index), newTab != currentTab else { return }
        guard let newPageIndex = pageIndex(for: newTab),
              let oldPageIndex = pageIndex(for: currentTab) else { return }

        let pageWidth = tabsPager.bounds.width
        guard pageWidth > 0 else {
            // Layout ещё не выполнен (раннее срабатывание). Финализируем
            // мгновенно, пейджер сам подъедет на первом layout-проходе.
            finalizeTabSwitch(to: newTab, animated: false)
            snapPagerToCurrentTab(animated: false)
            return
        }

        let delta = abs(newPageIndex - oldPageIndex)
        if delta == 1 {
            // Сосед — нативный анимированный setContentOffset. Финализация
            // придёт через scrollViewDidEndScrollingAnimation: там currentTab
            // обновляется на landed. Пред-расширим высоту до max(текущая,
            // целевая), чтобы целевой таб полностью отрисовался во время слайда.
            isTabSwitching = true
            preGrowCollectionsHeight(forSwipeBetween: currentTab, and: newTab)

            let target = CGPoint(x: CGFloat(newPageIndex) * pageWidth, y: 0)
            tabsPager.setContentOffset(target, animated: true)
        } else {
            // Дальний переход — без промежуточных слайдов: snapshot текущего
            // видимого участка пейджера, мгновенный offset, плавный fade.
            performFarTabSwitch(to: newTab, newPageIndex: newPageIndex, pageWidth: pageWidth)
        }
    }

    // Перед свайпом/слайдом расширяем collectionsContainer до максимума из
    // соседних высот, чтобы таб с центрированным эмпти полностью попадал в
    // viewport пейджера во время горизонтального движения. После settle —
    // finalizeTabSwitch анимирует обратно к высоте приземлившегося таба.
    private func preGrowCollectionsHeight(forSwipeBetween a: ProfileTab, and b: ProfileTab) {
        let targetHeight = max(tabHeight(for: a), tabHeight(for: b))
        guard abs(collectionsContainerHeightConstraint.constant - targetHeight) > 0.5 else { return }
        collectionsContainerHeightConstraint.constant = targetHeight
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            self.contentViewStack.layoutIfNeeded()
            self.view.layoutIfNeeded()
        }
    }

    private func performFarTabSwitch(to newTab: ProfileTab, newPageIndex: Int, pageWidth: CGFloat) {
        isTabSwitching = true

        // Снэпшот текущего видимого участка — кладём поверх collectionsContainer,
        // чтобы старый таб не пропадал одним кадром после прыжка offset.
        let snapshot = collectionsContainer.snapshotView(afterScreenUpdates: false)
        if let snapshot = snapshot {
            snapshot.frame = collectionsContainer.bounds
            collectionsContainer.addSubview(snapshot)
        }

        // Прыжок на целевую страницу мгновенно — без animated: true, чтобы
        // не было слайда через промежуточные табы.
        UIView.performWithoutAnimation {
            tabsPager.setContentOffset(CGPoint(x: CGFloat(newPageIndex) * pageWidth, y: 0), animated: false)
        }

        finalizeTabSwitch(to: newTab, animated: false)

        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            snapshot?.alpha = 0
        } completion: { _ in
            snapshot?.removeFromSuperview()
        }
    }

    // Общая точка финализации после settle пейджера: и для тапа-соседа
    // (через scrollViewDidEndScrollingAnimation), и для свайпа (через
    // scrollViewDidEndDecelerating), и для дальнего тапа (instant).
    private func finalizeTabSwitch(to newTab: ProfileTab, animated: Bool) {
        let didChangeTab = (newTab != currentTab)
        currentTab = newTab

        // isTabSwitching снимаем ДО updateCollectionsContainerHeight, чтобы тот
        // мог анимировать высоту до целевой (во время свайпа высота была pre-grow).
        isTabSwitching = false

        if didChangeTab {
            updateScreenBackgroundForCurrentTab()
            loadDataForTab(newTab)
        }

        updateCollectionsContainerHeight(animated: animated)

        // Цель: сегмент-пилюля встаёт на sticky-позицию (= navHeight в viewport),
        // первый элемент таба сразу под ней (10pt gap). С contentInset.top =
        // navHeight: viewport_y = contentY - contentOffset.y → нужен offset =
        // segmentedBarContainer.frame.minY - navHeight.
        let navHeight = self.containerLayout?.1 ?? 0
        let stickyOffset = segmentedBarContainer.frame.minY - navHeight
        let maxOffset = scrollView.contentSize.height - scrollView.bounds.height
        let minOffset = -scrollView.contentInset.top
        let targetOffsetY = min(max(stickyOffset, minOffset), maxOffset)
        if abs(scrollView.contentOffset.y - targetOffsetY) > 0.5 {
            if animated {
                // curveLinear без easeOut: scroll едет с постоянной скоростью
                // и просто останавливается. easeOut + native UIScrollView
                // deceleration давали ощущение пружинки в конце snap'а.
                UIView.animate(withDuration: 0.25, delay: 0, options: [.curveLinear]) {
                    self.scrollView.contentOffset.y = targetOffsetY
                }
            } else {
                scrollView.contentOffset.y = targetOffsetY
            }
        }

        if didChangeTab, let idx = pageIndex(for: newTab) {
            // Не анимируем — индикатор уже на нужной X-позиции от
            // setIndicatorProgress в scrollViewDidScroll.
            segmentedBar.selectIndex(idx, animated: false)
        }

        updateFloatingButton(for: newTab)

        // Фоны контейнеров не зависят от таба (всегда белый), но вызов
        // оставлен на случай будущих изменений семантики.
        updateContainerBackgrounds()
    }

    private func loadDataForTab(_ tab: ProfileTab) {
        switch tab {
        case .photo: break
        case .video:
            if !videoGalleryInitialized { videoGalleryInitialized = true; loadVideoGallery() }
        case .models:
            if !modelGalleryInitialized { modelGalleryInitialized = true; loadModelGallery() }
        case .channels:
            if !channelGalleryInitialized { channelGalleryInitialized = true; loadChannelGallery() }
        case .events:
            if !eventGalleryInitialized { eventGalleryInitialized = true; loadEventGallery() }
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