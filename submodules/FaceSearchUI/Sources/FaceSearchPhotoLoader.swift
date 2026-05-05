import UIKit
import DivoUIKit

public enum FaceSearchPhotoLoader {
    public static func loadProfilePhoto(
        url: URL,
        host: UIView?,
        completion: @escaping (UIImage?) -> Void
    ) {
        let overlay = DivoLoadingOverlay()
        if let host {
            overlay.show(in: host, message: "")
        }
        ImageLoader.shared.load(url: url) { image in
            overlay.hide()
            completion(image)
        }
    }
}
