import Foundation
import UIKit
import CoreImage
import Display
import AsyncDisplayKit
import AccountContext
import TelegramPresentationData
import DivoCore
import DivoUIKit

// MARK: - Detect State

enum FaceDetectState {
    case idle
    case scanning
    case noFaces
    case singleFace(FRFace)
    case multipleFaces([FRFace], selected: Int?)

    var selectedFaceIndex: Int? {
        switch self {
        case .singleFace(let face):
            return face.index
        case .multipleFaces(_, let selected):
            return selected
        default:
            return nil
        }
    }

    var canSearch: Bool {
        return selectedFaceIndex != nil
    }
}

// MARK: - Controller

public final class FaceSearchController: ViewController {
    private static let searchThreshold: Double = 0.3

    private let context: AccountContext
    private var presentationData: PresentationData
    private var selectedImage: UIImage
    private var detectState: FaceDetectState = .idle
    private var isSearching = false

    var onChangePhoto: (() -> Void)?

    public init(context: AccountContext, image: UIImage) {
        self.context = context
        self.selectedImage = image
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = FaceSearchNode(image: self.selectedImage)
        node.onBackPressed = { [weak self] in
            guard let self else { return }
            if let nav = self.navigationController as? NavigationController {
                _ = nav.popViewController(animated: true)
            } else {
                self.dismiss()
            }
        }
        node.onChangePhotoPressed = { [weak self] in
            self?.onChangePhoto?()
        }
        node.onFindPressed = { [weak self] in
            self?.handleFindPressed()
        }
        node.onFaceSelected = { [weak self] index in
            self?.selectFace(index)
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
        faceSearchNode?.applyState(detectState)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if case .idle = detectState {
            runDetect()
        }
    }

    public func updateImage(_ image: UIImage) {
        self.selectedImage = image
        (self.displayNode as? FaceSearchNode)?.updateImage(image)
        runDetect()
    }

    // MARK: - State Machine

    private var faceSearchNode: FaceSearchNode? {
        self.displayNode as? FaceSearchNode
    }

    private func transition(to state: FaceDetectState) {
        self.detectState = state
        faceSearchNode?.applyState(state)
    }

    // MARK: - Detect

    private func runDetect() {
        guard let imageData = selectedImage.jpegData(compressionQuality: 0.85) else { return }

        transition(to: .scanning)

        Task { @MainActor [weak self] in
            do {
                async let response: FRDetectResponse = DivoAPIClient.shared.upload(
                    path: "/fr/detect",
                    fileData: imageData
                )
                async let minimumDelay: Void = Task.sleep(nanoseconds: 1_300_000_000)

                let detectResult = try await response
                _ = try? await minimumDelay
                guard let self else { return }

                switch detectResult.faces.count {
                case 0:
                    self.transition(to: .noFaces)
                case 1:
                    self.transition(to: .singleFace(detectResult.faces[0]))
                default:
                    self.transition(to: .multipleFaces(detectResult.faces, selected: nil))
                }
            } catch {
                guard let self else { return }
                if let apiError = error as? DivoAPIError, case .httpError(let code, _) = apiError, code == 400 {
                    self.transition(to: .noFaces)
                } else {
                    self.transition(to: .idle)
                    self.presentError(for: error) { [weak self] in
                        self?.runDetect()
                    }
                }
            }
        }
    }

    // MARK: - Face Selection

    private func selectFace(_ index: Int) {
        guard case .multipleFaces(let faces, let currentSelected) = detectState else { return }
        let newIndex = (currentSelected == index) ? nil : index
        transition(to: .multipleFaces(faces, selected: newIndex))
    }

    // MARK: - Search

    private func handleFindPressed() {
        guard detectState.canSearch, !isSearching else { return }
        guard let faceIndex = detectState.selectedFaceIndex else { return }
        guard let imageData = selectedImage.jpegData(compressionQuality: 0.85) else { return }

        isSearching = true
        faceSearchNode?.setSearchLoading(true)

        Task { @MainActor [weak self] in
            do {
                async let searchResponse: FRSearchResponse = DivoAPIClient.shared.upload(
                    path: "/fr/search",
                    fileData: imageData,
                    fields: [
                        "face_index": "\(faceIndex)",
                        "top_k": "20",
                        "k_ratio": "\(Self.searchThreshold)"
                    ]
                )
                async let minimumDelay: Void = Task.sleep(nanoseconds: 1_300_000_000)

                let result = try await searchResponse
                _ = try? await minimumDelay
                guard let self else { return }
                self.isSearching = false
                self.faceSearchNode?.setSearchLoading(false)
                self.showResults(result.results, bbox: result.bbox, imageData: imageData, faceIndex: faceIndex)
            } catch {
                guard let self else { return }
                self.isSearching = false
                self.faceSearchNode?.setSearchLoading(false)
                self.presentError(for: error) { [weak self] in
                    self?.handleFindPressed()
                }
            }
        }
    }

    private static func isConnectionFailure(_ error: Error) -> Bool {
        if let apiError = error as? DivoAPIError, case .noInternetConnection = apiError {
            return true
        }
        if error is URLError {
            return true
        }
        return false
    }

    private func presentError(for error: Error, retryAction: @escaping () -> Void) {
        let title: String
        let subtitle: String
        if Self.isConnectionFailure(error) {
            title = DivoStrings.faceSearchInterruptedTitle
            subtitle = DivoStrings.faceSearchInterruptedSubtitle
        } else {
            title = DivoStrings.faceSearchServerErrorTitle
            subtitle = DivoStrings.faceSearchServerErrorSubtitle
        }
        faceSearchNode?.applyError(
            title: title,
            subtitle: subtitle,
            retryTitle: DivoStrings.faceSearchRetrySearch,
            onRetry: retryAction
        )
    }

    private func showResults(_ results: [FRSearchResult], bbox: FRBoundingBox?, imageData: Data, faceIndex: Int) {
        var historyEntryId: String?
        if !results.isEmpty {
            historyEntryId = saveFaceSearchHistory(results: results, bbox: bbox, imageData: imageData, faceIndex: faceIndex)
        }

        var initialFilters = FaceSearchFilterState()
        initialFilters.similarity = Self.searchThreshold
        let controller = FaceSearchResultsController(
            context: self.context,
            imageData: imageData,
            results: results,
            sourceImage: self.selectedImage,
            faceBBox: bbox,
            faceIndex: faceIndex,
            initialFilters: initialFilters,
            historyEntryId: historyEntryId
        )
        if let nav = self.navigationController as? NavigationController {
            nav.pushViewController(controller)
        }
    }

    @discardableResult
    private func saveFaceSearchHistory(results: [FRSearchResult], bbox: FRBoundingBox?, imageData: Data, faceIndex: Int) -> String {
        let faceImage: UIImage
        if let bbox {
            faceImage = FaceSearchResultsMapper.cropFaceSquare(from: selectedImage, bbox: bbox, padding: 16)
        } else {
            faceImage = selectedImage
        }
        let fields: [String: String] = [
            "face_index": "\(faceIndex)",
            "top_k": "20",
            "k_ratio": "\(Self.searchThreshold)"
        ]
        return FaceSearchHistoryStorage.shared.save(
            faceImage: faceImage,
            sourceImageData: imageData,
            resultsCount: results.count,
            faceIndex: faceIndex,
            faceBBox: bbox,
            searchFields: fields
        )
    }
}

// MARK: - Node

private final class FaceSearchNode: ASDisplayNode {
    var onBackPressed: (() -> Void)?
    var onChangePhotoPressed: (() -> Void)?
    var onFindPressed: (() -> Void)?
    var onFaceSelected: ((Int) -> Void)?

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
            string: DivoStrings.faceSearchScreenTitle.uppercased(),
            attributes: [
                .font: Font.helveticaNeue(20),
                .foregroundColor: DivoColorPalette.primaryText,
                .kern: 0.5
            ]
        )
        label.textAlignment = .center
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let photoContainer: UIView = {
        let container = UIView()
        container.clipsToBounds = true
        container.layer.cornerRadius = 32
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }()

