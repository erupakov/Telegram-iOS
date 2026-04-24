import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import TelegramPresentationData
import DivoCore
import DivoUIKit
import ProfileScreenUI

final class FaceSearchResultsController: ViewController {
    private let context: AccountContext
    private let imageData: Data
    private let sourceImage: UIImage?
    private let faceBBox: FRBoundingBox?
    private let faceIndex: Int

    private var results: [FRSearchResult]
    private let initialResults: [FRSearchResult]
    private let initialSimilarity: Double
    private var currentFilters: FaceSearchFilterState
    private var isReloading = false
    private var currentTask: Task<Void, Never>?

    init(
        context: AccountContext,
        imageData: Data,
        results: [FRSearchResult],
        sourceImage: UIImage?,
        faceBBox: FRBoundingBox?,
        faceIndex: Int,
        initialFilters: FaceSearchFilterState
    ) {
        self.context = context
        self.imageData = imageData
        self.results = results
        self.initialResults = results
        self.initialSimilarity = initialFilters.similarity
        self.sourceImage = sourceImage
        self.faceBBox = faceBBox
        self.faceIndex = faceIndex
        self.currentFilters = initialFilters
        super.init(navigationBarPresentationData: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        currentTask?.cancel()
    }

    override func loadDisplayNode() {
        let node = FaceSearchResultsNode(
            results: self.results,
            sourceImage: self.sourceImage,
            faceBBox: self.faceBBox,
            threshold: self.currentFilters.similarity
        )
        node.onBackPressed = { [weak self] in
            guard let self else { return }
            if let nav = self.navigationController as? NavigationController {
                _ = nav.popViewController(animated: true)
            } else {
                self.dismiss()
            }
        }
        node.onBrowseAllProfiles = { [weak self] in
            guard let self, let nav = self.navigationController as? NavigationController else { return }
            nav.popToRoot(animated: true)
        }
        node.onResultTapped = { [weak self] result in
            self?.openProfile(for: result)
        }
        node.onFilterPressed = { [weak self] in
            self?.openFilters()
        }
        node.onFiltersClear = { [weak self] in
            self?.clearFilters()
        }
        node.onFallbackAccept = { [weak self] similarity in
            self?.acceptFallback(similarity: similarity)
        }
        node.onLikeTapped = { [weak self] feedId, isLiked in
            self?.handleLike(feedId: feedId, isLiked: isLiked)
        }
        node.onSaveTapped = { [weak self] userId, isSaved in
            self?.handleSave(userId: userId, isSaved: isSaved)
        }
        node.onShareTapped = { [weak self] result, image in
            self?.handleShare(result: result, image: image)
        }
        node.updateFilterBadge(count: currentFilters.activeFilterCount)
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
    }

    private var resultsNode: FaceSearchResultsNode? {
        self.displayNode as? FaceSearchResultsNode
    }

    private func openFilters() {
        let filterVC = FaceSearchFilterController(currentFilters: self.currentFilters)

        filterVC.onApply = { [weak self] newFilters in
            guard let self else { return }
            self.applyFilters(newFilters)
        }
        filterVC.onClose = { [weak self] newFilters in
            guard let self, self.currentFilters != newFilters else { return }
            self.applyFilters(newFilters)
        }

        let navVC = UINavigationController(rootViewController: filterVC)
        if #available(iOS 15.0, *) {
            if let sheet = navVC.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 24
            }
        }
        self.view.window?.rootViewController?.present(navVC, animated: true)
    }

    private func applyFilters(_ newFilters: FaceSearchFilterState) {
        self.currentFilters = newFilters
        resultsNode?.updateFilterBadge(count: newFilters.activeFilterCount)
        reloadSearch()
    }

    private func clearFilters() {
        currentTask?.cancel()
        currentFilters.reset()
        self.results = initialResults
        resultsNode?.hideFallbackBanner()
        resultsNode?.hideReloadError()
        resultsNode?.updateFilterBadge(count: 0)
        resultsNode?.updateResults(initialResults, threshold: initialSimilarity)
    }

    private static func isConnectionFailure(_ error: Error) -> Bool {
        if let apiError = error as? DivoAPIError, case .noInternetConnection = apiError {
            return true
        }
        return error is URLError
    }

    private func acceptFallback(similarity: Double) {
        currentFilters.similarity = similarity
        resultsNode?.updateFilterBadge(count: currentFilters.activeFilterCount)
    }

    private func reloadSearch() {
        currentTask?.cancel()
        isReloading = true

        resultsNode?.setLoading(true)
        resultsNode?.hideFallbackBanner()
        resultsNode?.hideReloadError()

        let filters = self.currentFilters
        let faceIndex = self.faceIndex
        let imageData = self.imageData

        currentTask = Task { @MainActor [weak self] in
            do {
                let fields = Self.buildFields(faceIndex: faceIndex, filters: filters)
                let response: FRSearchResponse = try await DivoAPIClient.shared.upload(
                    path: "/fr/search",
                    fileData: imageData,
                    fields: fields
                )
                guard let self else { return }
                try Task.checkCancellation()

                if response.results.isEmpty {
                    let fallbackSteps = self.lowerSimilaritySteps(from: filters.similarity)
                    if !fallbackSteps.isEmpty {
                        try await self.performFallback(
                            filters: filters,
                            fallbackSteps: fallbackSteps,
                            faceIndex: faceIndex,
                            imageData: imageData
                        )
                    } else {
                        self.isReloading = false
                        self.resultsNode?.setLoading(false)
                        self.resultsNode?.showFilterNoResults()
                    }
                    return
                }

                self.isReloading = false
                self.results = response.results
                self.resultsNode?.setLoading(false)
                self.resultsNode?.updateResults(response.results, threshold: filters.similarity)
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                self.isReloading = false
                self.resultsNode?.setLoading(false)

                let title: String
                let subtitle: String
                if Self.isConnectionFailure(error) {
                    title = DivoStrings.faceSearchInterruptedTitle
                    subtitle = DivoStrings.faceSearchInterruptedSubtitle
                } else {
                    title = DivoStrings.faceSearchServerErrorTitle
                    subtitle = DivoStrings.faceSearchServerErrorSubtitle
                }
                self.resultsNode?.showReloadError(title: title, subtitle: subtitle) { [weak self] in
                    self?.reloadSearch()
                }
            }
        }
    }

    private func lowerSimilaritySteps(from current: Double) -> [Double] {
        let steps = FaceSearchFilterState.similaritySteps
        guard let idx = steps.firstIndex(of: current), idx > 0 else { return [] }
        return Array(steps[0..<idx].reversed())
    }

    private func performFallback(
        filters: FaceSearchFilterState,
        fallbackSteps: [Double],
        faceIndex: Int,
        imageData: Data
    ) async throws {
        for fallbackSimilarity in fallbackSteps {
            var fallbackFilters = filters
            fallbackFilters.similarity = fallbackSimilarity
            let fields = Self.buildFields(faceIndex: faceIndex, filters: fallbackFilters)
            let response: FRSearchResponse = try await DivoAPIClient.shared.upload(
                path: "/fr/search",
                fileData: imageData,
                fields: fields
            )
            try Task.checkCancellation()

            if !response.results.isEmpty {
                self.isReloading = false
                self.results = response.results
                self.resultsNode?.setLoading(false)

                let originalPercent = Int((filters.similarity * 100).rounded())
                let actualPercent = Int((fallbackSimilarity * 100).rounded())
                self.resultsNode?.updateResults(response.results, threshold: fallbackSimilarity)
                self.resultsNode?.showFallbackBanner(originalPercent: originalPercent, actualPercent: actualPercent, similarity: fallbackSimilarity, originalThreshold: filters.similarity)
                return
            }
        }

        self.isReloading = false
        self.resultsNode?.setLoading(false)
        self.resultsNode?.showFilterNoResults()
    }

    private static func buildFields(faceIndex: Int, filters: FaceSearchFilterState) -> [String: String] {
        var fields: [String: String] = [
            "face_index": "\(faceIndex)",
            "top_k": "20",
            "k_ratio": "\(filters.similarity)"
        ]

        if let roles = filters.apiRoles {
            fields["role"] = roles.joined(separator: ",")
        }
        if let countries = filters.apiCountries {
            fields["country_ids"] = countries.joined(separator: ",")
        }
        if let ageRange = filters.ageRange {
            fields["age_from"] = "\(ageRange.lowerBound)"
            fields["age_to"] = "\(ageRange.upperBound)"
        }
        if let heightRange = filters.heightRange {
            fields["height_from"] = "\(heightRange.lowerBound)"
            fields["height_to"] = "\(heightRange.upperBound)"
        }
        if let waistRange = filters.waistRange {
            fields["waist_from"] = "\(waistRange.lowerBound)"
            fields["waist_to"] = "\(waistRange.upperBound)"
        }
        if let hipsRange = filters.hipsRange {
            fields["hips_from"] = "\(hipsRange.lowerBound)"
            fields["hips_to"] = "\(hipsRange.upperBound)"
        }
        if let shoeSizeRange = filters.shoeSizeRange {
            fields["shoes_size_from"] = "\(shoeSizeRange.lowerBound)"
            fields["shoes_size_to"] = "\(shoeSizeRange.upperBound)"
        }
        if let hairLength = filters.hairLength, !hairLength.isEmpty {
            fields["hair_length"] = hairLength.map(String.init).joined(separator: ",")
        }

        return fields
    }

    private func handleLike(feedId: Int, isLiked: Bool) {
        let path = isLiked ? "/feedline/like" : "/feedline/unlike"
        let body = FollowRequest(id: feedId)
        Task { @MainActor in
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: body
                )
            } catch {
                // TODO: rollback
            }
        }
    }

    private func handleSave(userId: Int, isSaved: Bool) {
        let path = isSaved ? "/follower/follow" : "/follower/unfollow"
        let body = FollowRequest(id: userId)
        Task { @MainActor in
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: body
                )
            } catch {
                // TODO: rollback
            }
        }
    }

    private func handleShare(result: FRSearchResult, image: UIImage?) {
        guard let userId = result.userId else { return }
        let shareURL = URL(string: "\(DivoConfig.shareBaseURL)/profile/\(userId)")!
        let shareItem = DivoShareItemSource(
            url: shareURL,
            title: result.fullName ?? "",
            subtitle: FaceSearchResultsMapper.roleLabel(for: result.role) ?? "",
            image: image
        )
        let activityVC = UIActivityViewController(activityItems: [shareItem], applicationActivities: nil)
        self.view.window?.rootViewController?.present(activityVC, animated: true)
    }

    private func openProfile(for result: FRSearchResult) {
        let mainImageURL = result.image.flatMap(URL.init(string:))
        let location = FaceSearchResultsMapper.countryText(code: result.countryCode, name: result.countryName) ?? ""
        let model = ProfileModel(
            name: result.fullName ?? "",
            age: FaceSearchResultsMapper.computeAge(from: result.birthday),
            location: location,
            isVerified: false,
            likesCount: "0",
            viewsCount: "0",
            savesCount: "0",
            biography: "",
            socialMediaHandles: [],
            userId: result.userId,
            role: result.role,
            mainImageURL: mainImageURL,
            avatarImageURL: mainImageURL
        )
        let controller = PublicProfileScreenController(context: self.context, model: model)
        (self.navigationController as? NavigationController)?.pushViewController(controller, animated: true)
    }
}

