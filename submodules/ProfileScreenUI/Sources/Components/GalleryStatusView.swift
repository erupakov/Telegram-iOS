//
//  GalleryStatusView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.03.2026.
//

import UIKit
import Display
import DivoUIKit

final class GalleryStatusView: UIControl {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let loadingSpinner: DivoSegmentedSpinner = {
        let spinner = DivoSegmentedSpinner()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isUserInteractionEnabled = false
        return spinner
    }()
    
    private let statusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = DivoImage.addMediaProfile
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        return imageView
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = DivoColorPalette.primaryText
        label.font = Font.regular(10)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    private lazy var contentView: UIView = {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.isUserInteractionEnabled = false
        return contentView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = true
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        statusImageView.isHidden = true
        addSubview(containerView)
        containerView.addSubview(contentView)
        contentView.addSubview(loadingSpinner)
        contentView.addSubview(statusImageView)
        contentView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 140),
            containerView.heightAnchor.constraint(equalToConstant: 70),
            
            contentView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            loadingSpinner.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -DivoDesignTokens.Spacing.l),
            loadingSpinner.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            loadingSpinner.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            statusImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            statusImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -DivoDesignTokens.Spacing.l),
            statusImageView.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            statusImageView.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            statusLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: statusImageView.bottomAnchor, constant: DivoDesignTokens.Spacing.xs),
            statusLabel.topAnchor.constraint(equalTo: loadingSpinner.bottomAnchor, constant: DivoDesignTokens.Spacing.xs),
        ])
    }
    
    func configure(isLoading: Bool, text: String, isMyProfile: Bool) {
        if isMyProfile {
            statusImageView.isHidden = false
        }
        statusLabel.text = text
        if isLoading {
            statusImageView.isHidden = true
            loadingSpinner.isHidden = false
            loadingSpinner.startAnimating()
            
            self.isEnabled = false
        } else {
            loadingSpinner.isHidden = true
            loadingSpinner.stopAnimating()
            statusImageView.isHidden = !isMyProfile
            self.isEnabled = isMyProfile
        }
    }
    
    func loadingSpinner(isLoading: Bool) {
        if isLoading {
            statusImageView.isHidden = true
            loadingSpinner.isHidden = false
            loadingSpinner.startAnimating()
            self.isEnabled = false
        } else {
            loadingSpinner.isHidden = true
            loadingSpinner.stopAnimating()
            statusImageView.isHidden = false
            self.isEnabled = true
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.containerView.alpha = self.isHighlighted ? 0.7 : 1.0
                self.containerView.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }
}
