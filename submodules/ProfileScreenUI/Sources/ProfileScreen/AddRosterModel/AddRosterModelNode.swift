//
//  AddRosterModelNode.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 01.06.2026.
//

import UIKit
import AsyncDisplayKit
import Display
import DivoUIKit
import DivoCore

final class AddRosterModelNode: ASDisplayNode {
    
    // MARK: - State Properties
    var state: AddRosterScreenState = .initial {
        didSet {
            if oldValue != state {
                applyState()
            }
        }
    }
    
    private var users: [RosterSearchUser] = []

    // MARK: - Callbacks
    var onSearchTextChanged: ((String) -> Void)?
    var onLoadMore: (() -> Void)?
    var onUserSelected: ((RosterSearchUser) -> Void)?
    var onCloseTapped: (() -> Void)?
    var onRetry: (() -> Void)?

    // MARK: - UI Elements
    private let navigationBar = DivoNavigationBar()

    private let searchFieldContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
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
    
    let searchTextField: UITextField = {
        let field = UITextField()
        field.font = Font.regular(14)
        field.textColor = DivoColorPalette.primaryText
        field.tintColor = DivoColorPalette.accent
        field.placeholder = DivoStrings.feedSearchPlaceholder
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    private let searchFadeOverlay: UIView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        if let gradient = view.layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.cgColor,
                DivoColorPalette.screenBackground.withAlphaComponent(0).cgColor,
            ]
            gradient.locations = [0, 0.45]
        }
        return view
    }()

    private let faceScanButton: UIButton = {
        let button = UIButton(type: .custom)
        button.adjustsImageWhenHighlighted = false
        button.backgroundColor = DivoColorPalette.accent
        button.layer.cornerRadius = 18
        let image = DivoImage.searchFaceScan
        button.setImage(image, for: .normal)
        button.tintColor = DivoColorPalette.primaryTextOnDark
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - ScrollView & StackView (FilterOptionsController Style)
    
    private let resultsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.clipsToBounds = true
        view.layer.applyDivoShadow(radius: DivoDesignTokens.Shadow.radiusLarge)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let autocompleteLoader: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .medium)
        loader.color = DivoColorPalette.accent
        loader.hidesWhenStopped = true
        loader.translatesAutoresizingMaskIntoConstraints = false
        return loader
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 20, right: 0)
        scrollView.scrollIndicatorInsets = scrollView.contentInset
        return scrollView
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.backgroundColor = .clear
        return stackView
    }()

    // Белая карточка-подложка под стэк (автоматически тянется по высоте)
    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Состояние "Начните вводить текст"
    private let initialPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(26)
        label.textColor = DivoColorPalette.primaryText
        label.text = DivoStrings.addModelInitialState.uppercased()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Состояние "Результатов нет"
    private let emptyContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let emptyIconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.sheet
        view.layer.applyDivoShadow(opacity: 0.05)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emptyIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "magnifyingglass")
        imageView.tintColor = DivoColorPalette.systemLabelTertiary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let emptyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(26)
        label.textColor = DivoColorPalette.primaryText
        label.text = DivoStrings.addModelSearchNoFoundTitle.uppercased()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emptySubTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        label.text = DivoStrings.addModelSearchNoFoundSubtitle
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    // Рыжий лоадер для пагинации
    private let footerSpinner: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .medium)
        loader.color = DivoColorPalette.accent
        loader.hidesWhenStopped = true
        return loader
    }()

    private let footerSpinnerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 60).isActive = true
        return view
    }()

    private let errorPlaceholderView: ProfileTabErrorView = {
        let view = ProfileTabErrorView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    
    // MARK: - Init
    
    override init() {
        super.init()
        
        navigationBar.makeNavigationBar(
            title: DivoStrings.addModelTitle,
            font: Font.medium(16),
            backButtonConfiguration: .circle(DivoImage.searchCloseIcon),
            onBackTapped: { [weak self] in self?.onCloseTapped?() }
        )
    }

    override func didLoad() {
        super.didLoad()
        self.backgroundColor = DivoColorPalette.screenBackground
        setupLayout()
        applyState()
    }
    
    
    // MARK: - Private

    private func setupLayout() {
        view.addSubview(navigationBar)
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DivoDesignTokens.Spacing.m),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        view.addSubview(searchFieldContainer)
        searchFieldContainer.addSubview(searchIcon)
        searchFieldContainer.addSubview(searchTextField)
        searchFieldContainer.addSubview(faceScanButton)
        
        // Настройка ScrollView & StackView
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.insertSubview(backgroundView, belowSubview: stackView)
        
        view.addSubview(initialPlaceholderLabel)
        
        view.addSubview(autocompleteLoader)
        view.addSubview(errorPlaceholderView)
        
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChangedHandler), for: .editingChanged)
        scrollView.delegate = self
        
        // Оборачиваем footerSpinner в контейнер
        footerSpinner.center = CGPoint(x: (UIScreen.main.bounds.width - DivoDesignTokens.Spacing.xl) / 2, y: 30)
        footerSpinnerContainer.addSubview(footerSpinner)
        
        faceScanButton.addDivoPressState(.accentInline)
        faceScanButton.addTarget(self, action: #selector(faceScanTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            searchFieldContainer.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            searchFieldContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            searchFieldContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            searchFieldContainer.heightAnchor.constraint(equalToConstant: 40),

            searchIcon.leadingAnchor.constraint(equalTo: searchFieldContainer.leadingAnchor, constant: 14),
            searchIcon.centerYAnchor.constraint(equalTo: searchFieldContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 20),
            searchIcon.heightAnchor.constraint(equalToConstant: 20),

            searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            searchTextField.trailingAnchor.constraint(equalTo: faceScanButton.leadingAnchor, constant: -DivoDesignTokens.Spacing.s),
            searchTextField.topAnchor.constraint(equalTo: searchFieldContainer.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),

            faceScanButton.trailingAnchor.constraint(equalTo: searchFieldContainer.trailingAnchor, constant: -2),
            faceScanButton.centerYAnchor.constraint(equalTo: searchFieldContainer.centerYAnchor),
            faceScanButton.widthAnchor.constraint(equalToConstant: 38),
            faceScanButton.heightAnchor.constraint(equalToConstant: 38),

            initialPlaceholderLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            initialPlaceholderLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),
            initialPlaceholderLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            initialPlaceholderLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            errorPlaceholderView.topAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            errorPlaceholderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorPlaceholderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorPlaceholderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        view.addSubview(emptyContainer)
        emptyContainer.addSubview(emptyIconContainer)
        emptyIconContainer.addSubview(emptyIcon)
        emptyContainer.addSubview(emptyTitleLabel)
        emptyContainer.addSubview(emptySubTitleLabel)
        
        NSLayoutConstraint.activate([
            emptyContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            emptyContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.xl),
            emptyContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.xl),
            
            emptyIconContainer.centerXAnchor.constraint(equalTo: emptyContainer.centerXAnchor),
            emptyIconContainer.topAnchor.constraint(equalTo: emptyContainer.topAnchor),
            emptyIconContainer.widthAnchor.constraint(equalToConstant: 68),
            emptyIconContainer.heightAnchor.constraint(equalToConstant: 68),
            
            emptyIcon.centerXAnchor.constraint(equalTo: emptyIconContainer.centerXAnchor),
            emptyIcon.centerYAnchor.constraint(equalTo: emptyIconContainer.centerYAnchor),
            emptyIcon.widthAnchor.constraint(equalToConstant: 28),
            emptyIcon.heightAnchor.constraint(equalToConstant: 28),
            
            emptyTitleLabel.topAnchor.constraint(equalTo: emptyIconContainer.bottomAnchor, constant: 24),
            emptyTitleLabel.leadingAnchor.constraint(equalTo: emptyContainer.leadingAnchor),
            emptyTitleLabel.trailingAnchor.constraint(equalTo: emptyContainer.trailingAnchor),
            
            emptySubTitleLabel.topAnchor.constraint(equalTo: emptyTitleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            emptySubTitleLabel.leadingAnchor.constraint(equalTo: emptyContainer.leadingAnchor),
            emptySubTitleLabel.trailingAnchor.constraint(equalTo: emptyContainer.trailingAnchor),
            emptySubTitleLabel.bottomAnchor.constraint(equalTo: emptyContainer.bottomAnchor)
        ])
        
        // Позиционирование ScrollView, StackView и фоновой подложки (FilterOptionsController Style)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.bottomAnchor),
            
            backgroundView.topAnchor.constraint(equalTo: stackView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor)
        ])
        
        view.addSubview(resultsContainer)
        resultsContainer.addSubview(autocompleteLoader)
        
        NSLayoutConstraint.activate([
            autocompleteLoader.centerXAnchor.constraint(equalTo: resultsContainer.centerXAnchor),
            autocompleteLoader.centerYAnchor.constraint(equalTo: resultsContainer.centerYAnchor)
        ])
        
        // Позиционирование белой карточки-контейнера без привязки к низу экрана
        NSLayoutConstraint.activate([
            resultsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            resultsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            resultsContainer.topAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor, constant: 12),
            resultsContainer.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        view.addSubview(searchFadeOverlay)
        NSLayoutConstraint.activate([
            searchFadeOverlay.topAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),
            searchFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchFadeOverlay.heightAnchor.constraint(equalToConstant: 60),
        ])
    }
    
    private func applyState() {
        switch state {
        case .initial:
            resultsContainer.isHidden = true
            scrollView.isHidden = true
            autocompleteLoader.isHidden = true
            autocompleteLoader.stopAnimating()
            errorPlaceholderView.isHidden = true
            emptyContainer.isHidden = true
            initialPlaceholderLabel.isHidden = false
            
        case .loading:
            resultsContainer.isHidden = false
            scrollView.isHidden = true
            errorPlaceholderView.isHidden = true
            emptyContainer.isHidden = true
            initialPlaceholderLabel.isHidden = true
            
            autocompleteLoader.isHidden = false
            autocompleteLoader.startAnimating()
            
        case .success(let users):
            resultsContainer.isHidden = true
            autocompleteLoader.isHidden = true
            autocompleteLoader.stopAnimating()
            errorPlaceholderView.isHidden = true
            emptyContainer.isHidden = true
            initialPlaceholderLabel.isHidden = true
            
            // Наполнение stackView вьюшками моделей
            self.users = users
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            for (index, user) in users.enumerated() {
                let cell = RosterUserView()
                cell.configure(with: user, searchText: searchTextField.text ?? "")
                
                // Скрываем разделитель у последней ячейки
                let isLast = index == users.count - 1
                cell.setupSeparator(isHidden: isLast)
                
                // Добавляем жест нажатия
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(userCellTapped(_:)))
                cell.addGestureRecognizer(tapGesture)
                cell.tag = index
                cell.addPressState(alpha: DivoDesignTokens.PressState.alphaOnClear)
                
                stackView.addArrangedSubview(cell)
            }
            
            scrollView.isHidden = false
            
        case .empty:
            resultsContainer.isHidden = true
            scrollView.isHidden = true
            autocompleteLoader.isHidden = true
            autocompleteLoader.stopAnimating()
            errorPlaceholderView.isHidden = true
            initialPlaceholderLabel.isHidden = true
            
            emptyTitleLabel.text = DivoStrings.noSearchResults.uppercased()
            emptySubTitleLabel.text = DivoStrings.noSearchResultsSubtitle
            emptyContainer.isHidden = false
            
        case .failed(let networkError):
            resultsContainer.isHidden = true
            scrollView.isHidden = true
            autocompleteLoader.isHidden = true
            autocompleteLoader.stopAnimating()
            emptyContainer.isHidden = true
            initialPlaceholderLabel.isHidden = true
            
            errorPlaceholderView.isHidden = false
            errorPlaceholderView.configure(tab: .events, networkError: networkError) { [weak self] in
                self?.onRetry?()
            }
        }
    }

    
    // MARK: - Handlers
    
    @objc private func faceScanTapped() {
        view.endEditing(true)
        searchTextField.resignFirstResponder()
    }

    @objc private func searchTextChangedHandler() {
        onSearchTextChanged?(searchTextField.text ?? "")
    }

    @objc private func userCellTapped(_ gesture: UITapGestureRecognizer) {
        view.endEditing(true)
        guard let cell = gesture.view, cell.tag < users.count else { return }
        let selectedUser = users[cell.tag]
        onUserSelected?(selectedUser)
    }
}


// MARK: - UIScrollViewDelegate

extension AddRosterModelNode: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === self.scrollView else { return }
        
        // КРИТИЧЕСКИЙ ФИКС: разрешаем пагинацию только в состоянии успеха и только если список уже не пуст
        guard case .success = state, !users.isEmpty else { return }
        
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        // Предотвращаем ложный триггер при пустом скролле на этапе первой верстки
        guard contentHeight > 0 else { return }
        
        // Триггерим пагинацию при достижении конца списка с запасом в 200pt
        if offsetY > contentHeight - height - 200 {
            onLoadMore?()
        }
    }
}


// MARK: - UITextFieldDelegate

extension AddRosterModelNode: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