// MARK: - Mapper

enum FaceSearchResultsMapper {

    static func computeAge(from birthday: String?) -> Int? {
        guard let birthday, !birthday.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: birthday) else { return nil }
        return Calendar.current.dateComponents([.year], from: date, to: Date()).year
    }

    static func countryText(code: String?, name: String?) -> String? {
        guard let name else { return nil }
        let flag = CountryHelper.emojiFlag(for: code)
        return "\(flag) \(name)"
    }

    static func roleLabel(for role: String?) -> String? {
        switch role {
        case "model": return DivoStrings.debugModel
        case "new_face": return DivoStrings.debugNewTalent
        case "agency_employee": return DivoStrings.debugAgency
        default: return role
        }
    }

    static func viewModel(from result: FRSearchResult) -> SearchCardViewModel {
        let age = computeAge(from: result.birthday)
        let country = countryText(code: result.countryCode, name: result.countryName)

        let infoText: String
        if let age, let country {
            infoText = DivoStrings.ageString(age) + " • " + country
        } else if let age {
            infoText = DivoStrings.ageString(age)
        } else if let country {
            infoText = country
        } else {
            infoText = ""
        }

        return SearchCardViewModel(
            variant: .faceMatch(percent: result.score),
            feedId: nil,
            userId: result.userId,
            name: result.fullName,
            infoText: infoText.isEmpty ? nil : infoText,
            roleLabel: roleLabel(for: result.role),
            likesCount: 0,
            isLikedByUser: false,
            isFavoriteByUser: false,
            imageURL: result.image.flatMap(URL.init(string:))
        )
    }
}

