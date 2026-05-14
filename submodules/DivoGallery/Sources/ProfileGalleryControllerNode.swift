import Foundation
import UIKit
import AVFoundation
import Display
import AsyncDisplayKit
import TelegramCore
import DivoCore
import DivoUIKit
import TelegramPresentationData
import AccountContext
import PhotoResources

final class ProfileGalleryControllerNode: ASDisplayNode {
    
    private let context: AccountContext
    private var photos: [UserPhoto]
    private var videos: [UserVideoItem]
    private let initialIndex: Int
    private let isVideoGallery: Bool
    private let isOwnProfile: Bool
    
    private weak var controller: ViewController?
    
    private var presentationData: PresentationData
    private var mainCollectionView: UICollectionView!
    private var previewCollectionView: UICollectionView!
    private var previewHeight: CGFloat = 80
    private var isSyncingScroll = false
    private var isFirstLayout = true
    private var panGesture: UIPanGestureRecognizer!
    private var _currentIndex: Int
    
    private var isLoadingMore = false
    
    private var autoPlayWorkItem: DispatchWorkItem?
    
    var onIndexChanged: ((Int, Int) -> Void)?
    var requestMoreData: (() -> Void)?
    var currentIndex: Int { return _currentIndex }
    var onBackTapped: (() -> Void)?
    var onMenuTapped: (() -> Void)?
    
    private let navigationBar = DivoNavigationBar()
    
    // MARK: - Init
    
    init(
        context: AccountContext,
        presentationData: PresentationData,
        photos:[UserPhoto],
        videos: [UserVideoItem],
        initialIndex: Int,
        isVideoGallery: Bool,
        isOwnProfile: Bool,
        controller: ViewController
    ) {
        self.context = context
        self.presentationData = presentationData
        self.photos = photos
        self.videos = videos
        self.initialIndex = initialIndex
        self.isVideoGallery = isVideoGallery
        self.isOwnProfile = isOwnProfile
        self.controller = controller
        self._currentIndex = initialIndex
        
        super.init()
        
        navigationBar.makeNavigationBar(
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            rightButtonConfiguration: isOwnProfile ? .circle(DivoColorPalette.cardBackground, DivoColorPalette.primaryText, DivoImage.moreActionIconBlack, .pill) : nil,
            onBackTapped: {
                [weak self] in self?.onBackTapped?()
            },
            onCircleRightTapped: {
                [weak self] in self?.onMenuTapped?()
            },
            menu: setupMenu()
        )
        
        self.backgroundColor = .clear
        
        self.setupMainCollectionView()
        self.setupPreviewCollectionView()
        
        self.view.addSubview(navigationBar)
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Override
    
    override public func didLoad() {
        super.didLoad()
        self.panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.panGesture.delegate = self
        self.panGesture.cancelsTouchesInView = false
        self.view.addGestureRecognizer(self.panGesture)
        self.initializeScrollPosition()
    }
    
    func getCurrentPublicationId() -> Int? {
        let index = self._currentIndex
        if isVideoGallery {
            guard index >= 0 && index < videos.count else { return nil }
            return videos[index].id
        } else {
            guard index >= 0 && index < photos.count else { return nil }
            return photos[index].id
        }
    }
    
    private func getPublicationId(at index: Int) -> Int {
        if isVideoGallery {
            return videos[index].id
        } else {
            return photos[index].id
        }
    }

    private func setupMenu() -> UIMenu {
        if #available(iOS 14.0, *) {
            let blockAction = UIAction(
                title: DivoStrings.deletePhoto,
                image: nil,
                attributes: .destructive
            ) { [weak self] _ in
                self?.onMenuTapped?()
            }
            
            return UIMenu(title: "", children: [blockAction])
        } else {
            return UIMenu()
        }
    }
    
    
    // MARK: - Internal
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        
        self.isSyncingScroll = true
        
