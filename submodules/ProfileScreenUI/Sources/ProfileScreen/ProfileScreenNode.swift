import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import Postbox

final class ProfileScreenNode: ASDisplayNode {
    
    private let model: ProfileModel
    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData

    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let iconPlaceholder = "HeartActionIcon"
    
    private let uploadAvatar: () -> Void
    private let uploadPortfolioItem: () -> Void
    private let openEditLink: () -> Void
    
    private let openGallery: (Int) -> Void
    
    private let scrollView = UIScrollView()
    
    enum PhotoItem {
        case telegram(TelegramMediaImage)
        case local(UIImage, Date)
        case uploading(UIImage)
    }
    
    var localPhotos: [PhotoItem] = []
    
    private let contentViewStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.backgroundColor = .clear
        return stack
    }()
    
    private let headerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let blurredHeaderImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let headerImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .black
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    var currentPhoto: UIImage? = nil {
        didSet {
            if let currentPhoto = self.currentPhoto {
                avatarImageView.image = currentPhoto
            } else {
                self.avatarImageView.image = nil
            }
        }
    }
    
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 40
        iv.layer.borderWidth = 3
        iv.layer.borderColor = UIColor.white.cgColor
        iv.backgroundColor = .systemGray
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let avatarSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .whiteLarge)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textColor = .white
        return label
    }()
    
    private let statusStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()
    
    private let dmButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let likesView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let viewsView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let savesView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let socialMediaStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var segmentedBar: ProfileSegmentedBar = {
        let view = ProfileSegmentedBar()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var galleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isHidden = true
        collectionView.backgroundColor = .clear
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "GalleryCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private var profileInfoView: ProfileInfoView
    
    private lazy var emptyPhotosView: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = 12
        
        let icon = UIImageView(image: UIImage(bundleImageName: "Avatar/AddAvatarIconLarge"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "Upload your photos"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 40),
            icon.heightAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 90)
        ])
        
        button.addTarget(self, action: #selector(dmButtonTapped), for: .touchUpInside)
        return button
    }()
    private let emptyPhotosWrapper = UIView()
    
    init(
        controller: ViewController,
        context: AccountContext,
        presentationData: PresentationData,
        model: ProfileModel,
        uploadAvatar: @escaping () -> Void,
        uploadPortfolioItem: @escaping () -> Void,
        openEditLink: @escaping () -> Void,
        openGallery: @escaping (Int) -> Void
    ) {
            self.controller = controller
            self.context = context
            self.presentationData = presentationData
            self.model = model
            self.uploadAvatar = uploadAvatar
            self.uploadPortfolioItem = uploadPortfolioItem
            self.openEditLink = openEditLink
            self.openGallery = openGallery
            
            profileInfoView = ProfileInfoView(biography: "Some long text...", appearance: [])
            
            super.init()
            
            self.view.backgroundColor = .black
            
            self.view.addSubview(headerContainer)
            headerContainer.addSubview(headerImageView)
            headerContainer.addSubview(blurredHeaderImageView)
            
            self.view.addSubview(scrollView)
            scrollView.backgroundColor = .clear
            scrollView.contentInsetAdjustmentBehavior = .never
            scrollView.addSubview(contentViewStack)
            
            setupContent()
            configureNodes()
            updateLocalPhotos([])
        }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        let bounds = CGRect(origin: .zero, size: layout.size)
        transition.updateFrame(view: scrollView, frame: bounds)
        
        let contentInset = UIEdgeInsets(top: 0, left: 0, bottom: layout.insets(options: []).bottom, right: 0)
        let scrollIndicatorInsets = UIEdgeInsets(top: layout.insets(options: []).top, left: 0, bottom: 0, right: 0)
        
        self.scrollView.contentInset = contentInset
        self.scrollView.scrollIndicatorInsets = scrollIndicatorInsets
        
        applyGradientBlurMask()
        updateGalleryHeight()
        
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
    }
    
    override func layout() {
        super.layout()
        
        guard let (layout, _) = self.containerLayout else { return }
        let stackWidth = layout.size.width
        
        contentViewStack.layoutIfNeeded()
        
        let targetSize = CGSize(width: stackWidth, height: UIView.layoutFittingCompressedSize.height)
        let contentHeight = contentViewStack.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        
        contentViewStack.frame = CGRect(x: 0, y: 0, width: stackWidth, height: contentHeight)
        scrollView.contentSize = CGSize(width: stackWidth, height: contentHeight)
        
        applyGradientBlurMask()
    }
    
    private func applyGradientBlurMask() {
        let blurStartPoint: CGFloat = 100.0
        let blurFullPoint: CGFloat = 400.0
        
        guard let originalImage = headerImageView.image else { return }
        
        let blurredImage = originalImage.applyBlur(radius: 20)
        blurredHeaderImageView.image = blurredImage
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = blurredHeaderImageView.bounds
        
        let totalHeight = self.view.bounds.height
        guard totalHeight > 0 else { return }
        
        let startLocation = blurStartPoint / totalHeight
        let fullLocation = blurFullPoint / totalHeight
        
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        gradientLayer.locations = [NSNumber(value: Double(startLocation)),
                                   NSNumber(value: Double(fullLocation))]
        
        blurredHeaderImageView.layer.mask = gradientLayer
    }
    
    private func setupContent() {
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: self.view.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            headerContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            headerImageView.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            headerImageView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            headerImageView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            headerImageView.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            
            blurredHeaderImageView.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            blurredHeaderImageView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            blurredHeaderImageView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            blurredHeaderImageView.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            
            scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            contentViewStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentViewStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentViewStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentViewStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentViewStack.widthAnchor.constraint(equalTo: self.view.widthAnchor)
        ])
        
        setupProfileHeaderInfo()
        setupBiographyBlock()
        setupSocialMediaBlock()
        setupSegmentedBar()
        contentViewStack.setCustomSpacing(16, after: socialMediaStack)
        setupGallery()
        if let segmentedWrapper = contentViewStack.arrangedSubviews.first(where: { $0.subviews.contains(segmentedBar) }) {
            contentViewStack.setCustomSpacing(5, after: segmentedWrapper)
        }
    }
    
    private func setupProfileHeaderInfo() {
        let profileHeaderWrapper = UIView()
        profileHeaderWrapper.translatesAutoresizingMaskIntoConstraints = false
        
        let infoStack = UIStackView(arrangedSubviews: [nameLabel, statusStack])
        infoStack.axis = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 0
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        
        profileHeaderWrapper.addSubview(avatarImageView)
        profileHeaderWrapper.addSubview(avatarSpinner)
        profileHeaderWrapper.addSubview(infoStack)
        profileHeaderWrapper.addSubview(dmButton)
        
        let counterActionsStack: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [likesView, viewsView, savesView])
            stack.axis = .horizontal
            stack.spacing = 20
            stack.distribution = .fillEqually
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        
        profileHeaderWrapper.addSubview(counterActionsStack)
        
        var dmButtonWidthAnchor: CGFloat = 100
        if model.isMyProfile {
            dmButtonWidthAnchor = 300
        }
        
        NSLayoutConstraint.activate([
            profileHeaderWrapper.heightAnchor.constraint(equalToConstant: 380),
            
            avatarImageView.heightAnchor.constraint(equalToConstant: 80),
            avatarImageView.widthAnchor.constraint(equalToConstant: 80),
            avatarImageView.leadingAnchor.constraint(equalTo: profileHeaderWrapper.leadingAnchor, constant: 16),
            avatarImageView.topAnchor.constraint(equalTo: profileHeaderWrapper.topAnchor, constant: 190),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            
            infoStack.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 15),
            infoStack.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: -10),
            
            dmButton.leadingAnchor.constraint(equalTo: profileHeaderWrapper.leadingAnchor, constant: 16),
            dmButton.topAnchor.constraint(equalTo: infoStack.bottomAnchor, constant: 20),
            dmButton.heightAnchor.constraint(equalToConstant: 40),
            dmButton.widthAnchor.constraint(equalToConstant: dmButtonWidthAnchor),
            
            counterActionsStack.topAnchor.constraint(equalTo: dmButton.bottomAnchor, constant: 20),
            counterActionsStack.leadingAnchor.constraint(equalTo: profileHeaderWrapper.leadingAnchor, constant: 16),
            counterActionsStack.trailingAnchor.constraint(equalTo: profileHeaderWrapper.trailingAnchor, constant: -16),
        ])
        
        contentViewStack.addArrangedSubview(profileHeaderWrapper)
    }
    
    func toggleSpinner(active: Bool) {
        if active {
            avatarSpinner.startAnimating()
            avatarImageView.alpha = 0.5
        } else {
            avatarSpinner.stopAnimating()
            avatarImageView.alpha = 1.0
        }
    }
    
    func updateLocalPhotos(_ photos: [TelegramMediaImage]) {
        self.localPhotos = photos.map { PhotoItem.telegram($0) }
        let hasPhotos = !localPhotos.isEmpty
        
        self.emptyPhotosWrapper.isHidden = hasPhotos
        self.galleryCollectionView.isHidden = !hasPhotos
        
        if hasPhotos {
            self.galleryCollectionView.reloadData()
            
            updateGalleryHeight()
            
            self.setNeedsLayout()
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
//    func addTempUploadingPhoto(_ image: UIImage) {
//        self.localPhotos.insert(.uploading(image), at: 0)
//        self.galleryCollectionView.isHidden = false
//        self.emptyPhotosWrapper.isHidden = true
//        self.galleryCollectionView.reloadData()
//        updateGalleryHeight()
//        
//        UIView.animate(withDuration: 0.3) {
//            self.view.layoutIfNeeded()
//        }
//    }
    
    func addTempUploadingPhotos(_ images: [UIImage]) {
        let newItems = images.map { PhotoItem.uploading($0) }
        self.localPhotos.insert(contentsOf: newItems, at: 0)
        
        self.galleryCollectionView.isHidden = false
        self.emptyPhotosWrapper.isHidden = true
        
        self.galleryCollectionView.reloadData()
        self.updateGalleryHeight()
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func updateGalleryHeight() {
        guard let (layout, _) = self.containerLayout,
              let flowLayout = galleryCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        
        let itemsPerRow: CGFloat = 3
        let spacing: CGFloat = 1
        let totalWidth = layout.size.width
        let itemWidth = (totalWidth - (2 * spacing)) / itemsPerRow
        
        let totalItems = CGFloat(!localPhotos.isEmpty ? localPhotos.count : model.galleryImageNames.count)
        let rowCount = ceil(totalItems / itemsPerRow)
        let galleryHeight = (rowCount * itemWidth) + max(0, (rowCount - 1) * spacing)
        
        galleryCollectionView.constraints.filter { $0.firstAttribute == .height }.forEach {
            galleryCollectionView.removeConstraint($0)
        }
        
        let heightConstraint = galleryCollectionView.heightAnchor.constraint(equalToConstant: galleryHeight)
        heightConstraint.priority = .required
        heightConstraint.isActive = true
        
        flowLayout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        galleryCollectionView.collectionViewLayout.invalidateLayout()
    }

    
    private func setupBiographyBlock() {
        let wrapperView = UIView()
        wrapperView.translatesAutoresizingMaskIntoConstraints = false
        profileInfoView.layer.cornerRadius = 8
        profileInfoView.clipsToBounds = true
        wrapperView.addSubview(profileInfoView)
        profileInfoView.translatesAutoresizingMaskIntoConstraints = false
        
        let sideMargin: CGFloat = 16.0
        NSLayoutConstraint.activate([
            profileInfoView.topAnchor.constraint(equalTo: wrapperView.topAnchor),
            profileInfoView.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor),
            profileInfoView.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor, constant: sideMargin),
            profileInfoView.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor, constant: -sideMargin)
        ])
        contentViewStack.addArrangedSubview(wrapperView)
    }
    
    private func setupSocialMediaBlock() {
        updateSocialMediaStack(nil)
        let paddedSocialMedia = UIView()
        paddedSocialMedia.translatesAutoresizingMaskIntoConstraints = false
        paddedSocialMedia.addSubview(socialMediaStack)
        NSLayoutConstraint.activate([
            socialMediaStack.topAnchor.constraint(equalTo: paddedSocialMedia.topAnchor),
            socialMediaStack.bottomAnchor.constraint(equalTo: paddedSocialMedia.bottomAnchor),
            socialMediaStack.leadingAnchor.constraint(equalTo: paddedSocialMedia.leadingAnchor, constant: 16),
            socialMediaStack.trailingAnchor.constraint(equalTo: paddedSocialMedia.trailingAnchor, constant: -16),
            socialMediaStack.heightAnchor.constraint(equalToConstant: 70)
        ])
        contentViewStack.addArrangedSubview(paddedSocialMedia)
    }
    
    private func setupSegmentedBar() {
        let paddedSegmentedBar = UIView()
        paddedSegmentedBar.translatesAutoresizingMaskIntoConstraints = false
        paddedSegmentedBar.addSubview(segmentedBar)
        NSLayoutConstraint.activate([
            segmentedBar.topAnchor.constraint(equalTo: paddedSegmentedBar.topAnchor),
            segmentedBar.bottomAnchor.constraint(equalTo: paddedSegmentedBar.bottomAnchor),
            segmentedBar.leadingAnchor.constraint(equalTo: paddedSegmentedBar.leadingAnchor, constant: 0),
            segmentedBar.trailingAnchor.constraint(equalTo: paddedSegmentedBar.trailingAnchor, constant: 0),
            segmentedBar.heightAnchor.constraint(equalToConstant: 40)
        ])
        contentViewStack.addArrangedSubview(paddedSegmentedBar)
    }
    
    private func setupGallery() {
        let galleryWrapper = UIView()
        galleryWrapper.translatesAutoresizingMaskIntoConstraints = false
        galleryWrapper.addSubview(galleryCollectionView)
        
        NSLayoutConstraint.activate([
            galleryCollectionView.topAnchor.constraint(equalTo: galleryWrapper.topAnchor),
            galleryCollectionView.bottomAnchor.constraint(equalTo: galleryWrapper.bottomAnchor),
            galleryCollectionView.leadingAnchor.constraint(equalTo: galleryWrapper.leadingAnchor, constant: 0),
            galleryCollectionView.trailingAnchor.constraint(equalTo: galleryWrapper.trailingAnchor, constant: 0)
        ])
        
        emptyPhotosWrapper.translatesAutoresizingMaskIntoConstraints = false
        emptyPhotosWrapper.addSubview(emptyPhotosView)
        emptyPhotosView.translatesAutoresizingMaskIntoConstraints = false
        emptyPhotosWrapper.isHidden = true
        
        NSLayoutConstraint.activate([
            emptyPhotosView.topAnchor.constraint(equalTo: emptyPhotosWrapper.topAnchor, constant: 24),
            emptyPhotosView.bottomAnchor.constraint(equalTo: emptyPhotosWrapper.bottomAnchor),
            emptyPhotosView.leadingAnchor.constraint(equalTo: emptyPhotosWrapper.leadingAnchor, constant: 16),
            emptyPhotosView.trailingAnchor.constraint(equalTo: emptyPhotosWrapper.trailingAnchor, constant: -16)
        ])
        
        contentViewStack.addArrangedSubview(emptyPhotosWrapper)
        contentViewStack.addArrangedSubview(galleryWrapper)
    }
    
    private func createStatusBadge(text: String, iconName: String) -> UIView {
        let icon = UIImageView(image: UIImage(named: iconPlaceholder))
        icon.tintColor = .black
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 12).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 12).isActive = true
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .black
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        stack.layer.cornerRadius = 8
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        return stack
    }
    
    private func setupDmButtonContent() {
        dmButton.subviews.forEach { $0.removeFromSuperview() }
        var iconImageName = "Chat/Context Menu/MessageBubble"
        var labelText = "Send DM"
        if model.isMyProfile {
            iconImageName = "Avatar/AddAvatarIconLarge"
            labelText = "Upload your photos"
        }
        let iconImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.image = UIImage(bundleImageName: iconImageName)
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            return imageView
        }()
        let label: UILabel = {
            let label = UILabel()
            label.text = labelText
            label.textColor = .white
            label.font = Font.helveticaNeue(13)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        let stackView: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [iconImageView, label])
            stack.axis = .horizontal
            stack.spacing = 4
            stack.alignment = .center
            stack.isUserInteractionEnabled = false
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        dmButton.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: dmButton.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: dmButton.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    override func didLoad() {
        super.didLoad()
        if model.isMyProfile {
            dmButton.addTarget(self, action: #selector(dmButtonTapped), for: .touchUpInside)
        }
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        avatarImageView.addGestureRecognizer(tapGesture)
    }
    
    private func setupCounterView(_ container: UIView, count: String, name: String, iconName: String) {
        container.subviews.forEach { $0.removeFromSuperview() }
        let icon: UIImageView = {
            let imageView = UIImageView()
            imageView.image = UIImage(bundleImageName: iconName)
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
            return imageView
        }()
        let countLabel: UILabel = {
            let label = UILabel()
            label.text = count
            label.font = UIFont.boldSystemFont(ofSize: 14)
            label.textColor = .white
            return label
        }()
        let nameLabel: UILabel = {
            let label = UILabel()
            label.text = name
            label.font = UIFont.systemFont(ofSize: 10)
            label.textColor = .white
            return label
        }()
        let countStack: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [icon, countLabel])
            stack.axis = .horizontal
            stack.spacing = 2
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        let mainStack: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [countStack, nameLabel])
            stack.axis = .horizontal
            stack.spacing = 5
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        container.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            mainStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            mainStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            mainStack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 0),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: 0),
        ])
    }
    
    private func createSocialMediaButton(handle: String, iconName: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .black.withAlphaComponent(0.12)
        button.layer.cornerRadius = 10
        let icon = UIImageView()
        icon.image = UIImage(bundleImageName: iconName)
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.isUserInteractionEnabled = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let label = UILabel()
        label.text = handle
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .white
        label.isUserInteractionEnabled = false
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 5
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        button.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        button.addAction(for: .touchUpInside, action)
        return button
    }
    
    @objc private func avatarTapped() {
        self.uploadAvatar()
    }
    
    @objc private func dmButtonTapped() {
        self.uploadPortfolioItem()
    }
    
    private func configureNodes() {
        if model.isMyProfile {
            if !model.photos.isEmpty {
                guard let photo = model.photos.first else { return }
                let image = photo.image
                guard let representation = largestImageRepresentation(image.representations) else { return }
                let resourceData = context.account.postbox.mediaBox.resourceData(representation.resource)
                let _ = (resourceData |> deliverOnMainQueue).start(next: { data in
                    if data.complete {
                        if let uiImage = UIImage(contentsOfFile: data.path) {
                            self.avatarImageView.image = uiImage
                        }
                    } else {
                        let _ = self.context.account.postbox.mediaBox.fetchedResource(representation.resource, parameters: nil).start()
                    }
                })
            }
        } else {
            avatarImageView.image = UIImage(named: model.avatarImageName)
        }
        nameLabel.text = model.name
        if let lastName = model.lastName {
            nameLabel.text = model.name + " " + lastName
        }
        let modelBadge = createStatusBadge(text: "model", iconName: "model_icon")
        let ageLocationBadge = createStatusBadge(text: "\(model.age) y.o. · \(model.location)", iconName: "location_icon")
        statusStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if !model.isMyProfile {
            statusStack.addArrangedSubview(modelBadge)
            statusStack.addArrangedSubview(ageLocationBadge)
        }
        setupDmButtonContent()
        setupCounterView(likesView, count: model.likesCount, name: "Like", iconName: "Chat/Input/Text/AccessoryIconReaction")
        setupCounterView(viewsView, count: model.viewsCount, name: "Viewed", iconName: "Stories/EmbeddedViewIcon")
        setupCounterView(savesView, count: model.savesCount, name: "Save", iconName: "Instant View/Bookmark")
    }
    
    private func updateSocialMediaStack(_ socialMedia: SocialLinks?) {
        socialMediaStack.arrangedSubviews.forEach { view in
            socialMediaStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        if let socialMedia = socialMedia {
            if let instagram = socialMedia.instagram,
               let name = URL(string: instagram)?.pathComponents.last(where: { $0 != "/" }) {
                let buttonView = createSocialMediaButton(handle: "@" + name, iconName: "Models/instaIcon") {
                    self.openURL(instagram)
                }
                socialMediaStack.addArrangedSubview(buttonView)
            }
            if let tiktok = socialMedia.tiktok,
               let name = URL(string: tiktok)?.pathComponents.last(where: { $0 != "/" }) {
                let buttonView = createSocialMediaButton(handle: "@" + name, iconName: "Models/TikTokIcon") {
                    self.openURL(tiktok)
                }
                socialMediaStack.addArrangedSubview(buttonView)
            }
            if let youtube = socialMedia.youtube,
               let name = URL(string: youtube)?.pathComponents.last(where: { $0 != "/" }) {
                let buttonView = createSocialMediaButton(handle: name, iconName: "Models/youtubeIcon") {
                    self.openURL(youtube)
                }
                socialMediaStack.addArrangedSubview(buttonView)
            }
            if let website = socialMedia.website, !website.isEmpty {
                let buttonView = createSocialMediaButton(handle: "website", iconName: "Models/webIcon") {
                    self.openURL(website)
                }
                socialMediaStack.addArrangedSubview(buttonView)
            }
        }
        if socialMediaStack.arrangedSubviews.count == 0 {
            let buttonView = createSocialMediaButton(handle: "Add Links", iconName: "Models/Link") {
                self.openEditLink()
            }
            socialMediaStack.addArrangedSubview(buttonView)
        }
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    public func reloadSocialMedia(_ socialMedia: SocialLinks?) {
        updateSocialMediaStack(socialMedia)
    }
    
    public func reloadBackground(_ image: TelegramMediaImage?) {
        if let image = image {
            guard let representation = largestImageRepresentation(image.representations) else { return }
            let resourceData = context.account.postbox.mediaBox.resourceData(representation.resource)
            let _ = (resourceData |> deliverOnMainQueue).start(next: { data in
                if data.complete {
                    if let uiImage = UIImage(contentsOfFile: data.path) {
                        UIView.transition(with: self.headerImageView,
                                          duration: 0.3,
                                          options: .transitionCrossDissolve,
                                          animations: {
                            self.headerImageView.image = uiImage
                        }, completion: nil)
                    }
                } else {
                    let _ = self.context.account.postbox.mediaBox.fetchedResource(representation.resource, parameters: nil).start()
                }
            })
        } else {
            headerImageView.image = UIImage(named: model.mainImageName)
        }
    }
    
    func updateNameLabel(_ name: String) {
        nameLabel.text = name
    }
    
    func getUpdates(_ about: String?, _ physicalParams: PhysicalParams?, _ gender: SecureIdGender?) {
        
        var appearanceAttrs: [AppearanceAttribute] = []
        if let physicalParams = physicalParams {
            
            if let gender = gender {
                appearanceAttrs.append(AppearanceAttribute(title: "Gender", value: gender == .male ? "Male" : "Female"))
            }
            
            if let age = physicalParams.age {
                appearanceAttrs.append(AppearanceAttribute(title: "Age (y.o)", value: String(age)))
            }
            if let height = physicalParams.height {
                appearanceAttrs.append(AppearanceAttribute(title: "Height (cm)", value: String(height)))
            }
            if let waist = physicalParams.waist {
                appearanceAttrs.append(AppearanceAttribute(title: "Waist (cm)", value: String(waist)))
            }
            if let hips = physicalParams.hips {
                appearanceAttrs.append(AppearanceAttribute(title: "Hips (cm)", value: String(hips)))
            }
            if let shoeSize = physicalParams.shoeSize {
                appearanceAttrs.append(AppearanceAttribute(title: "Shoe size (EU)", value: String(shoeSize)))
            }
            if let hairLength = physicalParams.hairLength {
                appearanceAttrs.append(AppearanceAttribute(title: "Hair length (cm)", value: String(hairLength)))
            }
            if let hairColor = physicalParams.hairColor {
                appearanceAttrs.append(AppearanceAttribute(title: "Hair color", value: hairColor))
            }
            if let eyeColor = physicalParams.eyeColor {
                appearanceAttrs.append(AppearanceAttribute(title: "Eye color", value: eyeColor))
            }
            if let skinColor = physicalParams.skinColor {
                appearanceAttrs.append(AppearanceAttribute(title: "Skin color", value: skinColor))
            }
        }
        
        profileInfoView.update(biography: about ?? "", appearance: appearanceAttrs)
    }
}

extension ProfileScreenNode: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if !localPhotos.isEmpty {
            return localPhotos.count
        }
        return model.galleryImageNames.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as? GalleryCell else {
            return UICollectionViewCell()
        }
        if !localPhotos.isEmpty {
            let item = localPhotos[indexPath.item]
            switch item {
            case .telegram(let image):
                guard let representation = largestImageRepresentation(image.representations) else { return cell }
                let resourceData = context.account.postbox.mediaBox.resourceData(representation.resource)
                let _ = (resourceData |> deliverOnMainQueue).start(next: { data in
                    if data.complete {
                        if let uiImage = UIImage(contentsOfFile: data.path) {
                            cell.configure(with: uiImage)
                        }
                    } else {
                        let _ = self.context.account.postbox.mediaBox.fetchedResource(representation.resource, parameters: nil).start()
                    }
                })
            case .local(let uiImage, _):
                cell.configure(with: uiImage)
            case .uploading(let uiImage):
                cell.configure(with: uiImage, isUploading: true)
            }
            return cell
        }
        guard let imageName = model.galleryImageNames[safe: indexPath.row] else { return cell }
        cell.configure(with: imageName)
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let (layout, _) = self.containerLayout else { return .zero }
        let totalSpacing: CGFloat = 2
        let width = (layout.size.width - totalSpacing) / 3.0
        return CGSize(width: width, height: width)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1.0
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1.0
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.openGallery(indexPath.item)
    }
}

extension ProfileScreenNode: ProfileInfoViewDelegate {
    func profileInfoViewDidUpdateContentHeight() {
        UIView.animate(withDuration: 0.25, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        })
    }
}

extension ProfileScreenNode: ProfileSegmentedBarDelegate {
    func segmentedBar(_ segmentedBar: ProfileSegmentedBar, didSelectIndex index: Int) {
        DispatchQueue.main.async {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
}
