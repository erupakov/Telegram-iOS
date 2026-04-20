import UIKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit

struct InteractionUser {
    let id: Int
    let name: String
    let role: String
    let avatarUrl: String?
    let isPremium: Bool
}

enum InteractionListType {
    case likes
    case views
    case saves

    var title: String {
        switch self {
        case .likes: return DivoStrings.likes
        case .views: return DivoStrings.viewed
        case .saves: return DivoStrings.saved
        }
    }
}

final class InteractionListViewController: UIViewController {
    private let listType: InteractionListType
    private var users: [InteractionUser] = []
    private var filteredUsers: [InteractionUser] = []

    var requestData: ((Int, @escaping ([InteractionUser], Bool, Bool) -> Void) -> Void)?
    
    private var currentOffset: Int = 0
    private let limit: Int = 20
    private var isLoadingMore: Bool = false
    private var hasMorePages: Bool = true
    private var isMyProfile: Bool

    var onUserTapped: ((InteractionUser) -> Void)?

    private let errorContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let errorTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        label.text = DivoStrings.serverUnavailable
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
        label.numberOfLines = 2
        return label
    }()
    
    private let emptyContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emptyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(26)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
        label.numberOfLines = 2
        return label
    }()
    
    private let emptySubTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
        label.numberOfLines = 0
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(20)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        return label
    }()

    private let searchFieldContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
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
        field.placeholder = DivoStrings.search
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
        view.isHidden = true
        if let gradient = view.layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.cgColor,
                DivoColorPalette.screenBackground.withAlphaComponent(0).cgColor,
            ]
            gradient.locations = [0, 0.45]
        }
        return view
    }()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .none
        tv.register(InteractionUserCell.self, forCellReuseIdentifier: InteractionUserCell.reuseIdentifier)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isHidden = true
        tv.showsVerticalScrollIndicator = false
        tv.backgroundColor = DivoColorPalette.screenBackground
        tv.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
        return tv
    }()

    private let loadingSpinner = DivoSegmentedSpinner()

    private let footerSpinner: DivoSegmentedSpinner

    init(type: InteractionListType, isMyProfile: Bool) {
        self.isMyProfile = isMyProfile
        self.listType = type

        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 60))
        let spinner = DivoSegmentedSpinner(frame: CGRect(x: 0, y: 0, width: 32, height: 32))

        spinner.center = footerView.center
        spinner.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]

        footerView.addSubview(spinner)
        self.footerSpinner = spinner
        self.footerSpinner.isHidden = true
        tableView.tableFooterView = footerView

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadInitialData()
    }

    private func setupUI() {
        view.backgroundColor = DivoColorPalette.screenBackground
        titleLabel.text = listType.title

        view.addSubview(errorContainer)
        errorContainer.addSubview(errorTitleLabel)

        view.addSubview(emptyContainer)
        emptyContainer.addSubview(emptyTitleLabel)
        emptyContainer.addSubview(emptySubTitleLabel)

        view.addSubview(titleLabel)
        view.addSubview(searchFieldContainer)
        searchFieldContainer.addSubview(searchIcon)
        searchFieldContainer.addSubview(searchTextField)
        view.addSubview(tableView)
        view.addSubview(loadingSpinner)
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.isHidden = true
        view.addSubview(searchFadeOverlay)

        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        tableView.dataSource = self
        tableView.delegate = self

        let elementHeight: CGFloat = 40.0
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            searchFieldContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            searchFieldContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            searchFieldContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            searchFieldContainer.heightAnchor.constraint(equalToConstant: elementHeight),

            searchIcon.leadingAnchor.constraint(equalTo: searchFieldContainer.leadingAnchor, constant: 14),
            searchIcon.centerYAnchor.constraint(equalTo: searchFieldContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 20),
            searchIcon.heightAnchor.constraint(equalToConstant: 20),

            searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            searchTextField.trailingAnchor.constraint(equalTo: searchFieldContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            searchTextField.topAnchor.constraint(equalTo: searchFieldContainer.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),

            searchFadeOverlay.topAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),
            searchFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchFadeOverlay.heightAnchor.constraint(equalToConstant: 60),

            tableView.topAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingSpinner.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            loadingSpinner.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            emptyContainer.topAnchor.constraint(equalTo: view.topAnchor),
            emptyContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyTitleLabel.centerXAnchor.constraint(equalTo: emptyContainer.centerXAnchor),
            emptyTitleLabel.centerYAnchor.constraint(equalTo: emptyContainer.centerYAnchor),
            emptyTitleLabel.leadingAnchor.constraint(equalTo: emptyContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            emptyTitleLabel.trailingAnchor.constraint(equalTo: emptyContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            emptySubTitleLabel.topAnchor.constraint(equalTo: emptyTitleLabel.bottomAnchor, constant: 10),
            emptySubTitleLabel.leadingAnchor.constraint(equalTo: emptyContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            emptySubTitleLabel.trailingAnchor.constraint(equalTo: emptyContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            emptySubTitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: emptyContainer.bottomAnchor),

            errorContainer.topAnchor.constraint(equalTo: view.topAnchor),
            errorContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            errorTitleLabel.centerXAnchor.constraint(equalTo: errorContainer.centerXAnchor),
            errorTitleLabel.centerYAnchor.constraint(equalTo: errorContainer.centerYAnchor),
            errorTitleLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            errorTitleLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])
    }

    private func configure(with isEmptyTable: Bool, emptyTitle: String? = nil, emptySubTitle: String? = nil) {
        if isEmptyTable {
            emptyContainer.isHidden = false
            searchFieldContainer.isHidden = true
            searchFadeOverlay.isHidden = true
            tableView.isHidden = true
            errorContainer.isHidden = true
            
            emptyTitleLabel.text = emptyTitle
            emptySubTitleLabel.text = emptySubTitle
        } else {
            emptyContainer.isHidden = true
            searchFieldContainer.isHidden = false
            searchFadeOverlay.isHidden = false
            tableView.isHidden = false

        }
    }
    
    private func loadInitialData() {
        loadingSpinner.startAnimating()
        loadingSpinner.isHidden = false
        currentOffset = 0
        isLoadingMore = true
        
        requestData?(0) { [weak self] newUsers, hasMore, error in
            guard let self = self, !error else { 
                self?.showSnackbar(
                    message: DivoStrings.failedLoadInteractionList,
                    style: .error
                )
                self?.loadingSpinner.stopAnimating()
                self?.loadingSpinner.isHidden = true
                self?.errorContainer.isHidden = false
                return 
            }
            self.errorContainer.isHidden = true
            self.isLoadingMore = false
            self.hasMorePages = hasMore
            
            self.currentOffset = self.limit
            
            self.users = newUsers
            self.filteredUsers = newUsers
            
            DispatchQueue.main.async {
                self.loadingSpinner.stopAnimating()
                self.loadingSpinner.isHidden = true
                self.updateEmptyState()
                self.tableView.reloadData()
            }
        }
    }
    
    private func loadNextPage() {
        // Проверка searchTextField.text?.isEmpty ?? true здесь защищает от старта пагинации во время поиска, 
        // но не спасает, если поиск начался ПОСЛЕ старта пагинации.
        guard !isLoadingMore, hasMorePages, searchTextField.text?.isEmpty ?? true else { return }
        
        isLoadingMore = true
        footerSpinner.startAnimating()
        footerSpinner.isHidden = false
        
        let startIndex = self.filteredUsers.count
        
        requestData?(currentOffset) { [weak self] newUsers, hasMore, error in
            guard let self = self else { return }
            
            self.currentOffset += self.limit
            self.isLoadingMore = false
            self.hasMorePages = hasMore
            
            // 1. Добавляем новых пользователей в общий массив
            self.users.append(contentsOf: newUsers)
            
            DispatchQueue.main.async {
                self.footerSpinner.stopAnimating()
                self.footerSpinner.isHidden = true
                
                let searchText = self.searchTextField.text ?? ""
                
                // 2. Проверяем, ввел ли пользователь что-то в поиск, пока шел запрос
                if !searchText.isEmpty {
                    // Фильтруем заново с учетом пришедших новых данных
                    self.filteredUsers = self.users.filter { $0.name.lowercased().contains(searchText.lowercased()) }
                    
                    // Так как список был отфильтрован, insertRows делать нельзя (индексы сдвинуты).
                    // Просто обновляем таблицу.
                    self.tableView.reloadData()
                } else {
                    // Поиска нет. Обновляем отображаемый массив всеми данными
                    self.filteredUsers = self.users
                    
                    if !newUsers.isEmpty {
                        // 3. Защита от крэша (Fallback)
                        // Убеждаемся, что таблица действительно содержит то количество строк, которое мы ожидаем
                        let currentRowCount = self.tableView.numberOfRows(inSection: 0)
                        
                        if currentRowCount == startIndex {
                            let indexPaths = (0..<newUsers.count).map {
                                IndexPath(row: startIndex + $0, section: 0)
                            }
                            self.tableView.performBatchUpdates({
                                self.tableView.insertRows(at: indexPaths, with: .fade)
                            }, completion: nil)
                        } else {
                            // Если количество строк не совпадает (например, таблица обновилась по другой причине),
                            // безопасно обновляем всю таблицу без анимации вставки
                            self.tableView.reloadData()
                        }
                    } else {
                        self.hasMorePages = false
                    }
                }
            }
        }
    }

    private func updateEmptyState() {
        if filteredUsers.isEmpty {
            if self.listType == .likes {
                isMyProfile ? 
                configure(with: true, emptyTitle: DivoStrings.noLikesYetMyProfile, emptySubTitle: DivoStrings.noLikesSubtitleMyProfile) :
                configure(with: true, emptyTitle: DivoStrings.noLikesYet, emptySubTitle: DivoStrings.noLikesSubtitle)
            } else if self.listType == .saves {
                isMyProfile ? 
                configure(with: true, emptyTitle: DivoStrings.nothingSavedYetMyProfile, emptySubTitle: DivoStrings.nothingSavedSubtitleMyProfile) :
                configure(with: true, emptyTitle: DivoStrings.nothingSavedYet, emptySubTitle: DivoStrings.nothingSavedSubtitle)
            } else if self.listType == .views {
                isMyProfile ? 
                configure(with: true, emptyTitle: DivoStrings.noProfileViewedYetMyProfile, emptySubTitle: DivoStrings.noProfileViewedSubtitleMyProfile) :
                configure(with: true, emptyTitle: DivoStrings.noProfileViewedYet, emptySubTitle: DivoStrings.noProfileViewedSubtitle)
            }
        } else {
            configure(with: false)
        }
    }

    @objc private func searchTextChanged() {
        let searchText = searchTextField.text ?? ""
        if searchText.isEmpty {
            filteredUsers = users
        } else {
            filteredUsers = users.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        tableView.reloadData()
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

extension InteractionListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredUsers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: InteractionUserCell.reuseIdentifier, for: indexPath) as? InteractionUserCell  else {
            return UITableViewCell()
        }
        cell.configure(with: filteredUsers[indexPath.row])
        return cell
    }
}

extension InteractionListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 68
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = filteredUsers[indexPath.row]
        onUserTapped?(user)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        if offsetY > contentHeight - height - 200 {
            loadNextPage()
        }
    }
}

extension InteractionListViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}


// MARK: - GradientView

private final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
}