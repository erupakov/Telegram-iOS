//
//  ModelsSearchNode.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.04.2026.
//

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import DivoCore
import DivoUIKit

struct SearchUserItem {
    let name: String
    let username: String
    let avatarColor: UIColor
}

final class ModelsSearchNode: ASDisplayNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private let topBarContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let searchFieldContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 20
        view.layer.shadowColor = DivoColorPalette.shadow.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.masksToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let searchIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(bundleImageName: "Components/Search/SearchFieldIcon") ?? UIImage(systemName: "magnifyingglass")
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
        field.placeholder = DivoStrings.feedSearchPlaceholder
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
        
    private let filterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.setImage(UIImage(bundleImageName: "Components/Search/FilterIcon"), for: .normal)
        button.tintColor = .black
        button.layer.shadowColor = DivoColorPalette.shadow.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 12
        button.layer.masksToBounds = false
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
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        let image = UIImage(bundleImageName: "Components/Search/SearchCloseIcon") ?? UIImage(systemName: "xmark")
        button.setImage(image, for: .normal)
        button.tintColor = .black
        button.layer.shadowColor = DivoColorPalette.shadow.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 12
        button.layer.masksToBounds = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let resultsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 24
        view.clipsToBounds = true
        view.layer.shadowColor = DivoColorPalette.shadow.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 16
        view.layer.masksToBounds = false
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let resultsTableView: UITableView = {
        let tableView = UITableView()
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private let faceScanButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.accent
        button.layer.cornerRadius = 26
        let image = UIImage(bundleImageName: "Components/Search/FaceScan") ?? UIImage(systemName: "person.fill.viewfinder")
        button.setImage(image, for: .normal)
        button.tintColor = DivoColorPalette.accentSecondary
        button.layer.shadowColor = DivoColorPalette.shadow.cgColor
        button.layer.shadowOpacity = 0.1
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 12
        button.layer.masksToBounds = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let resultsCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .black
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var gridCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.isHidden = true
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.showsVerticalScrollIndicator = false
        return cv
    }()
    
    private let bottomBlurOverlay: GradientBlurView = {
        let view = GradientBlurView(isTop: false)
        view.isHidden = true
        return view
    }()
    
    private let autocompleteLoader: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .medium)
        loader.color = DivoColorPalette.accentSecondary
        loader.hidesWhenStopped = true
        loader.translatesAutoresizingMaskIntoConstraints = false
        return loader
    }()
    
    private let gridCenterLoader: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .large)
        loader.color = DivoColorPalette.accentSecondary
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
        view.backgroundColor = .white
        view.layer.cornerRadius = 34
        view.layer.shadowColor = DivoColorPalette.shadow.cgColor
        view.layer.shadowOpacity = 0.05
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
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
    
    private let activeFiltersContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 18
        view.layer.shadowColor = DivoColorPalette.shadow.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
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
    
    private let resultFilterStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .fill
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
    
    private var currentResults:[SearchUserItem] = []
    
    private var resultsContainerHeightConstraint: NSLayoutConstraint?
    private var faceScanButtonBottomConstraint: NSLayoutConstraint?
    
    private var currentAutocompleteResults: [SearchUserDTO] = []
    private var currentGridResults: [SearchUserDTO] = []
    
    var onClosePressed: (() -> Void)?
    var onFilterPressed: (() -> Void)?
    var requestAutocomplete: ((String) -> Void)?
    var requestGridSearch: ((String) -> Void)?
    var loadMoreGridResults: (() -> Void)?
    
    private var searchTimer: Timer?
    
    enum SearchMode {
        case idle
        case autocomplete
        case grid
    }

    var mode: SearchMode = .idle
    
    private var currentTask: Task<Void, Never>?
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground
    }
    
    override func didLoad() {
        super.didLoad()
        setupUI()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        searchTextField.becomeFirstResponder()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        searchTimer?.invalidate()
    }
    
    
    // MARK: Private
    
    private func setupUI() {
        setupTopContainer()
        setupGridContainer()
        setupResultsContainer()
        setupEmptyStateContainer()
        setupFaceScanActionButton()
    }
    
    private func setupTopContainer() {
        let safeArea = view.safeAreaLayoutGuide
        let sidePadding: CGFloat = 16.0
        let elementHeight: CGFloat = 40.0
        let spacing: CGFloat = 8.0
        
        view.addSubview(topBarContainer)
        topBarContainer.addSubview(searchFieldContainer)
        searchFieldContainer.addSubview(searchIcon)
        searchFieldContainer.addSubview(searchTextField)
        topBarContainer.addSubview(filterButton)
        topBarContainer.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            topBarContainer.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 8),
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
            searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchTextField.trailingAnchor.constraint(equalTo: searchFieldContainer.trailingAnchor, constant: -6),
            searchTextField.topAnchor.constraint(equalTo: searchFieldContainer.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor)
        ])

        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)

        filterButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        filterButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        closeButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        closeButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        filterButton.addTarget(self, action: #selector(filterTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    }
    
    private func setupResultsContainer() {
        let sidePadding: CGFloat = 16.0
        
        view.addSubview(resultsContainer)
        resultsContainer.addSubview(resultsTableView)
        
        resultsTableView.delegate = self
        resultsTableView.dataSource = self
        resultsTableView.register(SearchUserCell.self, forCellReuseIdentifier: "UserCell")
        
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
            resultsTableView.topAnchor.constraint(equalTo: resultsContainer.topAnchor, constant: 8),
            resultsTableView.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor),
            resultsTableView.trailingAnchor.constraint(equalTo: resultsContainer.trailingAnchor),
            resultsTableView.bottomAnchor.constraint(equalTo: resultsContainer.bottomAnchor, constant: -8)
        ])
        
    }
    
    private func setupGridContainer() {
        let sidePadding: CGFloat = 16.0
        
        view.addSubview(gridCenterLoader)
        
        resultFilterStackView.addArrangedSubview(resultsCountLabel)
        resultFilterStackView.addArrangedSubview(stackSpacer)
        resultFilterStackView.addArrangedSubview(activeFiltersContainer)
        
        view.addSubview(resultFilterStackView)
        activeFiltersContainer.addSubview(activeFiltersLabel)
        
        view.addSubview(gridCollectionView)
        
        view.addSubview(bottomBlurOverlay)
        
        NSLayoutConstraint.activate([
            gridCenterLoader.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gridCenterLoader.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        NSLayoutConstraint.activate([
            resultFilterStackView.topAnchor.constraint(equalTo: topBarContainer.bottomAnchor, constant: 10),
            resultFilterStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sidePadding),
            resultFilterStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sidePadding),
        ])
        
        NSLayoutConstraint.activate([
            activeFiltersLabel.leadingAnchor.constraint(equalTo: activeFiltersContainer.leadingAnchor, constant: 12),
            activeFiltersLabel.trailingAnchor.constraint(equalTo: activeFiltersContainer.trailingAnchor, constant: -12),
            activeFiltersLabel.centerYAnchor.constraint(equalTo: activeFiltersContainer.centerYAnchor),
            
            activeFiltersContainer.heightAnchor.constraint(equalToConstant: 36),
        ])
        
        NSLayoutConstraint.activate([
            gridCollectionView.topAnchor.constraint(equalTo: resultFilterStackView.bottomAnchor, constant: 12),
            gridCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sidePadding),
            gridCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sidePadding),
            gridCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            bottomBlurOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBlurOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBlurOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBlurOverlay.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        gridCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 70, right: 0)
        
        gridCollectionView.delegate = self
        gridCollectionView.dataSource = self
        gridCollectionView.register(SearchResultGridCell.self, forCellWithReuseIdentifier: "GridCell")
    }
    
    private func setupEmptyStateContainer() {
        view.addSubview(emptyStateContainer)
        emptyStateContainer.addSubview(emptyStateIconContainer)
        emptyStateIconContainer.addSubview(emptyStateIcon)
        emptyStateContainer.addSubview(emptyStateTitle)
        emptyStateContainer.addSubview(emptyStateSubtitle)
        
        NSLayoutConstraint.activate([
            emptyStateContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            emptyStateContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
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
            emptyStateTitle.bottomAnchor.constraint(equalTo: emptyStateSubtitle.topAnchor, constant: -8),
            
            emptyStateSubtitle.topAnchor.constraint(equalTo: emptyStateTitle.bottomAnchor, constant: 8),
            emptyStateSubtitle.leadingAnchor.constraint(equalTo: emptyStateContainer.leadingAnchor),
            emptyStateSubtitle.trailingAnchor.constraint(equalTo: emptyStateContainer.trailingAnchor),
            emptyStateSubtitle.bottomAnchor.constraint(equalTo: emptyStateContainer.bottomAnchor)
        ])
    }
    
    private func updateResultFilterStackVisibility() {
        let shouldHide = resultsCountLabel.isHidden && activeFiltersContainer.isHidden
        resultFilterStackView.isHidden = shouldHide
        stackSpacer.isHidden = shouldHide

        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func setupFaceScanActionButton() {
        let safeArea = view.safeAreaLayoutGuide
        
        view.addSubview(faceScanButton)
        
        faceScanButtonBottomConstraint = faceScanButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -16)
        faceScanButtonBottomConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            faceScanButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            faceScanButton.widthAnchor.constraint(equalToConstant: 52),
            faceScanButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }
    
    
    // MARK: - Internal
    
    func updateActiveFiltersCount(_ count: Int) {
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
            if !activeFiltersContainer.isHidden {
                UIView.animate(withDuration: 0.3, animations: {
                    self.activeFiltersContainer.alpha = 0
                }) { _ in
                    self.activeFiltersContainer.isHidden = true
                }
            }
        }
        updateResultFilterStackVisibility()
    }
    
    func setFiltersButtonEnabled(_ isEnabled: Bool) {
        filterButton.isEnabled = isEnabled
        filterButton.alpha = isEnabled ? 1.0 : 0.5
    }

    func showFiltersButtonLoading() {
        filterButton.isEnabled = false
        filterButton.setImage(nil, for: .normal)
        filterButtonLoader.isHidden = false
        filterButtonLoader.startAnimating()
    }

    func hideFiltersButtonLoading() {
        filterButton.isEnabled = true
        filterButton.setImage(UIImage(bundleImageName: "Components/Search/FilterIcon"), for: .normal)
        filterButtonLoader.stopAnimating()
        filterButtonLoader.isHidden = true
    }
    
    func showAutocompleteLoading() {
        currentAutocompleteResults = []
        resultsTableView.reloadData()
        resultsContainer.isHidden = false
        resultsContainerHeightConstraint?.constant = 64
        autocompleteLoader.startAnimating()
        
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    func showGridLoading(isFirstPage: Bool) {
        self.mode = .grid
        self.searchTimer?.invalidate()
        self.currentTask?.cancel()
        
        self.currentAutocompleteResults = []
        self.resultsTableView.reloadData()
        self.resultsContainer.isHidden = true
        self.resultsContainerHeightConstraint?.constant = 0
        self.autocompleteLoader.stopAnimating()
        
        if isFirstPage {
            gridCollectionView.isHidden = true
            bottomBlurOverlay.isHidden = true
            resultsCountLabel.isHidden = true
            emptyStateContainer.isHidden = true
            updateResultFilterStackVisibility()
            
            gridCenterLoader.startAnimating()
        }
    }
    
    func updateAutocomplete(results: [SearchUserDTO]) {
        guard mode == .autocomplete else { return }
        
        autocompleteLoader.stopAnimating()
        
        currentAutocompleteResults = results
        resultsTableView.reloadData()
        
        if results.isEmpty {
            resultsContainer.isHidden = true
            emptyStateContainer.isHidden = false
        } else {
            emptyStateContainer.isHidden = true
            resultsContainer.isHidden = false
            
            let height = CGFloat(results.count) * 64 + 16
            resultsContainerHeightConstraint?.constant = height
        }
        
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    func updateGrid(results: [SearchUserDTO], totalCount: Int, isFirstPage: Bool, query: String) {
        guard mode == .grid else { return }
        
        gridCenterLoader.stopAnimating()
        
        if isFirstPage {
            currentGridResults = results
            
            if results.isEmpty {
                emptyStateContainer.isHidden = false
                gridCollectionView.isHidden = true
                bottomBlurOverlay.isHidden = true
                resultsCountLabel.isHidden = true
            } else {
                emptyStateContainer.isHidden = true
                gridCollectionView.isHidden = false
                bottomBlurOverlay.isHidden = false
                resultsCountLabel.isHidden = false
                
                resultsCountLabel.text = query.isEmpty ? DivoStrings.feedSearchCountNoQuery(totalCount) : DivoStrings.feedSearchCount(totalCount, query)
                gridCollectionView.reloadData()
            }
            
            updateResultFilterStackVisibility()
        } else {
            let start = currentGridResults.count
            let end = start + results.count
            
            currentGridResults.append(contentsOf: results)
            
            let indexPaths = (start..<end).map { IndexPath(item: $0, section: 0) }
            
            gridCollectionView.performBatchUpdates {
                gridCollectionView.insertItems(at: indexPaths)
            }
        }
    }
    
    
    // MARK: @objc
    
    @objc private func buttonPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            sender.alpha = 0.6
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        })
    }
    
    @objc private func buttonReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, animations: {
            sender.alpha = 1.0
            sender.transform = .identity
        })
    }
    
    @objc private func searchTextChanged() {
        let text = searchTextField.text ?? ""
        
        searchTimer?.invalidate()
        currentTask?.cancel()
        
        resultsCountLabel.isHidden = true
        gridCollectionView.isHidden = true
        bottomBlurOverlay.isHidden = true
        emptyStateContainer.isHidden = true
        updateResultFilterStackVisibility()
        
        if text.isEmpty {
            mode = .autocomplete
            updateAutocomplete(results: [])
            return
        }
        
        mode = .autocomplete
        
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self else { return }
            
            self.showAutocompleteLoading()
            
            self.currentTask = Task { @MainActor in
                self.requestAutocomplete?(text)
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
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        UIView.animate(withDuration: 0.3) {
            let safeAreaBottom = self.view.safeAreaInsets.bottom
            self.faceScanButtonBottomConstraint?.constant = -(keyboardFrame.height - safeAreaBottom + 16)
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        UIView.animate(withDuration: 0.3) {
            self.faceScanButtonBottomConstraint?.constant = -16
            self.view.layoutIfNeeded()
        }
    }
    
    private static func flag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
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
            bottomInset: 16,
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

extension ModelsSearchNode: UITextFieldDelegate {
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

extension ModelsSearchNode: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentAutocompleteResults.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64.0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath) as? SearchUserCell else {
            return UITableViewCell()
        }
        let item = currentAutocompleteResults[indexPath.row]
        let query = searchTextField.text ?? ""
        cell.configure(with: item, query: query)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        searchTextField.resignFirstResponder()
    }
}

extension ModelsSearchNode: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return currentGridResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GridCell", for: indexPath) as? SearchResultGridCell else {
            return UICollectionViewCell()
        }
        if let countryName = currentGridResults[indexPath.item].user?.city?.countryName {
            cell.configure(
                with: currentGridResults[indexPath.item],
                county: "\(Self.flag(for: currentGridResults[indexPath.item].user?.city?.countryCode))"+" \(countryName)")
        } else {
            cell.configure(
                with: currentGridResults[indexPath.item],
                county: "\(Self.flag(for: currentGridResults[indexPath.item].user?.city?.countryCode))")
        }
        return cell
    }
        
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 12) / 2
        let height = width * 1.4
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let threshold = currentGridResults.count - 8
        if indexPath.item >= threshold && threshold > 0 {
            loadMoreGridResults?()
        }
    }
}