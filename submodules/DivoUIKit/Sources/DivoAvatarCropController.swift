import UIKit
import DivoCore

/// Кадрирование фото перед загрузкой: zoom/pan по фото + апертура (круг для аватара,
/// прямоугольник заданного aspect — для фона профиля). Свой светлый экран в DIVO-палитре
/// (нативный редактор Telegram жёстко тёмный и не бьётся с темой приложения).
///
/// Отдаёт `UIImage` области под апертурой в `onComplete` (для круга — квадрат); сам себя
/// закрывает по «Готово»/«Отмена».
public final class DivoAvatarCropController: UIViewController, UIScrollViewDelegate {

    public enum Shape {
        /// Круглая апертура, на выходе квадрат (аватар, лого агентства).
        case circle
        /// Прямоугольная апертура с соотношением сторон width / height (фон профиля).
        case rectangle(aspectRatio: CGFloat)
    }

    private let image: UIImage
    private let shape: Shape
    private let onComplete: (UIImage) -> Void
    private let onCancel: (() -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let overlayView = CropOverlayView()
    private let titleLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)

    private var didSetupZoom = false

    // Отступ апертуры от краёв экрана.
    private let apertureMargin: CGFloat = 24.0
    // Потолок большей стороны результата (px): ава в UI мелкая — 1024 с запасом;
    // фон профиля на весь экран — 2048.
    private var maxOutputDimension: CGFloat {
        switch shape {
        case .circle: return 1024.0
        case .rectangle: return 2048.0
        }
    }

    public init(image: UIImage, shape: Shape = .circle, onComplete: @escaping (UIImage) -> Void, onCancel: (() -> Void)? = nil) {
        // Кроп режет cgImage напрямую — EXIF-поворот должен быть уже «впечён» в пиксели.
        self.image = DivoAvatarCropController.normalizedOrientation(image)
        self.shape = shape
        self.onComplete = onComplete
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
        view.backgroundColor = DivoColorPalette.screenBackground

        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        imageView.image = image
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        overlayView.isUserInteractionEnabled = false
        if case .rectangle = shape {
            overlayView.isCircle = false
        }
        view.addSubview(overlayView)

        titleLabel.text = DivoStrings.avatarCropTitle
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.font = .systemFont(ofSize: 17.0, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        view.addSubview(titleLabel)

        cancelButton.setTitle(DivoStrings.cancel, for: .normal)
        cancelButton.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17.0, weight: .regular)
        cancelButton.contentHorizontalAlignment = .left
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)

        doneButton.setTitle(DivoStrings.done, for: .normal)
        doneButton.setTitleColor(DivoColorPalette.accent, for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17.0, weight: .semibold)
        doneButton.contentHorizontalAlignment = .right
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        view.addSubview(doneButton)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        scrollView.frame = view.bounds
        overlayView.frame = view.bounds

        let aperture = apertureRect()
        overlayView.apertureRect = aperture

        let safeTop = view.safeAreaInsets.top
        let barHeight: CGFloat = 44.0
        let sidePadding: CGFloat = 16.0
        let buttonWidth: CGFloat = 88.0
        cancelButton.frame = CGRect(x: sidePadding, y: safeTop, width: buttonWidth, height: barHeight)
        doneButton.frame = CGRect(x: view.bounds.width - sidePadding - buttonWidth, y: safeTop, width: buttonWidth, height: barHeight)
        let titleX = cancelButton.frame.maxX + 8.0
        titleLabel.frame = CGRect(x: titleX, y: safeTop, width: doneButton.frame.minX - 8.0 - titleX, height: barHeight)

