import UIKit
import DivoUIKit

/// Скелетон для табов-списков (channels / models / events) во время
/// первичной загрузки. Имитирует вертикальный список из 66pt-рядов,
/// как в реальных списках. Заменяет старый `*GalleryStatusView` со
/// starburst-спиннером в центре.
final class GalleryListShimmerView: UIView {
    private let rowHeight: CGFloat = 66
    private let rowSpacing: CGFloat = 8
    private let horizontalInset: CGFloat = 16
    private let cornerRadius: CGFloat = 12
    /// Максимум 4 ряда — превью списка, не залив всего экрана.
    private let maxRows: Int = 4
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

        let stride = rowHeight + rowSpacing
        let fittingRows = max(1, Int(floor(bounds.height / stride)))
        let rows = min(maxRows, fittingRows)
        let cellWidth = bounds.width - 2 * horizontalInset

        for row in 0..<rows {
            let cell = ShimmerView(frame: CGRect(
                x: horizontalInset,
                y: CGFloat(row) * stride,
                width: cellWidth,
                height: rowHeight
            ))
            cell.layer.cornerRadius = cornerRadius
            cell.layer.masksToBounds = true
            addSubview(cell)
            cells.append(cell)
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
