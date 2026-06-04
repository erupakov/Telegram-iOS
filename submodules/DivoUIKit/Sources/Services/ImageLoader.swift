import UIKit
import ObjectiveC
import DivoCore

public final class ImageLoader {
    public static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 150
    }

    public func cachedImage(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }

    public func load(url: URL, completion: @escaping (UIImage?) -> Void) {
        let deliver: (UIImage?) -> Void = { image in
            if DivoDebugFlags.slowImageLoading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { completion(image) }
            } else {
                DispatchQueue.main.async { completion(image) }
            }
        }

        if let cached = cache.object(forKey: url as NSURL) {
            deliver(cached)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                deliver(nil)
                return
            }
            self?.cache.setObject(image, forKey: url as NSURL)
            deliver(image)
        }.resume()
    }
}

private var currentURLKey: UInt8 = 0

public extension UIImageView {
    var currentLoadingURL: URL? {
        get { objc_getAssociatedObject(self, &currentURLKey) as? URL }
        set { objc_setAssociatedObject(self, &currentURLKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func loadImage(from url: URL?, placeholder: UIImage? = nil, cropAvatarIfNeeded: Bool = false) {
        loadImage(from: url, placeholder: placeholder, cropAvatarIfNeeded: cropAvatarIfNeeded, completion: nil)
    }

    func loadImage(from url: URL?, placeholder: UIImage? = nil, cropAvatarIfNeeded: Bool = false, completion: ((UIImage?) -> Void)?) {
        image = placeholder
        
        if cropAvatarIfNeeded {
            applyAvatarTopCropIfNeeded(image: placeholder)
        } else {
            layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        currentLoadingURL = url
        guard let url = url, !DivoDebugFlags.forceImagePlaceholders else {
            removeShimmerOverlay()
            completion?(nil)
            return
        }

        addShimmerOverlay()

        ImageLoader.shared.load(url: url) { [weak self] loadedImage in
            guard self?.currentLoadingURL == url else { return }

            let finalImage = loadedImage ?? placeholder
            self?.image = finalImage
            
            if cropAvatarIfNeeded {
                self?.applyAvatarTopCropIfNeeded(image: finalImage)
            }
            
            self?.removeShimmerOverlay()
            completion?(loadedImage)
        }
    }

    /// Кроп для круглых аватарок: для портретных фото берём верхний квадрат,
    /// чтобы лицо/голова не «съедались» при центрированном `.scaleAspectFill`.
    ///
    /// Выставляет `layer.contentsRect`.
    func applyAvatarTopCropIfNeeded(image: UIImage?) {
        guard let image, let cgImage = image.cgImage else {
            layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            return
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        guard width > 0, height > 0 else {
            layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
            return
        }

        if height > width {
            // Портрет: верхний квадрат.
            let normalizedCropHeight = width / height
            layer.contentsRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: normalizedCropHeight)
        } else if width > height {
            // Альбом: центральный квадрат по X.
            let normalizedCropWidth = height / width
            let x = (1.0 - normalizedCropWidth) / 2.0
            layer.contentsRect = CGRect(x: x, y: 0.0, width: normalizedCropWidth, height: 1.0)
        } else {
            layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
    }

    func cancelImageLoad() {
        currentLoadingURL = nil
        removeShimmerOverlay()
    }
}
