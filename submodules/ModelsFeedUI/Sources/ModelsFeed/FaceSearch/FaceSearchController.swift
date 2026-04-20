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
    private let selectedImage: UIImage

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
        node.onFindPressed = {
            // TODO: send photo to face search API
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
    }

    public func updateImage(_ image: UIImage) {
        (self.displayNode as? FaceSearchNode)?.updateImage(image)
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

    private let photoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 32
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
        let constraint = photoImageView.heightAnchor.constraint(equalTo: photoImageView.widthAnchor, multiplier: ratio)
        constraint.priority = .defaultHigh
        constraint.isActive = true
        photoAspectConstraint = constraint
    }

    private func setupUI() {
        let safeArea = view.safeAreaLayoutGuide

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(photoImageView)
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

            photoImageView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: DivoDesignTokens.Spacing.l),
            photoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            photoImageView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            photoImageView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            photoImageView.bottomAnchor.constraint(lessThanOrEqualTo: findButton.topAnchor, constant: -(DivoDesignTokens.Spacing.m + 40 + DivoDesignTokens.Spacing.s)),

            changePhotoButton.topAnchor.constraint(equalTo: photoImageView.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
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

        let preferredWidth = photoImageView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -2 * DivoDesignTokens.Spacing.m)
        preferredWidth.priority = .defaultLow
        preferredWidth.isActive = true

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        changePhotoButton.addTarget(self, action: #selector(changePhotoTapped), for: .touchUpInside)
        findButton.addTarget(self, action: #selector(findTapped), for: .touchUpInside)
    }

    @objc private func backTapped() { onBackPressed?() }
    @objc private func changePhotoTapped() { onChangePhotoPressed?() }
    @objc private func findTapped() { onFindPressed?() }
}
