import UIKit
import PhotosUI
import DivoCore

/// Тонкая обёртка над `PHPickerViewController` для выбора фото на полях `.photo`.
///
/// PHPicker (iOS 14+) — современная альтернатива `UIImagePickerController`: не требует
/// явного разрешения на доступ к библиотеке (sandboxed), сразу даёт UI выбора. Это упрощает
/// онбординг — юзеру не приходится дважды кликать «Allow access».
///
/// Класс целиком помечен `@available(iOS 14, *)`. На iOS 13 (если он ещё в матрице поддержки)
/// нужен fallback на `UIImagePickerController` — пока не реализован.
@available(iOS 14, *)
public final class OnboardingPhotoPicker: NSObject, PHPickerViewControllerDelegate {

    public enum PickerError: Error, LocalizedError {
        case nothingPicked
        case failedToLoadImage
        case failedToWriteTempFile

        public var errorDescription: String? {
            switch self {
            case .nothingPicked: return "No photo selected"
            case .failedToLoadImage: return "Couldn't load the selected photo"
            case .failedToWriteTempFile: return "Couldn't save the photo locally"
            }
        }
    }

    private var completion: ((Swift.Result<String, Error>) -> Void)?

    /// Показывает PHPicker на указанном контроллере. `completion` дёргается после выбора /
    /// отмены / ошибки. На этапе скелета результат — путь к временному файлу,
    /// которым coordinator кладёт значение в `FormFieldValue.asset(...)`.
    public func present(on host: UIViewController, completion: @escaping (Swift.Result<String, Error>) -> Void) {
        self.completion = completion

        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        // Удерживаем `self` на время показа sheet — после dismiss отпустим в делегате.
        objc_setAssociatedObject(picker, &Self.retainKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        host.present(picker, animated: true)
    }

    // MARK: - PHPickerViewControllerDelegate

    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        defer { objc_setAssociatedObject(picker, &Self.retainKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }

        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            completion?(.failure(PickerError.nothingPicked))
            completion = nil
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    divoLog("Onboarding photo pick failed: \(error)", level: .error)
                    self.completion?(.failure(error))
                    self.completion = nil
                    return
                }
                guard let image = object as? UIImage else {
                    self.completion?(.failure(PickerError.failedToLoadImage))
                    self.completion = nil
                    return
                }
                do {
                    let path = try self.writeTempFile(image)
                    self.completion?(.success(path))
                } catch {
                    divoLog("Onboarding photo write failed: \(error)", level: .error)
                    self.completion?(.failure(error))
                }
                self.completion = nil
            }
        }
    }

    // MARK: - Helpers

    private func writeTempFile(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw PickerError.failedToWriteTempFile
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DivoOnboarding", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("photo-\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url.path
    }

    private static var retainKey: UInt8 = 0
}