    private let photoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let faceOverlayView: FaceOverlayView = {
        let overlay = FaceOverlayView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        return overlay
    }()

    private let scanLineView: ScanLineView = {
        let v = ScanLineView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let faceBanner: UIView = {
        let banner = UIView()
        banner.backgroundColor = DivoColorPalette.cardBackground
        banner.layer.cornerRadius = 16
        banner.layer.borderWidth = 1
        banner.clipsToBounds = true
        banner.alpha = 0
        banner.translatesAutoresizingMaskIntoConstraints = false
        return banner
    }()

    private let faceBannerLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(14)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(14)
        label.textColor = DivoColorPalette.secondaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let changePhotoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(DivoStrings.faceSearchChangePhoto, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(15)
        button.backgroundColor = DivoColorPalette.secondaryButtonBackground
        button.layer.cornerRadius = 20
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        button.addDivoPressState(.secondary)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let findButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(DivoStrings.faceSearchFindProfiles, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(20)
        button.backgroundColor = DivoColorPalette.accent
        button.layer.cornerRadius = 28
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addDivoPressState(.primary)
        return button
    }()

    private let hintLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.3
        style.alignment = .center
        label.attributedText = NSAttributedString(
            string: DivoStrings.faceSearchSortedByScore,
            attributes: [
                .font: Font.regular(12),
                .foregroundColor: DivoColorPalette.secondaryText,
                .paragraphStyle: style
            ]
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Error state

    private let errorContainer: UIView = {
        let v = UIView()
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let errorIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = DivoImage.faceSearchError
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let errorTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 20) ?? Font.bold(20)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let errorSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let retrySearchButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(DivoStrings.faceSearchRetrySearch, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(20)
        button.backgroundColor = DivoColorPalette.accent
        button.layer.cornerRadius = 28
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addDivoPressState(.primary)
        return button
    }()

    private var retryAction: (() -> Void)?
    private var originalPhotoImage: UIImage?
    private var isErrorVisible = false

    private var photoAspectConstraint: NSLayoutConstraint?
    private var photoTopConstraint: NSLayoutConstraint?
    private var photoCenterYConstraint: NSLayoutConstraint?
    private var changeTopWithBanner: NSLayoutConstraint?
    private var changeTopStatusConstraint: NSLayoutConstraint?
    private var currentImageSize: CGSize = .zero

    init(image: UIImage) {
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground
        self.photoImageView.image = image
        self.currentImageSize = image.size
    }

    override func didLoad() {
        super.didLoad()
        setupUI()
        if let image = photoImageView.image {
            applyAspectRatio(for: image)
        }
    }

    func updateImage(_ image: UIImage) {
        originalPhotoImage = nil
        self.photoImageView.image = image
        self.currentImageSize = image.size
        applyAspectRatio(for: image)
        faceOverlayView.configure(faces: [], imageSize: .zero, selectedIndex: nil)
        setBannerVisible(false, animated: false)
        applyState(.idle)
    }

    private func applyAspectRatio(for image: UIImage) {
        photoAspectConstraint?.isActive = false
        photoAspectConstraint = nil

        guard image.size.width > 0, image.size.height > 0 else { return }

        let ratio = image.size.height / image.size.width
        let hc = photoContainer.heightAnchor.constraint(equalTo: photoContainer.widthAnchor, multiplier: ratio)
        hc.priority = UILayoutPriority(751)
        hc.isActive = true
        photoAspectConstraint = hc

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func setupUI() {
        let safeArea = view.safeAreaLayoutGuide

        photoContainer.addSubview(photoImageView)
        photoContainer.addSubview(faceOverlayView)
        photoContainer.addSubview(scanLineView)

        faceBanner.addSubview(faceBannerLabel)

        errorContainer.addSubview(errorIconView)
        errorContainer.addSubview(errorTitleLabel)
        errorContainer.addSubview(errorSubtitleLabel)

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(photoContainer)
        view.addSubview(faceBanner)
        view.addSubview(statusLabel)
        view.addSubview(changePhotoButton)
        view.addSubview(findButton)
        view.addSubview(hintLabel)
        view.addSubview(errorContainer)
        view.addSubview(retrySearchButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: DivoDesignTokens.Spacing.s),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            photoContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            photoContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            photoContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            photoImageView.topAnchor.constraint(equalTo: photoContainer.topAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: photoContainer.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor),
            photoImageView.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor),

            faceOverlayView.topAnchor.constraint(equalTo: photoContainer.topAnchor),
            faceOverlayView.leadingAnchor.constraint(equalTo: photoContainer.leadingAnchor),
            faceOverlayView.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor),
            faceOverlayView.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor),

            scanLineView.topAnchor.constraint(equalTo: photoContainer.topAnchor),
            scanLineView.leadingAnchor.constraint(equalTo: photoContainer.leadingAnchor),
            scanLineView.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor),
            scanLineView.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor),

