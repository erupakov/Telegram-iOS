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
    
    var state: AddRosterScreenState = .initial {
        didSet {
            if oldValue != state {
                applyState()
            }
        }
    }
    
    private var users: [RosterSearchUser] = []

    var onSearchTextChanged: ((String) -> Void)?
    var onUserSelected: ((RosterSearchUser) -> Void)?
    var onCloseTapped: (() -> Void)?
    var onRetry: (() -> Void)?

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
        scrollView.keyboardDismissMode = .onDrag
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

    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

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
        imageView.image = DivoImage.searchFieldIcon
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
        
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        dismissTap.delegate = self
        self.view.addGestureRecognizer(dismissTap)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

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
        
        // Настройка ScrollView & StackView
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.insertSubview(backgroundView, belowSubview: stackView)
        
        view.addSubview(initialPlaceholderLabel)
        
        view.addSubview(errorPlaceholderView)
        
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChangedHandler), for: .editingChanged)

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
            searchTextField.trailingAnchor.constraint(equalTo: searchFieldContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            searchTextField.topAnchor.constraint(equalTo: searchFieldContainer.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),

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

        case .idle:
            resultsContainer.isHidden = true
            scrollView.isHidden = true
            autocompleteLoader.isHidden = true
            autocompleteLoader.stopAnimating()
            errorPlaceholderView.isHidden = true
            emptyContainer.isHidden = true
            initialPlaceholderLabel.isHidden = true
            
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
            
            self.users = users
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            for (index, user) in users.enumerated() {
                let cell = RosterUserView()
                cell.configure(with: user, searchText: searchTextField.text ?? "")
                
                let isLast = index == users.count - 1
                cell.setupSeparator(isHidden: isLast)
                
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
            
            emptyContainer.isHidden = false
            
        case .failed(let networkError):
            resultsContainer.isHidden = true
            scrollView.isHidden = true
            autocompleteLoader.isHidden = true
            autocompleteLoader.stopAnimating()
            emptyContainer.isHidden = true
            initialPlaceholderLabel.isHidden = true
            
            errorPlaceholderView.isHidden = false
            errorPlaceholderView.configure(tab: .models, networkError: networkError) { [weak self] in
                self?.onRetry?()
            }
        }
    }


    // MARK: - Handlers

    @objc private func searchTextChangedHandler() {
        onSearchTextChanged?(searchTextField.text ?? "")
    }

    @objc private func userCellTapped(_ gesture: UITapGestureRecognizer) {
        view.endEditing(true)
        guard let cell = gesture.view, cell.tag < users.count else { return }
        let selectedUser = users[cell.tag]
        onUserSelected?(selectedUser)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        currentKeyboardHeight = frame.height
        snackbar.updateBottomInset(snackbarBottomInset)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        currentKeyboardHeight = 0
        snackbar.updateBottomInset(snackbarBottomInset)
    }

    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()
    private var currentKeyboardHeight: CGFloat = 0

    private var snackbarBottomInset: CGFloat {
        if currentKeyboardHeight > 0 {
            return currentKeyboardHeight - view.safeAreaInsets.bottom + DivoDesignTokens.Spacing.m
        } else {
            return DivoDesignTokens.Spacing.m
        }
    }

    func showSnackbar(message: String, style: SnackbarStyle) {
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: snackbarBottomInset,
            bottomAnchor: view.safeAreaLayoutGuide.bottomAnchor
        )
    }
}


// MARK: - UITextFieldDelegate

extension AddRosterModelNode: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}


// MARK: - UIGestureRecognizerDelegate

extension AddRosterModelNode: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl || touch.view is RosterUserView {
            return false
        }
        return true
    }
}
