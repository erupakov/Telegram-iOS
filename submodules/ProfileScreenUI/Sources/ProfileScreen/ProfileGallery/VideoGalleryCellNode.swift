import Foundation
import UIKit
import AVFoundation
import AVKit
import Display
import AsyncDisplayKit
import TelegramCore
import DivoCore
import TelegramPresentationData
import AccountContext
import PhotoResources

final class VideoGalleryCellNode: UICollectionViewCell {
    
    private let playerViewController = AVPlayerViewController()
    private let loadingSpinner = UIActivityIndicatorView(style: .large)
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    private var displayLink: CADisplayLink?
    private var pendingVideoURL: URL?
    
    private weak var nativeControlsView: UIView?
    
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    
    // MARK: - Override
    
    override func prepareForReuse() {
        super.prepareForReuse()
        resetPlayer()
    }
    
    
    // MARK: - Internal
    
    func configure(with file: UserVideoFile) {
        resetPlayer()
        guard let urlString = file.fullUrl, let url = URL(string: urlString) else { return }
        pendingVideoURL = url
    }
    
    func play() {
        if player == nil, let url = pendingVideoURL {
            setupPlayer(with: url)
        }
        player?.play()
    }
    
    func pause() { player?.pause() }
    
    
    // MARK: - Private
    
    private func setupViews() {
        self.backgroundColor = .black
        contentView.backgroundColor = .black
        
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        playerViewController.videoGravity = .resizeAspect
        playerViewController.showsPlaybackControls = true
        
        playerViewController.additionalSafeAreaInsets = UIEdgeInsets(top: 120, left: 0, bottom: 150, right: 0)
        contentView.addSubview(playerViewController.view)
        
        loadingSpinner.color = .white
        loadingSpinner.hidesWhenStopped = true
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingSpinner)
        
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            loadingSpinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    private func getAppleControlsView() -> UIView? {
        if let cached = nativeControlsView, cached.superview != nil {
            return cached
        }
        guard let root = playerViewController.view else { return nil }
        nativeControlsView = recursiveSearchForControlsView(in: root)
        return nativeControlsView
    }
    
    private func recursiveSearchForControlsView(in view: UIView) -> UIView? {
        let className = String(describing: type(of: view))
        if className.contains("PlaybackControls") {
            return view
        }
        for subview in view.subviews {
            if let found = recursiveSearchForControlsView(in: subview) {
                return found
            }
        }
        return nil
    }
    
    private func setupPlayer(with url: URL) {
        loadingSpinner.startAnimating()
        
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.isMuted = false
        playerViewController.player = player
        
        statusObservation = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                if item.status == .readyToPlay || item.status == .failed {
                    self?.loadingSpinner.stopAnimating()
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }
    
    private func resetPlayer() {
        statusObservation?.invalidate()
        statusObservation = nil
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        player?.pause()
        player = nil
        playerItem = nil
        pendingVideoURL = nil
        playerViewController.player = nil
        loadingSpinner.stopAnimating()
        
        nativeControlsView = nil
    }
}