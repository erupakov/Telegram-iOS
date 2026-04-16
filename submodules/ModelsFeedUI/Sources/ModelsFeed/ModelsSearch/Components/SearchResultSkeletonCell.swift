//
//  SearchResultSkeletonCell.swift
//  ModelsFeedUI
//

import UIKit
import DivoUIKit

final class SearchResultSkeletonCell: UICollectionViewCell {

    static let reuseIdentifier = "SkeletonCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = DivoColorPalette.skeletonBackground
        contentView.layer.cornerRadius = DivoDesignTokens.Radius.l
        contentView.clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setShimmering(_ enabled: Bool) {
        if enabled {
            contentView.addShimmerOverlay()
        } else {
            contentView.removeShimmerOverlay()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.removeShimmerOverlay()
    }
}
