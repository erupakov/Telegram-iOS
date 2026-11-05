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

    /// Пробует URL по очереди (один лоадер на всю попытку) и отдаёт первое загрузившееся фото;
    /// `nil` — не загрузилось ни одно (или список пуст).
    public static func loadProfilePhoto(
        urls: [URL],
        host: UIView?,
        completion: @escaping (UIImage?) -> Void
    ) {
        guard !urls.isEmpty else {
            completion(nil)
            return
        }
        let overlay = DivoLoadingOverlay()
        if let host {
            overlay.show(in: host, message: "")
        }
        loadFirst(urls[...]) { image in
            overlay.hide()
            completion(image)
        }
    }

    private static func loadFirst(_ urls: ArraySlice<URL>, completion: @escaping (UIImage?) -> Void) {
        guard let url = urls.first else {
            completion(nil)
            return
        }
        ImageLoader.shared.load(url: url) { image in
            if let image {
                completion(image)
            } else {
                loadFirst(urls.dropFirst(), completion: completion)
            }
        }
    }
}