        if !didSetupZoom {
            didSetupZoom = true
            setupZoom(aperture: aperture)
        } else {
            applyContentInset(aperture: aperture)
        }
    }

    private func apertureRect() -> CGRect {
        switch shape {
        case .circle:
            let side = min(view.bounds.width, view.bounds.height) - 2.0 * apertureMargin
            let x = (view.bounds.width - side) / 2.0
            let y = (view.bounds.height - side) / 2.0
            return CGRect(x: x, y: y, width: side, height: side)
        case let .rectangle(aspectRatio):
            // Вписываем прямоугольник в область между верхней панелью кнопок и низом safe area.
            let ratio = aspectRatio > 0 ? aspectRatio : 1.0
            let top = view.safeAreaInsets.top + 44.0 + apertureMargin
            let bottom = view.bounds.height - view.safeAreaInsets.bottom - apertureMargin
            let available = CGRect(
                x: apertureMargin,
                y: top,
                width: max(view.bounds.width - 2.0 * apertureMargin, 1.0),
                height: max(bottom - top, 1.0)
            )
            var width = available.width
            var height = width / ratio
            if height > available.height {
                height = available.height
                width = height * ratio
            }
            return CGRect(
                x: available.midX - width / 2.0,
                y: available.midY - height / 2.0,
                width: width,
                height: height
            )
        }
    }

    private func setupZoom(aperture: CGRect) {
        // Вырожденный размер картинки → деление в min-zoom дало бы NaN/inf и ассерт скролла.
        guard image.size.width > 0, image.size.height > 0 else { return }
        imageView.frame = CGRect(origin: .zero, size: image.size)

        // min-zoom, при котором фото гарантированно заполняет круг без пустот.
        let minScale = max(aperture.width / image.size.width, aperture.height / image.size.height)
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = max(minScale * 4.0, minScale)
        scrollView.zoomScale = minScale

        applyContentInset(aperture: aperture)

        // Центрируем фото по апертуре.
        let contentW = image.size.width * minScale
        let contentH = image.size.height * minScale
        scrollView.contentOffset = CGPoint(
            x: contentW / 2.0 - aperture.midX,
            y: contentH / 2.0 - aperture.midY
        )
    }

    // Инсеты = поля между краями скролла и апертурой: позволяют довести любой
    // край фото до края круга, но не дальше (круг всегда закрыт).
    private func applyContentInset(aperture: CGRect) {
        scrollView.contentInset = UIEdgeInsets(
            top: aperture.minY,
            left: aperture.minX,
            bottom: view.bounds.height - aperture.maxY,
            right: view.bounds.width - aperture.maxX
        )
    }

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onCancel?()
        }
    }

    @objc private func doneTapped() {
        let cropped = croppedImage()
        dismiss(animated: true) { [weak self] in
            self?.onComplete(cropped)
        }
    }

    private func croppedImage() -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let aperture = apertureRect()
        let scale = scrollView.zoomScale
        // Апертура в координатах контента скролла (учитывает contentOffset).
        let apertureInContent = view.convert(aperture, to: scrollView)

        // Контентные точки → точки изображения (÷ zoom) → пиксели (× image.scale).
        let px = image.scale
        var cropRect = CGRect(
            x: apertureInContent.origin.x / scale * px,
            y: apertureInContent.origin.y / scale * px,
            width: apertureInContent.size.width / scale * px,
            height: apertureInContent.size.height / scale * px
        )

        // Форма апертуры + кламп по границам изображения (страхует от дробных вылазов).
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        switch shape {
        case .circle:
            let side = min(cropRect.width, cropRect.height, imageWidth, imageHeight)
            cropRect.size = CGSize(width: side, height: side)
        case let .rectangle(aspectRatio):
            let ratio = aspectRatio > 0 ? aspectRatio : 1.0
            var width = min(cropRect.width, imageWidth)
            var height = width / ratio
            if height > imageHeight {
                height = imageHeight
                width = height * ratio
            }
            cropRect.size = CGSize(width: width, height: height)
        }
        cropRect.origin.x = min(max(cropRect.origin.x, 0.0), max(imageWidth - cropRect.width, 0.0))
        cropRect.origin.y = min(max(cropRect.origin.y, 0.0), max(imageHeight - cropRect.height, 0.0))
        cropRect = cropRect.integral

        guard let cropped = cgImage.cropping(to: cropRect) else { return image }
        let croppedImage = UIImage(cgImage: cropped, scale: 1.0, orientation: .up)

        let longestSide = CGFloat(max(cropped.width, cropped.height))
        guard longestSide > maxOutputDimension else { return croppedImage }

        let downscale = maxOutputDimension / longestSide
        let targetSize = CGSize(
            width: (CGFloat(cropped.width) * downscale).rounded(),
            height: (CGFloat(cropped.height) * downscale).rounded()
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            croppedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private static func normalizedOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up, image.size.width > 0, image.size.height > 0 else {
            return image
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

// MARK: - Overlay: светлый скрим + прозрачная апертура (круг или прямоугольник)

private final class CropOverlayView: UIView {

    var apertureRect: CGRect = .zero {
        didSet { setNeedsLayout() }
    }

    var isCircle: Bool = true {
        didSet { setNeedsLayout() }
    }

    private let scrimLayer = CAShapeLayer()
    private let ringLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        scrimLayer.fillRule = .evenOdd
        scrimLayer.fillColor = DivoColorPalette.screenBackground.withAlphaComponent(0.85).cgColor
        layer.addSublayer(scrimLayer)

        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.strokeColor = DivoColorPalette.cardBackground.cgColor
        ringLayer.lineWidth = 2.0
        layer.addSublayer(ringLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        scrimLayer.frame = bounds
        ringLayer.frame = bounds

        let aperturePath = isCircle
            ? UIBezierPath(ovalIn: apertureRect)
            : UIBezierPath(roundedRect: apertureRect, cornerRadius: 12.0)

        let scrimPath = UIBezierPath(rect: bounds)
        scrimPath.append(aperturePath)
        scrimPath.usesEvenOddFillRule = true
        scrimLayer.path = scrimPath.cgPath

        ringLayer.path = aperturePath.cgPath
    }
}
