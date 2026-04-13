import UIKit
import Display
import TelegramCore
import DivoCore

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

    var requestData: ((Int, @escaping ([InteractionUser], Bool) -> Void) -> Void)?
    
    private var currentOffset: Int = 0
    private let limit: Int = 20
    private var isLoadingMore: Bool = false
    private var hasMorePages: Bool = true
    
    private let emptyContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emptyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(26)
        label.textColor = UIColor(hexString: "#000000")
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
        return label
    }()
    
    private let emptySubTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = UIColor(hexString: "#222222")
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(20)
        label.textColor = UIColor(hexString: "#222222")
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        return label
    }()

    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = DivoStrings.search
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.isHidden = true
        return searchBar
    }()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .none
        tv.register(InteractionUserCell.self, forCellReuseIdentifier: InteractionUserCell.reuseIdentifier)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isHidden = true
        tv.showsVerticalScrollIndicator = false
        return tv
    }()

    private let footerSpinner: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50)
        return indicator
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    init(type: InteractionListType) {
        self.listType = type
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        tableView.tableFooterView = footerSpinner
        loadInitialData()
    }

    private func setupUI() {
        view.backgroundColor = DivoGlassColors.screenBackground
        titleLabel.text = listType.title

        view.addSubview(emptyContainer)
        emptyContainer.addSubview(emptyTitleLabel)
        emptyContainer.addSubview(emptySubTitleLabel)

        view.addSubview(titleLabel)
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)

        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyContainer.topAnchor.constraint(equalTo: view.topAnchor),
            emptyContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyTitleLabel.centerXAnchor.constraint(equalTo: emptyContainer.centerXAnchor),
            emptyTitleLabel.centerYAnchor.constraint(equalTo: emptyContainer.centerYAnchor),
            emptyTitleLabel.leadingAnchor.constraint(equalTo: emptyContainer.leadingAnchor, constant: 8),
            emptyTitleLabel.trailingAnchor.constraint(equalTo: emptyContainer.trailingAnchor, constant: -8),
            
            emptySubTitleLabel.topAnchor.constraint(equalTo: emptyTitleLabel.bottomAnchor, constant: 10),
            emptySubTitleLabel.leadingAnchor.constraint(equalTo: emptyContainer.leadingAnchor, constant: 8),
            emptySubTitleLabel.trailingAnchor.constraint(equalTo: emptyContainer.trailingAnchor, constant: -8),
            emptySubTitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: emptyContainer.bottomAnchor),
        ])
    }

    private func configure(with isEmptyTable: Bool, emptyTitle: String? = nil, emptySubTitle: String? = nil) {
        if isEmptyTable {
            emptyContainer.isHidden = false
            searchBar.isHidden = true
            tableView.isHidden = true
            
            emptyTitleLabel.text = emptyTitle
            emptySubTitleLabel.text = emptySubTitle
        } else {
            emptyContainer.isHidden = true
            searchBar.isHidden = false
            tableView.isHidden = false
        }
    }
    
    private func loadInitialData() {
        loadingIndicator.startAnimating()
        currentOffset = 0
        isLoadingMore = true
        
        requestData?(0) { [weak self] newUsers, hasMore in
            guard let self = self else { return }
            self.isLoadingMore = false
            self.hasMorePages = hasMore
            
            self.currentOffset = self.limit
            
            self.users = newUsers
            self.filteredUsers = newUsers
            
            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating()
                self.updateEmptyState()
                self.tableView.reloadData()
            }
        }
    }
    
    private func loadNextPage() {
        guard !isLoadingMore, hasMorePages, searchBar.text?.isEmpty ?? true else { return }
        
        isLoadingMore = true
        footerSpinner.startAnimating()
        
        let startIndex = self.filteredUsers.count
        
        requestData?(currentOffset) { [weak self] newUsers, hasMore in
            guard let self = self else { return }
            
            self.currentOffset += self.limit
            self.isLoadingMore = false
            self.hasMorePages = hasMore
            
            self.users.append(contentsOf: newUsers)
            self.filteredUsers = self.users
            
            DispatchQueue.main.async {
                self.footerSpinner.stopAnimating()
                
                if !newUsers.isEmpty {
                    let indexPaths = (0..<newUsers.count).map {
                        IndexPath(row: startIndex + $0, section: 0)
                    }
                    
                    self.tableView.performBatchUpdates({
                        self.tableView.insertRows(at: indexPaths, with: .fade)
                    }, completion: nil)
                    
                } else {
                    self.hasMorePages = false
                }
            }
        }
    }
    
    private func updateEmptyState() {
        if filteredUsers.isEmpty {
            if self.listType == .likes {
                configure(with: true, emptyTitle: DivoStrings.noLikesYet, emptySubTitle: DivoStrings.noLikesSubtitle)
            } else if self.listType == .saves {
                configure(with: true, emptyTitle: DivoStrings.nothingSavedYet, emptySubTitle: DivoStrings.nothingSavedSubtitle)
            } else if self.listType == .views {
                configure(with: true, emptyTitle: DivoStrings.noProfileViewedYet, emptySubTitle: DivoStrings.noProfileViewedSubtitle)
            }
        } else {
            configure(with: false)
        }
    }
}

extension InteractionListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredUsers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: InteractionUserCell.reuseIdentifier, for: indexPath) as! InteractionUserCell
        cell.configure(with: filteredUsers[indexPath.row])
        return cell
    }
}

extension InteractionListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 74
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = filteredUsers[indexPath.row]
        print("Open profile: \(user.name)")
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        // Подгружаем данные за 200 поинтов до конца списка
        if offsetY > contentHeight - height - 200 {
            loadNextPage()
        }
    }
}

extension InteractionListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredUsers = users
        } else {
            filteredUsers = users.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        tableView.reloadData()
    }
}

