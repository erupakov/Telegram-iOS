import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import TelegramPresentationData
import DivoCore
import DivoUIKit

public final class FaceSearchController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var selectedImage: UIImage
    private var isLoading = false

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
            self?.startFaceSearch()
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
    }

    public func updateImage(_ image: UIImage) {
        self.selectedImage = image
        (self.displayNode as? FaceSearchNode)?.updateImage(image)
    }

    // MARK: - Face Search Flow

    private var faceSearchNode: FaceSearchNode? {
        self.displayNode as? FaceSearchNode
    }

    private func startFaceSearch() {
        guard !isLoading else { return }
        guard let imageData = selectedImage.jpegData(compressionQuality: 0.85) else { return }

        isLoading = true
        faceSearchNode?.setLoading(true)

        Task { @MainActor in
            do {
                let detectResponse: FRDetectResponse = try await DivoAPIClient.shared.upload(
                    path: "/fr/detect",
                    fileData: imageData
                )

                guard !detectResponse.faces.isEmpty else {
                    self.showNoFacesAlert()
                    self.finishLoading()
                    return
                }

                let faceIndex = 0
                let searchResponse: FRSearchResponse = try await DivoAPIClient.shared.upload(
                    path: "/fr/search",
                    fileData: imageData,
                    fields: [
                        "face_index": "\(faceIndex)",
                        "top_k": "20",
                        "k_ratio": "0.3"
                    ]
                )

                self.finishLoading()
                self.showResults(searchResponse.results, detectResponse: detectResponse)
            } catch {
                self.finishLoading()
                self.showErrorAlert(error)
            }
        }
    }

    private func finishLoading() {
        isLoading = false
        faceSearchNode?.setLoading(false)
    }

    private func showNoFacesAlert() {
        let alert = UIAlertController(
            title: DivoStrings.faceSearchNoFacesTitle,
            message: DivoStrings.faceSearchNoFacesMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    private func showErrorAlert(_ error: Error) {
        let alert = UIAlertController(
            title: DivoStrings.faceSearchErrorTitle,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    private func showResults(_ results: [FRSearchResult], detectResponse: FRDetectResponse) {
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
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let photoContainer: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }()

    private let photoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 32
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
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

    private var photoAspectConstraint: NSLayoutConstraint?

    init(image: UIImage) {
        super.init()
        self.backgroundColor = DivoColorPalette.cardBackground
        self.photoImageView.image = image
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
        applyAspectRatio(for: image)
    }

    private func applyAspectRatio(for image: UIImage) {
        photoAspectConstraint?.isActive = false
        guard image.size.width > 0 else { return }
        let ratio = image.size.height / image.size.width
        let constraint = photoContainer.heightAnchor.constraint(equalTo: photoContainer.widthAnchor, multiplier: ratio)
        constraint.priority = .defaultHigh
        constraint.isActive = true
        photoAspectConstraint = constraint
    }

    private func setupUI() {
        let safeArea = view.safeAreaLayoutGuide

        photoContainer.addSubview(photoImageView)

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(photoContainer)
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

            photoContainer.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: DivoDesignTokens.Spacing.l),
            photoContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            photoContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            photoContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            photoContainer.bottomAnchor.constraint(lessThanOrEqualTo: findButton.topAnchor, constant: -(DivoDesignTokens.Spacing.m + 40 + DivoDesignTokens.Spacing.s)),

            photoImageView.topAnchor.constraint(equalTo: photoContainer.topAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: photoContainer.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor),
            photoImageView.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor),

            changePhotoButton.topAnchor.constraint(equalTo: photoContainer.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            changePhotoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            changePhotoButton.heightAnchor.constraint(equalToConstant: 40),

            hintLabel.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.l),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.l),

            findButton.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -DivoDesignTokens.Spacing.s),
            findButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.l),
            findButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.l),
            findButton.heightAnchor.constraint(equalToConstant: 56),
        ])

        let preferredWidth = photoContainer.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -2 * DivoDesignTokens.Spacing.m)
        preferredWidth.priority = .defaultLow
        preferredWidth.isActive = true

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        changePhotoButton.addTarget(self, action: #selector(changePhotoTapped), for: .touchUpInside)
        findButton.addTarget(self, action: #selector(findTapped), for: .touchUpInside)
    }

    func setLoading(_ loading: Bool) {
        findButton.isEnabled = !loading
        changePhotoButton.isEnabled = !loading
        if loading {
            findButton.setTitle(nil, for: .normal)
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = .white
            spinner.tag = 999
            spinner.translatesAutoresizingMaskIntoConstraints = false
            findButton.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: findButton.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: findButton.centerYAnchor)
            ])
            spinner.startAnimating()
        } else {
            findButton.setTitle(DivoStrings.faceSearchFindProfiles, for: .normal)
            if let spinner = findButton.viewWithTag(999) as? UIActivityIndicatorView {
                spinner.stopAnimating()
                spinner.removeFromSuperview()
            }
        }
    }

    @objc private func backTapped() { onBackPressed?() }
    @objc private func changePhotoTapped() { onChangePhotoPressed?() }
    @objc private func findTapped() { onFindPressed?() }
}
