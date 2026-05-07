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
    private var presentationData: PresentationData

    // Callbacks
    var onBackTapped: (() -> Void)?
    var onShareTapped: (() -> Void)?
    var onBookmarkTapped: (() -> Void)?
    var onApplyTapped: (() -> Void)?

    var coverImage: UIImage? {
        return backgroundImageView.image
    }

    // MARK: - Core Layout
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var isPerformingLayout = false

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
    private var navigationBarTitleHeightConstraint: NSLayoutConstraint!
    
    private let navBarBlurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialLight)
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
    
    private let bookmarkButton = UIButton(type: .custom)

    // MARK: - Event Info Section (Header)
    
    private let eventTypeContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let eventInfoWrapper: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
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
    
    private let participantsView = StatPillView(icon: DivoImage.statView)
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
        label.text = "All applied"
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
        label.text = "All applied"
        return label
    }()

    // MARK: - Content Sections
    private let organizerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let organizatiorView: OrganizatiorView = {
        let organizatiorView = OrganizatiorView()
        organizatiorView.translatesAutoresizingMaskIntoConstraints = false
        return organizatiorView
    }()
    
    private let organizatiorShimmerView: UIView = {
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
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let previousEventsTitleLabel = UILabel()
    private let imageGalleryCollectionView: UICollectionView
    let previousEventsCollectionView: UICollectionView

    private let isMyEvent: Bool

    // MARK: - Init
    init(context: AccountContext, presentationData: PresentationData, isMyEvent: Bool = false) {
        self.context = context
        self.presentationData = presentationData
        self.isMyEvent = isMyEvent

        let flowLayoutGallery = UICollectionViewFlowLayout()
        flowLayoutGallery.scrollDirection = .horizontal
        flowLayoutGallery.minimumLineSpacing = 0
        flowLayoutGallery.minimumInteritemSpacing = 0
        self.imageGalleryCollectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayoutGallery)

        let flowLayoutPreviousEvents = UICollectionViewFlowLayout()
        flowLayoutPreviousEvents.scrollDirection = .horizontal
        self.previousEventsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayoutPreviousEvents)

        super.init()
        self.backgroundColor = DivoColorPalette.darkBackground

        setupUI()
        configureNodes()
    }

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
        updateNavBarBlurMask()
        
        if !actionsShimmerView.isHidden {
            actionsShimmerView.startAnimation()
        }
        
        if !eventCostTypeShimmerContainer.isHidden && !eventTypeLabelShimmerContainer.isHidden {
            eventCostTypeShimmerContainer.stopShimmering()
            eventCostTypeShimmerContainer.startShimmering()
            eventTypeLabelShimmerContainer.stopShimmering()
            eventTypeLabelShimmerContainer.startShimmering()
        }
        
        if !eventDeadlineShimmerContainer.isHidden && !applyButtonShimmer.isHidden {
            eventDeadlineShimmerContainer.stopShimmering()
            applyButtonShimmer.stopShimmering()
            eventDeadlineShimmerContainer.startShimmering()
            applyButtonShimmer.startShimmering()
        }
        
        if !organizatiorShimmerView.isHidden{
            organizatiorShimmerView.stopShimmering()
            organizatiorShimmerView.startShimmering()
        }
        
        if !currentAppliedShimmerView.isHidden && !allAppliedShimmerView.isHidden {
            currentAppliedShimmerView.stopShimmering()
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

    // MARK: - Setup UI
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
        
        // Align Moving Blur
        NSLayoutConstraint.activate([
            blurredHeaderImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            blurredHeaderImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            blurredHeaderImageView.topAnchor.constraint(equalTo: eventTypeContainer.topAnchor, constant: -20),
            blurredHeaderImageView.bottomAnchor.constraint(equalTo: whiteSheetBackground.topAnchor, constant: 20)
        ])
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
            navBarBlurView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52)
        ])
    }

    private func setupCustomNavBar() {
        view.addSubview(customNavBar)
        
        customNavBar.addSubview(closeButton)
        customNavBar.addSubview(rightButtonContainer)
        
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
    
    @objc private func likesViewDidTap() {

    }
    
    @objc private func viewsViewDidTap() {

    }
    
    @objc private func savesViewDidTap() {

    }
    
    @objc private func likesPillTapped() {

    }
    
    @objc private func savesPillTapped() {

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
        infoStack.addSubview(profileHeaderShimmerView)
        
        NSLayoutConstraint.activate([
            infoStack.topAnchor.constraint(equalTo: profileHeaderWrapper.topAnchor),
            infoStack.bottomAnchor.constraint(equalTo: profileHeaderWrapper.bottomAnchor),
            infoStack.leadingAnchor.constraint(equalTo: profileHeaderWrapper.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            infoStack.trailingAnchor.constraint(equalTo: profileHeaderWrapper.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            profileHeaderShimmerView.leadingAnchor.constraint(equalTo: infoStack.leadingAnchor),
            profileHeaderShimmerView.trailingAnchor.constraint(equalTo: infoStack.trailingAnchor),
            profileHeaderShimmerView.topAnchor.constraint(equalTo: infoStack.topAnchor),
            profileHeaderShimmerView.bottomAnchor.constraint(equalTo: infoStack.bottomAnchor),
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
        
        contentViewStack.setCustomSpacing(24, after: container)
    }
    
    private func setupAllAppliedContainer() {
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
            
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            currentAppliedShimmerView.heightAnchor.constraint(equalToConstant: 74),
            allAppliedShimmerView.heightAnchor.constraint(equalToConstant: 74),
        ])
        
        NSLayoutConstraint.activate([
            whiteSheetBackground.topAnchor.constraint(equalTo: container.topAnchor),
            whiteSheetBackground.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            whiteSheetBackground.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            whiteSheetBackground.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 1000)
        ])
    }

    private func setupOrganizerContainer() {
        contentViewStack.addArrangedSubview(organizerContainer)

        organizerContainer.addSubview(organizatiorView)
        organizerContainer.addSubview(organizatiorShimmerView)
        
        NSLayoutConstraint.activate([
            organizatiorView.leadingAnchor.constraint(equalTo: organizerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            organizatiorView.topAnchor.constraint(equalTo: organizerContainer.topAnchor),
            organizatiorView.trailingAnchor.constraint(equalTo: organizerContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            organizatiorView.bottomAnchor.constraint(equalTo: organizerContainer.bottomAnchor),
            
            organizatiorShimmerView.leadingAnchor.constraint(equalTo: organizerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            organizatiorShimmerView.topAnchor.constraint(equalTo: organizerContainer.topAnchor),
            organizatiorShimmerView.trailingAnchor.constraint(equalTo: organizerContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            organizatiorShimmerView.bottomAnchor.constraint(equalTo: organizerContainer.bottomAnchor),
            organizatiorShimmerView.heightAnchor.constraint(equalToConstant: 96)
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
    }

    private func createParamRow(icon: UIImageView, title: String, valueLabel: UILabel) -> UIView {
        let view = UIView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = DivoColorPalette.primaryText
        icon.contentMode = .scaleAspectFit
        
        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = Font.regular(14)
        titleLbl.textColor = DivoColorPalette.primaryText
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        
        valueLabel.font = Font.semibold(14)
        valueLabel.textColor = DivoColorPalette.primaryText
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(icon)
        view.addSubview(titleLbl)
        view.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            
            titleLbl.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            titleLbl.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            view.heightAnchor.constraint(equalToConstant: 24)
        ])
        return view
    }

    private func createSeparator() -> UIView {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.separatorSoft
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    private func setupCollections() {
        contentViewStack.addArrangedSubview(collectionsContainer)
        
        imageGalleryCollectionView.translatesAutoresizingMaskIntoConstraints = false
        imageGalleryCollectionView.backgroundColor = .clear
        imageGalleryCollectionView.dataSource = self
        imageGalleryCollectionView.delegate = self
        imageGalleryCollectionView.register(ImageGalleryCell.self, forCellWithReuseIdentifier: "ImageGalleryCell")
        
        previousEventsTitleLabel.text = DivoStrings.previousEvents
        previousEventsTitleLabel.font = Font.semibold(18)
        previousEventsTitleLabel.textColor = DivoColorPalette.primaryText
        previousEventsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        previousEventsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        previousEventsCollectionView.backgroundColor = .clear
        previousEventsCollectionView.dataSource = self
        previousEventsCollectionView.delegate = self
        previousEventsCollectionView.register(EventPreviousCollectionViewCell.self, forCellWithReuseIdentifier: "EventPreviousCollectionViewCell")
        
        collectionsContainer.addSubview(imageGalleryCollectionView)
        collectionsContainer.addSubview(previousEventsTitleLabel)
        collectionsContainer.addSubview(previousEventsCollectionView)
        
        NSLayoutConstraint.activate([
            imageGalleryCollectionView.topAnchor.constraint(equalTo: collectionsContainer.topAnchor),
            imageGalleryCollectionView.leadingAnchor.constraint(equalTo: collectionsContainer.leadingAnchor),
            imageGalleryCollectionView.trailingAnchor.constraint(equalTo: collectionsContainer.trailingAnchor),
            imageGalleryCollectionView.heightAnchor.constraint(equalToConstant: 140),
            
            previousEventsTitleLabel.topAnchor.constraint(equalTo: imageGalleryCollectionView.bottomAnchor, constant: 24),
            previousEventsTitleLabel.leadingAnchor.constraint(equalTo: collectionsContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            
            previousEventsCollectionView.topAnchor.constraint(equalTo: previousEventsTitleLabel.bottomAnchor, constant: 12),
            previousEventsCollectionView.leadingAnchor.constraint(equalTo: collectionsContainer.leadingAnchor),
            previousEventsCollectionView.trailingAnchor.constraint(equalTo: collectionsContainer.trailingAnchor),
            previousEventsCollectionView.heightAnchor.constraint(equalToConstant: 310),
            previousEventsCollectionView.bottomAnchor.constraint(equalTo: collectionsContainer.bottomAnchor, constant: -40)
        ])
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
        
        organizatiorShimmerView.isHidden = false
        organizatiorView.isHidden = true
        
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
            eventCostTypeContainer.isHidden = false
            
            eventTypeLabelShimmerContainer.isHidden = true
            eventTypeLabelContainer.isHidden = false
            
            profileHeaderShimmerView.isHidden = true
            profileHeaderView.alpha = 1.0
            profileHeaderView.isHidden = false
            
            eventDeadlineShimmerContainer.isHidden = true
            eventDeadlineContainer.isHidden = false
            
            applyButtonShimmer.isHidden = true
            applyButton.isHidden = false
            
            organizatiorShimmerView.isHidden = true
            organizatiorView.isHidden = false

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

    // MARK: - Actions
    @objc private func backTapped() { onBackTapped?() }
    @objc private func shareTapped() { onShareTapped?() }
    @objc private func bookmarkTapped() { onBookmarkTapped?() }
    @objc private func applyTapped() { onApplyTapped?() }
    
    private func buildAppearanceList(attributes: EventFullModelAttributes?) -> [AppearanceAttribute] {
        
        var items: [AppearanceAttribute] = []
        
        if let gender = attributes?.gender {
            let genderTitles = gender.compactMap { $0.title }.joined(separator: ", ")
            items.append(.init(title: DivoStrings.attrGender, value: genderTitles))
        }
        if let height = attributes?.height {
            items.append(.init(title: DivoStrings.heightCm, value: "\(height.from ?? 0)-\(height.to ?? 0)"))
        }
        if let weight = attributes?.weight {
            items.append(.init(title: DivoStrings.weightKg, value: "\(weight.from ?? 0)-\(weight.to ?? 0)"))
        }
        if let waist = attributes?.waist {
            items.append(.init(title: DivoStrings.waistCm, value: "\(waist.from ?? 0)-\(waist.to ?? 0)"))
        }
        if let hips = attributes?.hips {
            items.append(.init(title: DivoStrings.hipsCm, value: "\(hips.from ?? 0)-\(hips.to ?? 0)"))
        }
        if let shoesSize = attributes?.shoesSize {
            items.append(.init(title: DivoStrings.shoeSizeEU, value: "\(shoesSize.from ?? 0)-\(shoesSize.to ?? 0)"))
        }
        if let hairColor = attributes?.hairColor {
            let hairColorTitles = hairColor.compactMap { $0.title }.joined(separator: ", ")
            items.append(.init(title: DivoStrings.attrHairColor, value: hairColorTitles))
        }
        if let hairLength = attributes?.hairLength {
            let hairLengthTitles = hairLength.compactMap { $0.title }.joined(separator: ", ")
            items.append(.init(title: DivoStrings.attrHairLength, value: hairLengthTitles))
        }
        if let eyeColor = attributes?.eyeColor {
            let eyeColorTitles = eyeColor.compactMap { $0.title }.joined(separator: ", ")
            items.append(.init(title: DivoStrings.eyeColor, value: eyeColorTitles))
        }
        if let skinColor = attributes?.skinColor {
            let skinColorTitles = skinColor.compactMap { $0.title }.joined(separator: ", ")
            items.append(.init(title: DivoStrings.skinColor, value: skinColorTitles))
        }
        
        return items
    }

    // MARK: - Data Population
    func updateEventData(_ newEventData: EventFullDetailData) {
        self.eventData = newEventData

        setImage(urlString: newEventData.files?.first?.fullUrl, for: backgroundImageView)

        eventTypeLabel.text = newEventData.type?.title
        
        eventCostTypeLabel.isHidden = newEventData.cost == nil
        eventCostTypeLabel.text = newEventData.cost
        
        let (data, time) = formatEventDateAndTime(dateString: newEventData.date)
        profileHeaderView.configure(
            with: EventViewModel(
                name: newEventData.title,
                date: data,
                time: time,
                countryFlag: Self.flag(for: newEventData.address?.city?.countryCode),
                city: newEventData.address?.city?.name,
                cost: newEventData.cost
            )
        )
        
        // ПОМЕНЯТЬ ДАТУ ПРИ ОБНОВЛЕНИИ АПИ
        let (_, deadlineTime) = formatEventDateAndTime(dateString: newEventData.date)
        eventDeadlineLabel.text = DivoStrings.deadlineData(deadlineTime)
        
        // НУЖНО ПОЛУЧАТЬ ИЗ РУЧКИ ДАННЫЕ, ПОКА ИХ ТАМ НЕТ
        currentAppliedLabel.text = DivoStrings.currentApplied(23)
        allAppliedLabel.text = DivoStrings.allApplied(24)
        
        let logoURLString = newEventData.creator?.avatar?.fullUrl
        let logoURL = logoURLString != nil ? URL(string: logoURLString!) : nil
        organizatiorView.configure(name: newEventData.creator?.fullName , logoURL: logoURL)
        
        descriptionView.update(biography: newEventData.description)
        
        // СЮДА НАДО ПЕРЕДАВАТ ЗНАЧЕНИЕ ТРЕБОВАНИЙ, ПОКА НЕТ В АПИ
        requirementsLabel.text = newEventData.description

        let appearance = buildAppearanceList(attributes: newEventData.modelAttributes)
        parametersView.update(appearance: appearance)
        
        // Mock data for counters
        participantsView.setValue("1024")
        likesView.setValue("1.2K")
        viewsView.setValue("2.4K")
        savesView.setValue("300")
        
        stopShimmers()
    }
    
    // Получаем картинку флага в зависимости от кода страны
    private static func flag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }
    
    private func formatEventDateAndTime(dateString: String?) -> (date: String, time: String) {
        guard let dateString = dateString else {
            return ("TBD", "TBD")
        }

        let serverFormatter = DateFormatter()
        serverFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        serverFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = serverFormatter.date(from: dateString) else {
            return (dateString, "")
        }

        let languageCode = Locale.preferredLanguages.first?
            .components(separatedBy: "-")
            .first?
            .lowercased() ?? "en"
        let localeIdentifierByLanguage: [String: String] = [
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
        case "en":
            timeUIFormatter.dateFormat = "h:mm a"
        case "zh":
            timeUIFormatter.dateFormat = "a h:mm"
        case "ru", "pt", "es":
            timeUIFormatter.dateFormat = "HH:mm"
        default:
            timeUIFormatter.dateFormat = "HH:mm"
        }
        let formattedTime = timeUIFormatter.string(from: date)

        return (formattedDate, formattedTime)
    }
    

    private func setImage(urlString: String? = nil, for imageView: UIImageView) {
        if let photoURLString = urlString, let photoURL = CDNURLHelper.convertToCDNURL(photoURLString) {
            imageView.loadImage(from: photoURL)
        }
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        navigationBarTitleHeightConstraint.isActive = false
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: navigationBarHeight + 18)
        navigationBarTitleHeightConstraint.isActive = true
        
        applyGradientBlurMask()
        updateNavBarBlurMask()
        self.layoutIfNeeded()
    }
}

// MARK: - Scroll & Animations
extension EventDetailControllerNode: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
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
        
        if navBarWhiteGradientLayer.superlayer == nil {
            navBarBlurView.contentView.layer.insertSublayer(navBarWhiteGradientLayer, at: 0)
        }
        navBarWhiteGradientLayer.frame = bounds
        navBarWhiteGradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.74).cgColor,
            UIColor.white.withAlphaComponent(0.70).cgColor,
            UIColor.white.withAlphaComponent(0.20).cgColor,
            UIColor.clear.cgColor
        ]
        navBarWhiteGradientLayer.locations = [0.0, 0.15, 0.45, 0.70]

        let maskLayer = CAGradientLayer()
        maskLayer.frame = bounds
        maskLayer.colors = [
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor,
            UIColor.clear.cgColor
        ]
        maskLayer.locations = [0.0, 0.22, 0.50, 0.75]
        navBarBlurView.layer.mask = maskLayer
    }

    private func updateNavigationBarTitleVisibility() {
        guard let (_, navigationBarHeight) = self.containerLayout else { return }
        
        let offsetY = scrollView.contentOffset.y
        let nameY = eventInfoWrapper.frame.minY > 0 ? eventInfoWrapper.frame.minY : 300.0
        
        let titleStartShowingOffset = nameY - navigationBarHeight - 40
        let titleFullyVisibleOffset = nameY - navigationBarHeight + 20
        
        var titleAlpha: CGFloat = 0.0
        if offsetY < titleStartShowingOffset { titleAlpha = 0.0 }
        else if offsetY >= titleFullyVisibleOffset { titleAlpha = 1.0 }
        else { titleAlpha = (offsetY - titleStartShowingOffset) / (titleFullyVisibleOffset - titleStartShowingOffset) }
        
//        navTitleLabel.alpha = titleAlpha
        navBarBlurView.alpha = min(1.0, titleAlpha * 2.0)

        // Blend colors
        let maxProgress = titleAlpha
        let iconColor = DivoColorPalette.primaryTextOnDark //.blend(with: DivoColorPalette.primaryText, alpha: maxProgress)
        closeButton.tintColor = iconColor
        shareButton.tintColor = iconColor
        bookmarkButton.tintColor = iconColor
        
        let bgStartColor = DivoColorPalette.statPillBackground
        // let bgEndColor = DivoColorPalette.cardBackground
        let currentBgColor = bgStartColor //.blend(with: bgEndColor, alpha: maxProgress)
        
        closeButton.backgroundColor = currentBgColor
        rightButtonContainer.backgroundColor = currentBgColor
        
        let borderStartColor = DivoColorPalette.statPillBorder.cgColor
        let borderEndColor = UIColor.clear.cgColor
        closeButton.layer.borderColor = maxProgress > 0.5 ? borderEndColor : borderStartColor
        rightButtonContainer.layer.borderColor = maxProgress > 0.5 ? borderEndColor : borderStartColor
    }
}

// MARK: - Collections Delegate
extension EventDetailControllerNode: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    private var previousEvents: [EventData] {
        return[
            EventData(title: "fashion model event", subtitle: "May 27 · 5:00 PM · NY NYFW Magazine", profileName: "", timeRemaining: "", type: "Conference"),
            EventData(title: "Previous Event 2", subtitle: "", profileName: "", timeRemaining: "", type: "Casting"),
            EventData(title: "Previous Event 3", subtitle: "", profileName: "", timeRemaining: "", type: "Casting")
        ]
    }

    private var imageGalleryItems: [UIImage?] {
        return Array(repeating: DivoImage.statLike, count: 6)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == imageGalleryCollectionView { return imageGalleryItems.count }
        if collectionView == previousEventsCollectionView { return previousEvents.count }
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == imageGalleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageGalleryCell", for: indexPath) as? ImageGalleryCell else { return UICollectionViewCell() }
            cell.configure(with: imageGalleryItems[indexPath.item])
            return cell
        } else {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EventPreviousCollectionViewCell", for: indexPath) as? EventPreviousCollectionViewCell else { return UICollectionViewCell() }
            cell.configure(with: previousEvents[indexPath.item])
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == imageGalleryCollectionView {
            let itemWidth = collectionView.bounds.width / 3.0
            return CGSize(width: itemWidth, height: 140)
        } else {
            return CGSize(width: 240, height: 290)
        }
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

