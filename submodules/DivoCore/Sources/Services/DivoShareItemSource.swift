import Foundation
import UIKit
import LinkPresentation

public final class DivoShareItemSource: NSObject, UIActivityItemSource {
    private let url: URL
    private let title: String
    private let subtitle: String
    private let image: UIImage?

    public init(url: URL, title: String, subtitle: String, image: UIImage?) {
        self.url = url
        self.title = title
        self.subtitle = subtitle
        self.image = image
    }

    public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }

    public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        let label = subtitle.isEmpty ? title : "\(title) — \(subtitle)"
        return "\(label)\n\(url.absoluteString)"
    }

    public func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = subtitle.isEmpty ? title : "\(title)\n\(subtitle)"
        
        if let image = image {
            let largeImage = forceLargeSize(for: image)
            metadata.imageProvider = NSItemProvider(object: largeImage)
        }
        
        return metadata
    }
    
    
    // MARK: - Helpers
    
    private func forceLargeSize(for image: UIImage) -> UIImage {
        let minimumTargetSize: CGFloat = 600.0
        let maxDimension = max(image.size.width, image.size.height)
        
        if maxDimension >= minimumTargetSize {
            return image
        }
        
        let scale = minimumTargetSize / maxDimension
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