        if let flowLayout = self.mainCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = layout.size
            flowLayout.invalidateLayout()
        }
        
        if let previewLayout = self.previewCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let inset = (layout.size.width - previewLayout.itemSize.width) / 2.0
            previewLayout.sectionInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
            previewLayout.invalidateLayout()
        }
        
        self.mainCollectionView.layoutIfNeeded()
        self.previewCollectionView.layoutIfNeeded()
        
        if self.isFirstLayout {
            self.isFirstLayout = false
            
            let mainOffset = CGPoint(x: CGFloat(self.initialIndex) * layout.size.width, y: 0)
            self.mainCollectionView.setContentOffset(mainOffset, animated: false)
            
            if let previewLayout = self.previewCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                let itemTotalWidth = previewLayout.itemSize.width + previewLayout.minimumLineSpacing
                let targetPreviewOffset = CGPoint(x: CGFloat(self.initialIndex) * itemTotalWidth, y: 0)
                self.previewCollectionView.setContentOffset(targetPreviewOffset, animated: false)
            }
            
            self.mainCollectionView.layoutIfNeeded()
            self.previewCollectionView.layoutIfNeeded()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self else { return }
                self.updatePreviewSelection()
                self.updatePreviewCellsScale()
                self.playVideo(at: self.currentIndex)
            }
        }
        
        self.isSyncingScroll = false
    }
    
    func toggleControlsVisibility() {
        guard let controller = self.controller else { return }
        let willShow = !controller.displayNavigationBar
        controller.setDisplayNavigationBar(willShow, transition: .animated(duration: 0.25, curve: .easeInOut))
    }
    
    func pauseAllVideos() {
        guard self.isVideoGallery else { return }
        for cell in self.mainCollectionView.visibleCells {
            (cell as? VideoGalleryCellNode)?.pause()
        }
    }
    
    func updateData(photos:[UserPhoto], videos: [UserVideoItem]) {
        self.isLoadingMore = false

        let oldPhotosCount = self.photos.count
        let oldVideosCount = self.videos.count

        self.photos = photos
        self.videos = videos

        let oldCount = self.isVideoGallery ? oldVideosCount : oldPhotosCount
        let newCount = self.isVideoGallery ? videos.count : photos.count

        if newCount > oldCount {
            let indexPaths = (oldCount..<newCount).map { IndexPath(item: $0, section: 0) }

            self.mainCollectionView.performBatchUpdates({
                self.mainCollectionView.insertItems(at: indexPaths)
            }, completion: nil)

            self.previewCollectionView.performBatchUpdates({
                self.previewCollectionView.insertItems(at: indexPaths)
            }, completion: nil)
        }

        self.updatePreviewSelection()
    }
    
    func finishLoadingWithoutNewData() {
        self.isLoadingMore = false
    }
    
    func removePublication(withId id: Int) {
        let indexToRemove: Int
        
        if isVideoGallery {
            guard let index = self.videos.firstIndex(where: { $0.id == id }) else { return }
            self.videos.remove(at: index)
            indexToRemove = index
        } else {
            guard let index = self.photos.firstIndex(where: { $0.id == id }) else { return }
            self.photos.remove(at: index)
            indexToRemove = index
        }
        
        let indexPath = IndexPath(item: indexToRemove, section: 0)
        
        let totalCount = isVideoGallery ? self.videos.count : self.photos.count
        
        if _currentIndex >= totalCount && totalCount > 0 {
            _currentIndex = totalCount - 1
        }

        self.previewCollectionView.performBatchUpdates({
            self.previewCollectionView.deleteItems(at: [indexPath])
        }, completion: nil)
        
        self.mainCollectionView.performBatchUpdates({
            self.mainCollectionView.deleteItems(at: [indexPath])
        }, completion: {[weak self] _ in
            guard let self = self else { return }
            
            if totalCount > 0 {
                let targetOffset = CGPoint(x: CGFloat(self._currentIndex) * self.mainCollectionView.bounds.width, y: 0)
                self.mainCollectionView.setContentOffset(targetOffset, animated: true)
                self.updatePreviewSelection()
                self.playVideo(at: self._currentIndex)
            }
        })
    }
    
    
    // MARK: - Private
    
    private func initializeScrollPosition() {
        guard self.photos.isEmpty == false || self.videos.isEmpty == false else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            
            let mainOffset = CGPoint(x: CGFloat(self.initialIndex) * self.mainCollectionView.bounds.width, y: 0)
            self.mainCollectionView.setContentOffset(mainOffset, animated: false)
            
            if let previewLayout = self.previewCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                let itemTotalWidth = previewLayout.itemSize.width + previewLayout.minimumLineSpacing
                let targetPreviewOffset = CGPoint(x: CGFloat(self.initialIndex) * itemTotalWidth, y: 0)
                self.previewCollectionView.setContentOffset(targetPreviewOffset, animated: false)
            }
            
            self.mainCollectionView.layoutIfNeeded()
            self.previewCollectionView.layoutIfNeeded()
            
            self.updatePreviewSelection()
            self.updatePreviewCellsScale()
        }
    }
    
    private func updatePreviewSelection() {
        for cell in self.previewCollectionView.visibleCells {
            if let previewCell = cell as? PreviewCell,
               let indexPath = self.previewCollectionView.indexPath(for: previewCell) {
                previewCell.isSelected = indexPath.item == self.currentIndex
            }
        }
    }
    
    private func setupMainCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .black
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate = .fast
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.contentInsetAdjustmentBehavior = .never
        
        if self.isVideoGallery {
            cv.register(VideoGalleryCellNode.self, forCellWithReuseIdentifier: "VideoCell")
        } else {
            cv.register(PhotoGalleryCellNode.self, forCellWithReuseIdentifier: "PhotoCell")
        }
        
        self.view.addSubview(cv)
        self.mainCollectionView = cv
        
        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: self.view.topAnchor),
            cv.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            cv.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }
    
    private func setupPreviewCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 50, height: 50)
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(PreviewCell.self, forCellWithReuseIdentifier: "PreviewCell")
        cv.decelerationRate = .fast
        
        self.view.addSubview(cv)
        self.previewCollectionView = cv
        
        NSLayoutConstraint.activate([
            cv.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            cv.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            cv.heightAnchor.constraint(equalToConstant: self.previewHeight)
        ])
    }
    
    private func playVideo(at index: Int) {
        guard self.isVideoGallery else { return }
        
        for cell in self.mainCollectionView.visibleCells {
            (cell as? VideoGalleryCellNode)?.pause()
        }
        
        let targetIndexPath = IndexPath(item: index, section: 0)
        if let targetCell = self.mainCollectionView.cellForItem(at: targetIndexPath) as? VideoGalleryCellNode {
            targetCell.play()
        }
    }
    
    
    // MARK: - @objc
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self.view)
        let velocity = gesture.velocity(in: self.view)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                self.backgroundColor = .black
                self.mainCollectionView.transform = CGAffineTransform(translationX: 0, y: translation.y)
                self.previewCollectionView.transform = CGAffineTransform(translationX: 0, y: translation.y)
            }
        case .ended, .cancelled:
            if translation.y > 150 || velocity.y > 500 {
                self.pauseAllVideos()
                
                if let nav = self.controller?.navigationController as? NavigationController {
                    _ = nav.popViewController(animated: true)
                } else {
                    self.controller?.dismiss()
                }
            } else {
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    self.mainCollectionView.transform = .identity
                    self.previewCollectionView.transform = .identity
                }
            }
        default:
            break
        }
    }

        
    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: DivoDesignTokens.Spacing.m,
            bottomAnchor: view.safeAreaLayoutGuide.bottomAnchor,
            retryTitle: retryAction != nil ? DivoStrings.retry : nil,
            retryAction: retryAction,
            persistent: persistent
        )
    }

    func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
    }
}


