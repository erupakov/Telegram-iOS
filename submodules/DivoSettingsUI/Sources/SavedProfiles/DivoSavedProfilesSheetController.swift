import UIKit
import Display
import DivoCore
import DivoUIKit

/// Шторка «Сохранённые профили»: список подписок (following) с переходом в публичный профиль.
/// Данные — `POST /follower/following`, пагинация по мере скролла.
final class DivoSavedProfilesSheetController: UIViewController {

    var onProfileSelected: ((FollowingUser) -> Void)?

    private enum Phase: Equatable {
        case loading
        case content
        case empty
        case failed(networkError: Bool)
    }

    private let pageLimit = 30

    private var items: [FollowingUser] = []
    private var offset = 0
    private var canLoadMore = true
    private var isLoadingPage = false
    private var currentTask: Task<Void, Never>?

    private var phase: Phase = .loading {
        didSet {
            if oldValue != phase { applyState() }
        }
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = Font.helveticaNeue(20)
        label.textColor = DivoColorPalette.primaryText
        label.text = DivoStrings.savedProfiles.uppercased()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.showsVerticalScrollIndicator = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let loader: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .medium)
        loader.color = DivoColorPalette.accent
        loader.hidesWhenStopped = true
        loader.translatesAutoresizingMaskIntoConstraints = false
        return loader
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(15)
        label.textColor = DivoColorPalette.secondaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let snackbar = DivoSnackbar()

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DivoDesignTokens.Radius.sheet
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        currentTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
        view.backgroundColor = DivoColorPalette.screenBackground
        setupUI()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DivoSavedProfileCell.self, forCellReuseIdentifier: DivoSavedProfileCell.reuseId)

        applyState()
        loadFirstPage()
    }

    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(tableView)
        view.addSubview(loader)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: DivoDesignTokens.Spacing.l),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loader.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loader.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.xl),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.xl),
        ])
    }

    // MARK: - State

    private func applyState() {
        switch phase {
        case .loading:
            loader.startAnimating()
            tableView.isHidden = true
            statusLabel.isHidden = true
        case .content:
            loader.stopAnimating()
            tableView.isHidden = false
            statusLabel.isHidden = true
        case .empty:
            loader.stopAnimating()
            tableView.isHidden = true
            statusLabel.isHidden = false
            statusLabel.text = DivoStrings.savedProfilesEmpty
        case let .failed(networkError):
            loader.stopAnimating()
            tableView.isHidden = true
            statusLabel.isHidden = false
            statusLabel.text = networkError ? DivoStrings.noInternetConnection : DivoStrings.savedProfilesLoadFailed
        }
    }

    // MARK: - Loading

    private func loadFirstPage() {
        currentTask?.cancel()
        offset = 0
        items = []
        canLoadMore = true
        isLoadingPage = false
        tableView.reloadData()
        phase = .loading
        fetchNextPage(isFirstPage: true)
    }

    private func fetchNextPage(isFirstPage: Bool) {
        guard !isLoadingPage, canLoadMore else { return }
        isLoadingPage = true

        currentTask = Task { @MainActor in
            do {
                let request = FollowingListRequest(offset: offset, limit: pageLimit)
                let response: FollowingResponse = try await DivoAPIClient.shared.request(
                    path: "/follower/following",
                    method: "POST",
                    body: request
                )
                guard !Task.isCancelled else { return }
                isLoadingPage = false

                let newItems = response.data.items
                items.append(contentsOf: newItems)
                offset += newItems.count
                canLoadMore = newItems.count == pageLimit
                tableView.reloadData()
                phase = items.isEmpty ? .empty : .content
            } catch {
                if Task.isCancelled { return }
                isLoadingPage = false
                handleLoadError(error, isFirstPage: isFirstPage)
            }
        }
    }

    private func handleLoadError(_ error: Error, isFirstPage: Bool) {
        let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.savedProfilesLoadFailed
        // Ошибка первой страницы — целиком failed-состояние с persistent-снекбаром; ошибка
        // догрузки не прячет уже показанный список (CODE_REVIEW §6) — транзиентный снекбар.
        if isFirstPage {
            phase = .failed(networkError: isNetworkError(error))
        }
        snackbar.show(
            in: view,
            message: userMsg,
            style: .error,
            bottomInset: DivoDesignTokens.Spacing.m,
            bottomAnchor: view.safeAreaLayoutGuide.bottomAnchor,
            retryTitle: DivoStrings.retry,
            retryAction: { [weak self] in
                guard let self else { return }
                if isFirstPage {
                    self.loadFirstPage()
                } else {
                    self.fetchNextPage(isFirstPage: false)
                }
            },
            persistent: isFirstPage
        )
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if let apiError = error as? DivoAPIError, case .noInternetConnection = apiError {
            return true
        }
        return false
    }

    private func handleSelection(_ user: FollowingUser) {
        currentTask?.cancel()
        dismiss(animated: true) { [weak self] in
            self?.onProfileSelected?(user)
        }
    }
}

// MARK: - UITableView

extension DivoSavedProfilesSheetController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DivoSavedProfileCell.reuseId, for: indexPath) as! DivoSavedProfileCell
        cell.configure(with: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        handleSelection(items[indexPath.row])
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row >= items.count - 3 {
            fetchNextPage(isFirstPage: false)
        }
    }
}

// MARK: - Cell

private final class DivoSavedProfileCell: UITableViewCell {

    static let reuseId = "DivoSavedProfileCell"

    private static let avatarSize: CGFloat = 48

    private let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = DivoSavedProfileCell.avatarSize / 2
        iv.backgroundColor = DivoColorPalette.imagePlaceholderDark
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.semibold(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(13)
        label.textColor = DivoColorPalette.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .clear

        let textStack = UIStackView(arrangedSubviews: [nameLabel, roleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(avatarView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            textStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: DivoDesignTokens.Spacing.s + 4),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelImageLoad()
        avatarView.image = nil
        avatarView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    func configure(with user: FollowingUser) {
        nameLabel.text = user.fullName ?? ""
        roleLabel.text = user.roleLabel

        let placeholder = DivoImage.emptyBackgroundAvatar
        if let url = CDNURLHelper.convertToCDNURL(user.avatarURLString) {
            avatarView.loadImage(from: url, placeholder: placeholder, cropAvatarIfNeeded: true)
        } else {
            avatarView.image = placeholder
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        applyDivoListHighlight(highlighted)
    }
}
