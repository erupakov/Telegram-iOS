import UIKit
import PhotosUI
import Display
import DivoCore
import DivoUIKit

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
    private weak var host: UIViewController?
    private var pendingPicker: PHPickerViewController?
    private var isPickerDismissed = false
    private var loadResult: Swift.Result<UIImage, Error>?

    /// Показывает PHPicker на указанном контроллере. `completion` дёргается после выбора /
    /// отмены / ошибки. На этапе скелета результат — путь к временному файлу,
    /// которым coordinator кладёт значение в `FormFieldValue.asset(...)`.
    public func present(on host: UIViewController, completion: @escaping (Swift.Result<String, Error>) -> Void) {
        self.completion = completion
        self.host = host

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
        divoLog("PHPicker didFinishPicking: results.count=\(results.count)", level: .info)

        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            divoLog("PHPicker: no image provider in results — treat as cancel", level: .info)
            picker.dismiss(animated: true)
            finish(.failure(PickerError.nothingPicked), releasing: picker)
            return
        }

        // Кроп показываем, когда и PHPicker закрылся, и картинка загрузилась: present поверх
        // ещё закрывающегося пикера UIKit молча проигнорирует. `self` удерживается associated
        // object'ом на picker'е до finish(...) — см. present(on:).
        pendingPicker = picker
        picker.dismiss(animated: true) { [weak self] in
            self?.isPickerDismissed = true
            self?.presentCropIfReady()
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            let image = object as? UIImage
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    self.loadResult = .failure(error)
                } else if let image = image {
                    self.loadResult = .success(image)
                } else {
                    self.loadResult = .failure(PickerError.failedToLoadImage)
                }
                self.presentCropIfReady()
            }
        }
    }

    private func presentCropIfReady() {
        guard isPickerDismissed, let loadResult = loadResult, let picker = pendingPicker else { return }
        self.loadResult = nil

        let image: UIImage
        switch loadResult {
        case let .failure(error):
            divoLog("PHPicker loadObject failed: \(error)", level: .error)
            finish(.failure(error), releasing: picker)
            return
        case let .success(value):
            image = value
        }
        guard let host = self.host, host.presentedViewController == nil else {
            // Хост пропал/занят — не теряем выбор: сохраняем без кадрирования.
            saveAndFinish(image, releasing: picker)
            return
        }
        // Фото в онбординге — это аватар (или лого агентства), в UI он круглый:
        // даём выбрать зону кружком, как в «Редактировать профиль» (DIVI-68).
        let cropController = DivoAvatarCropController(
            image: image,
            shape: .circle,
            onComplete: { [weak self] cropped in
                self?.saveAndFinish(cropped, releasing: picker)
            },
            onCancel: { [weak self] in
                divoLog("Avatar crop cancelled — treat as cancel", level: .info)
                self?.finish(.failure(PickerError.nothingPicked), releasing: picker)
            }
        )
        host.present(cropController, animated: true)
    }

    private func saveAndFinish(_ image: UIImage, releasing picker: PHPickerViewController) {
        do {
            let path = try writeTempFile(image)
            divoLog("PHPicker: image saved to \(path)", level: .info)
            finish(.success(path), releasing: picker)
        } catch {
            divoLog("PHPicker writeTempFile failed: \(error)", level: .error)
            finish(.failure(error), releasing: picker)
        }
    }

    /// Отдаёт результат и отпускает удержание `self` на picker'е (последним — иначе self
    /// может деинициализироваться раньше вызова completion).
    private func finish(_ result: Swift.Result<String, Error>, releasing picker: PHPickerViewController) {
        completion?(result)
        completion = nil
        host = nil
        pendingPicker = nil
        objc_setAssociatedObject(picker, &Self.retainKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Helpers

    private func writeTempFile(_ image: UIImage) throws -> String {
        guard let data = image.fixedOrientation().jpegData(compressionQuality: 0.9) else {
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