// MARK: - UIGestureRecognizerDelegate

extension ProfileGalleryControllerNode: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: self.view)
            return velocity.y > abs(velocity.x)
        }
        return true
    }
}


// MARK: - UICollectionViewDataSource

extension ProfileGalleryControllerNode: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.isVideoGallery ? self.videos.count : self.photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == self.mainCollectionView {
            if self.isVideoGallery {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCell", for: indexPath) as! VideoGalleryCellNode
                let video = self.videos[indexPath.item]
                if let videoFile = video.files.first(where: { MediaFormatValidator.isVideo($0.fileExtension) }) {
                    cell.configure(with: videoFile)
                }
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoGalleryCellNode
                let photo = self.photos[indexPath.item]
                cell.configure(with: photo.photo)
                cell.onSingleTap = { [weak self] in
                    self?.toggleControlsVisibility()
                }
                return cell
            }
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PreviewCell", for: indexPath) as! PreviewCell
            if self.isVideoGallery {
                let video = self.videos[indexPath.item]
                if let previewFile = video.files.first(where: { MediaFormatValidator.isImage($0.fileExtension) }),
                   let previewUrl = CDNURLHelper.convertToCDN(previewFile.fullUrl) {
                    cell.configure(with: previewUrl, isVideo: false)
                } else if let videoFile = video.files.first(where: { MediaFormatValidator.isVideo($0.fileExtension) }),
                          let videoUrl = CDNURLHelper.convertToCDN(videoFile.fullUrl) {
                    cell.configure(with: videoUrl, isVideo: true)
                }
            } else {
                let photo = self.photos[indexPath.item]
                let rawUrl = photo.preview?.fullUrl ?? photo.photo.fullUrl
                if let previewUrl = CDNURLHelper.convertToCDN(rawUrl) {
                    cell.configure(with: previewUrl, isVideo: false)
                }
            }
            return cell
        }
    }
}


// MARK: - UICollectionViewDelegate

