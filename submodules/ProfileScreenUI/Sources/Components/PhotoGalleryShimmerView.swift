import UIKit
import DivoUIKit

/// Скелетон для фото-таба профиля во время первичной загрузки.
/// Имитирует 3-колоночную сетку квадратных ячеек с 1pt-зазором, как
/// `galleryCollectionView`. Ячейки собираются на первом layoutSubviews,
/// когда bounds становятся ненулевыми; повторно — только если bounds
/// реально изменились (защита от лишних пересборок).
final class PhotoGalleryShimmerView: UIView {
    private let columns: Int = 3
    private let cellSpacing: CGFloat = 1
    /// Ровно 2 ряда — компактное «превью» grid'а. Сразу после шиммера идёт
    /// карусель similar (тоже в шиммер-стейте), без вертикального gap.
    private let maxRows: Int = 2
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

        let totalSpacing = CGFloat(columns - 1) * cellSpacing
        let cellSide = (bounds.width - totalSpacing) / CGFloat(columns)
        let rowStride = cellSide + cellSpacing
        // Используем `ceil`, иначе при контейнере ровно под 2 ряда
        // (например 262pt при rowStride 131.33pt = 1.99) `floor` даёт 1 ряд.
        let fittingRows = max(1, Int(ceil(bounds.height / rowStride)))
        let rows = min(maxRows, fittingRows)

        for row in 0..<rows {
            for col in 0..<columns {
                let cell = ShimmerView(frame: CGRect(
                    x: CGFloat(col) * (cellSide + cellSpacing),
                    y: CGFloat(row) * rowStride,
                    width: cellSide,
                    height: cellSide
                ))
                addSubview(cell)
                cells.append(cell)
            }
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
