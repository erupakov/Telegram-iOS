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

final class PhotoGalleryCellNode: UICollectionViewCell, UIScrollViewDelegate {
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.minimumZoomScale = 1.0
        sv.maximumZoomScale = 4.0
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        return sv
    }()
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        return iv
    }()
    
    private let spinner: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    var onSingleTap: (() -> Void)?

    // Ячейка переиспользуется при скролле: старая (медленная) загрузка не должна
    // перезаписать картинку нового элемента — отменяем таск и сверяем id конфигурации.
    private var imageLoadingTask: URLSessionDataTask?
    private var configurationId: Int = 0


    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.backgroundColor = .black
        
        self.scrollView.delegate = self
        self.contentView.addSubview(self.scrollView)
        self.scrollView.addSubview(self.imageView)
        self.contentView.addSubview(self.spinner)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        self.scrollView.addGestureRecognizer(doubleTap)
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.require(toFail: doubleTap)
        self.scrollView.addGestureRecognizer(singleTap)
    }
    
    required init?(coder: NSCoder) { fatalError() }


    // MARK: - Override
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ручная расстановка: так зум не конфликтует с констрейнтами
        self.scrollView.frame = self.contentView.bounds
        self.spinner.center = CGPoint(x: self.contentView.bounds.midX, y: self.contentView.bounds.midY)
        
        if self.scrollView.zoomScale == 1.0 {
            self.imageView.frame = self.scrollView.bounds
            self.scrollView.contentSize = self.imageView.bounds.size
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.cancelImageLoading()
        self.imageView.image = nil
        self.scrollView.zoomScale = 1.0
        self.spinner.startAnimating()
    }
    

    // MARK: - Internal

    func configure(with file: UserFile) {
        self.cancelImageLoading()
        self.spinner.startAnimating()
        self.scrollView.zoomScale = 1.0
        self.imageView.image = nil
        
        guard let urlString = file.fullUrl, let url = URL(string: urlString) else {
            self.spinner.stopAnimating()
            return
        }
        
        let currentConfigurationId = self.configurationId
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            let image = data.flatMap { UIImage(data: $0) }
            DispatchQueue.main.async {
                guard let self = self, self.configurationId == currentConfigurationId else { return }
                self.imageLoadingTask = nil
                if let image = image {
                    self.imageView.image = image
                } else if let error = error, (error as NSError).code != NSURLErrorCancelled {
                    print("Failed to load image: \(error)")
                }
                self.spinner.stopAnimating()
            }
        }
        self.imageLoadingTask = task
        task.resume()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        self.imageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                                        y: scrollView.contentSize.height * 0.5 + offsetY)
    }

    // MARK: - Private

    private func cancelImageLoading() {
        self.configurationId &+= 1
        self.imageLoadingTask?.cancel()
        self.imageLoadingTask = nil
    }

    // MARK: - @objc
    
    @objc private func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
        self.onSingleTap?()
    }
    
    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let point = recognizer.location(in: imageView)
            let scrollSize = scrollView.bounds.size
            let size = CGSize(width: scrollSize.width / scrollView.maximumZoomScale, height: scrollSize.height / scrollView.maximumZoomScale)
            let origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
            scrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
        }
    }
}