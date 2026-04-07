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
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle

public class OnboardingScreenController: UIViewController {
    
    private let pagesData: [OnboardingPage] = [
        OnboardingPage(imageName: "Onboarding/OnboardingFirst", title: DivoStrings.onboardingTitle1),
        OnboardingPage(imageName: "Onboarding/OnboardingSecond", title: DivoStrings.onboardingTitle2),
        OnboardingPage(imageName: "Onboarding/OnboardingThird", title: DivoStrings.onboardingTitle3)
    ]
    
    public var onFinish: (() -> Void)?

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.backgroundColor = .black
        cv.contentInsetAdjustmentBehavior = .never
        cv.register(OnboardingCell.self, forCellWithReuseIdentifier: OnboardingCell.reuseIdentifier)
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()
    
    private let pageControlStackView = UIStackView()
    private var indicatorViews = [UIView]()
    private var indicatorWidthConstraints = [NSLayoutConstraint]()
    
    private let continueButton = UIButton(type: .system)
    
    private let brandColor = UIColor(hex: "#BF7A54")
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateIndicators(currentIndex: 0)
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        pageControlStackView.axis = .horizontal
        pageControlStackView.spacing = 8
        pageControlStackView.distribution = .fill
        pageControlStackView.alignment = .center
        pageControlStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControlStackView)
        
        setupIndicators()
        
        continueButton.setTitle(DivoStrings.continueButton, for: .normal)
        continueButton.titleLabel?.font = Font.helveticaNeue(20)
        continueButton.backgroundColor = brandColor
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.layer.cornerRadius = 6
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(continueButton)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            continueButton.heightAnchor.constraint(equalToConstant: 56),
            
            pageControlStackView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -30),
            pageControlStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControlStackView.heightAnchor.constraint(equalToConstant: 10)
        ])
        
        view.layoutIfNeeded()
    }
    
    private func setupIndicators() {
        for _ in 0..<pagesData.count {
            let view = UIView()
            view.backgroundColor = .white.withAlphaComponent(0.5)
            view.layer.cornerRadius = 4
            view.translatesAutoresizingMaskIntoConstraints = false
            
            view.heightAnchor.constraint(equalToConstant: 8).isActive = true
            
            let widthConstraint = view.widthAnchor.constraint(equalToConstant: 8)
            widthConstraint.isActive = true
            indicatorWidthConstraints.append(widthConstraint)
            
            indicatorViews.append(view)
            pageControlStackView.addArrangedSubview(view)
        }
    }
    
    
    // MARK: - Actions & Logic
    
    @objc private func continueButtonTapped() {
        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        let visiblePoint = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        
        guard let indexPath = collectionView.indexPathForItem(at: visiblePoint) else { return }
        
        let nextIndex = indexPath.item + 1
        
        if nextIndex < pagesData.count {
            collectionView.scrollToItem(at: IndexPath(item: nextIndex, section: 0), at: .centeredHorizontally, animated: true)
        } else {
            finishOnboarding()
        }
    }
    
    private func finishOnboarding() {
        print("Onboarding Finished!")
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        onFinish?()
    }
    
    
    // MARK: - Indicator Animation Logic
    
    private func updateIndicators(currentIndex: Int) {
        for (index, _) in indicatorViews.enumerated() {
            indicatorWidthConstraints[index].constant = (index == currentIndex) ? 24 : 8
        }
        UIView.animate(withDuration: 0.3) {
            for (index, view) in self.indicatorViews.enumerated() {
                view.backgroundColor = (index == currentIndex) ? self.brandColor : .white.withAlphaComponent(0.5)
            }
            self.pageControlStackView.layoutIfNeeded()
        }
    }
}


// MARK: - UICollectionView DataSource & Delegate
extension OnboardingScreenController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pagesData.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OnboardingCell.reuseIdentifier, for: indexPath) as? OnboardingCell else {
            return UICollectionViewCell()
        }

        let data = pagesData[indexPath.item]
        cell.configure(imageName: data.imageName, title: data.title)
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.frame.size
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let centerPoint = CGPoint(x: scrollView.contentOffset.x + scrollView.frame.width / 2, y: scrollView.frame.height / 2)

        if let indexPath = collectionView.indexPathForItem(at: centerPoint) {
            updateIndicators(currentIndex: indexPath.item)
        }
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
