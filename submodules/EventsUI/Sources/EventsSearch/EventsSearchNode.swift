//
//  EventsSearchNode.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 29.05.2026.
//

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import DivoCore
import DivoUIKit

final class EventsSearchNode: ASDisplayNode {
    private let context: AccountContext
    
    private let topBarContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let searchFieldContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.layer.applyDivoShadow()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let searchIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = DivoImage.searchFieldIcon
        imageView.tintColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let searchTextField: UITextField = {
        let field = UITextField()
        field.font = Font.regular(14)
        field.textColor = DivoColorPalette.primaryText
        field.tintColor = DivoColorPalette.accentSecondary
        field.placeholder = DivoStrings.eventsSearchPlaceholder
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
        
    private let filterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        button.setImage(DivoImage.searchFilterIcon, for: .normal)
        button.tintColor = DivoColorPalette.primaryText
        button.layer.applyDivoShadow()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let filterButtonLoader: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .medium)
        loader.color = DivoColorPalette.accent
        loader.hidesWhenStopped = true
        loader.translatesAutoresizingMaskIntoConstraints = false
        loader.isHidden = true
        return loader
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        let image = DivoImage.searchCloseIcon
        button.setImage(image, for: .normal)
        button.tintColor = DivoColorPalette.primaryText
        button.layer.applyDivoShadow()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let resultsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.card
        view.clipsToBounds = true
        view.layer.applyDivoShadow(radius: DivoDesignTokens.Shadow.radiusLarge)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let resultsTableView: UITableView = {
        let tableView = UITableView()
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = true
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .onDrag
        tableView.showsVerticalScrollIndicator = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private let resultsCountLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryText
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var gridCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.isHidden = true
        cv.keyboardDismissMode = .onDrag
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.showsVerticalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        return cv
    }()

    private let bottomBlurOverlay: DivoGlassBlurView = {
        let view = DivoGlassBlurView(
            direction: .bottom,
            blurStyle: .systemUltraThinMaterialLight,
            falloff: .linear
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let autocompleteLoader: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .medium)
        loader.color = DivoColorPalette.accent
        loader.hidesWhenStopped = true
        loader.translatesAutoresizingMaskIntoConstraints = false
        return loader
    }()
    
