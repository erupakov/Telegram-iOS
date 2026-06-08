import UIKit
import Display
import AsyncDisplayKit
import CoreImage
import DivoUIKit
import DivoCore

final class DivoQrNode: ASDisplayNode {

    private enum Layout {
        static let cardSize: CGFloat = 280
        static let qrInset: CGFloat = 28
        static let buttonBottomInset: CGFloat = 40
        static let cardCenterYOffset: CGFloat = -40
        static let renderSize: CGFloat = 600
    }

    var onBackTapped: (() -> Void)?
    var onShareTapped: (() -> Void)?

    private let navigationBar = DivoNavigationBar()

    private let qrCard: UIView = {
        let view = UIView()
        // cardBackground = white — нужен именно белый фон под чёрными модулями QR для сканируемости.
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.card
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let qrImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    // Запасной вариант, если QR не сгенерировался (теоретически) — показываем саму ссылку текстом,
    // чтобы карточка не осталась пустой.
    private let fallbackLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private let shareButton = DivoButton()

    private let payload: String

    init(shareURL: String) {
        self.payload = shareURL
        super.init()

        self.backgroundColor = DivoColorPalette.screenBackground

        navigationBar.makeNavigationBar(
            title: DivoStrings.qrCodeTitle.uppercased(),
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            onBackTapped: { [weak self] in self?.onBackTapped?() }
        )

        shareButton.makeDivoButton(title: DivoStrings.share)
    }

    override func didLoad() {
        super.didLoad()
        setupUI()
        setupConstraints()
        if let image = DivoQrNode.makeQRImage(from: payload, size: Layout.renderSize) {
            qrImageView.image = image
        } else {
            qrImageView.isHidden = true
            fallbackLabel.isHidden = false
            fallbackLabel.text = payload
        }
        shareButton.addTarget(self, action: #selector(shareButtonPressed), for: .touchUpInside)
    }

    private func setupUI() {
        view.addSubview(navigationBar)
        view.addSubview(qrCard)
        qrCard.addSubview(qrImageView)
        qrCard.addSubview(fallbackLabel)
        view.addSubview(shareButton)
    }

    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: safeArea.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            qrCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            qrCard.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: Layout.cardCenterYOffset),
            qrCard.widthAnchor.constraint(equalToConstant: Layout.cardSize),
            qrCard.heightAnchor.constraint(equalToConstant: Layout.cardSize),

            qrImageView.topAnchor.constraint(equalTo: qrCard.topAnchor, constant: Layout.qrInset),
            qrImageView.bottomAnchor.constraint(equalTo: qrCard.bottomAnchor, constant: -Layout.qrInset),
            qrImageView.leadingAnchor.constraint(equalTo: qrCard.leadingAnchor, constant: Layout.qrInset),
            qrImageView.trailingAnchor.constraint(equalTo: qrCard.trailingAnchor, constant: -Layout.qrInset),

            fallbackLabel.centerYAnchor.constraint(equalTo: qrCard.centerYAnchor),
            fallbackLabel.leadingAnchor.constraint(equalTo: qrCard.leadingAnchor, constant: Layout.qrInset),
            fallbackLabel.trailingAnchor.constraint(equalTo: qrCard.trailingAnchor, constant: -Layout.qrInset),

            shareButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            shareButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Layout.buttonBottomInset),
        ])
    }

    @objc private func shareButtonPressed() {
        onShareTapped?()
    }

    private static func makeQRImage(from string: String, size: CGFloat) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage, ciImage.extent.width > 0 else { return nil }
        // Масштабируем ДО растеризации, чтобы пиксели остались чёткими (без размытия при upscale).
        let scale = size / ciImage.extent.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let ciContext = CIContext(options: nil)
        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
