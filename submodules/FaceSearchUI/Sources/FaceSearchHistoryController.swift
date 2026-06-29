import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import TelegramPresentationData
import DivoCore
import DivoUIKit

public final class FaceSearchHistoryController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData

    public var onItemTapped: ((FaceSearchHistoryItem) -> Void)?
    public var onStartFaceSearch: (() -> Void)?

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
    }

    override public func loadDisplayNode() {
        let items = FaceSearchHistoryStorage.shared.loadAll()
        let node = FaceSearchHistoryScreenNode(items: items)

        node.onBackPressed = { [weak self] in
            guard let self else { return }
            if let nav = self.navigationController as? NavigationController {
                _ = nav.popViewController(animated: true)
            } else {
                self.dismiss()
            }
        }
        node.onClearAll = { [weak self] in
            FaceSearchHistoryStorage.shared.clearAll()
            divoTrack(.faceSearchHistoryCleared)
            self?.historyNode?.updateItems([])
        }
        node.onItemTapped = { [weak self] item in
            self?.onItemTapped?(item)
        }
        node.onStartSearch = { [weak self] in
            guard let self else { return }
            if let nav = self.navigationController as? NavigationController {
                _ = nav.popViewController(animated: true)
            }
            self.onStartFaceSearch?()
        }

        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
        let items = FaceSearchHistoryStorage.shared.loadAll()
        self.historyNode?.updateItems(items)
    }

    private var historyNode: FaceSearchHistoryScreenNode? {
        self.displayNode as? FaceSearchHistoryScreenNode
    }
}

// MARK: - Node

private final class FaceSearchHistoryScreenNode: ASDisplayNode, UITableViewDataSource, UITableViewDelegate {

    var onBackPressed: (() -> Void)?
    var onClearAll: (() -> Void)?
    var onItemTapped: ((FaceSearchHistoryItem) -> Void)?
    var onStartSearch: (() -> Void)?

    private var items: [FaceSearchHistoryItem]
    private var cardHeightConstraint: NSLayoutConstraint?

    // MARK: - Top bar

    private let backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(DivoImage.searchChevronLeft, for: .normal)
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
        label.attributedText = NSAttributedString(
            string: DivoStrings.faceSearchHistoryScreenTitle.uppercased(),
            attributes: [
                .font: Font.helveticaNeue(20),
                .foregroundColor: DivoColorPalette.primaryText,
                .kern: 0.5
            ]
        )
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let clearAllButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(DivoStrings.faceSearchHistoryClearAll, for: .normal)
        button.setTitleColor(DivoColorPalette.accent, for: .normal)
        button.titleLabel?.font = UIFont(name: "HelveticaNeue", size: 15) ?? UIFont.systemFont(ofSize: 15)
        button.addDivoPressState(.text)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Content

    private let cardContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.card
        view.clipsToBounds = true
        view.layer.applyDivoShadow(radius: DivoDesignTokens.Shadow.radiusLarge)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.showsVerticalScrollIndicator = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Empty state

