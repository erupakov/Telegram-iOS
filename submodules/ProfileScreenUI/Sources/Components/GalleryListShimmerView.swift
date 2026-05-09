import UIKit
import DivoUIKit

/// Скелетон для табов-списков (channels / models / events) во время
/// первичной загрузки. Каждый ряд: круглая аватарка 52×52 + 2 строки текста
/// (164×24 сверху, 209×25 снизу с клампом по ширине экрана). Рядов столько,
/// сколько влезает в текущую высоту контейнера — шиммер заполняет весь
/// видимый экран.
final class GalleryListShimmerView: UIView {
    private let rowSpacing: CGFloat = 16
    private let horizontalInset: CGFloat = 16
    private let avatarSize: CGFloat = 52
    private let avatarToTextSpacing: CGFloat = 6
    private let firstLineWidth: CGFloat = 164
    private let firstLineHeight: CGFloat = 24
    private let secondLineWidth: CGFloat = 209
    private let secondLineHeight: CGFloat = 25
    private let textLineGap: CGFloat = 4
    private var cells: [ShimmerView] = []
    private var lastLaidOutBounds: CGRect = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds != lastLaidOutBounds else { return }
        lastLaidOutBounds = bounds
        rebuildCells()
    }

    private func rebuildCells() {
        cells.forEach {
            $0.stopShimmer()
            $0.removeFromSuperview()
        }
        cells.removeAll()

        guard bounds.width > 0, bounds.height > 0 else { return }

        let textOriginX = horizontalInset + avatarSize + avatarToTextSpacing
        // Кламп ширины: палка не должна вылезать за правый край (важно для
        // узких экранов типа iPhone SE, где 209pt не влезают).
        let textAvailableWidth = max(0, bounds.width - textOriginX - horizontalInset)
        let firstLine = min(firstLineWidth, textAvailableWidth)
        let secondLine = min(secondLineWidth, textAvailableWidth)

        // Высота ряда = max(аватара, текстового блока). На практике аватар
        // 52pt больше блока 24+4+25 = 53pt — ряд диктуется большим из них.
        let textBlockHeight = firstLineHeight + textLineGap + secondLineHeight
        let rowHeight = max(avatarSize, textBlockHeight)
        let stride = rowHeight + rowSpacing

        // Заполняем всю высоту: округляем вверх, чтобы последний ряд частично
        // уходил за нижний край (clipsToBounds = true обрежет).
        let rows = max(1, Int(ceil(bounds.height / stride)))

        for row in 0..<rows {
            let rowOriginY = CGFloat(row) * stride

            let avatar = ShimmerView(frame: CGRect(
                x: horizontalInset,
                y: rowOriginY + (rowHeight - avatarSize) / 2,
                width: avatarSize,
                height: avatarSize
            ))
            avatar.layer.cornerRadius = avatarSize / 2
            avatar.layer.masksToBounds = true
            addSubview(avatar)
            cells.append(avatar)

            // Текстовый блок центрирован по высоте ряда.
            let textBlockOriginY = rowOriginY + (rowHeight - textBlockHeight) / 2

            let firstLineView = ShimmerView(frame: CGRect(
                x: textOriginX,
                y: textBlockOriginY,
                width: firstLine,
                height: firstLineHeight
            ))
            firstLineView.layer.cornerRadius = firstLineHeight / 2
            firstLineView.layer.masksToBounds = true
            addSubview(firstLineView)
            cells.append(firstLineView)

            let secondLineView = ShimmerView(frame: CGRect(
                x: textOriginX,
                y: textBlockOriginY + firstLineHeight + textLineGap,
                width: secondLine,
                height: secondLineHeight
            ))
            secondLineView.layer.cornerRadius = secondLineHeight / 2
            secondLineView.layer.masksToBounds = true
            addSubview(secondLineView)
            cells.append(secondLineView)
        }

        if !isHidden {
            cells.forEach { $0.startShimmer() }
        }
    }

    func startAnimation() {
        cells.forEach { $0.startShimmer() }
    }

    func stopAnimation() {
        cells.forEach { $0.stopShimmer() }
    }
}
