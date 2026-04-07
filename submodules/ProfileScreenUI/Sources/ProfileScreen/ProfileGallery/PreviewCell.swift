import Foundation
import UIKit
import AVFoundation
import Display
import AsyncDisplayKit
import TelegramCore
import DivoCore
import TelegramPresentationData
import AccountContext
import PhotoResources

final class PreviewCell: UICollectionViewCell {
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let spinner: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var imageLoadingTask: Task<Void, Never>?
    private var configurationId: Int = 0
    
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.backgroundColor = .darkGray
        self.layer.cornerRadius = 8
        self.clipsToBounds = true
        
        self.contentView.addSubview(self.imageView)
        self.contentView.addSubview(self.spinner)
        
        NSLayoutConstraint.activate([
            self.imageView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            self.imageView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
            self.imageView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
            self.imageView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor),
            
            self.spinner.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor),
            self.spinner.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    
    // MARK: - Override
    
    override func prepareForReuse() {
        super.prepareForReuse()
        configurationId &+= 1
        self.imageLoadingTask?.cancel()
        self.imageLoadingTask = nil
        self.imageView.image = nil
        self.spinner.startAnimating()
        // Сброс трансформации перед переиспользованием ячейки
        self.transform = .identity
        self.alpha = 1.0
        self.layer.borderWidth = 0
    }
    
    
    // MARK: - Internal
    
    func configure(with urlString: String, isVideo: Bool = false) {
        configurationId &+= 1
        let currentConfigurationId = configurationId
        
        self.imageLoadingTask?.cancel()
        self.imageLoadingTask = nil
        self.spinner.startAnimating()
        
        guard let url = URL(string: urlString) else {
            self.spinner.stopAnimating()
            return
        }
        
        if isVideo {
            let urlKey = url.absoluteString
            if let cached = VideoGalleryCell.cachedFirstFrame(for: urlKey)
                ?? VideoGalleryCell.cachedPreviewFrame(for: urlKey) {
                self.imageView.image = cached
                self.spinner.stopAnimating()
            } else {
                self.imageLoadingTask = Task { @MainActor in
                    do {
                        let image = try await self.generateVideoThumbnail(from: url, at: 0.1)
                        guard !Task.isCancelled, self.configurationId == currentConfigurationId else { return }
                        self.imageView.image = image
                        VideoGalleryCell.cachePreviewFrame(image, for: urlKey)
                    } catch {
                        guard !Task.isCancelled else { return }
                        print("Failed to generate video thumbnail: \(error)")
                    }
                    guard !Task.isCancelled, self.configurationId == currentConfigurationId else { return }
                    self.spinner.stopAnimating()
                }
            }
        } else {
            ImageLoader.shared.load(url: url) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self, self.configurationId == currentConfigurationId else { return }
                    self.spinner.stopAnimating()
                    if let image = image {
                        self.imageView.image = image
                    }
                }
            }
        }
    }
    
    
    // MARK: - Private
    
    private func generateVideoThumbnail(from url: URL, at time: Double) async throws -> UIImage {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 150, height: 150)
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: cmTime)]) { _, cgImage, _, _, _ in
                if let cgImage = cgImage {
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } else {
                    continuation.resume(throwing: NSError(domain: "ThumbnailGeneration", code: -1, userInfo: nil))
                }
            }
        }
    }
}