    private let emptyStateView: DivoEmptyStateView = {
        let view = DivoEmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // MARK: - Init

    init(items: [FaceSearchHistoryItem]) {
        self.items = items
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground
    }

    override func didLoad() {
        super.didLoad()
        setupUI()
        applyState()
    }

    // MARK: - Setup

    private func setupUI() {
        let safeArea = view.safeAreaLayoutGuide
        let sidePadding: CGFloat = 16

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(clearAllButton)
        view.addSubview(cardContainer)
        cardContainer.addSubview(tableView)
        view.addSubview(emptyStateView)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FaceSearchHistoryFullCell.self, forCellReuseIdentifier: FaceSearchHistoryFullCell.reuseId)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: DivoDesignTokens.Spacing.s),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sidePadding),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            clearAllButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            clearAllButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sidePadding),

            cardContainer.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            cardContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sidePadding),
            cardContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sidePadding),
            cardContainer.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -sidePadding),

            tableView.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),

            emptyStateView.topAnchor.constraint(equalTo: backButton.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let heightConstraint = cardContainer.heightAnchor.constraint(equalToConstant: CGFloat(items.count) * 82)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true
        cardHeightConstraint = heightConstraint

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        clearAllButton.addTarget(self, action: #selector(clearAllTapped), for: .touchUpInside)
    }

    // MARK: - State

    func updateItems(_ newItems: [FaceSearchHistoryItem]) {
        items = newItems
        tableView.reloadData()
        applyState()
    }

    private func applyState() {
        let empty = items.isEmpty
        cardContainer.isHidden = empty
        clearAllButton.isHidden = empty
        emptyStateView.isHidden = !empty
        cardHeightConstraint?.constant = CGFloat(items.count) * 82

        if empty {
            let searchIcon = UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)) ?? UIImage()
            emptyStateView.configure(DivoEmptyStateView.Configuration(
                style: .smallOnTinted(icon: searchIcon),
                title: DivoStrings.faceSearchHistoryNoSearchesTitle,
                subtitle: DivoStrings.faceSearchHistoryNoSearchesSubtitle,
                ctaTitle: DivoStrings.faceSearchHistoryStartSearch,
                onCTATapped: { [weak self] in
                    self?.onStartSearch?()
                }
            ))
            emptyStateView.animateAppearance()
        }
    }

    // MARK: - Actions

    @objc private func backTapped() { onBackPressed?() }

    @objc private func clearAllTapped() { onClearAll?() }

    // MARK: - UITableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        82
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FaceSearchHistoryFullCell.reuseId, for: indexPath) as! FaceSearchHistoryFullCell
        cell.configure(with: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onItemTapped?(items[indexPath.row])
    }
}

// MARK: - Cell

private final class FaceSearchHistoryFullCell: UITableViewCell {

    static let reuseId = "FaceSearchHistoryFullCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 24
        iv.backgroundColor = DivoColorPalette.imagePlaceholderDark
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "HelveticaNeue-Medium", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "HelveticaNeue", size: 14) ?? UIFont.systemFont(ofSize: 14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let filterLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "HelveticaNeue", size: 14) ?? UIFont.systemFont(ofSize: 14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let chevronView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: config))
        iv.tintColor = DivoColorPalette.primaryText.withAlphaComponent(0.3)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(avatarImageView)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(dateLabel)
        textStack.addArrangedSubview(filterLabel)
        contentView.addSubview(textStack)
        contentView.addSubview(chevronView)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 48),
            avatarImageView.heightAnchor.constraint(equalToConstant: 48),

            textStack.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -8),

            chevronView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            chevronView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 12),
        ])
    }

    func configure(with item: FaceSearchHistoryItem) {
        titleLabel.text = DivoStrings.faceSearchHistoryResultsFound(item.resultsCount)
        dateLabel.text = Self.formatDate(item.date)
        filterLabel.text = Self.buildFilterSummary(item)
        avatarImageView.image = FaceSearchHistoryStorage.shared.faceImage(for: item)
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let targetAlpha: CGFloat = highlighted ? DivoDesignTokens.PressState.alpha : 1
        let targetScale: CGFloat = highlighted ? DivoDesignTokens.PressState.scaleListRow : 1
        UIView.animate(withDuration: DivoDesignTokens.PressState.pressDuration) {
            self.contentView.alpha = targetAlpha
            self.contentView.transform = CGAffineTransform(scaleX: targetScale, y: targetScale)
        }
    }

    private static func buildFilterSummary(_ item: FaceSearchHistoryItem) -> String {
        let defaultSimilarity = 30
        var parts: [String] = []

        if item.similarityPercent != defaultSimilarity {
            parts.append(DivoStrings.faceSearchHistorySimilarity(item.similarityPercent))
        }
        parts.append(contentsOf: item.filterParts)

        return parts.isEmpty ? DivoStrings.faceSearchHistoryNoFilters : parts.joined(separator: " · ")
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: DivoStrings.current.localeIdentifier)
        switch DivoStrings.current {
        case .en: formatter.dateFormat = "EEEE, d MMM 'at' HH:mm"
        case .ru: formatter.dateFormat = "EEEE, d MMM 'в' HH:mm"
        case .es: formatter.dateFormat = "EEEE, d MMM 'a las' HH:mm"
        case .pt: formatter.dateFormat = "EEEE, d MMM 'às' HH:mm"
        case .zh: formatter.dateFormat = "EEEE, M月d日 HH:mm"
        }
        return formatter.string(from: date)
    }
}
