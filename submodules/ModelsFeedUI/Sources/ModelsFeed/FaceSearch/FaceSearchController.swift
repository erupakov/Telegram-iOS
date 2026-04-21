import Foundation
import UIKit
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
    private let context: AccountContext
    private var presentationData: PresentationData
    private var selectedImage: UIImage
    private var detectState: FaceDetectState = .idle
    private var detectResponse: FRDetectResponse?
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
        self.detectResponse = nil
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

        faceSearchNode?.hideSnackbar()
        transition(to: .scanning)

        Task { @MainActor in
            do {
                let response: FRDetectResponse = try await DivoAPIClient.shared.upload(
                    path: "/fr/detect",
                    fileData: imageData
                )
                self.detectResponse = response

                switch response.faces.count {
                case 0:
                    self.transition(to: .noFaces)
                case 1:
                    self.transition(to: .singleFace(response.faces[0]))
                default:
                    self.transition(to: .multipleFaces(response.faces, selected: nil))
                }
            } catch {
                if Self.isNoFaceError(error) {
                    self.transition(to: .noFaces)
                } else {
                    self.transition(to: .idle)
                    self.showNetworkError(error) { [weak self] in
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
        faceSearchNode?.hideSnackbar()
        faceSearchNode?.setSearchLoading(true)

        Task { @MainActor in
            do {
                let searchResponse: FRSearchResponse = try await DivoAPIClient.shared.upload(
                    path: "/fr/search",
                    fileData: imageData,
                    fields: [
                        "face_index": "\(faceIndex)",
                        "top_k": "20",
                        "k_ratio": "0.3"
                    ]
                )

                self.isSearching = false
                self.faceSearchNode?.setSearchLoading(false)
                self.showResults(searchResponse.results, detectResponse: self.detectResponse)
            } catch {
                self.isSearching = false
                self.faceSearchNode?.setSearchLoading(false)
                self.showNetworkError(error) { [weak self] in
                    self?.handleFindPressed()
                }
            }
        }
    }

    private static func isNoFaceError(_ error: Error) -> Bool {
        guard let apiError = error as? DivoAPIError,
              case .httpError(statusCode: 400, body: let body) = apiError else {
            return false
        }
        return body.contains("No face detected") || body.contains("no face")
    }

    private func showNetworkError(_ error: Error, retryAction: @escaping () -> Void) {
        let message: String
        if let apiError = error as? DivoAPIError, case .noInternetConnection = apiError {
            message = DivoStrings.faceSearchErrorNoInternet
        } else {
            message = DivoStrings.faceSearchErrorGeneric
        }
        faceSearchNode?.showSnackbar(
            message: message,
            retryAction: retryAction
        )
    }

    private func showResults(_ results: [FRSearchResult], detectResponse: FRDetectResponse?) {
        let controller = FaceSearchResultsController(
            context: self.context,
            results: results
        )
        if let nav = self.navigationController as? NavigationController {
            nav.pushViewController(controller)
        }
    }
}

// MARK: - Node

private final class FaceSearchNode: ASDisplayNode {
    var onBackPressed: (() -> Void)?
    var onChangePhotoPressed: (() -> Void)?
    var onFindPressed: (() -> Void)?
    var onFaceSelected: ((Int) -> Void)?

    private let snackbar = DivoSnackbar()

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
        banner.backgroundColor = DivoColorPalette.accent
        banner.isHidden = true
        banner.translatesAutoresizingMaskIntoConstraints = false
        return banner
    }()

    private let faceBannerLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(14)
        label.textColor = .white
        label.textAlignment = .center
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
        button.setTitleColor(DivoColorPalette.disabledText, for: .disabled)
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

    private var photoAspectConstraint: NSLayoutConstraint?
    private var photoTopConstraint: NSLayoutConstraint?
    private var photoCenterYConstraint: NSLayoutConstraint?
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
        self.photoImageView.image = image
        self.currentImageSize = image.size
        applyAspectRatio(for: image)
        faceOverlayView.clearErrorBorder()
        faceOverlayView.configure(faces: [], imageSize: .zero, selectedIndex: nil)
        faceBanner.isHidden = true
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
        photoContainer.addSubview(faceBanner)

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(photoContainer)
        view.addSubview(statusLabel)
        view.addSubview(changePhotoButton)
        view.addSubview(findButton)
        view.addSubview(hintLabel)

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
            photoContainer.bottomAnchor.constraint(lessThanOrEqualTo: changePhotoButton.topAnchor, constant: -(DivoDesignTokens.Spacing.m + DivoDesignTokens.Spacing.s)),

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

            faceBanner.leadingAnchor.constraint(equalTo: photoContainer.leadingAnchor),
            faceBanner.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor),
            faceBanner.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor),
            faceBanner.heightAnchor.constraint(equalToConstant: 48),

            faceBannerLabel.centerXAnchor.constraint(equalTo: faceBanner.centerXAnchor),
            faceBannerLabel.centerYAnchor.constraint(equalTo: faceBanner.centerYAnchor),
            faceBannerLabel.leadingAnchor.constraint(greaterThanOrEqualTo: faceBanner.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            faceBannerLabel.trailingAnchor.constraint(lessThanOrEqualTo: faceBanner.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            statusLabel.topAnchor.constraint(equalTo: photoContainer.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.l),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.l),

            changePhotoButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
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
        ])

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

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        changePhotoButton.addTarget(self, action: #selector(changePhotoTapped), for: .touchUpInside)
        findButton.addTarget(self, action: #selector(findTapped), for: .touchUpInside)

        faceOverlayView.onFaceSelected = { [weak self] index in
            self?.onFaceSelected?(index)
        }
    }

    // MARK: - State Application

    func applyState(_ state: FaceDetectState) {
        faceOverlayView.clearErrorBorder()
        findButton.isHidden = false
        changePhotoButton.isHidden = false
        hintLabel.isHidden = false
        photoTopConstraint?.isActive = true
        photoCenterYConstraint?.isActive = false
        statusLabel.attributedText = nil
        statusLabel.text = nil

        switch state {
        case .idle:
            setScanningVisible(false)
            faceBanner.isHidden = true
            statusLabel.alpha = 0
            findButton.isEnabled = false
            findButton.backgroundColor = DivoColorPalette.buttonDisabledBackground
            changePhotoButton.isEnabled = true
            hintLabel.alpha = 1
            faceOverlayView.configure(faces: [], imageSize: .zero, selectedIndex: nil)

        case .scanning:
            setScanningVisible(true)
            faceBanner.isHidden = true
            statusLabel.alpha = 0
            findButton.isEnabled = false
            findButton.backgroundColor = DivoColorPalette.buttonDisabledBackground
            changePhotoButton.isEnabled = false
            hintLabel.alpha = 0
            faceOverlayView.configure(faces: [], imageSize: .zero, selectedIndex: nil)

        case .noFaces:
            setScanningVisible(false)
            faceBanner.isHidden = true
            statusLabel.attributedText = makeNoFacesText()
            statusLabel.alpha = 1
            findButton.isEnabled = false
            findButton.backgroundColor = DivoColorPalette.buttonDisabledBackground
            changePhotoButton.isEnabled = true
            hintLabel.attributedText = makeBottomText(DivoStrings.faceSearchSortedByScore)
            hintLabel.alpha = 1
            faceOverlayView.showErrorBorder()

        case .singleFace(let face):
            setScanningVisible(false)
            faceBannerLabel.text = DivoStrings.faceSearchFaceSelected
            faceBanner.backgroundColor = .white
            faceBannerLabel.textColor = DivoColorPalette.primaryText
            faceBanner.isHidden = false
            statusLabel.alpha = 0
            findButton.isEnabled = true
            findButton.backgroundColor = DivoColorPalette.accent
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
            faceBanner.backgroundColor = hasSelection ? .white : DivoColorPalette.accent
            faceBannerLabel.textColor = hasSelection ? DivoColorPalette.primaryText : .white
            faceBanner.isHidden = false
            statusLabel.alpha = 0
            findButton.isEnabled = hasSelection
            findButton.backgroundColor = hasSelection ? DivoColorPalette.accent : DivoColorPalette.buttonDisabledBackground
            changePhotoButton.isEnabled = true
            hintLabel.attributedText = makeBottomText(DivoStrings.faceSearchSortedByScore)
            hintLabel.alpha = 1
            faceOverlayView.configure(faces: faces, imageSize: currentImageSize, selectedIndex: selected)
        }
    }

    func setSearchLoading(_ loading: Bool) {
        if loading {
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
            faceBanner.isHidden = true
        }

        photoTopConstraint?.isActive = !centered
        photoCenterYConstraint?.isActive = centered
        findButton.isHidden = centered
        changePhotoButton.isHidden = centered
        hintLabel.isHidden = centered

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
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

    // MARK: - Snackbar

    func showSnackbar(message: String, retryAction: @escaping () -> Void) {
        snackbar.show(
            in: view,
            message: message,
            style: .error,
            bottomInset: 0,
            bottomAnchor: findButton.bottomAnchor,
            retryTitle: DivoStrings.faceSearchRetry,
            retryAction: retryAction,
            persistent: true
        )
    }

    func hideSnackbar() {
        snackbar.hide(animated: true)
    }

    // MARK: - Actions

    @objc private func backTapped() { onBackPressed?() }
    @objc private func changePhotoTapped() { onChangePhotoPressed?() }
    @objc private func findTapped() { onFindPressed?() }
}