            faceBanner.topAnchor.constraint(equalTo: photoContainer.bottomAnchor, constant: 10),
            faceBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            faceBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            faceBanner.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),

            faceBannerLabel.topAnchor.constraint(equalTo: faceBanner.topAnchor, constant: 8),
            faceBannerLabel.bottomAnchor.constraint(equalTo: faceBanner.bottomAnchor, constant: -8),
            faceBannerLabel.leadingAnchor.constraint(equalTo: faceBanner.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            faceBannerLabel.trailingAnchor.constraint(equalTo: faceBanner.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            statusLabel.topAnchor.constraint(equalTo: photoContainer.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.l),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.l),

            changePhotoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            changePhotoButton.heightAnchor.constraint(equalToConstant: 40),
            changePhotoButton.bottomAnchor.constraint(lessThanOrEqualTo: findButton.topAnchor, constant: -DivoDesignTokens.Spacing.m),

            hintLabel.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.l),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.l),

            findButton.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -DivoDesignTokens.Spacing.s),
            findButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.l),
            findButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.l),
            findButton.heightAnchor.constraint(equalToConstant: 56),

            retrySearchButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            retrySearchButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.l),
            retrySearchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.l),
            retrySearchButton.heightAnchor.constraint(equalToConstant: 56),

            errorContainer.topAnchor.constraint(greaterThanOrEqualTo: photoContainer.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            errorContainer.bottomAnchor.constraint(lessThanOrEqualTo: retrySearchButton.topAnchor, constant: -DivoDesignTokens.Spacing.m),
            errorContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.l),
            errorContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.l),

            errorIconView.topAnchor.constraint(equalTo: errorContainer.topAnchor),
            errorIconView.centerXAnchor.constraint(equalTo: errorContainer.centerXAnchor),
            errorIconView.widthAnchor.constraint(equalToConstant: 68),
            errorIconView.heightAnchor.constraint(equalToConstant: 68),

            errorTitleLabel.topAnchor.constraint(equalTo: errorIconView.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            errorTitleLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor),
            errorTitleLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor),
            errorTitleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),

            errorSubtitleLabel.topAnchor.constraint(equalTo: errorTitleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.xs),
            errorSubtitleLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor),
            errorSubtitleLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor),
            errorSubtitleLabel.bottomAnchor.constraint(equalTo: errorContainer.bottomAnchor),
        ])

        let errorResting = errorContainer.topAnchor.constraint(equalTo: photoContainer.bottomAnchor, constant: 60)
        errorResting.priority = UILayoutPriority(250)
        errorResting.isActive = true

        let preferredWidth = photoContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m)
        preferredWidth.priority = UILayoutPriority(750)
        preferredWidth.isActive = true
        let preferredTrailing = photoContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m)
        preferredTrailing.priority = UILayoutPriority(750)
        preferredTrailing.isActive = true

        photoTopConstraint = photoContainer.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: DivoDesignTokens.Spacing.l)
        photoTopConstraint?.isActive = true

        photoCenterYConstraint = photoContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20)
        photoCenterYConstraint?.isActive = false

        let changeTopPhoto = changePhotoButton.topAnchor.constraint(greaterThanOrEqualTo: photoContainer.bottomAnchor, constant: 16)
        changeTopPhoto.isActive = true
        changeTopStatusConstraint = changePhotoButton.topAnchor.constraint(greaterThanOrEqualTo: statusLabel.bottomAnchor, constant: 16)
        let changeTopResting = changePhotoButton.topAnchor.constraint(equalTo: photoContainer.bottomAnchor, constant: 16)
        changeTopResting.priority = UILayoutPriority(250)
        changeTopResting.isActive = true
        changeTopWithBanner = changePhotoButton.topAnchor.constraint(greaterThanOrEqualTo: faceBanner.bottomAnchor, constant: 16)

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        changePhotoButton.addTarget(self, action: #selector(changePhotoTapped), for: .touchUpInside)
        findButton.addTarget(self, action: #selector(findTapped), for: .touchUpInside)
        retrySearchButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        faceOverlayView.onFaceSelected = { [weak self] index in
            self?.onFaceSelected?(index)
        }
    }

    // MARK: - State Application

    func applyState(_ state: FaceDetectState) {
        clearErrorIfNeeded()
        findButton.isHidden = false
        changePhotoButton.isHidden = false
        hintLabel.isHidden = false
        photoTopConstraint?.isActive = true
        photoCenterYConstraint?.isActive = false
        statusLabel.attributedText = nil
        statusLabel.text = nil
        changeTopStatusConstraint?.isActive = false

        switch state {
        case .idle:
            setScanningVisible(false)
            setBannerVisible(false, animated: true)
            statusLabel.alpha = 0
            findButton.isEnabled = false
            changePhotoButton.isEnabled = true
            hintLabel.alpha = 1
            faceOverlayView.configure(faces: [], imageSize: .zero, selectedIndex: nil)

        case .scanning:
            setScanningVisible(true)
            setBannerVisible(false, animated: true)
            statusLabel.alpha = 0
            findButton.isEnabled = false
            changePhotoButton.isEnabled = false
            hintLabel.alpha = 0
            faceOverlayView.configure(faces: [], imageSize: .zero, selectedIndex: nil)

        case .noFaces:
            setScanningVisible(false)
            setBannerVisible(false, animated: true)
            statusLabel.attributedText = makeNoFacesText()
            statusLabel.alpha = 1
            changeTopStatusConstraint?.isActive = true
            findButton.isEnabled = false
            changePhotoButton.isEnabled = true
            hintLabel.attributedText = makeBottomText(DivoStrings.faceSearchSortedByScore)
            hintLabel.alpha = 1
            faceOverlayView.configure(faces: [], imageSize: .zero, selectedIndex: nil)

        case .singleFace(let face):
            setScanningVisible(false)
            faceBannerLabel.text = DivoStrings.faceSearchFaceSelected
            applySelectedBannerStyle()
            setBannerVisible(true, animated: true)
            statusLabel.alpha = 0
            findButton.isEnabled = true
            changePhotoButton.isEnabled = true
            hintLabel.attributedText = makeBottomText(DivoStrings.faceSearchSortedByScore)
            hintLabel.alpha = 1
            faceOverlayView.configure(faces: [face], imageSize: currentImageSize, selectedIndex: face.index)

        case .multipleFaces(let faces, let selected):
            setScanningVisible(false)
            let hasSelection = selected != nil
            faceBannerLabel.text = hasSelection
                ? DivoStrings.faceSearchFaceSelected
                : DivoStrings.faceSearchMultipleFaces(faces.count)
            if hasSelection {
                applySelectedBannerStyle()
            } else {
                applyMultipleBannerStyle()
            }
            setBannerVisible(true, animated: true)
            statusLabel.alpha = 0
            findButton.isEnabled = hasSelection
            changePhotoButton.isEnabled = true
            hintLabel.attributedText = makeBottomText(DivoStrings.faceSearchSortedByScore)
            hintLabel.alpha = 1
            faceOverlayView.configure(faces: faces, imageSize: currentImageSize, selectedIndex: selected)
        }
    }

    private func applySelectedBannerStyle() {
        faceBanner.backgroundColor = DivoColorPalette.cardBackground
        faceBanner.layer.borderColor = DivoColorPalette.primaryText.withAlphaComponent(0.1).cgColor
    }

    private func applyMultipleBannerStyle() {
        faceBanner.backgroundColor = DivoColorPalette.faceBannerMultipleBackground
        faceBanner.layer.borderColor = DivoColorPalette.accent.withAlphaComponent(0.5).cgColor
    }

    private func setBannerVisible(_ visible: Bool, animated: Bool) {
        let targetAlpha: CGFloat = visible ? 1 : 0
        let needsLayoutChange = (changeTopWithBanner?.isActive ?? false) != visible
        guard faceBanner.alpha != targetAlpha || needsLayoutChange else { return }

        changeTopWithBanner?.isActive = visible

        if visible {
            faceBanner.transform = CGAffineTransform(translationX: 0, y: -6)
        }

        let block = {
            self.faceBanner.alpha = targetAlpha
            self.faceBanner.transform = .identity
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                usingSpringWithDamping: 0.88,
                initialSpringVelocity: 0.2,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: block
            )
        } else {
            block()
        }
    }

    func setSearchLoading(_ loading: Bool) {
        if loading {
            clearErrorIfNeeded()
            setScanningVisible(true)
            faceOverlayView.configure(faces: [], imageSize: .zero, selectedIndex: nil)
            setSearchCenteredLayout(true)
        } else {
            setScanningVisible(false)
            setSearchCenteredLayout(false)
            statusLabel.attributedText = nil
            statusLabel.text = nil
            statusLabel.alpha = 0
        }
    }

    // MARK: - Error state

    func applyError(
        title: String,
        subtitle: String,
        retryTitle: String,
        onRetry: @escaping () -> Void
    ) {
        isErrorVisible = true
        retryAction = onRetry

        errorTitleLabel.text = title.uppercased()
        errorSubtitleLabel.text = subtitle
        retrySearchButton.setTitle(retryTitle, for: .normal)

        setScanningVisible(false)
        setBannerVisible(false, animated: false)
        setSearchCenteredLayout(false)

        statusLabel.attributedText = nil
        statusLabel.text = nil
        statusLabel.alpha = 0
        faceOverlayView.configure(faces: [], imageSize: .zero, selectedIndex: nil)

        findButton.isHidden = true
        changePhotoButton.isHidden = true
        hintLabel.isHidden = true

        setPhotoDesaturated(true)

        errorContainer.isHidden = false
        retrySearchButton.isHidden = false
        view.bringSubviewToFront(errorContainer)
        view.bringSubviewToFront(retrySearchButton)
    }

    private func clearErrorIfNeeded() {
        guard isErrorVisible else { return }
        isErrorVisible = false
        retryAction = nil
        errorContainer.isHidden = true
        retrySearchButton.isHidden = true
        setPhotoDesaturated(false)
    }

    private func setPhotoDesaturated(_ desaturated: Bool) {
        if desaturated {
            guard originalPhotoImage == nil, let image = photoImageView.image else { return }
            originalPhotoImage = image
            guard let ci = CIImage(image: image) else { return }
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(ci, forKey: kCIInputImageKey)
            filter?.setValue(0.15, forKey: "inputSaturation")
            filter?.setValue(-0.05, forKey: "inputBrightness")
            guard let output = filter?.outputImage,
                  let cg = CIContext().createCGImage(output, from: output.extent) else { return }
            photoImageView.image = UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
        } else {
            if let original = originalPhotoImage {
                photoImageView.image = original
                originalPhotoImage = nil
            }
        }
    }

    // MARK: - Helpers

    private func setScanningVisible(_ visible: Bool) {
        if visible {
            scanLineView.isHidden = false
            scanLineView.startAnimating()
        } else {
            scanLineView.stopAnimating()
            scanLineView.isHidden = true
        }
    }

    private func setSearchCenteredLayout(_ centered: Bool) {
        if centered {
            statusLabel.attributedText = nil
            statusLabel.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 20) ?? Font.bold(20)
            statusLabel.textColor = DivoColorPalette.primaryText
            statusLabel.text = DivoStrings.faceSearchScanning
            statusLabel.alpha = 1
            view.bringSubviewToFront(statusLabel)
            setBannerVisible(false, animated: false)
        }

        photoTopConstraint?.isActive = !centered
        photoCenterYConstraint?.isActive = centered
        findButton.isHidden = centered
        changePhotoButton.isHidden = centered
        hintLabel.isHidden = centered

        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            if centered {
                self?.statusLabel.alpha = 1
            }
        })
    }

    private func makeNoFacesText() -> NSAttributedString {
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .center
        titleStyle.lineHeightMultiple = 1.0
        titleStyle.paragraphSpacing = 8

        let descStyle = NSMutableParagraphStyle()
        descStyle.alignment = .center
        descStyle.lineHeightMultiple = 1.3
        descStyle.paragraphSpacing = 2

        let bulletStyle = NSMutableParagraphStyle()
        bulletStyle.alignment = .center
        bulletStyle.lineHeightMultiple = 1.3

        let result = NSMutableAttributedString()

        let titleFont = UIFont(name: "HelveticaNeue-CondensedBold", size: 20) ?? Font.bold(20)
        result.append(NSAttributedString(
            string: DivoStrings.faceSearchNoFaceDetected,
            attributes: [
                .font: titleFont,
                .foregroundColor: DivoColorPalette.primaryText,
                .paragraphStyle: titleStyle
            ]
        ))

        result.append(NSAttributedString(string: "\n"))

        let descFont = UIFont(name: "HelveticaNeue", size: 14) ?? Font.regular(14)
        result.append(NSAttributedString(
            string: DivoStrings.faceSearchNoFaceDescription,
            attributes: [
                .font: descFont,
                .foregroundColor: DivoColorPalette.primaryText,
                .paragraphStyle: descStyle
            ]
        ))

        let bulletSpacingStyle = NSMutableParagraphStyle()
        bulletSpacingStyle.alignment = .center
        bulletSpacingStyle.lineHeightMultiple = 1.0
        bulletSpacingStyle.paragraphSpacingBefore = 12
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 2),
            .paragraphStyle: bulletSpacingStyle
        ]))

        let bulletFont = UIFont(name: "HelveticaNeue", size: 12) ?? Font.regular(12)
        let bulletColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        let bullets = [DivoStrings.faceSearchNoFaceBullet1, DivoStrings.faceSearchNoFaceBullet2]
        for (i, bullet) in bullets.enumerated() {
            result.append(NSAttributedString(
                string: "· " + bullet + (i < bullets.count - 1 ? "\n" : ""),
                attributes: [
                    .font: bulletFont,
                    .foregroundColor: bulletColor,
                    .paragraphStyle: bulletStyle
                ]
            ))
        }

        return result
    }

    private func makeBottomText(_ text: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.3
        style.alignment = .center
        return NSAttributedString(
            string: text,
            attributes: [
                .font: Font.regular(12),
                .foregroundColor: DivoColorPalette.secondaryText,
                .paragraphStyle: style
            ]
        )
    }

    // MARK: - Actions

    @objc private func backTapped() { onBackPressed?() }
    @objc private func changePhotoTapped() { onChangePhotoPressed?() }
    @objc private func findTapped() { onFindPressed?() }
    @objc private func retryTapped() { retryAction?() }
}
