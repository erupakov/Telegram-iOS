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
    private let results: [FRSearchResult]
    private let sourceImage: UIImage?
    private let threshold: Double

    init(
        context: AccountContext,
        results: [FRSearchResult],
        sourceImage: UIImage?,
        threshold: Double
    ) {
        self.context = context
        self.results = results
        self.sourceImage = sourceImage
        self.threshold = threshold
        super.init(navigationBarPresentationData: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        let node = FaceSearchResultsNode(
            results: self.results,
            sourceImage: self.sourceImage,
            threshold: self.threshold
        )
        node.onBackPressed = { [weak self] in
            guard let self else { return }
            if let nav = self.navigationController as? NavigationController {
                _ = nav.popViewController(animated: true)
            } else {
                self.dismiss()
            }
        }
        node.onResultTapped = { [weak self] result in
            self?.openProfile(for: result)
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
    }

    private func openProfile(for result: FRSearchResult) {
        let mainImageURL = result.image.flatMap(URL.init(string:))
        let model = ProfileModel(
            name: result.fullName ?? "",
            age: FaceSearchResultsMapper.computeAge(from: result.birthday) ?? 0,
            location: FaceSearchResultsMapper.hardcodedCountry,
            isVerified: false,
            likesCount: "0",
            viewsCount: "0",
            savesCount: "0",
            biography: "",
            socialMediaHandles: [],
            userId: result.userId,
            role: nil,
            mainImageURL: mainImageURL,
            avatarImageURL: mainImageURL
        )
        let controller = PublicProfileScreenController(context: self.context, model: model)
        (self.navigationController as? NavigationController)?.pushViewController(controller, animated: true)
    }
}

// MARK: - Mapper

enum FaceSearchResultsMapper {
    static let hardcodedCountry = "🇺🇸 USA"
    static let rolePlaceholder = "Ждём сервер"

    static func computeAge(from birthday: String?) -> Int? {
        guard let birthday, !birthday.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: birthday) else { return nil }
        return Calendar.current.dateComponents([.year], from: date, to: Date()).year
    }

    static func viewModel(from result: FRSearchResult) -> SearchCardViewModel {
        let age = computeAge(from: result.birthday)
        let infoText: String
        if let age {
            infoText = "\(age) y.o" + " • " + hardcodedCountry
        } else {
            infoText = hardcodedCountry
        }
        return SearchCardViewModel(
            variant: .faceMatch(percent: result.score),
            feedId: nil,
            userId: result.userId,
            name: result.fullName,
            infoText: infoText,
            roleLabel: rolePlaceholder,
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
    var onResultTapped: ((FRSearchResult) -> Void)?

    private let results: [FRSearchResult]
    private let sourceImage: UIImage?
    private let threshold: Double

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

    // MARK: Header row (avatar + results count + threshold)

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

    // MARK: Sub-header ("N profiles found" + "Sorted by: match")

    private let profilesFoundLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let sortedByLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: Grid + empty

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

    init(results: [FRSearchResult], sourceImage: UIImage?, threshold: Double) {
        self.results = results
        self.sourceImage = sourceImage
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
        view.addSubview(sortedByLabel)
        view.addSubview(collectionView)
        view.addSubview(emptyStateView)

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

            sortedByLabel.centerYAnchor.constraint(equalTo: profilesFoundLabel.centerYAnchor),
            sortedByLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            collectionView.topAnchor.constraint(equalTo: profilesFoundLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.topAnchor.constraint(equalTo: backButton.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        collectionView.contentInset = UIEdgeInsets(
            top: 0,
            left: DivoDesignTokens.Spacing.m,
            bottom: DivoDesignTokens.Spacing.m,
            right: DivoDesignTokens.Spacing.m
        )

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }

    private func applyContent() {
        avatarImageView.image = sourceImage

        let percent = Int((threshold * 100).rounded())
        let resultsCountText = DivoStrings.faceSearchResultsCount(results.count)
        let thresholdText = DivoStrings.faceSearchSimilarityThreshold(percent)
        headerLabel.text = "\(resultsCountText) · \(thresholdText)"

        profilesFoundLabel.text = DivoStrings.faceSearchProfilesFound(results.count)

        let sortedByAttr = NSMutableAttributedString(
            string: DivoStrings.faceSearchSortedBy + " ",
            attributes: [.foregroundColor: DivoColorPalette.systemLabelPlaceholder]
        )
        sortedByAttr.append(NSAttributedString(
            string: DivoStrings.faceSearchSortMatch,
            attributes: [.foregroundColor: DivoColorPalette.primaryText]
        ))
        sortedByLabel.attributedText = sortedByAttr

        if results.isEmpty {
            showEmptyState()
        }
    }

    private func showEmptyState() {
        collectionView.isHidden = true
        avatarImageView.isHidden = true
        headerLabel.isHidden = true
        profilesFoundLabel.isHidden = true
        sortedByLabel.isHidden = true
        emptyStateView.isHidden = false

        emptyStateView.configure(DivoEmptyStateView.Configuration(
            icon: DivoImage.faceSearchEmpty,
            title: DivoStrings.faceSearchNoResults,
            subtitle: DivoStrings.faceSearchNoResultsSubtitle,
            ctaTitle: DivoStrings.faceSearchTryDifferentPhoto,
            onCTATapped: { [weak self] in
                self?.onBackPressed?()
            }
        ))
        emptyStateView.animateAppearance()
    }

    @objc private func backTapped() { onBackPressed?() }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        results.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FaceMatchCell", for: indexPath) as! SearchResultGridCell
        let result = results[indexPath.item]
        cell.configure(with: FaceSearchResultsMapper.viewModel(from: result))
        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let gap: CGFloat = 10
        let sideInsets = DivoDesignTokens.Spacing.m * 2
        let width = (collectionView.bounds.width - gap - sideInsets) / 2
        return CGSize(width: width, height: 240)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < results.count else { return }
        onResultTapped?(results[indexPath.item])
    }
}
