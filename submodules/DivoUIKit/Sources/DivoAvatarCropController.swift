import UIKit
import DivoCore

/// Круглое кадрирование аватара перед загрузкой: zoom/pan по фото + круглая
/// апертура. Свой светлый экран в DIVO-палитре (нативный редактор Telegram
/// жёстко тёмный и не бьётся с темой приложения).
///
/// Отдаёт квадратный `UIImage` области под кругом в `onComplete`; сам себя
/// закрывает по «Готово»/«Отмена».
public final class DivoAvatarCropController: UIViewController, UIScrollViewDelegate {

    private let image: UIImage
    private let onComplete: (UIImage) -> Void
    private let onCancel: (() -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let overlayView = CropOverlayView()
    private let titleLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)

    private var didSetupZoom = false

    // Отступ круга от краёв экрана.
    private let apertureMargin: CGFloat = 24.0
    // Потолок стороны выходного квадрата (px) — ава в UI мелкая, 1024 с запасом.
    private let maxOutputDimension: CGFloat = 1024.0

    public init(image: UIImage, onComplete: @escaping (UIImage) -> Void, onCancel: (() -> Void)? = nil) {
        self.image = image
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
        let side = min(view.bounds.width, view.bounds.height) - 2.0 * apertureMargin
        let x = (view.bounds.width - side) / 2.0
        let y = (view.bounds.height - side) / 2.0
        return CGRect(x: x, y: y, width: side, height: side)
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

        // Квадрат + кламп по границам изображения (страхует от дробных вылазов).
        let side = min(cropRect.width, cropRect.height)
        cropRect.size = CGSize(width: side, height: side)
        cropRect.origin.x = min(max(cropRect.origin.x, 0.0), max(CGFloat(cgImage.width) - side, 0.0))
        cropRect.origin.y = min(max(cropRect.origin.y, 0.0), max(CGFloat(cgImage.height) - side, 0.0))
        cropRect = cropRect.integral

        guard let cropped = cgImage.cropping(to: cropRect) else { return image }
        let croppedImage = UIImage(cgImage: cropped, scale: 1.0, orientation: .up)

        guard CGFloat(cropped.width) > maxOutputDimension else { return croppedImage }

        let targetSize = CGSize(width: maxOutputDimension, height: maxOutputDimension)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            croppedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - Overlay: светлый скрим + прозрачный круг

private final class CropOverlayView: UIView {

    var apertureRect: CGRect = .zero {
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

        let scrimPath = UIBezierPath(rect: bounds)
        scrimPath.append(UIBezierPath(ovalIn: apertureRect))
        scrimPath.usesEvenOddFillRule = true
        scrimLayer.path = scrimPath.cgPath

        ringLayer.path = UIBezierPath(ovalIn: apertureRect).cgPath
    }
}
