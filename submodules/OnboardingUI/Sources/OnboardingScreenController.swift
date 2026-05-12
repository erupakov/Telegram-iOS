//
//  OnboardingScreenController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 28.02.2026.
//

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle

public class OnboardingScreenController: UIViewController, UIScrollViewDelegate {
    
    private let pagesData: [OnboardingPage] = [
        OnboardingPage(image: DivoImage.onboardingFirst, title: DivoStrings.onboardingTitle1, subtitle: DivoStrings.onboardingSubTitle1),
        OnboardingPage(image: DivoImage.onboardingSecond, title: DivoStrings.onboardingTitle2, subtitle: DivoStrings.onboardingSubTitle2),
        OnboardingPage(image: DivoImage.onboardingThird, title: DivoStrings.onboardingTitle3, subtitle: DivoStrings.onboardingSubTitle3)
    ]
    
    public var onFinish: (() -> Void)?
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.showsHorizontalScrollIndicator = false
        sv.backgroundColor = .clear
        sv.contentInsetAdjustmentBehavior = .never
        sv.delegate = self
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let pagesStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let pageControlStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = DivoDesignTokens.Spacing.s
        stack.distribution = .fill
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private var indicatorViews = [UIView]()
    private var indicatorWidthConstraints = [NSLayoutConstraint]()
    
    private let continueButton: DivoButton = {
        let btn = DivoButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateIndicatorsContinuously(progress: 0.0)
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        continueButton.makeDivoButton(title: DivoStrings.continueButton)
        
        view.backgroundColor = DivoColorPalette.shadow
        
        view.addSubview(scrollView)
        scrollView.addSubview(pagesStackView)
        view.addSubview(pageControlStackView)
        view.addSubview(continueButton)
        
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        
        for pageData in pagesData {
            let pageView = OnboardingPageView()
            pageView.configure(image: pageData.image, title: pageData.title, subtitle: pageData.subtitle)
            pagesStackView.addArrangedSubview(pageView)
            
            pageView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        }
        
        setupIndicators()
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            pagesStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            pagesStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            pagesStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            pagesStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            pagesStackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            continueButton.heightAnchor.constraint(equalToConstant: 56),
            
            pageControlStackView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -30),
            pageControlStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControlStackView.heightAnchor.constraint(equalToConstant: 10)
        ])
    }
    
    private func setupIndicators() {
        for _ in 0..<pagesData.count {
            let view = UIView()
            view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.6)
            view.layer.cornerRadius = DivoDesignTokens.Radius.xs
            view.translatesAutoresizingMaskIntoConstraints = false
            
            view.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.s).isActive = true
            let widthConstraint = view.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.s)
            widthConstraint.isActive = true
            indicatorWidthConstraints.append(widthConstraint)
            
            indicatorViews.append(view)
            pageControlStackView.addArrangedSubview(view)
        }
    }
    
    // MARK: - Actions & Logic
    
    @objc private func continueButtonTapped() {
        let currentIndex = Int(round(scrollView.contentOffset.x / view.bounds.width))
        let nextIndex = currentIndex + 1
        
        if nextIndex < pagesData.count {
            let offsetX = CGFloat(nextIndex) * view.bounds.width
            scrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
        } else {
            finishOnboarding()
        }
    }
    
    private func finishOnboarding() {
        print("Onboarding Finished!")
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        onFinish?()
    }
    
    // MARK: - Continuous Indicator Animation Logic
    
    private func updateIndicatorsContinuously(progress: CGFloat) {
        for (index, view) in indicatorViews.enumerated() {
            let distance = abs(progress - CGFloat(index))
            
            let activeRatio = max(0, 1.0 - distance)
            
            let minWidth: CGFloat = 8.0
            let maxWidth: CGFloat = 24.0
            let newWidth = minWidth + (maxWidth - minWidth) * activeRatio
            
            indicatorWidthConstraints[index].constant = newWidth
            
            let inactiveColor = DivoColorPalette.cardBackground.withAlphaComponent(0.6)
            view.backgroundColor = blendColor(from: inactiveColor, to: DivoColorPalette.accent, percentage: activeRatio)
        }
        
        self.pageControlStackView.layoutIfNeeded()
    }
    
    // Вспомогательная функция для плавного смешивания двух цветов
    private func blendColor(from color1: UIColor, to color2: UIColor, percentage: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 + (r2 - r1) * percentage
        let g = g1 + (g2 - g1) * percentage
        let b = b1 + (b2 - b1) * percentage
        let a = a1 + (a2 - a1) * percentage
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    // MARK: - UIScrollViewDelegate
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0 else { return }
        
        let progress = scrollView.contentOffset.x / scrollView.bounds.width
        
        updateIndicatorsContinuously(progress: progress)
    }
}