    private let gridCenterLoader: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .large)
        loader.color = DivoColorPalette.accent
        loader.hidesWhenStopped = true
        loader.translatesAutoresizingMaskIntoConstraints = false
        return loader
    }()
    
    // MARK: - Empty State Elements
    
    private let emptyStateContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emptyStateIconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.sheet
        view.layer.applyDivoShadow(opacity: 0.05)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let emptyStateIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "magnifyingglass")
        imageView.tintColor = DivoColorPalette.systemLabelTertiary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let emptyStateTitle: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.feedSearchNoFound
        label.font = Font.helveticaNeue(26)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emptyStateSubtitle: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.feedSearchNoFilters
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emptyStateResetButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(DivoStrings.feedSearchResetFilters, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = Font.medium(14)
        button.backgroundColor = DivoColorPalette.secondaryButtonBackground
        button.layer.cornerRadius = 20
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
        button.addDivoPressState(.secondary)
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let activeFiltersContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = 18
        view.layer.applyDivoShadow()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let activeFiltersLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let activeFiltersClearButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        button.tintColor = DivoColorPalette.primaryText
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let resultFilterStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.isHidden = true
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let stackSpacer: UIView = {
        let view = UIView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Skeleton Elements

    private let filterSkeletonLeft: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.skeletonBackground
        view.layer.cornerRadius = 9.5
        view.clipsToBounds = true
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let filterSkeletonRight: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.skeletonBackground
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let skeletonCount = 6

    private var resultsContainerHeightConstraint: NSLayoutConstraint?
    private var gridTopToFilterStackConstraint: NSLayoutConstraint?
    private var gridTopToSkeletonConstraint: NSLayoutConstraint?

    private var currentAutocompleteResults: [EventItem] = []
    private var currentGridResults: [EventData] = []

    var onClosePressed: (() -> Void)?
    var onFilterPressed: (() -> Void)?
    var onEventTapped: ((EventData) -> Void)?
    var requestAutocomplete: ((String) -> Void)?
    var cancelAutocomplete: (() -> Void)?
    var requestGridSearch: ((String) -> Void)?
    var loadMoreGridResults: (() -> Void)?
    var onSearchCleared: (() -> Void)?
    var onGridApplyTapped: ((Int, EventCollectionViewCell) -> Void)?
    var onFiltersClearTapped: (() -> Void)?
    
    private var searchTimer: Timer?
    private var currentKeyboardHeight: CGFloat = 0
    private var loaderDelayTimer: Timer?
    
    enum SearchMode {
        case idle
        case autocomplete
        case grid
    }

    enum GridState {
        case idle
        case loading
        case error
        case empty
        case results
    }

    enum PaginationState {
        case idle
        case loading
        case error
    }

    var mode: SearchMode = .idle
    private var gridState: GridState = .idle
    private var paginationState: PaginationState = .idle
    private var activeFiltersCount: Int = 0

    private var currentTask: Task<Void, Never>?
    
    init(context: AccountContext) {
        self.context = context
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground
    }
    
    override func didLoad() {
        super.didLoad()
        setupUI()

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardTapped))
        dismissTap.cancelsTouchesInView = false
        view.addGestureRecognizer(dismissTap)

        let dismissSwipe = UISwipeGestureRecognizer(target: self, action: #selector(dismissKeyboardTapped))
        dismissSwipe.direction = .down
        view.addGestureRecognizer(dismissSwipe)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        searchTextField.becomeFirstResponder()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        searchTimer?.invalidate()
        currentTask?.cancel()
    }
    
    private func setupUI() {
        setupTopContainer()
        setupGridContainer()
        setupResultsContainer()
        setupEmptyStateContainer()
    }
    
    private func setupTopContainer() {
        let safeArea = view.safeAreaLayoutGuide
        let sidePadding: CGFloat = DivoDesignTokens.Spacing.m
        let elementHeight: CGFloat = 40.0
        let spacing: CGFloat = DivoDesignTokens.Spacing.s
        
        view.addSubview(topBarContainer)
        topBarContainer.addSubview(searchFieldContainer)
        searchFieldContainer.addSubview(searchIcon)
        searchFieldContainer.addSubview(searchTextField)
        topBarContainer.addSubview(filterButton)
        topBarContainer.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            topBarContainer.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: DivoDesignTokens.Spacing.s),
            topBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarContainer.heightAnchor.constraint(equalToConstant: elementHeight)
        ])
        
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            closeButton.trailingAnchor.constraint(equalTo: topBarContainer.trailingAnchor, constant: -sidePadding),
            closeButton.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: elementHeight),
            closeButton.heightAnchor.constraint(equalToConstant: elementHeight)
        ])
        
        filterButton.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            filterButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -spacing),
            filterButton.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            filterButton.widthAnchor.constraint(equalToConstant: elementHeight),
            filterButton.heightAnchor.constraint(equalToConstant: elementHeight)
        ])
        
        filterButton.addSubview(filterButtonLoader)
        NSLayoutConstraint.activate([
            filterButtonLoader.centerXAnchor.constraint(equalTo: filterButton.centerXAnchor),
            filterButtonLoader.centerYAnchor.constraint(equalTo: filterButton.centerYAnchor)
        ])
        
        NSLayoutConstraint.activate([
            searchFieldContainer.leadingAnchor.constraint(equalTo: topBarContainer.leadingAnchor, constant: sidePadding),
            searchFieldContainer.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -spacing),
            searchFieldContainer.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            searchFieldContainer.heightAnchor.constraint(equalToConstant: elementHeight)
        ])
        
        NSLayoutConstraint.activate([
            searchIcon.leadingAnchor.constraint(equalTo: searchFieldContainer.leadingAnchor, constant: 14),
            searchIcon.centerYAnchor.constraint(equalTo: searchFieldContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 20),
            searchIcon.heightAnchor.constraint(equalToConstant: 20)
        ])

        NSLayoutConstraint.activate([
            searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            searchTextField.trailingAnchor.constraint(equalTo: searchFieldContainer.trailingAnchor, constant: -14),
            searchTextField.topAnchor.constraint(equalTo: searchFieldContainer.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor)
        ])

        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)

        filterButton.addDivoPressState(.pill)
        closeButton.addDivoPressState(.pill)

        filterButton.addTarget(self, action: #selector(filterTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    }
    
    private func setupResultsContainer() {
        let sidePadding: CGFloat = DivoDesignTokens.Spacing.m
        
        view.addSubview(resultsContainer)
        resultsContainer.addSubview(resultsTableView)
        
        resultsTableView.delegate = self
        resultsTableView.dataSource = self
        resultsTableView.register(EventSearchCell.self, forCellReuseIdentifier: "EventCell")
        
        resultsContainer.addSubview(autocompleteLoader)
        
        NSLayoutConstraint.activate([
            autocompleteLoader.centerXAnchor.constraint(equalTo: resultsContainer.centerXAnchor),
            autocompleteLoader.centerYAnchor.constraint(equalTo: resultsContainer.centerYAnchor)
        ])
        
        NSLayoutConstraint.activate([
            resultsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sidePadding),
            resultsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sidePadding),
            resultsContainer.topAnchor.constraint(equalTo: resultFilterStackView.bottomAnchor, constant: 12)
        ])
        
        resultsContainerHeightConstraint = resultsContainer.heightAnchor.constraint(equalToConstant: 0)
        resultsContainerHeightConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            resultsTableView.topAnchor.constraint(equalTo: resultsContainer.topAnchor, constant: DivoDesignTokens.Spacing.s),
            resultsTableView.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor),
            resultsTableView.trailingAnchor.constraint(equalTo: resultsContainer.trailingAnchor),
            resultsTableView.bottomAnchor.constraint(equalTo: resultsContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.s)
        ])
    }
    
    private func setupGridContainer() {
        let sidePadding: CGFloat = 16.0
        
        view.addSubview(gridCenterLoader)
        
        resultFilterStackView.addArrangedSubview(resultsCountLabel)
        resultFilterStackView.addArrangedSubview(stackSpacer)
        resultFilterStackView.addArrangedSubview(activeFiltersContainer)
        
        activeFiltersContainer.addSubview(activeFiltersLabel)
        activeFiltersContainer.addSubview(activeFiltersClearButton)
        activeFiltersClearButton.addTarget(self, action: #selector(filtersClearTapped), for: .touchUpInside)
        
        view.addSubview(gridCollectionView)
        view.addSubview(bottomBlurOverlay)
        
        view.addSubview(resultFilterStackView)

        NSLayoutConstraint.activate([
            gridCenterLoader.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gridCenterLoader.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        NSLayoutConstraint.activate([
            resultFilterStackView.topAnchor.constraint(equalTo: topBarContainer.bottomAnchor, constant: 10),
            resultFilterStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sidePadding),
            resultFilterStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sidePadding)
        ])
        
        NSLayoutConstraint.activate([
            activeFiltersLabel.leadingAnchor.constraint(equalTo: activeFiltersContainer.leadingAnchor, constant: 12),
            activeFiltersLabel.centerYAnchor.constraint(equalTo: activeFiltersContainer.centerYAnchor),

            activeFiltersClearButton.leadingAnchor.constraint(equalTo: activeFiltersLabel.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            activeFiltersClearButton.trailingAnchor.constraint(equalTo: activeFiltersContainer.trailingAnchor, constant: -12),
            activeFiltersClearButton.centerYAnchor.constraint(equalTo: activeFiltersContainer.centerYAnchor),
            activeFiltersClearButton.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.m),
            activeFiltersClearButton.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.m),

            activeFiltersContainer.heightAnchor.constraint(equalToConstant: 36),
        ])
        
        gridTopToFilterStackConstraint = gridCollectionView.topAnchor.constraint(equalTo: resultFilterStackView.bottomAnchor, constant: 12)
        gridTopToFilterStackConstraint?.isActive = true

        NSLayoutConstraint.activate([
            gridCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sidePadding),
            gridCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sidePadding),
            gridCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomBlurOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBlurOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBlurOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBlurOverlay.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        gridCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        
        gridCollectionView.delegate = self
        gridCollectionView.dataSource = self
        gridCollectionView.register(EventCollectionViewCell.self, forCellWithReuseIdentifier: "EventCell") // Наша ячейка эвента
        gridCollectionView.register(SearchResultSkeletonCell.self, forCellWithReuseIdentifier: SearchResultSkeletonCell.reuseIdentifier)

        view.addSubview(filterSkeletonLeft)
        view.addSubview(filterSkeletonRight)

        NSLayoutConstraint.activate([
            filterSkeletonRight.topAnchor.constraint(equalTo: topBarContainer.bottomAnchor, constant: 10),
            filterSkeletonRight.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sidePadding),
            filterSkeletonRight.widthAnchor.constraint(equalToConstant: 104),
            filterSkeletonRight.heightAnchor.constraint(equalToConstant: 36),

            filterSkeletonLeft.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sidePadding),
            filterSkeletonLeft.centerYAnchor.constraint(equalTo: filterSkeletonRight.centerYAnchor),
            filterSkeletonLeft.widthAnchor.constraint(equalToConstant: 135),
            filterSkeletonLeft.heightAnchor.constraint(equalToConstant: 19),
        ])

        gridTopToSkeletonConstraint = gridCollectionView.topAnchor.constraint(equalTo: filterSkeletonRight.bottomAnchor, constant: 12)
    }
    
    private func setupEmptyStateContainer() {
        view.addSubview(emptyStateContainer)
        emptyStateContainer.addSubview(emptyStateIconContainer)
        emptyStateIconContainer.addSubview(emptyStateIcon)
        emptyStateContainer.addSubview(emptyStateTitle)
        emptyStateContainer.addSubview(emptyStateSubtitle)
        emptyStateContainer.addSubview(emptyStateResetButton)
        emptyStateResetButton.addTarget(self, action: #selector(emptyStateResetTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            emptyStateContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            emptyStateContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.xl),
            emptyStateContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.xl),

            emptyStateIconContainer.centerXAnchor.constraint(equalTo: emptyStateContainer.centerXAnchor),
            emptyStateIconContainer.topAnchor.constraint(equalTo: emptyStateContainer.topAnchor),
            emptyStateIconContainer.widthAnchor.constraint(equalToConstant: 68),
            emptyStateIconContainer.heightAnchor.constraint(equalToConstant: 68),

            emptyStateIcon.centerXAnchor.constraint(equalTo: emptyStateIconContainer.centerXAnchor),
            emptyStateIcon.centerYAnchor.constraint(equalTo: emptyStateIconContainer.centerYAnchor),
            emptyStateIcon.widthAnchor.constraint(equalToConstant: 28),
            emptyStateIcon.heightAnchor.constraint(equalToConstant: 28),

            emptyStateTitle.topAnchor.constraint(equalTo: emptyStateIconContainer.bottomAnchor, constant: 24),
            emptyStateTitle.leadingAnchor.constraint(equalTo: emptyStateContainer.leadingAnchor),
            emptyStateTitle.trailingAnchor.constraint(equalTo: emptyStateContainer.trailingAnchor),

            emptyStateSubtitle.topAnchor.constraint(equalTo: emptyStateTitle.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            emptyStateSubtitle.leadingAnchor.constraint(equalTo: emptyStateContainer.leadingAnchor),
            emptyStateSubtitle.trailingAnchor.constraint(equalTo: emptyStateContainer.trailingAnchor),

            emptyStateResetButton.topAnchor.constraint(equalTo: emptyStateSubtitle.bottomAnchor, constant: 20),
            emptyStateResetButton.centerXAnchor.constraint(equalTo: emptyStateContainer.centerXAnchor),
            emptyStateResetButton.heightAnchor.constraint(equalToConstant: 40),
            emptyStateResetButton.bottomAnchor.constraint(equalTo: emptyStateContainer.bottomAnchor)
        ])
    }

    @objc private func emptyStateResetTapped() {
        onFiltersClearTapped?()
    }

    private func updateResultFilterStackVisibility() {
        let shouldHide = resultsCountLabel.isHidden && activeFiltersContainer.isHidden
        resultFilterStackView.isHidden = shouldHide
        stackSpacer.isHidden = shouldHide
    }
    
    // MARK: - Internal
    
    func updateActiveFiltersCount(_ count: Int) {
        activeFiltersCount = count
        if count > 0 {
            let baseString = DivoStrings.filterBy + " "
            let numberString = "\(count)"
            
            let attrString = NSMutableAttributedString(string: baseString + numberString)
            let baseRange = NSRange(location: 0, length: baseString.count)
            let numberRange = NSRange(location: baseString.count, length: numberString.count)
            
            attrString.addAttribute(.font, value: Font.medium(12), range: baseRange)
            attrString.addAttribute(.foregroundColor, value: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6), range: baseRange)
            
            attrString.addAttribute(.font, value: Font.medium(12), range: numberRange)
            attrString.addAttribute(.foregroundColor, value: DivoColorPalette.primaryText, range: numberRange)
            
            activeFiltersLabel.attributedText = attrString
            
            if activeFiltersContainer.isHidden {
                activeFiltersContainer.alpha = 0
                activeFiltersContainer.isHidden = false
                UIView.animate(withDuration: 0.3) {
                    self.activeFiltersContainer.alpha = 1
                }
            }
        } else {
            activeFiltersContainer.layer.removeAllAnimations()
            activeFiltersContainer.alpha = 1
            activeFiltersContainer.isHidden = true
        }
        emptyStateResetButton.isHidden = count == 0
        updateResultFilterStackVisibility()
    }
    
    func showFiltersButtonLoading() {
        filterButton.isEnabled = false
        filterButton.setImage(nil, for: .normal)
        filterButtonLoader.isHidden = false
        filterButtonLoader.startAnimating()
    }

    func hideFiltersButtonLoading() {
        filterButton.isEnabled = true
        filterButton.setImage(DivoImage.searchFilterIcon, for: .normal)
        filterButtonLoader.stopAnimating()
        filterButtonLoader.isHidden = true
    }
    
    func showAutocompleteLoading() {
        currentAutocompleteResults = []
        resultsTableView.reloadData()
        autocompleteLoader.startAnimating()

        let wasHidden = resultsContainer.isHidden
        resultsContainerHeightConstraint?.constant = 64
        resultsContainer.isHidden = false

        if wasHidden {
            view.layoutIfNeeded()
        } else {
            UIView.animate(withDuration: 0.2) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    func hideAutocompleteLoading() {
        loaderDelayTimer?.invalidate()
        autocompleteLoader.stopAnimating()
        resultsContainer.isHidden = true
        resultsContainerHeightConstraint?.constant = 0
        resultsContainer.layer.removeAllAnimations()
        view.layoutIfNeeded()
    }
    
    func showGridLoading(isFirstPage: Bool) {
        self.mode = .grid
        self.searchTimer?.invalidate()
        self.loaderDelayTimer?.invalidate()
        self.currentTask?.cancel()

        self.currentAutocompleteResults = []
        self.resultsTableView.reloadData()
        self.resultsContainer.isHidden = true
        self.resultsContainerHeightConstraint?.constant = 0
        self.autocompleteLoader.stopAnimating()

        if isFirstPage {
            gridState = .loading
            paginationState = .idle
            gridCenterLoader.stopAnimating()
            emptyStateContainer.isHidden = true
            hideSnackbar(animated: false)

            filterSkeletonLeft.isHidden = false
            filterSkeletonRight.isHidden = false
            filterSkeletonLeft.addShimmerOverlay()
            filterSkeletonRight.addShimmerOverlay()
            resultFilterStackView.isHidden = true

            gridTopToFilterStackConstraint?.isActive = false
            gridTopToSkeletonConstraint?.isActive = true

            gridCollectionView.isHidden = false
            bottomBlurOverlay.isHidden = true
            resultsCountLabel.isHidden = true

            gridCollectionView.reloadData()
        }
    }

    func showGridError() {
        gridState = .error
        gridCenterLoader.stopAnimating()
        emptyStateContainer.isHidden = true

        filterSkeletonLeft.removeShimmerOverlay()
        filterSkeletonRight.removeShimmerOverlay()
        filterSkeletonLeft.isHidden = false
        filterSkeletonRight.isHidden = false

        gridTopToFilterStackConstraint?.isActive = false
        gridTopToSkeletonConstraint?.isActive = true

        gridCollectionView.isHidden = false
        bottomBlurOverlay.isHidden = true

        gridCollectionView.reloadData()
    }

    func showPaginationLoading() {
        guard gridState == .results else { return }
        let wasIdle = paginationState == .idle

        if wasIdle {
            let start = currentGridResults.count
            let indexPaths = [IndexPath(item: start, section: 0), IndexPath(item: start + 1, section: 0)]
            gridCollectionView.performBatchUpdates {
                self.paginationState = .loading
                self.gridCollectionView.insertItems(at: indexPaths)
            }
        } else {
            paginationState = .loading
            let start = currentGridResults.count
            for i in 0..<2 {
                if let cell = gridCollectionView.cellForItem(at: IndexPath(item: start + i, section: 0)) as? SearchResultSkeletonCell {
                    cell.setShimmering(true)
                }
            }
        }
    }

    func showPaginationError() {
        guard gridState == .results else { return }
        paginationState = .error
        let start = currentGridResults.count
        for i in 0..<2 {
            if let cell = gridCollectionView.cellForItem(at: IndexPath(item: start + i, section: 0)) as? SearchResultSkeletonCell {
                cell.setShimmering(false)
            }
        }
    }
    
    func updateAutocomplete(results: [EventItem]) {
        guard mode == .autocomplete else { return }
        
        loaderDelayTimer?.invalidate()
        autocompleteLoader.stopAnimating()
        
        currentAutocompleteResults = results
        resultsTableView.reloadData()
        
        if results.isEmpty {
            resultsContainer.isHidden = true
            resultsContainerHeightConstraint?.constant = 0
            view.layoutIfNeeded()
            let hasQuery = !(searchTextField.text ?? "").isEmpty
            emptyStateContainer.isHidden = !hasQuery
        } else {
            emptyStateContainer.isHidden = true
            let wasHidden = resultsContainer.isHidden
            let maxVisibleRows = 5
            let visibleRows = min(results.count, maxVisibleRows)
            let height = CGFloat(visibleRows) * 64 + 16
            resultsContainerHeightConstraint?.constant = height
            resultsContainer.isHidden = false

            if wasHidden {
                view.layoutIfNeeded()
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
    
    func updateGrid(results: [EventData], totalCount: Int, isFirstPage: Bool, query: String) {
        guard mode == .grid else { return }

        gridCenterLoader.stopAnimating()

        if isFirstPage {
            currentGridResults = results

            filterSkeletonLeft.removeShimmerOverlay()
            filterSkeletonRight.removeShimmerOverlay()
            filterSkeletonLeft.isHidden = true
            filterSkeletonRight.isHidden = true

            gridTopToSkeletonConstraint?.isActive = false
            gridTopToFilterStackConstraint?.isActive = true

            if results.isEmpty {
                gridState = .empty
                emptyStateContainer.isHidden = false
                gridCollectionView.isHidden = true
                bottomBlurOverlay.isHidden = true
                resultsCountLabel.isHidden = true
            } else {
                gridState = .results
                emptyStateContainer.isHidden = true
                gridCollectionView.isHidden = false
                bottomBlurOverlay.isHidden = false
                resultsCountLabel.isHidden = false

                resultsCountLabel.text = query.isEmpty ? DivoStrings.feedSearchCountNoQuery(totalCount) : DivoStrings.feedSearchCount(totalCount, query)
            }

            gridCollectionView.reloadData()
            gridCollectionView.setContentOffset(.zero, animated: false)
            updateResultFilterStackVisibility()
        } else {
            let hadPagination = paginationState != .idle
            let start = currentGridResults.count
            let insertPaths = (start..<(start + results.count)).map { IndexPath(item: $0, section: 0) }

            if hadPagination {
                let skeletonPaths = [IndexPath(item: start, section: 0),
                                     IndexPath(item: start + 1, section: 0)]
                gridCollectionView.performBatchUpdates {
                    self.paginationState = .idle
                    self.currentGridResults.append(contentsOf: results)
                    self.gridCollectionView.deleteItems(at: skeletonPaths)
                    self.gridCollectionView.insertItems(at: insertPaths)
                }
            } else {
                gridCollectionView.performBatchUpdates {
                    self.currentGridResults.append(contentsOf: results)
                    self.gridCollectionView.insertItems(at: insertPaths)
                }
            }
        }
    }
    
    // MARK: @objc
    
    @objc private func searchTextChanged() {
        let text = searchTextField.text ?? ""

        searchTimer?.invalidate()
        loaderDelayTimer?.invalidate()
        currentTask?.cancel()
        cancelAutocomplete?()

        gridState = .idle
        paginationState = .idle
        hideSnackbar(animated: true)
        resultsCountLabel.isHidden = true
        gridCollectionView.isHidden = true
        bottomBlurOverlay.isHidden = true
        emptyStateContainer.isHidden = true
        filterSkeletonLeft.removeShimmerOverlay()
        filterSkeletonRight.removeShimmerOverlay()
        filterSkeletonLeft.isHidden = true
        filterSkeletonRight.isHidden = true
        gridTopToSkeletonConstraint?.isActive = false
        gridTopToFilterStackConstraint?.isActive = true
        updateResultFilterStackVisibility()

        if text.isEmpty {
            mode = .autocomplete
            updateAutocomplete(results: [])
            onSearchCleared?()
            return
        }
        
        mode = .autocomplete
        
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self else { return }
            
            self.currentTask = Task { @MainActor in
                self.requestAutocomplete?(text)
            }
            
            self.loaderDelayTimer?.invalidate()
            self.loaderDelayTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                self?.showAutocompleteLoading()
            }
        }
    }
    
    @objc private func closeTapped() {
        searchTextField.resignFirstResponder()
        onClosePressed?()
    }
    
    @objc private func filterTapped() {
        onFilterPressed?()
    }

    @objc private func filtersClearTapped() {
        onFiltersClearTapped?()
    }

    @objc private func dismissKeyboardTapped() {
        searchTextField.resignFirstResponder()
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

        currentKeyboardHeight = keyboardFrame.height
        snackbar.updateBottomInset(snackbarBottomInset)
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        currentKeyboardHeight = 0
        snackbar.updateBottomInset(snackbarBottomInset)
    }

    private var snackbarBottomInset: CGFloat {
        if currentKeyboardHeight > 0 {
            return currentKeyboardHeight - view.safeAreaInsets.bottom + 16
        } else {
            return 16
        }
    }

    // MARK: - Grid State Helpers

    func gridItem(forEventId eventId: Int) -> EventData? {
        guard let idx = currentGridResults.firstIndex(where: { $0.id == eventId }) else { return nil }
        return currentGridResults[idx]
    }

    func applyGridApplyState(eventId: Int, isApplied: Bool) {
        guard let idx = currentGridResults.firstIndex(where: { $0.id == eventId }) else { return }
        currentGridResults[idx].isApplied = isApplied
        if let cell = gridCollectionView.cellForItem(at: IndexPath(item: idx, section: 0)) as? EventCollectionViewCell {
            cell.setApplyButtonLoading(false, isApplied: isApplied)
        }
    }

    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: snackbarBottomInset,
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

extension EventsSearchNode: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        searchTimer?.invalidate()
        currentTask?.cancel()
        
        let query = textField.text ?? ""
        guard !query.isEmpty else { return true }
        guard emptyStateContainer.isHidden else { return true }
        
        mode = .grid
        
        resultsContainer.isHidden = true
        resultsContainerHeightConstraint?.constant = 0
        
        showGridLoading(isFirstPage: true)
        requestGridSearch?(query)
        
        return true
    }
}

extension EventsSearchNode: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentAutocompleteResults.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64.0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "EventCell", for: indexPath) as? EventSearchCell else {
            return UITableViewCell()
        }
        let item = currentAutocompleteResults[indexPath.row]
        cell.configure(with: item)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        searchTextField.resignFirstResponder()
        // let item = currentAutocompleteResults[indexPath.row]
        // Переход на детальную страницу
        // ...
    }
}