// MARK: - Node

private final class FaceSearchResultsNode: ASDisplayNode, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onBackPressed: (() -> Void)?
    var onBrowseAllProfiles: (() -> Void)?
    var onResultTapped: ((FRSearchResult) -> Void)?
    var onFilterPressed: (() -> Void)?
    var onFiltersClear: (() -> Void)?
    var onFallbackAccept: ((Double) -> Void)?
    var onLikeTapped: ((Int, Bool) -> Void)?
    var onSaveTapped: ((Int, Bool) -> Void)?
    var onShareTapped: ((FRSearchResult, UIImage?) -> Void)?

    private var results: [FRSearchResult]
    private let sourceImage: UIImage?
    private let faceBBox: FRBoundingBox?
    private var threshold: Double

    // MARK: Top bar

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

    private let filterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(DivoImage.searchFilterIcon, for: .normal)
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
            string: DivoStrings.faceSearchSimilarProfilesTitle.uppercased(),
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

    // MARK: Header row

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 26
        iv.backgroundColor = DivoColorPalette.imagePlaceholderDark
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let headerLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(20)
        label.textColor = DivoColorPalette.primaryText
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: Sub-header

    private let profilesFoundLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
        label.font = Font.medium(12)
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

    // MARK: Fallback banner

    private let fallbackBanner: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.clipsToBounds = true
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let fallbackLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let fallbackAdjustButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(DivoStrings.faceSearchAdjustFilters, for: .normal)
        button.setTitleColor(DivoColorPalette.accent, for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(14)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var fallbackSimilarity: Double?
    private var originalSimilarity: Double?
    private var isShowingSkeleton = false
    private let skeletonCount = 6
    private var collectionTopToSubheader: NSLayoutConstraint?
    private var collectionTopToFilters: NSLayoutConstraint?
    private var collectionTopToBanner: NSLayoutConstraint?

    // MARK: Grid + empty + loading

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.showsVerticalScrollIndicator = false
        cv.showsHorizontalScrollIndicator = false
        cv.register(SearchResultGridCell.self, forCellWithReuseIdentifier: "FaceMatchCell")
        cv.register(SearchResultSkeletonCell.self, forCellWithReuseIdentifier: SearchResultSkeletonCell.reuseIdentifier)
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let emptyStateView: DivoEmptyStateView = {
        let view = DivoEmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let reloadErrorView: DivoEmptyStateView = {
        let view = DivoEmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()


    init(results: [FRSearchResult], sourceImage: UIImage?, faceBBox: FRBoundingBox?, threshold: Double) {
        self.results = results
        self.sourceImage = sourceImage
        self.faceBBox = faceBBox
        self.threshold = threshold
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground
    }

    override func didLoad() {
        super.didLoad()
        setupUI()
        applyContent()
    }

    private func setupUI() {
        let safeArea = view.safeAreaLayoutGuide

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(filterButton)
        view.addSubview(avatarImageView)
        view.addSubview(headerLabel)
        view.addSubview(profilesFoundLabel)
        view.addSubview(activeFiltersContainer)
        activeFiltersContainer.addSubview(activeFiltersLabel)
        activeFiltersContainer.addSubview(activeFiltersClearButton)
        activeFiltersClearButton.addTarget(self, action: #selector(filtersClearTapped), for: .touchUpInside)
        view.addSubview(fallbackBanner)
        fallbackBanner.addSubview(fallbackLabel)
        fallbackBanner.addSubview(fallbackAdjustButton)
        fallbackAdjustButton.addTarget(self, action: #selector(fallbackAcceptTapped), for: .touchUpInside)
        view.addSubview(collectionView)
        view.addSubview(emptyStateView)
        view.addSubview(reloadErrorView)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: DivoDesignTokens.Spacing.s),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),

            filterButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            filterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            filterButton.widthAnchor.constraint(equalToConstant: 40),
            filterButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            avatarImageView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.widthAnchor.constraint(equalToConstant: 52),
            avatarImageView.heightAnchor.constraint(equalToConstant: 52),

            headerLabel.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            headerLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            profilesFoundLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            profilesFoundLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),

            activeFiltersContainer.centerYAnchor.constraint(equalTo: profilesFoundLabel.centerYAnchor),
            activeFiltersContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            activeFiltersContainer.heightAnchor.constraint(equalToConstant: 36),

            activeFiltersLabel.leadingAnchor.constraint(equalTo: activeFiltersContainer.leadingAnchor, constant: 12),
            activeFiltersLabel.centerYAnchor.constraint(equalTo: activeFiltersContainer.centerYAnchor),

            activeFiltersClearButton.leadingAnchor.constraint(equalTo: activeFiltersLabel.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            activeFiltersClearButton.trailingAnchor.constraint(equalTo: activeFiltersContainer.trailingAnchor, constant: -12),
            activeFiltersClearButton.centerYAnchor.constraint(equalTo: activeFiltersContainer.centerYAnchor),

            fallbackBanner.topAnchor.constraint(equalTo: activeFiltersContainer.bottomAnchor, constant: 12),
            fallbackBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            fallbackBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            fallbackLabel.topAnchor.constraint(equalTo: fallbackBanner.topAnchor, constant: 12),
            fallbackLabel.leadingAnchor.constraint(equalTo: fallbackBanner.leadingAnchor, constant: 18),
            fallbackLabel.bottomAnchor.constraint(equalTo: fallbackBanner.bottomAnchor, constant: -12),
            fallbackLabel.trailingAnchor.constraint(lessThanOrEqualTo: fallbackAdjustButton.leadingAnchor, constant: -8),

            fallbackAdjustButton.topAnchor.constraint(equalTo: fallbackBanner.topAnchor, constant: 12),
            fallbackAdjustButton.trailingAnchor.constraint(equalTo: fallbackBanner.trailingAnchor, constant: -18),

            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.topAnchor.constraint(equalTo: backButton.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            reloadErrorView.topAnchor.constraint(equalTo: profilesFoundLabel.bottomAnchor),
            reloadErrorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            reloadErrorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            reloadErrorView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let topToSubheader = collectionView.topAnchor.constraint(equalTo: profilesFoundLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.m)
        topToSubheader.isActive = true
        self.collectionTopToSubheader = topToSubheader

        let topToFilters = collectionView.topAnchor.constraint(equalTo: activeFiltersContainer.bottomAnchor, constant: 12)
        topToFilters.isActive = false
        self.collectionTopToFilters = topToFilters

        let topToBanner = collectionView.topAnchor.constraint(equalTo: fallbackBanner.bottomAnchor, constant: 12)
        topToBanner.isActive = false
        self.collectionTopToBanner = topToBanner

        collectionView.contentInset = UIEdgeInsets(
            top: 0,
            left: DivoDesignTokens.Spacing.m,
            bottom: DivoDesignTokens.Spacing.m,
            right: DivoDesignTokens.Spacing.m
        )

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        filterButton.addTarget(self, action: #selector(filterTapped), for: .touchUpInside)
    }

    private func applyContent() {
        if let sourceImage, let faceBBox {
            avatarImageView.image = Self.cropFaceSquare(from: sourceImage, bbox: faceBBox, padding: 16)
        } else {
            avatarImageView.image = sourceImage
        }

        updateHeaderTexts()

        if results.isEmpty {
            showEmptyState()
        }
    }

    private func updateHeaderTexts() {
        let percent = Int((threshold * 100).rounded())
        let resultsCountText = DivoStrings.faceSearchResultsCount(results.count)
        let thresholdText = DivoStrings.faceSearchSimilarityThreshold(percent)
        headerLabel.text = "\(resultsCountText) · \(thresholdText)"

        profilesFoundLabel.text = DivoStrings.faceSearchProfilesFound(results.count)
    }

    func updateResults(_ newResults: [FRSearchResult], threshold: Double) {
        self.results = newResults
        self.threshold = threshold

        updateHeaderTexts()

        if newResults.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
            collectionView.reloadData()
            collectionView.setContentOffset(CGPoint(x: -collectionView.contentInset.left, y: -collectionView.contentInset.top), animated: false)
        }
    }

    func updateFilterBadge(count: Int) {
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

            if !fallbackBanner.isHidden {
                collectionTopToSubheader?.isActive = false
                collectionTopToFilters?.isActive = false
                collectionTopToBanner?.isActive = true
            } else {
                collectionTopToSubheader?.isActive = false
                collectionTopToBanner?.isActive = false
                collectionTopToFilters?.isActive = true
            }

            if activeFiltersContainer.isHidden {
                activeFiltersContainer.alpha = 0
                activeFiltersContainer.isHidden = false
                UIView.animate(withDuration: 0.3) {
                    self.activeFiltersContainer.alpha = 1
                    self.view.layoutIfNeeded()
                }
            }
        } else {
            activeFiltersContainer.isHidden = true
            collectionTopToFilters?.isActive = false
            if !fallbackBanner.isHidden {
                collectionTopToSubheader?.isActive = false
                collectionTopToBanner?.isActive = true
            } else {
                collectionTopToBanner?.isActive = false
                collectionTopToSubheader?.isActive = true
                collectionTopToSubheader?.constant = DivoDesignTokens.Spacing.m
            }
        }
    }

    func setLoading(_ loading: Bool) {
        isShowingSkeleton = loading
        collectionView.reloadData()
    }

    func showReloadError(title: String, subtitle: String, retry: @escaping () -> Void) {
        collectionView.isHidden = true
        profilesFoundLabel.isHidden = true
        fallbackBanner.isHidden = true
        reloadErrorView.isHidden = false

        reloadErrorView.configure(DivoEmptyStateView.Configuration(
            icon: DivoImage.faceSearchError,
            title: title,
            subtitle: subtitle,
            ctaTitle: DivoStrings.faceSearchRetrySearch,
            onCTATapped: retry,
            iconSize: 68
        ))
        reloadErrorView.animateAppearance()
    }

    func hideReloadError() {
        guard !reloadErrorView.isHidden else { return }
        reloadErrorView.isHidden = true
        collectionView.isHidden = false
        profilesFoundLabel.isHidden = false
    }

    private func showEmptyState() {
        collectionView.isHidden = true
        avatarImageView.isHidden = true
        headerLabel.isHidden = true
        profilesFoundLabel.isHidden = true
        activeFiltersContainer.isHidden = true
        fallbackBanner.isHidden = true
        emptyStateView.isHidden = false

        emptyStateView.configure(DivoEmptyStateView.Configuration(
            icon: DivoImage.faceSearchEmpty,
            title: DivoStrings.faceSearchNoResults,
            subtitle: DivoStrings.faceSearchNoResultsSubtitle,
            ctaTitle: DivoStrings.faceSearchTryDifferentPhoto,
            onCTATapped: { [weak self] in
                self?.onBackPressed?()
            },
            secondaryCtaTitle: DivoStrings.faceSearchBrowseAllProfiles,
            onSecondaryCTATapped: { [weak self] in
                self?.onBrowseAllProfiles?()
            }
        ))
        emptyStateView.animateAppearance()
    }

    private func hideEmptyState() {
        collectionView.isHidden = false
        avatarImageView.isHidden = false
        headerLabel.isHidden = false
        profilesFoundLabel.isHidden = false
        emptyStateView.isHidden = true
    }

    func showFallbackBanner(originalPercent: Int, actualPercent: Int, similarity: Double, originalThreshold: Double) {
        fallbackSimilarity = similarity
        originalSimilarity = originalThreshold
        fallbackLabel.text = DivoStrings.faceSearchFallbackMessage(original: originalPercent, actual: actualPercent)
        self.threshold = originalThreshold
        updateHeaderTexts()
        profilesFoundLabel.text = DivoStrings.faceSearchProfilesFound(0)

        collectionTopToSubheader?.isActive = false
        collectionTopToFilters?.isActive = false
        collectionTopToBanner?.isActive = true

        fallbackBanner.alpha = 0
        fallbackBanner.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.fallbackBanner.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    func showFilterNoResults() {
        collectionView.isHidden = true
        profilesFoundLabel.isHidden = true
        fallbackSimilarity = nil

        fallbackLabel.text = DivoStrings.faceSearchNoResultsWithFilters

        collectionTopToSubheader?.isActive = false
        collectionTopToFilters?.isActive = false
        collectionTopToBanner?.isActive = true

        fallbackBanner.alpha = 0
        fallbackBanner.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.fallbackBanner.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    func hideFallbackBanner() {
        guard !fallbackBanner.isHidden else { return }
        fallbackBanner.isHidden = true
        collectionView.isHidden = false
        profilesFoundLabel.isHidden = false

        collectionTopToBanner?.isActive = false
        if activeFiltersContainer.isHidden {
            collectionTopToFilters?.isActive = false
            collectionTopToSubheader?.isActive = true
            collectionTopToSubheader?.constant = DivoDesignTokens.Spacing.m
        } else {
            collectionTopToSubheader?.isActive = false
            collectionTopToFilters?.isActive = true
        }
    }

    @objc private func backTapped() { onBackPressed?() }
    @objc private func filterTapped() { onFilterPressed?() }
    @objc private func filtersClearTapped() { onFiltersClear?() }
    @objc private func fallbackAcceptTapped() {
        if let similarity = fallbackSimilarity {
            hideFallbackBanner()
            self.threshold = similarity
            updateHeaderTexts()
            view.layoutIfNeeded()
            onFallbackAccept?(similarity)
        } else {
            onFilterPressed?()
        }
    }

    // MARK: - UICollectionView

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        isShowingSkeleton ? skeletonCount : results.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isShowingSkeleton {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SearchResultSkeletonCell.reuseIdentifier, for: indexPath) as! SearchResultSkeletonCell
            cell.setShimmering(true)
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FaceMatchCell", for: indexPath) as! SearchResultGridCell
        let result = results[indexPath.item]
        cell.configure(with: FaceSearchResultsMapper.viewModel(from: result))
        cell.onLikeTapped = { [weak self] feedId, isLiked in
            self?.onLikeTapped?(feedId, isLiked)
        }
        cell.onSaveTapped = { [weak self] userId, isSaved in
            self?.onSaveTapped?(userId, isSaved)
        }
        cell.onShareTapped = { [weak self, weak cell] in
            guard let self, let cell else { return }
            self.onShareTapped?(result, cell.coverImage)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let gap: CGFloat = 10
        let sideInsets = DivoDesignTokens.Spacing.m * 2
        let width = (collectionView.bounds.width - gap - sideInsets) / 2
        return CGSize(width: width, height: 240)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isShowingSkeleton, indexPath.item < results.count else { return }
        onResultTapped?(results[indexPath.item])
    }

    // MARK: - Helpers

    private static func cropFaceSquare(from image: UIImage, bbox: FRBoundingBox, padding: CGFloat) -> UIImage {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return image }

        let faceWidth = CGFloat(bbox.x2 - bbox.x1)
        let faceHeight = CGFloat(bbox.y2 - bbox.y1)
        let side = max(faceWidth, faceHeight) + 2 * padding

        let centerX = CGFloat(bbox.x1 + bbox.x2) / 2
        let centerY = CGFloat(bbox.y1 + bbox.y2) / 2

        var cropX = centerX - side / 2
        var cropY = centerY - side / 2
        var cropSide = side

        cropX = max(0, cropX)
        cropY = max(0, cropY)
        cropSide = min(cropSide, imageSize.width - cropX)
        cropSide = min(cropSide, imageSize.height - cropY)
        guard cropSide > 0 else { return image }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSide, height: cropSide))
        return renderer.image { _ in
            image.draw(at: CGPoint(x: -cropX, y: -cropY))
        }
    }
}
