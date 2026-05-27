import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle

final class EventDetailControllerNode: ASDisplayNode {
    private let context: AccountContext
    private var eventData: EventFullDetailData? = nil

    // Callbacks
    var onBackTapped: (() -> Void)?
    var onShareTapped: (() -> Void)?
    var onBookmarkTapped: (() -> Void)?
    var onApplyTapped: (() -> Void)?
    var onViewApplicationsTapped: (() -> Void)?
    var onGalleryItemTapped: ((String) -> Void)?
    var onWithdrawTapped: (() -> Void)?

    var coverImage: UIImage? {
        return backgroundImageView.image
    }

    // MARK: - Load phase

    enum LoadPhase: Equatable {
        case loading
        case content
        case failed(networkError: Bool)
    }

    // Единое состояние экрана. applyPhase() в didSet атомарно расставляет
    // видимости шиммеров/контента/error-view — точечные isHidden из сетевых
    // колбэков сюда не приходят, только смена фазы через сеттер.
    private var phase: LoadPhase = .loading {
        didSet {
            if oldValue != phase { applyPhase() }
        }
    }

    private let errorView: ProfileTabErrorView = {
        let view = ProfileTabErrorView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    var onRetryTapped: (() -> Void)?

    // MARK: - Core Layout
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var isPerformingLayout = false

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

    // MARK: - Background & Blur
    private let backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.backgroundColor = .gray
        return iv
    }()

    private let blurredHeaderImageView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    // MARK: - Navigation Bar
    private var navigationBarTitleView: ProfileNavigationBarTitleView?
    private var navigationBarTitleHeightConstraint: NSLayoutConstraint!
    private var titleVisibilityActivated = false
    
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
        button.backgroundColor = DivoColorPalette.statPillBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        button.layer.masksToBounds = true
        button.layer.borderWidth = 0.5
        button.layer.borderColor = DivoColorPalette.statPillBorder.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let rightButtonContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.statPillBackground
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

    private let shareButton: UIButton = {
        let button = UIButton(type: .custom)
        let image = DivoImage.share
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
    
    // MARK: - Event Info Section (Header)
    private let eventTypeContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let eventTypeLabelContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.roleBadgeBlue
        view.layer.cornerRadius = 13
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let eventTypeLabelShimmerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 13
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let eventTypeLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let eventCostTypeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.statPillBackground
        view.layer.cornerRadius = 13
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let eventCostTypeShimmerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 13
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let eventCostTypeIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.paid.withRenderingMode(.alwaysTemplate)
        iv.tintColor = DivoColorPalette.cardBackground
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let eventCostTypeLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.premiumLabel
        label.numberOfLines = 1
        return label
    }()
    
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
    private lazy var profileHeaderView = EventHeaderView()
    private lazy var profileHeaderShimmerView = EventHeaderShimmerView()
    
    private let eventInfoWrapper: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fill
        stack.spacing = DivoDesignTokens.Spacing.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let applyButtonShimmer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 18
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let applyButton: DivoButton = {
        let button = DivoButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let eventDeadlineContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.statPillBackground
        view.layer.cornerRadius = 18
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let eventDeadlineShimmerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 18
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let eventDeadlineLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        return label
    }()

    // MARK: - Counters Section
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
    
    private let counterActionsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let likesView = StatPillView(icon: DivoImage.statLike, filledIcon: DivoImage.statLikeFilled)
    private let viewsView = StatPillView(icon: DivoImage.statView)
    private let savesView = StatPillView(icon: DivoImage.statSave, filledIcon: DivoImage.statSaveFilled)