extension EventsSearchNode: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch gridState {
        case .loading, .error:
            return skeletonCount
        case .results:
            return currentGridResults.count + (paginationState != .idle ? 2 : 0)
        case .idle, .empty:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch gridState {
        case .loading, .error:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SearchResultSkeletonCell.reuseIdentifier, for: indexPath) as! SearchResultSkeletonCell
            cell.setShimmering(gridState == .loading)
            return cell
        case .results:
            if indexPath.item >= currentGridResults.count {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SearchResultSkeletonCell.reuseIdentifier, for: indexPath) as! SearchResultSkeletonCell
                cell.setShimmering(paginationState == .loading)
                return cell
            }
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EventCell", for: indexPath) as? EventCollectionViewCell else {
                return UICollectionViewCell()
            }
            let item = currentGridResults[indexPath.item]
            cell.configure(with: item, context: context)
            
            cell.onApply = { [weak self, weak cell] in
                guard let self = self, let cell = cell else { return }
                self.onGridApplyTapped?(item.id, cell)
            }
            return cell
        default:
            return UICollectionViewCell()
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let gap: CGFloat = 10
        let width = (collectionView.bounds.width - gap) / 2
        return CGSize(width: width, height: floor(width * 1.35)) // Используем ту же пропорцию, что и в главном списке
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard gridState == .results else { return }
        guard indexPath.item < currentGridResults.count else { return }
        let threshold = currentGridResults.count - 8
        if indexPath.item >= threshold && threshold > 0 {
            loadMoreGridResults?()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard gridState == .results, indexPath.item < currentGridResults.count else { return }
        let item = currentGridResults[indexPath.item]
        onEventTapped?(item)
    }
}
