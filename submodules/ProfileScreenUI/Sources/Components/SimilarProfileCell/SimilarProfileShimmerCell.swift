//
//  SimilarProfileCell.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 08.03.2026.
//

import UIKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit

final class SimilarProfileShimmerCell: UICollectionViewCell {
    static let reuseIdentifier = "SimilarProfileShimmerCell"
    
    private let shimmerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(shimmerContainer)
        NSLayoutConstraint.activate([
            shimmerContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            shimmerContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            shimmerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            shimmerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func startAnimation() {
        self.layoutIfNeeded()
        
        if shimmerContainer.layer.animation(forKey: "shimmer") == nil {
            shimmerContainer.startShimmering()
        }
    }
}
