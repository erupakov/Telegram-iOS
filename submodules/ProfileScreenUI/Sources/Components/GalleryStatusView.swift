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
        view.backgroundColor = .black.withAlphaComponent(0.12)
        view.layer.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isUserInteractionEnabled = false
        return spinner
    }()
    
    private let statusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.image = DivoImage.addPhotoIcon
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        return imageView
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = Font.helveticaNeue(10)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        return label
    }()
    
    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [spinner, statusImageView, statusLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        return stack
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
        containerView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 140),
            containerView.heightAnchor.constraint(equalToConstant: 70),
            
            contentStack.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    func configure(isLoading: Bool, text: String, isMyProfile: Bool) {
        if isMyProfile {
            statusImageView.isHidden = false
        }
        statusLabel.text = text
        if isLoading {
            statusImageView.isHidden = true
            spinner.isHidden = false
            spinner.startAnimating()
            self.isEnabled = false
        } else {
            spinner.isHidden = true
            spinner.stopAnimating()
            statusImageView.isHidden = !isMyProfile
            self.isEnabled = isMyProfile
        }
    }
    
    func loadingSpinner(isLoading: Bool) {
        if isLoading {
            statusImageView.isHidden = true
            spinner.isHidden = false
            spinner.startAnimating()
            self.isEnabled = false
        } else {
            spinner.isHidden = true
            spinner.stopAnimating()
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
