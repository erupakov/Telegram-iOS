import UIKit

public final class SearchResultSkeletonCell: UICollectionViewCell {

    public static let reuseIdentifier = "SkeletonCell"

    override public init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = DivoColorPalette.skeletonBackground
        contentView.layer.cornerRadius = DivoDesignTokens.Radius.l
        contentView.clipsToBounds = true
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setShimmering(_ enabled: Bool) {
        if enabled {
            contentView.addShimmerOverlay()
        } else {
            contentView.removeShimmerOverlay()
        }
    }

    override public func prepareForReuse() {
        super.prepareForReuse()
        contentView.removeShimmerOverlay()
    }
}