    // MARK: - White Sheet Background
    private let whiteSheetBackground: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let currentAppliedShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let currentAppliedContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        view.backgroundColor = DivoColorPalette.cardBackground
        return view
    }()
    
    private let currentAppliedIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = DivoImage.group
        iv.contentMode = .center
        iv.tintColor = DivoColorPalette.primaryText
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let currentAppliedLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        return label
    }()
    
    private let allAppliedShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let allAppliedContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        view.backgroundColor = DivoColorPalette.cardBackground
        return view
    }()
    
    private let allAppliedIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = DivoImage.seat
        iv.contentMode = .center
        iv.tintColor = DivoColorPalette.primaryText
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let allAppliedLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        return label
    }()

    // MARK: - Content Sections
    private let organizerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let organizerView: OrganizerView = {
        let organizerView = OrganizerView()
        organizerView.translatesAutoresizingMaskIntoConstraints = false
        return organizerView
    }()
    
    private let organizerShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let containerDescriptionShimmer: UIView = {
        let containerShimmer = UIView()
        containerShimmer.translatesAutoresizingMaskIntoConstraints = false
        return containerShimmer
    }()
    
    private let descriptionShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var descriptionView: DescriptionView = {
        let view = DescriptionView()
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    private let containerRequirementsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let containerRequirementsView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleRequirementsLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.requirementsCreateEvent
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let requirementsLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    
    private let requirementsShimmerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let requirementsShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let containerParametersShimmer: UIView = {
        let containerShimmer = UIView()
        containerShimmer.translatesAutoresizingMaskIntoConstraints = false
        return containerShimmer
    }()
    
    private let parametersShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var parametersView: ParametersView = {
        let view = ParametersView()
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    // MARK: - Collections
    private let collectionsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()
    
    private var collectionsContainerHeightConstraint: NSLayoutConstraint!
    
    private var galleryPhotos: [UserPhoto] = []
    private var galleryHeightConstraint: NSLayoutConstraint!
    
    private let galleryStatusView: GalleryStatusView = {
        let view = GalleryStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var galleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.isScrollEnabled = false
        cv.delaysContentTouches = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(GalleryCell.self, forCellWithReuseIdentifier: "GalleryCell")
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()

    var onEditEventTapped: (() -> Void)?
    var onCloseApplicationsTapped: (() -> Void)?
    var onCancelEventTapped: (() -> Void)?
    var onDeleteTapped: (() -> Void)?
    
    private let isMyEvent: Bool
    private let isPreviewMode: Bool
    
    var onEditPreviewTapped: (() -> Void)?
    var onPublishPreviewTapped: (() -> Void)?
    private let previewBottomContainer = UIView()
    private let editPreviewButton = DivoButton()
    private let publishPreviewButton = DivoButton()
    private let bottomFadeOverlay: UIView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        if let gradient = view.layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.withAlphaComponent(0).cgColor,
                DivoColorPalette.screenBackground.cgColor
            ]
            gradient.locations = [0, 0.45]
        }
        return view
    }()
    
    // MARK: - Bottom Spacer
    private let bottomSpacer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var bottomSpacerHeightConstraint: NSLayoutConstraint = bottomSpacer.heightAnchor.constraint(equalToConstant: 0)
    
    private let appliedStatusViewContainer: UIView = {
        let appliedStatusViewContainer = UIView()
        appliedStatusViewContainer.translatesAutoresizingMaskIntoConstraints = false
        return appliedStatusViewContainer
    }()
    
    private let appliedStatusView: EventAppliedStatusView = {
        let view = EventAppliedStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let appliedStatusShimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    
    // MARK: - Init
    
    init(context: AccountContext, isMyEvent: Bool = false, isPreviewMode: Bool = false) {
        self.context = context
        self.isMyEvent = isMyEvent
        self.isPreviewMode = isPreviewMode

        super.init()
        self.backgroundColor = DivoColorPalette.darkBackground
        
        // В preview share/more скрываются (нечего шарить, нет действий над черновиком),
        // back — всегда работает (закрывает preview → возвращает в CreateEvent).
        // Stats-pills (likes/views/saves) остаются видимыми, но без интерактивности —
        // чтобы пользователь видел будущий layout боевого экрана.
        self.likesView.isEnabled = !isPreviewMode
        self.viewsView.isEnabled = !isPreviewMode
        self.savesView.isEnabled = !isPreviewMode
        
        setupUI()
        setupErrorView()
        applyPhase()
    }

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
        let collapseOffset = collectionsContainer.frame.minY
        if collapseOffset > 0, scrollViewHeight > 0 {
            let minContentHeight = collapseOffset + scrollViewHeight
            let currentSpacerHeight = bottomSpacer.isHidden ? 0 : bottomSpacerHeightConstraint.constant
            let contentWithoutSpacer = contentHeight - currentSpacerHeight
            let bottomSafeInset = layout.intrinsicInsets.bottom
            let neededSpacerHeight = max(bottomSafeInset + 12, minContentHeight - contentWithoutSpacer)
            if !bottomSpacer.isHidden, abs(neededSpacerHeight - currentSpacerHeight) > 1.0 {
                bottomSpacerHeightConstraint.constant = neededSpacerHeight
                contentHeight = contentWithoutSpacer + neededSpacerHeight
            }
        }
        
        contentViewStack.frame = CGRect(x: 0, y: 0, width: stackWidth, height: contentHeight)
        scrollView.contentSize = CGSize(width: stackWidth, height: contentHeight)
        
        applyGradientBlurMask()
        updateNavBarBlurMask()
        
        // Шиммеры на CAGradientLayer теряют корректный фрейм при ресайзе вью,
        // поэтому на каждом ре-лейауте пересоздаём анимацию — только в .loading,
        // в остальных фазах шиммеры скрыты и пересоздание не нужно.
        if phase == .loading {
            actionsShimmerView.startAnimation()
            eventCostTypeShimmerContainer.stopShimmering()
            eventCostTypeShimmerContainer.startShimmering()
            eventTypeLabelShimmerContainer.stopShimmering()
            eventTypeLabelShimmerContainer.startShimmering()
        }

        if !eventDeadlineShimmerContainer.isHidden && !applyButtonShimmer.isHidden {
            eventDeadlineShimmerContainer.stopShimmering()
            eventDeadlineShimmerContainer.startShimmering()
            applyButtonShimmer.stopShimmering()
            eventDeadlineShimmerContainer.startShimmering()
            applyButtonShimmer.startShimmering()
        }

        if !appliedStatusShimmerView.isHidden{
            appliedStatusShimmerView.stopShimmering()
            appliedStatusShimmerView.startShimmering()
        }

        if !organizerShimmerView.isHidden{
            organizerShimmerView.stopShimmering()
            organizerShimmerView.startShimmering()
        }

        if !currentAppliedShimmerView.isHidden && !allAppliedShimmerView.isHidden {
            currentAppliedShimmerView.stopShimmering()
            currentAppliedShimmerView.startShimmering()
            allAppliedShimmerView.stopShimmering()
            currentAppliedShimmerView.startShimmering()
            allAppliedShimmerView.startShimmering()
        }

        if !descriptionShimmerView.isHidden {
            descriptionShimmerView.stopShimmering()
            descriptionShimmerView.startShimmering()
        }

        if !requirementsShimmerContainer.isHidden {
            requirementsShimmerView.stopShimmering()
            requirementsShimmerView.startShimmering()
        }

        if !parametersShimmerView.isHidden {
            parametersShimmerView.stopShimmering()
            parametersShimmerView.startShimmering()
        }
    }

    
    // MARK: - Private
    
    private func setupUI() {
        setupBackgroundAndScroll()
        setupTopBlur()
        setupCustomNavBar()
        setupContentViewStack()
        
        scrollView.insertSubview(blurredHeaderImageView, at: 0)
        
        setupCounterActionsContainer()
        setupEventType()
        setupProfileHeaderContainer()
        setupEventInfoWrapper()
        
        scrollView.insertSubview(whiteSheetBackground, belowSubview: contentViewStack)
        
        setupAllAppliedContainer()
        setupOrganizerContainer()
        setupAboutContainer()
        setupRequirementsContainer()
        setupParametersContainer()
        setupCollections()
        
        contentViewStack.addArrangedSubview(bottomSpacer)
        bottomSpacerHeightConstraint.isActive = true
        contentViewStack.setCustomSpacing(0, after: collectionsContainer)
        
        // Align Moving Blur
        NSLayoutConstraint.activate([
            blurredHeaderImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            blurredHeaderImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            blurredHeaderImageView.topAnchor.constraint(equalTo: eventTypeContainer.topAnchor, constant: -20),
            blurredHeaderImageView.bottomAnchor.constraint(equalTo: whiteSheetBackground.topAnchor, constant: 0)
        ])
        
        if isPreviewMode {
            setupPreviewBottomBar()
        }
    }
    
    private func setupPreviewBottomBar() {
        self.view.addSubview(bottomFadeOverlay)
        self.view.addSubview(previewBottomContainer)
        previewBottomContainer.translatesAutoresizingMaskIntoConstraints = false
        
        editPreviewButton.makeDivoButton(title: DivoStrings.settingsEdit, buttonFont: Font.helveticaNeue(20), radius: 28, divoButtonStyle: .secondary)
        editPreviewButton.backgroundColor = DivoColorPalette.secondaryButtonBackground
        editPreviewButton.setImage(DivoImage.pencil.withRenderingMode(.alwaysTemplate), for: .normal)
        editPreviewButton.setImage(DivoImage.pencil.withRenderingMode(.alwaysTemplate), for: .highlighted)
        editPreviewButton.tintColor = DivoColorPalette.primaryTextOnDark
        editPreviewButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -DivoDesignTokens.Spacing.xs, bottom: 0, right: DivoDesignTokens.Spacing.xs)
        
        publishPreviewButton.makeDivoButton(title: DivoStrings.publishEvent, loading: DivoStrings.saving, buttonFont: Font.helveticaNeue(20), radius: 28)
        
        editPreviewButton.translatesAutoresizingMaskIntoConstraints = false
        publishPreviewButton.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        
        stack.addArrangedSubview(editPreviewButton)
        stack.addArrangedSubview(publishPreviewButton)
        previewBottomContainer.addSubview(stack)
        
        NSLayoutConstraint.activate([
            previewBottomContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            previewBottomContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            previewBottomContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            previewBottomContainer.heightAnchor.constraint(equalToConstant: 100),
            
            stack.leadingAnchor.constraint(equalTo: previewBottomContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            stack.trailingAnchor.constraint(equalTo: previewBottomContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            stack.topAnchor.constraint(equalTo: previewBottomContainer.topAnchor, constant: DivoDesignTokens.Spacing.m),
            stack.heightAnchor.constraint(equalToConstant: 56),
            
            bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: 140)
        ])
        
        editPreviewButton.addTarget(self, action: #selector(editPreviewTapped), for: .touchUpInside)
        publishPreviewButton.addTarget(self, action: #selector(publishPreviewTapped), for: .touchUpInside)
    }

    private func setupBackgroundAndScroll() {
        self.view.addSubview(backgroundImageView)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
        
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

    // MARK: - Nav Bar
    private func setupTopBlur() {
        view.addSubview(navBarBlurView)
        NSLayoutConstraint.activate([
            navBarBlurView.topAnchor.constraint(equalTo: view.topAnchor),
            navBarBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBarBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBarBlurView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 280)
        ])
    }

    private func setupCustomNavBar() {
        view.addSubview(customNavBar)
        
        customNavBar.addSubview(closeButton)
        customNavBar.addSubview(rightButtonContainer)
        
        addPillBlur(to: closeButton)
        addPillBlur(to: rightButtonContainer)
        
        rightButtonContainer.addSubview(rightButtonsStack)
        rightButtonsStack.addArrangedSubview(shareButton)
        rightButtonsStack.addArrangedSubview(moreButton)
        
        closeButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        closeButton.addDivoPressState(.pill)
        
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        shareButton.addDivoPressState(.pill)
        
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
            
            shareButton.widthAnchor.constraint(equalToConstant: 40),
            shareButton.heightAnchor.constraint(equalToConstant: 40),
            
            moreButton.widthAnchor.constraint(equalToConstant: 40),
            moreButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        if !isMyEvent {
            shareButton.isHidden = false
            moreButton.isHidden = true
        } else {
            shareButton.isHidden = false
            moreButton.isHidden = false
            setupMoreMenu()
        }
    }

    // MARK: - Content Sections Setup
    
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
        contentViewStack.setCustomSpacing(6, after: counterActionsContainer)
        
        if isMyEvent {
            likesView.onAnyTap = { [weak self] in
                self?.likesViewDidTap()
            }
            savesView.onAnyTap = { [weak self] in
                self?.savesViewDidTap()
            }
            
        } else {
            likesView.onIconTap = {[weak self] in
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
    
    private func setupEventType() {
        contentViewStack.addArrangedSubview(eventTypeContainer)
        eventTypeContainer.addSubview(eventTypeLabelContainer)
        eventTypeLabelContainer.addSubview(eventTypeLabel)
        eventTypeContainer.addSubview(eventTypeLabelShimmerContainer)
        
        eventTypeContainer.addSubview(eventCostTypeContainer)
        eventCostTypeContainer.addSubview(eventCostTypeIcon)
        eventCostTypeContainer.addSubview(eventCostTypeLabel)
        eventTypeContainer.addSubview(eventCostTypeShimmerContainer)
        
        NSLayoutConstraint.activate([
            eventTypeContainer.heightAnchor.constraint(equalToConstant: 26),
            
            eventTypeLabelContainer.topAnchor.constraint(equalTo: eventTypeContainer.topAnchor),
            eventTypeLabelContainer.leadingAnchor.constraint(equalTo: eventTypeContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            eventTypeLabelContainer.bottomAnchor.constraint(equalTo: eventTypeContainer.bottomAnchor),
            
            eventTypeLabelShimmerContainer.topAnchor.constraint(equalTo: eventTypeContainer.topAnchor),
            eventTypeLabelShimmerContainer.leadingAnchor.constraint(equalTo: eventTypeContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            eventTypeLabelShimmerContainer.bottomAnchor.constraint(equalTo: eventTypeContainer.bottomAnchor),
            eventTypeLabelShimmerContainer.widthAnchor.constraint(equalToConstant: 66),
            
            eventTypeLabel.leadingAnchor.constraint(equalTo: eventTypeLabelContainer.leadingAnchor, constant: 12),
            eventTypeLabel.centerYAnchor.constraint(equalTo: eventTypeLabelContainer.centerYAnchor),
            eventTypeLabel.trailingAnchor.constraint(equalTo: eventTypeLabelContainer.trailingAnchor, constant: -12),
            
            eventCostTypeContainer.leadingAnchor.constraint(equalTo: eventTypeLabelContainer.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            eventCostTypeContainer.trailingAnchor.constraint(lessThanOrEqualTo: eventTypeContainer.trailingAnchor),
            eventCostTypeContainer.bottomAnchor.constraint(equalTo: eventTypeContainer.bottomAnchor),
            eventCostTypeContainer.topAnchor.constraint(equalTo: eventTypeContainer.topAnchor),
            
            eventCostTypeShimmerContainer.leadingAnchor.constraint(equalTo: eventTypeLabelShimmerContainer.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            eventCostTypeShimmerContainer.trailingAnchor.constraint(lessThanOrEqualTo: eventTypeContainer.trailingAnchor),
            eventCostTypeShimmerContainer.bottomAnchor.constraint(equalTo: eventTypeContainer.bottomAnchor),
            eventCostTypeShimmerContainer.topAnchor.constraint(equalTo: eventTypeContainer.topAnchor),
            eventCostTypeShimmerContainer.widthAnchor.constraint(equalToConstant: 66),

            eventCostTypeIcon.centerYAnchor.constraint(equalTo: eventCostTypeContainer.centerYAnchor),
            eventCostTypeIcon.leadingAnchor.constraint(equalTo: eventCostTypeContainer.leadingAnchor, constant: 12),

            eventCostTypeLabel.centerYAnchor.constraint(equalTo: eventCostTypeContainer.centerYAnchor),
            eventCostTypeLabel.leadingAnchor.constraint(equalTo: eventCostTypeIcon.trailingAnchor, constant: 2),
            eventCostTypeLabel.trailingAnchor.constraint(equalTo: eventCostTypeContainer.trailingAnchor, constant: -12),
        ])
    }
    
    private func setupProfileHeaderContainer() {
        contentViewStack.addArrangedSubview(profileHeaderWrapper)
        
        profileHeaderWrapper.addSubview(infoStack)
        infoStack.addArrangedSubview(profileHeaderView)
        
        profileHeaderShimmerView.translatesAutoresizingMaskIntoConstraints = false
        infoStack.addArrangedSubview(profileHeaderShimmerView)
        
        NSLayoutConstraint.activate([
            infoStack.topAnchor.constraint(equalTo: profileHeaderWrapper.topAnchor),
            infoStack.bottomAnchor.constraint(equalTo: profileHeaderWrapper.bottomAnchor),
            infoStack.leadingAnchor.constraint(equalTo: profileHeaderWrapper.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            infoStack.trailingAnchor.constraint(equalTo: profileHeaderWrapper.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            profileHeaderShimmerView.leadingAnchor.constraint(equalTo: infoStack.leadingAnchor),
            profileHeaderShimmerView.trailingAnchor.constraint(equalTo: infoStack.trailingAnchor),
        ])
        
        contentViewStack.setCustomSpacing(DivoDesignTokens.Spacing.m, after: profileHeaderWrapper)
        contentViewStack.setCustomSpacing(DivoDesignTokens.Spacing.m, after: profileHeaderShimmerView)
    }
    
    private func setupEventInfoWrapper() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        contentViewStack.addArrangedSubview(container)
        container.addSubview(eventInfoWrapper)
        container.addSubview(eventDeadlineShimmerContainer)
        container.addSubview(applyButtonShimmer)
        eventInfoWrapper.addArrangedSubview(eventDeadlineContainer)
        eventDeadlineContainer.addSubview(eventDeadlineLabel)
        eventInfoWrapper.addArrangedSubview(UIView())
        eventInfoWrapper.addArrangedSubview(applyButton)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 36),
            
            eventInfoWrapper.topAnchor.constraint(equalTo: container.topAnchor),
            eventInfoWrapper.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            eventInfoWrapper.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            eventInfoWrapper.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            eventDeadlineShimmerContainer.topAnchor.constraint(equalTo: container.topAnchor),
            eventDeadlineShimmerContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            eventDeadlineShimmerContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            eventDeadlineShimmerContainer.heightAnchor.constraint(equalToConstant: 36),
            eventDeadlineShimmerContainer.widthAnchor.constraint(equalToConstant: 140),
            
            eventDeadlineLabel.centerYAnchor.constraint(equalTo: eventDeadlineContainer.centerYAnchor),
            eventDeadlineLabel.trailingAnchor.constraint(equalTo: eventDeadlineContainer.trailingAnchor, constant: -12),
            eventDeadlineLabel.leadingAnchor.constraint(equalTo: eventDeadlineContainer.leadingAnchor, constant: 12),
            
            applyButtonShimmer.topAnchor.constraint(equalTo: container.topAnchor),
            applyButtonShimmer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            applyButtonShimmer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            applyButtonShimmer.heightAnchor.constraint(equalToConstant: 36),
            applyButtonShimmer.widthAnchor.constraint(equalToConstant: 100),
            
            applyButton.heightAnchor.constraint(equalToConstant: 36),
        ])
        
        applyButton.makeDivoButton(title: DivoStrings.applyNow, buttonFont: Font.helveticaNeue(14), radius: 18)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        // Дедлайн — информативная пилюль с датой, важно показать целиком.
        // applyButton может сжаться (truncate текста) — особенно в preview,
        // где текст «Apply now (preview only)» длиннее.
        eventDeadlineContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        eventDeadlineContainer.setContentHuggingPriority(.required, for: .horizontal)
        eventDeadlineLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        applyButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        contentViewStack.setCustomSpacing(24, after: container)
    }
    
    private func setupAllAppliedContainer() {
        
        let spacerView = UIView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        contentViewStack.addArrangedSubview(spacerView)
        NSLayoutConstraint.activate([
            spacerView.heightAnchor.constraint(equalToConstant: 20)
        ])
        contentViewStack.setCustomSpacing(0, after: spacerView)
        
        contentViewStack.addArrangedSubview(appliedStatusViewContainer)
        appliedStatusViewContainer.addSubview(appliedStatusView)
        appliedStatusViewContainer.addSubview(appliedStatusShimmerView)
        
        NSLayoutConstraint.activate([
            appliedStatusViewContainer.heightAnchor.constraint(equalToConstant: 48),
            
            appliedStatusView.topAnchor.constraint(equalTo: appliedStatusViewContainer.topAnchor),
            appliedStatusView.leadingAnchor.constraint(equalTo: appliedStatusViewContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            appliedStatusView.trailingAnchor.constraint(equalTo: appliedStatusViewContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            appliedStatusView.bottomAnchor.constraint(equalTo: appliedStatusViewContainer.bottomAnchor),
            
            appliedStatusShimmerView.leadingAnchor.constraint(equalTo: appliedStatusViewContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            appliedStatusShimmerView.topAnchor.constraint(equalTo: appliedStatusViewContainer.topAnchor),
            appliedStatusShimmerView.trailingAnchor.constraint(equalTo: appliedStatusViewContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            appliedStatusShimmerView.bottomAnchor.constraint(equalTo: appliedStatusViewContainer.bottomAnchor),
            appliedStatusShimmerView.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        appliedStatusView.onWithdrawTapped = { [weak self] in
            self?.onWithdrawTapped?()
        }
        
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        contentViewStack.addArrangedSubview(container)
        container.addSubview(stack)
        
        stack.addArrangedSubview(currentAppliedContainer)
        stack.addArrangedSubview(currentAppliedShimmerView)
        currentAppliedContainer.addSubview(currentAppliedIcon)
        currentAppliedContainer.addSubview(currentAppliedLabel)
        
        stack.addArrangedSubview(allAppliedContainer)
        stack.addArrangedSubview(allAppliedShimmerView)
        allAppliedContainer.addSubview(allAppliedIcon)
        allAppliedContainer.addSubview(allAppliedLabel)
        
        NSLayoutConstraint.activate([
            currentAppliedIcon.topAnchor.constraint(equalTo: currentAppliedContainer.topAnchor, constant: 14),
            currentAppliedIcon.centerXAnchor.constraint(equalTo: currentAppliedContainer.centerXAnchor),

            currentAppliedLabel.topAnchor.constraint(equalTo: currentAppliedIcon.bottomAnchor, constant: 6),
            currentAppliedLabel.centerXAnchor.constraint(equalTo: currentAppliedContainer.centerXAnchor),
            currentAppliedLabel.bottomAnchor.constraint(equalTo: currentAppliedContainer.bottomAnchor, constant: -14),
            
            allAppliedIcon.topAnchor.constraint(equalTo: allAppliedContainer.topAnchor, constant: 14),
            allAppliedIcon.centerXAnchor.constraint(equalTo: allAppliedContainer.centerXAnchor),

            allAppliedLabel.topAnchor.constraint(equalTo: allAppliedIcon.bottomAnchor, constant: 6),
            allAppliedLabel.centerXAnchor.constraint(equalTo: allAppliedContainer.centerXAnchor),
            allAppliedLabel.bottomAnchor.constraint(equalTo: allAppliedContainer.bottomAnchor, constant: -14),
            
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            currentAppliedShimmerView.heightAnchor.constraint(equalToConstant: 74),
            allAppliedShimmerView.heightAnchor.constraint(equalToConstant: 74),
        ])
        
        NSLayoutConstraint.activate([
            whiteSheetBackground.topAnchor.constraint(equalTo: spacerView.topAnchor),
            whiteSheetBackground.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            whiteSheetBackground.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            whiteSheetBackground.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 1000)
        ])
    }

    private func setupOrganizerContainer() {
        contentViewStack.addArrangedSubview(organizerContainer)

        organizerContainer.addSubview(organizerView)
        organizerContainer.addSubview(organizerShimmerView)
        
        NSLayoutConstraint.activate([
            organizerView.leadingAnchor.constraint(equalTo: organizerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            organizerView.topAnchor.constraint(equalTo: organizerContainer.topAnchor),
            organizerView.trailingAnchor.constraint(equalTo: organizerContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            organizerView.bottomAnchor.constraint(equalTo: organizerContainer.bottomAnchor),
            
            organizerShimmerView.leadingAnchor.constraint(equalTo: organizerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            organizerShimmerView.topAnchor.constraint(equalTo: organizerContainer.topAnchor),
            organizerShimmerView.trailingAnchor.constraint(equalTo: organizerContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            organizerShimmerView.bottomAnchor.constraint(equalTo: organizerContainer.bottomAnchor),
            organizerShimmerView.heightAnchor.constraint(equalToConstant: 96)
        ])
    }

    private func setupAboutContainer() {
        containerDescriptionShimmer.addSubview(descriptionShimmerView)
        contentViewStack.addArrangedSubview(containerDescriptionShimmer)
        contentViewStack.addArrangedSubview(descriptionView)
        
        NSLayoutConstraint.activate([
            descriptionShimmerView.heightAnchor.constraint(equalToConstant: 66),
            descriptionShimmerView.topAnchor.constraint(equalTo: containerDescriptionShimmer.topAnchor),
            descriptionShimmerView.bottomAnchor.constraint(equalTo: containerDescriptionShimmer.bottomAnchor),
            descriptionShimmerView.leadingAnchor.constraint(equalTo: containerDescriptionShimmer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            descriptionShimmerView.trailingAnchor.constraint(equalTo: containerDescriptionShimmer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])
    }
    
    private func setupRequirementsContainer() {
        contentViewStack.addArrangedSubview(requirementsShimmerContainer)
        
        let textStack = UIStackView(arrangedSubviews: [titleRequirementsLabel, requirementsLabel])
        textStack.axis = .vertical
        textStack.spacing = DivoDesignTokens.Spacing.s
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentViewStack.addArrangedSubview(containerRequirementsContainer)
        containerRequirementsContainer.addSubview(containerRequirementsView)
        containerRequirementsView.addSubview(textStack)
        requirementsShimmerContainer.addSubview(requirementsShimmerView)
        
        NSLayoutConstraint.activate([
            requirementsShimmerContainer.heightAnchor.constraint(equalToConstant: 66),
            
            requirementsShimmerView.topAnchor.constraint(equalTo: requirementsShimmerContainer.topAnchor),
            requirementsShimmerView.bottomAnchor.constraint(equalTo: requirementsShimmerContainer.bottomAnchor),
            requirementsShimmerView.leadingAnchor.constraint(equalTo: requirementsShimmerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            requirementsShimmerView.trailingAnchor.constraint(equalTo: requirementsShimmerContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            containerRequirementsView.topAnchor.constraint(equalTo: containerRequirementsContainer.topAnchor),
            containerRequirementsView.leadingAnchor.constraint(equalTo: containerRequirementsContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            containerRequirementsView.trailingAnchor.constraint(equalTo: containerRequirementsContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            containerRequirementsView.bottomAnchor.constraint(equalTo: containerRequirementsContainer.bottomAnchor),
            
            textStack.topAnchor.constraint(equalTo: containerRequirementsView.topAnchor, constant: 14),
            textStack.leadingAnchor.constraint(equalTo: containerRequirementsView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            textStack.trailingAnchor.constraint(equalTo: containerRequirementsView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            textStack.bottomAnchor.constraint(equalTo: containerRequirementsView.bottomAnchor, constant: -14),
        ])
    }

    private func setupParametersContainer() {
        containerParametersShimmer.addSubview(parametersShimmerView)
        contentViewStack.addArrangedSubview(containerParametersShimmer)
        contentViewStack.addArrangedSubview(parametersView)
        
        NSLayoutConstraint.activate([
            parametersShimmerView.heightAnchor.constraint(equalToConstant: 120),
            parametersShimmerView.topAnchor.constraint(equalTo: containerParametersShimmer.topAnchor),
            parametersShimmerView.bottomAnchor.constraint(equalTo: containerParametersShimmer.bottomAnchor),
            parametersShimmerView.leadingAnchor.constraint(equalTo: containerParametersShimmer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            parametersShimmerView.trailingAnchor.constraint(equalTo: containerParametersShimmer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])
        
        contentViewStack.setCustomSpacing(24, after: containerParametersShimmer)
        contentViewStack.setCustomSpacing(24, after: parametersView)
    }

    private func setupCollections() {
        contentViewStack.addArrangedSubview(collectionsContainer)
        
        collectionsContainerHeightConstraint = collectionsContainer.heightAnchor.constraint(equalToConstant: 160)
        collectionsContainerHeightConstraint.isActive = true
        
        galleryHeightConstraint = galleryCollectionView.heightAnchor.constraint(equalToConstant: 1)
        galleryHeightConstraint.isActive = true
        
        collectionsContainer.addSubview(galleryCollectionView)
        collectionsContainer.addSubview(galleryStatusView)
        
        NSLayoutConstraint.activate([
            galleryCollectionView.topAnchor.constraint(equalTo: collectionsContainer.topAnchor),
            galleryCollectionView.leadingAnchor.constraint(equalTo: collectionsContainer.leadingAnchor),
            galleryCollectionView.trailingAnchor.constraint(equalTo: collectionsContainer.trailingAnchor),
            galleryHeightConstraint,
            galleryCollectionView.bottomAnchor.constraint(equalTo: collectionsContainer.bottomAnchor),
            
            galleryStatusView.heightAnchor.constraint(equalToConstant: 160),
            galleryStatusView.topAnchor.constraint(equalTo: collectionsContainer.topAnchor),
            galleryStatusView.leadingAnchor.constraint(equalTo: collectionsContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            galleryStatusView.trailingAnchor.constraint(equalTo: collectionsContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])
        
        galleryCollectionView.isHidden = true
        galleryStatusView.isHidden = false
        galleryStatusView.configure(isLoading: true, text: DivoStrings.uploadingPhotos, isMyProfile: false)
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
    
    private func calculateCollectionsContainerHeight() -> CGFloat {
        guard let (layout, navBarHeight) = self.containerLayout else { return 160 }
        
        let fullScreenAvailableHeight = max(160, layout.size.height - navBarHeight)
        
        func heightFor(isEmpty: Bool, constraint: NSLayoutConstraint, isModelTab: Bool = false) -> CGFloat {
            if isEmpty {
                return fullScreenAvailableHeight
            }
            return constraint.constant
        }
        
        return heightFor(isEmpty: galleryPhotos.isEmpty, constraint: galleryHeightConstraint)
    }
    
    private func setupErrorView() {
        self.view.addSubview(errorView)
        NSLayoutConstraint.activate([
            errorView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            errorView.topAnchor.constraint(equalTo: self.view.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        // Navbar должен оставаться поверх errorView, чтобы кнопка «Назад» была
        // доступна в .failed-фазе.
        self.view.bringSubviewToFront(navBarBlurView)
        self.view.bringSubviewToFront(customNavBar)
    }

    private func applyPhase() {
        // Share/More имеют смысл только в обычном просмотре опубликованного события:
        // в preview черновика — шарить нечего и действий над черновиком нет;
        // moreButton дополнительно завязан на isMyEvent (для чужих событий он скрыт).
        switch phase {
        case .loading:
            errorView.isHidden = true
            shareButton.isHidden = isPreviewMode
            moreButton.isHidden = isPreviewMode || !isMyEvent
            configureNodes()
        case .content:
            errorView.isHidden = true
            shareButton.isHidden = isPreviewMode
            moreButton.isHidden = isPreviewMode || !isMyEvent
            stopShimmers()
        case .failed(let networkError):
            // stopShimmers скроет шиммеры (и попутно покажет контент-вьюхи),
            // hideAllContentSections тут же закроет контент — итого экран чист.
            stopShimmers()
            hideAllContentSections()
            // На .failed события нет — share/more над пустым экраном бессмысленны.
            shareButton.isHidden = true
            moreButton.isHidden = true
            errorView.configure(
                title: networkError ? DivoStrings.profileTabErrorNetworkTitle : DivoStrings.eventDetailErrorTitle,
                subtitle: DivoStrings.profileTabErrorSubtitle,
                onRetry: { [weak self] in self?.onRetryTapped?() }
            )
            errorView.isHidden = false
        }
    }

    private func hideAllContentSections() {
        counterActionsStack.isHidden = true
        eventCostTypeContainer.isHidden = true
        eventTypeLabelContainer.isHidden = true
        profileHeaderView.isHidden = true
        eventDeadlineContainer.isHidden = true
        applyButton.isHidden = true
        organizerView.isHidden = true
        allAppliedContainer.isHidden = true
        currentAppliedContainer.isHidden = true
        descriptionView.isHidden = true
        containerRequirementsContainer.isHidden = true
        parametersView.isHidden = true
        galleryCollectionView.isHidden = true
    }

    // MARK: - Phase API for controller

    func markFailed(networkError: Bool) {
        phase = .failed(networkError: networkError)
    }

    func resetToLoading() {
        phase = .loading
    }

    private func configureNodes() {
        actionsShimmerView.isHidden = false
        counterActionsStack.isHidden = true
        
        eventCostTypeShimmerContainer.isHidden = false
        eventCostTypeContainer.isHidden = true
        
        eventTypeLabelShimmerContainer.isHidden = false
        eventTypeLabelContainer.isHidden = true

        profileHeaderShimmerView.isHidden = false
        profileHeaderView.isHidden = true
        
        eventDeadlineShimmerContainer.isHidden = false
        eventDeadlineContainer.isHidden = true
        
        applyButtonShimmer.isHidden = false
        applyButton.isHidden = true

        appliedStatusShimmerView.isHidden = false
        appliedStatusView.isHidden = true
        
        organizerShimmerView.isHidden = false
        organizerView.isHidden = true
        
        allAppliedShimmerView.isHidden = false
        allAppliedContainer.isHidden = true
        
        currentAppliedShimmerView.isHidden = false
        currentAppliedContainer.isHidden = true
        
        descriptionShimmerView.isHidden = false
        containerDescriptionShimmer.isHidden = false
        descriptionView.isHidden = true
        
        requirementsShimmerContainer.isHidden = false
        containerRequirementsContainer.isHidden = true
        
        parametersShimmerView.isHidden = false
        containerParametersShimmer.isHidden = false
        parametersView.isHidden = true
        
        galleryCollectionView.isHidden = true
    }
    
    private func stopShimmers() {
        guard !profileHeaderShimmerView.isHidden else { return }

        UIView.performWithoutAnimation {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setAnimationDuration(0.0)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))

            actionsShimmerView.isHidden = true
            counterActionsStack.alpha = 1.0
            counterActionsStack.isHidden = false
            
            eventCostTypeShimmerContainer.isHidden = true
            eventCostTypeContainer.isHidden = self.eventData?.paymentType?.id == 2
            
            eventTypeLabelShimmerContainer.isHidden = true
            eventTypeLabelContainer.isHidden = false
            
            profileHeaderShimmerView.isHidden = true
            profileHeaderView.alpha = 1.0
            profileHeaderView.isHidden = false
            
            eventDeadlineShimmerContainer.isHidden = true
            eventDeadlineContainer.isHidden = false
            
            applyButtonShimmer.isHidden = true
            applyButton.isHidden = false

            appliedStatusShimmerView.isHidden = true
            appliedStatusView.isHidden = false
            
            organizerShimmerView.isHidden = true
            organizerView.isHidden = false

            allAppliedShimmerView.isHidden = true
            allAppliedContainer.isHidden = false
            
            currentAppliedShimmerView.isHidden = true
            currentAppliedContainer.isHidden = false
            
            descriptionShimmerView.isHidden = true
            containerDescriptionShimmer.isHidden = true
            descriptionView.isHidden = false
            
            requirementsShimmerContainer.isHidden = true
            containerRequirementsContainer.isHidden = false
            
            parametersShimmerView.isHidden = true
            containerParametersShimmer.isHidden = true
            parametersView.isHidden = false
            
            self.contentViewStack.setNeedsLayout()
            self.contentViewStack.layoutIfNeeded()
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            CATransaction.commit()
        }
    }
    
    private func setupMoreMenu() {
        moreButton.adjustsImageWhenHighlighted = false
        moreButton.addDivoPressState(.pill)

        if #available(iOS 14.0, *) {
            let editEventAction = UIAction(
                title: DivoStrings.editEvent,
                image: nil,
            ) {[weak self] _ in
                self?.onEditEventTapped?()
            }

            let closeApplicationsAction = UIAction(
                title: DivoStrings.closeApplications,
                image: nil,
            ) { [weak self] _ in
                self?.onCloseApplicationsTapped?()
            }
            
            let cancelEventAction = UIAction(
                title: DivoStrings.cancelEvent,
                image: nil,
            ) { [weak self] _ in
                self?.onCancelEventTapped?()
            }
                        
            let deleteAction = UIAction(
                title: DivoStrings.delete,
                image: nil,
                attributes: .destructive
            ) { [weak self] _ in
                self?.onDeleteTapped?()
            }

            let menu = UIMenu(title: "", children: [editEventAction, closeApplicationsAction, cancelEventAction, deleteAction])
            moreButton.menu = menu
            moreButton.showsMenuAsPrimaryAction = true
        }
    }
    
    private func buildAppearanceList(attributes: EventFullModelAttributes?) -> [AppearanceAttribute] {
        
        var items: [AppearanceAttribute] = []
        
        // Вспомогательная функция, которая собирает красивую строку без нулей
        func rangeString(from: Any?, to: Any?) -> String? {
            // Приводим к NSNumber. Это автоматом убирает лишние .0 (18.0 -> "18")
            let fStr = (from as? NSNumber)?.stringValue
            let tStr = (to as? NSNumber)?.stringValue
            
            if let f = fStr, let t = tStr {
                // Если значения одинаковые (например 18 и 18), выводим просто "18"
                return f == t ? f : "\(f)-\(t)"
            }
            // Если есть только одно значение, вернется оно. Если оба nil - вернется nil.
            return fStr ?? tStr
        }

        if let roles = attributes?.role {
            let roleOptions: [FilterOptionItem] = [
                FilterOptionItem(id: "model", title: DivoStrings.debugModel),
                FilterOptionItem(id: "new_face", title: DivoStrings.debugNewTalent)
            ]
            
            let rolesTitles = roles.compactMap { roleId in
                roleOptions.first(where: { $0.id == roleId })?.title
            }.joined(separator: ", ")
            
            if !rolesTitles.isEmpty {
                items.append(.init(title: DivoStrings.debugRole, value: rolesTitles))
            }
        }
        
        if let gender = attributes?.gender {
            let genderTitles = gender.compactMap { $0.title }.joined(separator: ", ")
            if !genderTitles.isEmpty {
                items.append(.init(title: DivoStrings.attrGender, value: genderTitles))
            }
        }
        if let age = attributes?.age, let str = rangeString(from: age.from, to: age.to) {
            items.append(.init(title: DivoStrings.ageYo, value: str))
        }

        if let height = attributes?.height, let str = rangeString(from: height.from, to: height.to) {
            items.append(.init(title: DivoStrings.heightCm, value: str))
        }

        if let weight = attributes?.weight, let str = rangeString(from: weight.from, to: weight.to) {
            items.append(.init(title: DivoStrings.weightKg, value: str))
        }

        if let waist = attributes?.waist, let str = rangeString(from: waist.from, to: waist.to) {
            items.append(.init(title: DivoStrings.waistCm, value: str))
        }

        if let hips = attributes?.hips, let str = rangeString(from: hips.from, to: hips.to) {
            items.append(.init(title: DivoStrings.hipsCm, value: str))
        }

        if let shoesSize = attributes?.shoesSize, let str = rangeString(from: shoesSize.from, to: shoesSize.to) {
            items.append(.init(title: DivoStrings.shoeSizeEU, value: str))
        }


        if let hairColor = attributes?.hairColor {
            let hairColorTitles = hairColor.compactMap { $0.title }.joined(separator: ", ")
            if !hairColorTitles.isEmpty {
                items.append(.init(title: DivoStrings.attrHairColor, value: hairColorTitles))
            }
        }
        
        if let hairLength = attributes?.hairLength {
            let hairLengthTitles = hairLength.compactMap { $0.title }.joined(separator: ", ")
            if !hairLengthTitles.isEmpty {
                items.append(.init(title: DivoStrings.attrHairLength, value: hairLengthTitles))
            }
        }
        
        if let eyeColor = attributes?.eyeColor {
            let eyeColorTitles = eyeColor.compactMap { $0.title }.joined(separator: ", ")
            if !eyeColorTitles.isEmpty {
                items.append(.init(title: DivoStrings.eyeColor, value: eyeColorTitles))
            }
        }
        
        if let skinColor = attributes?.skinColor {
            let skinColorTitles = skinColor.compactMap { $0.title }.joined(separator: ", ")
            if !skinColorTitles.isEmpty {
                items.append(.init(title: DivoStrings.skinColor, value: skinColorTitles))
            }
        }
        
        return items
    }
    
    private func updateGalleryCollectionViewHeight() {
        guard let (layout, _) = self.containerLayout else { return }
        
        let itemsPerRow: CGFloat = 3
        let spacing: CGFloat = 1
        let totalWidth = layout.size.width
        let itemWidth = (totalWidth - 2 * spacing) / itemsPerRow
        
        if phase != .content {
            galleryHeightConstraint.constant = itemWidth
            galleryCollectionView.isHidden = true
        } else if galleryPhotos.isEmpty {
            galleryHeightConstraint.constant = 1
            galleryCollectionView.isHidden = true
        } else {
            let rows = ceil(CGFloat(galleryPhotos.count) / itemsPerRow)
            let galleryHeight = rows * itemWidth + max(0, rows - 1) * spacing
            galleryHeightConstraint.constant = galleryHeight
            galleryCollectionView.isHidden = false
        }
        
        self.setNeedsLayout()
    }
    
    private static func flag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }
    
    private func formatEventDateAndTime(dateString: String?) -> (date: String, time: String) {
        guard let dateString = dateString else {
            return (DivoStrings.tbd, DivoStrings.tbd)
        }

        let serverFormatter = DateFormatter()
        serverFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        serverFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = serverFormatter.date(from: dateString) else {
            return (dateString, "")
        }

        let languageCode = Locale.preferredLanguages.first?.components(separatedBy: "-").first?.lowercased() ?? "en"
        let localeIdentifierByLanguage:[String: String] = [
            "ru": "ru_RU",
            "en": "en_US",
            "pt": "pt_PT",
            "es": "es_ES",
            "zh": "zh_CN"
        ]
        let locale = Locale(identifier: localeIdentifierByLanguage[languageCode] ?? "en_US")

        let dateUIFormatter = DateFormatter()
        dateUIFormatter.locale = locale
        dateUIFormatter.dateFormat = "LLLL d"
        let rawFormattedDate = dateUIFormatter.string(from: date)
        let formattedDate: String = {
            guard let first = rawFormattedDate.first else { return rawFormattedDate }
            return String(first).uppercased(with: locale) + rawFormattedDate.dropFirst()
        }()

        let timeUIFormatter = DateFormatter()
        timeUIFormatter.locale = locale
        switch languageCode {
        case "en": timeUIFormatter.dateFormat = "h:mm a"
        case "zh": timeUIFormatter.dateFormat = "a h:mm"
        case "ru", "pt", "es": timeUIFormatter.dateFormat = "HH:mm"
        default: timeUIFormatter.dateFormat = "HH:mm"
        }
        let formattedTime = timeUIFormatter.string(from: date)

        return (formattedDate, formattedTime)
    }
    
    private func setImage(urlString: String? = nil, for imageView: UIImageView) {
        if let photoURLString = urlString, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
            imageView.loadImage(from: photoURL)
        }
    }
    
    
    // MARK: - Internal
    
    func toggleSaving(active: Bool) {
        publishPreviewButton.setSaving(active, in: self.view)
    }
    
    func updateEventData(_ newEventData: EventFullDetailData) {
        // ВАЖНО: phase = .content выставляется в конце метода, после заполнения всех
        // полей. Иначе applyPhase → stopShimmers скрывает шиммеры до того как текст,
        // кнопки и контейнеры заполнены — пользователь видит пустые placeholder'ы.
        self.eventData = newEventData

        setImage(urlString: newEventData.files?.first?.fullUrl, for: backgroundImageView)

        eventTypeLabel.text = newEventData.type?.title
        
        setupNavigationBarTitle(name: newEventData.title ?? DivoStrings.noName)
        
        let isFree: Bool = newEventData.paymentType?.id == 2
        eventCostTypeContainer.isHidden = newEventData.paymentType?.id == 2
        eventCostTypeLabel.text = newEventData.cost
        
        let (data, time) = formatEventDateAndTime(dateString: newEventData.date)
        profileHeaderView.configure(
            with: EventViewModel(
                name: newEventData.title,
                date: data,
                time: time,
                countryFlag: Self.flag(for: newEventData.address?.city?.countryCode),
                city: newEventData.address?.city?.name,
                isFree: isFree,
                cost: newEventData.cost
            )
        )
        
        // updateEventData может прийти повторно (ретрай, refresh) — сбрасываем
        // ранее навешанные targets, иначе один тап стрельнёт несколько действий.
        applyButton.removeTarget(self, action: nil, for: .touchUpInside)
        applyButton.isUserInteractionEnabled = true
        appliedStatusViewContainer.isHidden = true

        if self.isMyEvent {
            applyButton.makeDivoButton(title: DivoStrings.viewApplications, buttonFont: Font.helveticaNeue(14), radius: 18)
            applyButton.addTarget(self, action: #selector(viewApplicationsTapped), for: .touchUpInside)
        } else if newEventData.isApplied == true {
            applyButton.makeDivoButton(title: DivoStrings.applied, leadingIcon: DivoImage.searchWhiteCheckmark, iconSize: CGSize(width: 16, height: 16), buttonFont: Font.helveticaNeue(14), radius: 18)
            applyButton.isUserInteractionEnabled = false
            let dateText = self.formatAppliedDate(newEventData.date)  //newEventData.appliedAt ??
            appliedStatusView.configure(appliedDateText: dateText)
            appliedStatusViewContainer.isHidden = false
        } else {
            applyButton.makeDivoButton(title: DivoStrings.applyNow, buttonFont: Font.helveticaNeue(14), radius: 18)
            applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        }
        
        if let deadlineText = EventDateFormatter.timeRemaining(deadline: newEventData.applicationDeadline) {
            eventDeadlineLabel.text = deadlineText
            eventDeadlineContainer.isHidden = false
        } else {
            eventDeadlineContainer.isHidden = true
        }
        
        currentAppliedLabel.text = DivoStrings.currentApplied(newEventData.appliesCount ?? 0)
        allAppliedLabel.text = DivoStrings.allApplied(newEventData.maxAttendees ?? 0)
        
        let logoURLString = newEventData.creator?.avatar?.fullUrl
        let logoURL = logoURLString != nil ? URL(string: logoURLString!) : nil
        organizerView.configure(name: newEventData.creator?.fullName , logoURL: logoURL)
        
        descriptionView.update(biography: newEventData.description)
        requirementsLabel.text = newEventData.requirements

        let appearance = buildAppearanceList(attributes: newEventData.modelAttributes)
        parametersView.update(appearance: appearance)
        
        likesView.setValue("1.2K")
        viewsView.setValue("2.4K")
        savesView.setValue("300")

        // Все поля заполнены — теперь атомарно переключаем фазу: applyPhase().content
        // спрячет шиммеры и покажет контент-контейнеры одним кадром, без промежутка.
        self.phase = .content
        activateTitleVisibility()
    }
    
    func updateWithPreviewData(_ data: EventPreviewData) {
        // phase = .content в конце метода, чтобы шиммеры не сменились пустыми
        // плейсхолдерами до фактического заполнения полей.
        if let cover = data.coverImage {
            backgroundImageView.image = cover
        } else {
            backgroundImageView.backgroundColor = DivoColorPalette.profileEmptyBackground
        }
        
        eventTypeLabel.text = data.request.type
        setupNavigationBarTitle(name: DivoStrings.previewEvent.uppercased())
        
        eventCostTypeContainer.isHidden = (data.request.isFree == true)
        eventCostTypeLabel.text = data.request.cost
        
        let (dStr, tStr) = formatEventDateAndTime(dateString: data.request.date)
        profileHeaderView.configure(
            with: EventViewModel(
                name: data.request.title,
                date: dStr,
                time: tStr,
                countryFlag: "🌍",
                city: DivoStrings.tbd,
                isFree: data.request.isFree,
                cost: data.request.cost
            )
        )
        
        if let deadlineText = EventDateFormatter.timeRemaining(deadline: data.request.applicationDeadline) {
            eventDeadlineLabel.text = deadlineText
            eventDeadlineContainer.isHidden = false
        } else {
            eventDeadlineContainer.isHidden = true
        }
        
        applyButton.makeDivoButton(title: DivoStrings.applyPreviewOnly, buttonFont: Font.helveticaNeue(14), radius: 18)
        applyButton.isEnabled = false
        
        currentAppliedLabel.text = DivoStrings.currentApplied(0)
        allAppliedLabel.text = DivoStrings.allApplied(data.request.maxAttendees ?? 0)
        
        organizerView.configure(name: DivoStrings.you, logoURL: nil)
        
        descriptionView.update(biography: data.request.description)
        requirementsLabel.text = data.request.requirements
        
        // Параметры
        var attrs: [AppearanceAttribute] = []
        if let roles = data.request.role {
            let roleOptions: [FilterOptionItem] = [
                FilterOptionItem(id: "model", title: DivoStrings.debugModel),
                FilterOptionItem(id: "new_face", title: DivoStrings.debugNewTalent)
            ]
            
            let rolesTitles = roles.compactMap { roleId in
                roleOptions.first(where: { $0.id == roleId })?.title
            }.joined(separator: ", ")
            
            if !rolesTitles.isEmpty {
                attrs.append(.init(title: DivoStrings.debugRole, value: rolesTitles))
            }
        }
        if let gender = data.request.gender {
            let genderTitles = gender.joined(separator: ", ")
            attrs.append(.init(title: DivoStrings.attrGender, value: genderTitles))
        }
        if let age = data.request.age {
            attrs.append(.init(title: DivoStrings.ageYo, value: "\(age.from)-\(age.to)"))
        }
        if let height = data.request.height {
            attrs.append(.init(title: DivoStrings.heightCm, value: "\(height.from)-\(height.to)"))
        }
        if let weight = data.request.weight {
            attrs.append(.init(title: DivoStrings.weightKg, value: "\(weight.from)-\(weight.to)"))
        }
        if let waist = data.request.waist {
            attrs.append(.init(title: DivoStrings.waistCm, value: "\(waist.from)-\(waist.to)"))
        }
        if let hips = data.request.hips {
            attrs.append(.init(title: DivoStrings.hipsCm, value: "\(hips.from)-\(hips.to)"))
        }
        if let shoesSize = data.request.shoesSize {
            attrs.append(.init(title: DivoStrings.shoeSizeEU, value: "\(shoesSize.from)-\(shoesSize.to)"))
        }
        if let hairColor = data.request.hairColor {
            let hairColorTitles = hairColor.compactMap( { String($0) } ).joined(separator: ", ")
            attrs.append(.init(title: DivoStrings.attrHairColor, value: hairColorTitles))
        }
        if let hairLength = data.request.hairLength {
            let hairLengthTitles = hairLength.compactMap( { String($0) } ).joined(separator: ", ")
            attrs.append(.init(title: DivoStrings.attrHairLength, value: hairLengthTitles))
        }
        if let eyeColor = data.request.eyeColor {
            let eyeColorTitles = eyeColor.compactMap( { String($0) } ).joined(separator: ", ")
            attrs.append(.init(title: DivoStrings.eyeColor, value: eyeColorTitles))
        }
        if let skinColor = data.request.skinColor {
            let skinColorTitles = skinColor.compactMap( { String($0) } ).joined(separator: ", ")
            attrs.append(.init(title: DivoStrings.skinColor, value: skinColorTitles))
        }
        
        if attrs.isEmpty {
            parametersView.isHidden = true
        } else {
            parametersView.isHidden = false
            parametersView.update(appearance: attrs)
        }
        
        // Статистика по нулям
        likesView.setValue("1K")
        viewsView.setValue("1K")
        savesView.setValue("1K")

        updateGallery(data.gallery)

        self.phase = .content
        activateTitleVisibility()
    }

    private func formatAppliedDate(_ dateString: String?) -> String {
        guard let dateString = dateString else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: DivoStrings.current.rawValue)
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: Date())
        }
        let serverFormatter = DateFormatter()
        serverFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        serverFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let date = serverFormatter.date(from: dateString) else { return dateString }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: DivoStrings.current.rawValue)
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }
    
    // Метод управления загрузкой отзыва
    func toggleWithdrawLoading(active: Bool) {
        appliedStatusView.setWithdrawLoading(active)
    }
    
    func updateGallery(_ photos: [UserPhoto]) {
        self.galleryPhotos = photos
        self.galleryCollectionView.reloadData()
        if !photos.isEmpty {
            self.galleryStatusView.isHidden = true
            self.galleryCollectionView.isHidden = false
        }
        updateGalleryCollectionViewHeight()
        updateCollectionsContainerHeight(animated: false)
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        navigationBarTitleHeightConstraint.isActive = false
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: navigationBarHeight)
        navigationBarTitleHeightConstraint.isActive = true
        
        applyGradientBlurMask()
        updateNavBarBlurMask()
        updateGalleryCollectionViewHeight()
        updateCollectionsContainerHeight(animated: false)
        
        updateNavigationBarTitleVisibility()
        
        self.layoutIfNeeded()
    }
    
    
    // MARK: - Actions
    
    @objc private func backTapped() { onBackTapped?() }
    @objc private func shareTapped() { onShareTapped?() }
    @objc private func bookmarkTapped() { onBookmarkTapped?() }
    @objc private func applyTapped() { onApplyTapped?() }
    @objc private func viewApplicationsTapped() { onViewApplicationsTapped?() }
    
    @objc private func likesViewDidTap() {}
    @objc private func viewsViewDidTap() {}
    @objc private func savesViewDidTap() {}
    @objc private func likesPillTapped() {}
    @objc private func savesPillTapped() {}
    
    
    @objc private func editPreviewTapped() { onEditPreviewTapped?() }
    @objc private func publishPreviewTapped() {
        toggleSaving(active: true)
        onPublishPreviewTapped?()
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
            bottomAnchor: editPreviewButton.topAnchor,
            retryTitle: retryAction != nil ? DivoStrings.retry : nil,
            retryAction: retryAction,
            persistent: persistent
        )
    }

    func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
    }
}


// MARK: - Scroll & Animations

extension EventDetailControllerNode: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let maxScrollY = scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
        let bottomLimit = max(0, maxScrollY)
        
        if scrollView.contentOffset.y > bottomLimit {
            scrollView.contentOffset.y = bottomLimit
        }
        
        updateNavigationBarTitleVisibility()
    }

    private func applyGradientBlurMask() {
        let blurHeight = blurredHeaderImageView.bounds.height
        guard blurHeight > 0 else { return }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = blurredHeaderImageView.bounds
        let fadeDistance: CGFloat = 60.0
        let fadeLocation = min(1.0, fadeDistance / blurHeight)
        
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor]
        gradientLayer.locations = [0.0, NSNumber(value: Double(fadeLocation))]
        blurredHeaderImageView.layer.mask = gradientLayer
    }

    private func updateNavBarBlurMask() {
        let bounds = navBarBlurView.bounds
        guard bounds.height > 0 else { return }
        guard let (_, navHeight) = self.containerLayout else { return }

        // Точка отсечения = collectionsContainer.top в sticky-state
        // (= navHeight + segmentBarHeight + 10). Считаем долю от bounds.height
        // динамически — иначе на разных safeArea.top mask промахивается мимо
        // tab content.
        let cutoffPt = navHeight
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
        let nameY = infoStack.frame.minY > 0 ? infoStack.frame.minY : 280.0
        
        let titleStartShowingOffset = nameY - navigationBarHeight - 40
        let titleFullyVisibleOffset = nameY - navigationBarHeight + 20
        
        var titleAlpha: CGFloat = 0.0
        if offsetY < titleStartShowingOffset { titleAlpha = 0.0 }
        else if offsetY >= titleFullyVisibleOffset { titleAlpha = 1.0 }
        else { titleAlpha = (offsetY - titleStartShowingOffset) / (titleFullyVisibleOffset - titleStartShowingOffset) }
        
        if titleView.alpha != titleAlpha {
            titleView.alpha = titleAlpha
        }
        
        navBarBlurView.alpha = min(1.0, titleAlpha * 2.0)

        let maxProgress = titleAlpha
        let iconColor = DivoColorPalette.primaryTextOnDark.blend(with: DivoColorPalette.primaryText, alpha: maxProgress)
        closeButton.tintColor = iconColor
        shareButton.tintColor = iconColor
        moreButton.tintColor = iconColor
        
        let bgStartColor = DivoColorPalette.statPillBackground
        let bgEndColor = DivoColorPalette.screenBackground
        let currentBgColor = bgStartColor.blend(with: bgEndColor, alpha: maxProgress)
        
        closeButton.backgroundColor = currentBgColor
        rightButtonContainer.backgroundColor = currentBgColor
        
        let borderStartColor = DivoColorPalette.statPillBorder.cgColor
        let borderEndColor = UIColor.clear.cgColor
        closeButton.layer.borderColor = maxProgress > 0.5 ? borderEndColor : borderStartColor
        rightButtonContainer.layer.borderColor = maxProgress > 0.5 ? borderEndColor : borderStartColor

        if offsetY > 0 {
            let pillAlpha = max(0, 1.0 - offsetY / 60.0)
            counterActionsStack.alpha = pillAlpha
            actionsShimmerView.alpha = pillAlpha
        } else {
            counterActionsStack.alpha = 1.0
            actionsShimmerView.alpha = 1.0
        }
    }
    
    private func activateTitleVisibility() {
        guard !titleVisibilityActivated else { return }
        titleVisibilityActivated = true
        self.setNeedsLayout()
        self.layoutIfNeeded()
        updateNavigationBarTitleVisibility()
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
}


// MARK: - Collections Delegate

extension EventDetailControllerNode: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == galleryCollectionView { return galleryPhotos.count }
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == galleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as? GalleryCell else { return UICollectionViewCell() }
            
            let photoItem = galleryPhotos[indexPath.item]
            if let fullUrlString = photoItem.photo.fullUrl, let url = CDNURLHelper.convertToCDNURL(fullUrlString) {
                cell.configure(with: url)
            }
            
            return cell
        }
        return UICollectionViewCell()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == galleryCollectionView {
            let photo = galleryPhotos[indexPath.item]
            guard let uuid = photo.photo.fileUuid else { return }
            onGalleryItemTapped?(uuid)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == galleryCollectionView {
            guard let (layout, _) = self.containerLayout else { return .zero }
            let totalSpacing: CGFloat = 2
            let width = (layout.size.width - totalSpacing) / 3.0
            return CGSize(width: width, height: width)
        }
        return .zero
    }
}


// MARK: - DescriptionViewDelegate

extension EventDetailControllerNode: DescriptionViewDelegate {
    func descriptionViewDidUpdateContentHeight(animated: Bool) {
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


// MARK: - ParametersViewDelegate

extension EventDetailControllerNode: ParametersViewDelegate {
    func parametersViewDidUpdateContentHeight(animated: Bool) {
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
