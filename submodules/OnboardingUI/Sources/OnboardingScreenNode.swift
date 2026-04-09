//
//  OnboardingScreenNode.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 28.02.2026.
//

import UIKit

struct OnboardingPage {
    let image: UIImage?
    let title: String
    let subtitle: String
}

class OnboardingScreenNode: UIViewController {

    private let backgroundImageView = UIImageView()
    
    init(page: OnboardingPage) {
        super.init(nibName: nil, bundle: nil)
        backgroundImageView.image = page.image
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    private func setupBackground() {
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}