extension ProfileGalleryControllerNode: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if collectionView == self.mainCollectionView && self.isVideoGallery,
           let videoCell = cell as? VideoGalleryCellNode {
            videoCell.pause()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if collectionView == self.mainCollectionView && self.isVideoGallery,
           let videoCell = cell as? VideoGalleryCellNode {
            videoCell.pause()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == self.previewCollectionView {
            self._currentIndex = indexPath.item
            self.mainCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isSyncingScroll else { return }
        
        if scrollView == self.mainCollectionView {
            isSyncingScroll = true
            let mainWidth = self.mainCollectionView.bounds.width
            guard mainWidth > 0 else { isSyncingScroll = false; return }
            
            let progress = self.mainCollectionView.contentOffset.x / mainWidth
            
            if let previewLayout = self.previewCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                let itemTotalWidth = previewLayout.itemSize.width + previewLayout.minimumLineSpacing
                let targetX = progress * itemTotalWidth
                self.previewCollectionView.contentOffset = CGPoint(x: targetX, y: 0)
            }
            
            updatePreviewCellsScale()
            
            let page = Int(round(progress))
            let totalCount = self.isVideoGallery ? self.videos.count : self.photos.count
            
            if page >= totalCount - 3 && !self.isLoadingMore {
                self.isLoadingMore = true
                self.requestMoreData?()
            }
            
            if page != self.currentIndex && page >= 0 && page < totalCount {
                self._currentIndex = page
                self.onIndexChanged?(page, totalCount)
                self.scheduleAutoPlay()
            }
            isSyncingScroll = false
            
        } else if scrollView == self.previewCollectionView {
            isSyncingScroll = true
            if let previewLayout = self.previewCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                let itemTotalWidth = previewLayout.itemSize.width + previewLayout.minimumLineSpacing
                let progress = scrollView.contentOffset.x / itemTotalWidth
                
                let targetX = progress * self.mainCollectionView.bounds.width
                self.mainCollectionView.contentOffset = CGPoint(x: targetX, y: 0)
                
                let page = Int(round(progress))
                let totalCount = self.isVideoGallery ? self.videos.count : self.photos.count
                
                if page >= totalCount - 3 && !self.isLoadingMore {
                    self.isLoadingMore = true
                    self.requestMoreData?()
                }
                
                if page != self.currentIndex && page >= 0 && page < totalCount {
                    self._currentIndex = page
                    self.onIndexChanged?(page, totalCount)
                    self.scheduleAutoPlay()
                }
            }
            updatePreviewCellsScale()
            isSyncingScroll = false
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        autoPlayWorkItem?.cancel()
        if scrollView == self.mainCollectionView && self.isVideoGallery {
            for cell in self.mainCollectionView.visibleCells {
                (cell as? VideoGalleryCellNode)?.pause()
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == self.mainCollectionView {
            playCenteredVideo()
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if scrollView == self.mainCollectionView {
            playCenteredVideo()
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView == self.mainCollectionView && !decelerate {
            playCenteredVideo()
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView == self.previewCollectionView {
            if let previewLayout = self.previewCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                let itemTotalWidth = previewLayout.itemSize.width + previewLayout.minimumLineSpacing
                let estimatedX = targetContentOffset.pointee.x
                let page = round(estimatedX / itemTotalWidth)
                targetContentOffset.pointee.x = page * itemTotalWidth
            }
        }
    }
    
    private func scheduleAutoPlay() {
        autoPlayWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.playCenteredVideo()
        }
        autoPlayWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    private func playCenteredVideo() {
        guard self.isVideoGallery else { return }
        
        let centerPoint = CGPoint(x: mainCollectionView.contentOffset.x + mainCollectionView.bounds.width / 2,
                                  y: mainCollectionView.bounds.height / 2)
        
        guard let indexPath = mainCollectionView.indexPathForItem(at: centerPoint) else { return }
        
        for cell in mainCollectionView.visibleCells {
            if let videoCell = cell as? VideoGalleryCellNode {
                if mainCollectionView.indexPath(for: cell) == indexPath {
                    videoCell.play()
                } else {
                    videoCell.pause()
                }
            }
        }
    }
    
    private func updatePreviewCellsScale() {
        let centerX = previewCollectionView.contentOffset.x + previewCollectionView.bounds.width / 2.0
        
        for cell in previewCollectionView.visibleCells {
            let cellCenterX = cell.center.x
            let distance = abs(cellCenterX - centerX)
            
            let scale = max(1.0, 1.25 - (distance / 200.0))
            let alpha = max(0.4, 1.0 - (distance / 150.0))
            
            cell.transform = CGAffineTransform(scaleX: scale, y: scale)
            cell.alpha = alpha
            
            if scale > 1.20 {
                cell.layer.borderWidth = 2.0 / scale
                cell.layer.borderColor = UIColor.white.cgColor
            } else {
                cell.layer.borderWidth = 0
            }
        }
    }
}
