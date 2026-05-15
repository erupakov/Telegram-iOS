import UIKit
import Display
import DivoCore
import DivoUIKit

final class DivoProfileSearchSheetController: UIViewController {

    var onProfileSelected: ((SearchUserDTO) -> Void)?

    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(DivoImage.searchCloseIcon, for: .normal)
        button.tintColor = DivoColorPalette.primaryText
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        button.layer.applyDivoShadow()
        button.addDivoPressState(.pill)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.attributedText = DivoTypography.sheetTitle(DivoStrings.faceRecognitionUseDivoPhoto)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
        let iv = UIImageView()
        iv.image = DivoImage.searchFieldIcon
        iv.tintColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let searchTextField: UITextField = {
        let field = UITextField()
        field.font = Font.regular(14)
        field.textColor = DivoColorPalette.primaryText
        field.tintColor = DivoColorPalette.accentSecondary
        field.placeholder = DivoStrings.faceRecognitionProfileSearchPlaceholder
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .search
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.keyboardDismissMode = .onDrag
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

    private let snackbar = DivoSnackbar()

    private var results: [SearchUserDTO] = []
    private var selectedUserId: Int?
    private var currentQuery: String = ""
    private var debounceTimer: Timer?
    private var currentTask: Task<Void, Never>?

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
        debounceTimer?.invalidate()
        currentTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DivoColorPalette.screenBackground
        setupUI()

        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        searchTextField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        searchTextField.delegate = self

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DivoProfileSearchCell.self, forCellReuseIdentifier: DivoProfileSearchCell.reuseId)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchTextField.becomeFirstResponder()
    }

    private func setupUI() {
        view.addSubview(closeButton)
        view.addSubview(titleLabel)
        view.addSubview(searchFieldContainer)
        searchFieldContainer.addSubview(searchIcon)
        searchFieldContainer.addSubview(searchTextField)
        view.addSubview(tableView)
        view.addSubview(loader)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: DivoDesignTokens.Spacing.m),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),

            searchFieldContainer.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            searchFieldContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            searchFieldContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            searchFieldContainer.heightAnchor.constraint(equalToConstant: 44),

            searchIcon.leadingAnchor.constraint(equalTo: searchFieldContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            searchIcon.centerYAnchor.constraint(equalTo: searchFieldContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 16),
            searchIcon.heightAnchor.constraint(equalToConstant: 16),

            searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            searchTextField.trailingAnchor.constraint(equalTo: searchFieldContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            searchTextField.topAnchor.constraint(equalTo: searchFieldContainer.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),

            tableView.topAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loader.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            loader.topAnchor.constraint(equalTo: tableView.topAnchor, constant: DivoDesignTokens.Spacing.l),
        ])
    }

    // MARK: - Search

    @objc private func textChanged(_ field: UITextField) {
        let query = field.text ?? ""
        currentQuery = query
        debounceTimer?.invalidate()
        currentTask?.cancel()

        if query.isEmpty {
            loader.stopAnimating()
            results = []
            tableView.reloadData()
            return
        }

        loader.startAnimating()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.fetch()
        }
    }

    private func fetch() {
        let query = currentQuery
        currentTask = Task { @MainActor in
            do {
                let request = ModelsSearchRequest(offset: 0, limit: 20, query: query, withoutNfts: true)
                let response: ModelsSearchResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/search",
                    method: "POST",
                    body: request
                )
                guard !Task.isCancelled, query == self.currentQuery else { return }
                self.loader.stopAnimating()
                self.results = response.data.items
                self.tableView.reloadData()
            } catch {
                if Task.isCancelled { return }
                self.loader.stopAnimating()
                let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.feedSearchResultsLoadFailed
                self.snackbar.show(
                    in: self.view,
                    message: userMsg,
                    style: .error,
                    bottomInset: DivoDesignTokens.Spacing.m,
                    bottomAnchor: self.view.safeAreaLayoutGuide.bottomAnchor,
                    retryTitle: DivoStrings.retry,
                    retryAction: { [weak self] in self?.fetch() },
                    persistent: true
                )
            }
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func handleSelection(_ user: SearchUserDTO) {
        selectedUserId = user.user?.id ?? user.id
        tableView.reloadData()
        view.endEditing(true)
        debounceTimer?.invalidate()
        currentTask?.cancel()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.dismiss(animated: true) { [weak self] in
                self?.onProfileSelected?(user)
            }
        }
    }
}

// MARK: - UITableView

extension DivoProfileSearchSheetController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DivoProfileSearchCell.reuseId, for: indexPath) as! DivoProfileSearchCell
        let user = results[indexPath.row]
        let userId = user.user?.id ?? user.id
        cell.configure(with: user, query: currentQuery, isSelected: userId == selectedUserId)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        handleSelection(results[indexPath.row])
    }
}

extension DivoProfileSearchSheetController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Cell

private final class DivoProfileSearchCell: UITableViewCell {

    static let reuseId = "DivoProfileSearchCell"

    private static let avatarSize: CGFloat = 48

    private let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = DivoProfileSearchCell.avatarSize / 2
        iv.backgroundColor = DivoColorPalette.imagePlaceholderDark
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let checkmarkView: UIImageView = {
        let iv = UIImageView()
        iv.image = DivoImage.searchOrangeCheckmark
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(checkmarkView)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: DivoDesignTokens.Spacing.s + 4),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkView.leadingAnchor, constant: -DivoDesignTokens.Spacing.s),

            checkmarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            checkmarkView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkView.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelImageLoad()
        avatarView.image = nil
        avatarView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    func configure(with item: SearchUserDTO, query: String, isSelected: Bool) {
        nameLabel.attributedText = Self.highlightedName(item.title ?? item.user?.fullName ?? "", query: query)
        checkmarkView.isHidden = !isSelected

        if let urlString = item.searchImage?.fullUrl,
           let url = CDNURLHelper.convertToCDNURL(urlString) {
            avatarView.loadImage(from: url) { [weak self] image in
                self?.avatarView.applyAvatarTopCropIfNeeded(image: image)
            }
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        applyDivoListHighlight(highlighted)
    }

    private static func highlightedName(_ name: String, query: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: name,
            attributes: [.foregroundColor: DivoColorPalette.primaryText]
        )
        guard !query.isEmpty else { return attributed }
        let range = (name.lowercased() as NSString).range(of: query.lowercased())
        if range.location != NSNotFound {
            attributed.addAttribute(.foregroundColor, value: DivoColorPalette.accent, range: range)
        }
        return attributed
    }
}
