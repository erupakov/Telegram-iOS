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

final class PublicProfileScreenNode: ASDisplayNode {
    
    private let model: ProfileModel
    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var headerHeightConstraint: NSLayoutConstraint!
    private let iconPlaceholder = "HeartActionIcon"
    private let fixedHeaderHeight: CGFloat = 630.0
    
    private let addPhoto: () -> Void
    
    private let scrollView = UIScrollView()
    
    enum PhotoItem {
        case telegram(TelegramPeerPhoto)
        case local(UIImage, Date)
    }
    
    var localPhotos: [PhotoItem] = []
    
    private let contentViewStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let headerContainer = UIView()
    
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
        iv.backgroundColor = .gray
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
        collectionView.backgroundColor = .black
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "GalleryCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private lazy var profileInfoView: ProfileInfoView = {
        let view = ProfileInfoView(
            biography: model.biography,
            appearance: "model.appearance"
        )
        view.delegate = self
        return view
    }()
    
    init(controller: ViewController, context: AccountContext, presentationData: PresentationData, model: ProfileModel, addPhoto: @escaping () -> Void) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        self.model = model
        self.addPhoto = addPhoto
        super.init()
        
        self.view.backgroundColor = .black
        
        self.view.addSubview(scrollView)
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.addSubview(contentViewStack)
        
        localPhotos = model.photos.map { PhotoItem.telegram($0) }
        
        setupContent()
        configureNodes()
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
        
        headerHeightConstraint.constant = fixedHeaderHeight
        
        applyGradientBlurMask()
        
        if let flowLayout = galleryCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let itemsPerRow: CGFloat = 3
            let spacing: CGFloat = 1
            let totalWidth = layout.size.width
            let itemWidth = (totalWidth - 2 * spacing) / itemsPerRow
            
            let fixedRows: CGFloat = 3
            let galleryHeight = fixedRows * itemWidth + (fixedRows - 1) * spacing
            
            galleryCollectionView.constraints.filter({ $0.firstAttribute == .height }).forEach({ $0.isActive = false })
            galleryCollectionView.heightAnchor.constraint(equalToConstant: galleryHeight).isActive = true
            
            flowLayout.itemSize = CGSize(width: itemWidth, height: itemWidth)
            galleryCollectionView.collectionViewLayout.invalidateLayout()
        }
        
        self.layoutIfNeeded()
    }
    
    override func layout() {
        super.layout()
        
        guard let (layout, _) = self.containerLayout else { return }
        
        let stackWidth = layout.size.width
        
        contentViewStack.layoutIfNeeded()
        
        let contentHeight = contentViewStack.systemLayoutSizeFitting(
            CGSize(width: stackWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        
        contentViewStack.frame = CGRect(x: 0, y: 0, width: stackWidth, height: contentHeight)
        scrollView.contentSize = CGSize(width: stackWidth, height: contentHeight)
        
        applyGradientBlurMask()
    }
    
    private func applyGradientBlurMask() {
        let blurStartPoint: CGFloat = 100.0
        let blurFullPoint: CGFloat = 250.0
        
        guard let originalImage = headerImageView.image,
              let headerHeight = headerHeightConstraint?.constant,
              headerHeight > 0
        else {
            return
        }
        
        let blurredImage = originalImage.applyBlur(radius: 20)
        blurredHeaderImageView.image = blurredImage
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = blurredHeaderImageView.bounds
        
        let startLocation = blurStartPoint / headerHeight
        let fullLocation = blurFullPoint / headerHeight
        
        let clampedStartLocation = max(0.0, min(1.0, startLocation))
        let clampedFullLocation = max(0.0, min(1.0, fullLocation))
        
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        
        gradientLayer.locations = [NSNumber(value: Double(clampedStartLocation)),
                                   NSNumber(value: Double(clampedFullLocation))]
        
        blurredHeaderImageView.layer.mask = gradientLayer
    }
    
    private func setupContent() {
        
        NSLayoutConstraint.activate([
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
        
        setupHeaderLayout()
        setupBiographyBlock()
        let overlap: CGFloat = -250.0
        contentViewStack.setCustomSpacing(overlap, after: headerContainer)
        setupSocialMediaBlock()
        setupSegmentedBar()
        contentViewStack.setCustomSpacing(-175, after: socialMediaStack)
        setupGallery()
        contentViewStack.setCustomSpacing(-40, after: segmentedBar)
    }
    
    private func setupHeaderLayout() {
        headerContainer.addSubview(headerImageView)
        headerContainer.addSubview(blurredHeaderImageView)
        contentViewStack.addArrangedSubview(headerContainer)
        
        headerImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            headerImageView.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            headerImageView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            headerImageView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            headerImageView.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            
            blurredHeaderImageView.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            blurredHeaderImageView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            blurredHeaderImageView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            blurredHeaderImageView.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
        ])
        
        headerHeightConstraint = headerContainer.heightAnchor.constraint(equalToConstant: fixedHeaderHeight)
        headerHeightConstraint.isActive = true
        
        let infoStack = UIStackView(arrangedSubviews: [nameLabel, statusStack])
        infoStack.axis = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 0
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        
        headerContainer.addSubview(avatarImageView)
        
        headerContainer.addSubview(avatarSpinner)
        NSLayoutConstraint.activate([
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor)
        ])
        
        headerContainer.addSubview(infoStack)
        
        headerContainer.addSubview(dmButton)
        
        let counterActionsStack: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [likesView, viewsView, savesView])
            stack.axis = .horizontal
            stack.spacing = 20
            stack.distribution = .fillEqually
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        
        headerContainer.addSubview(counterActionsStack)
        
        var dmButtonWidthAnchor: CGFloat = 100
        
        if model.isMyProfile {
            dmButtonWidthAnchor = 300
        }
        NSLayoutConstraint.activate([
            avatarImageView.heightAnchor.constraint(equalToConstant: 80),
            avatarImageView.widthAnchor.constraint(equalToConstant: 80),
            avatarImageView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            avatarImageView.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 190),
            
            infoStack.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 15),
            infoStack.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: -10),
            
            dmButton.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            dmButton.topAnchor.constraint(equalTo: infoStack.bottomAnchor, constant: 20),
            dmButton.heightAnchor.constraint(equalToConstant: 40),
            dmButton.widthAnchor.constraint(equalToConstant: dmButtonWidthAnchor),
            
            counterActionsStack.topAnchor.constraint(equalTo: dmButton.bottomAnchor, constant: 20),
            counterActionsStack.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            
            counterActionsStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            counterActionsStack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
        ])
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
    
    func addPhotoToCollection() {
        if let currentPhoto = currentPhoto {
            let newItem = PhotoItem.local(currentPhoto, Date())
            
            self.localPhotos.insert(newItem, at: 0)
            
            self.galleryCollectionView.performBatchUpdates({
                self.galleryCollectionView.insertItems(at: [IndexPath(item: 0, section: 0)])
            })
        }
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
        
        for (index, handle) in model.socialMediaHandles.enumerated() {
            socialMediaStack.addArrangedSubview(createSocialMediaButton(handle: handle, iconName: model.socialMediaIcons[safe: index] ?? iconPlaceholder))
        }
        
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
        contentViewStack.addArrangedSubview(galleryCollectionView)
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
    
    private func createSocialMediaButton(handle: String, iconName: String) -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = .black.withAlphaComponent(0.12)
        button.layer.cornerRadius = 10
        
        let icon = UIImageView()
        icon.image = UIImage(bundleImageName: iconName)
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        let label = UILabel()
        label.text = handle
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .white
        
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 5
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        return button
    }
    
    @objc private func dmButtonTapped() {
        self.addPhoto()
    }
    
    private func configureNodes() {
        
        headerImageView.image = UIImage(named: model.mainImageName)
        if model.isMyProfile {
            
            if !model.photos.isEmpty {
                guard let photo = model.photos.first else {
                    return
                }
                
                let image = photo.image
                guard let representation = largestImageRepresentation(image.representations) else {
                    return
                }
                
                let resourceData = context.account.postbox.mediaBox.resourceData(representation.resource)
                let _ = (resourceData
                         |> deliverOnMainQueue).start(next: { data in
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
        
        socialMediaStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, handle) in model.socialMediaHandles.enumerated() {
            let iconName = model.socialMediaIcons[safe: index] ?? iconPlaceholder
            socialMediaStack.addArrangedSubview(createSocialMediaButton(handle: handle, iconName: iconName))
        }
    }
}

extension PublicProfileScreenNode: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
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
            case .telegram(let peerPhoto):
                let image = peerPhoto.image
                guard let representation = largestImageRepresentation(image.representations) else {
                    return cell
                }
                
                let resourceData = context.account.postbox.mediaBox.resourceData(representation.resource)
                let _ = (resourceData
                         |> deliverOnMainQueue).start(next: { data in
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
            }
            
            return cell
        }
        
        guard let imageName = model.galleryImageNames[safe: indexPath.row] else {
            return cell
        }
        
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
}

extension PublicProfileScreenNode: ProfileInfoViewDelegate {
    func profileInfoViewDidUpdateContentHeight() {
        DispatchQueue.main.async {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
}

extension PublicProfileScreenNode: ProfileSegmentedBarDelegate {
    func segmentedBar(_ segmentedBar: ProfileSegmentedBar, didSelectIndex index: Int) {
        print("Selected segment index: \(index)")
        
        DispatchQueue.main.async {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
}
