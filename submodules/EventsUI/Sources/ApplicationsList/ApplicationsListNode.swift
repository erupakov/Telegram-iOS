//
//  ApplicationsListNode.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 28.05.2026.
//

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import DivoUIKit
import DivoCore

final class ApplicationsListNode: ASDisplayNode {
    private let context: AccountContext
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var savedNavBarHeight: CGFloat = 56

    // Callbacks
    var onBackTapped: (() -> Void)?
    var onTabSelected: ((Int) -> Void)?
    var onApplicantTapped: ((ApplicantItem) -> Void)?
    var onSelectionTapped: ((Int) -> Void)?
    var onRetry: (() -> Void)?

    private let navigationBar = DivoNavigationBar()

    // MARK: - UI Elements

    private let searchFadeOverlay: UIView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        if let gradient = view.layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.cgColor,
                DivoColorPalette.screenBackground.withAlphaComponent(0).cgColor,
            ]
            gradient.locations = [0, 0.45]
        }
        return view
    }()

    // Мета-заголовок
    private let metaHeaderContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(ApplicationsListCell.self, forCellWithReuseIdentifier: ApplicationsListCell.reuseIdentifier)
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()

    private let emptyView: DivoEmptyStateView = {
        let view = DivoEmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // Вью полноэкранной ошибки
    private let errorView: ProfileTabErrorView = {
        let view = ProfileTabErrorView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private var items: [ApplicantItem] = []
    private var shimmerViews: [UIView] = []

    // MARK: - State Machine (Стейт-машина)
    public enum ApplyPhase: Equatable {
        case loading
        case content
        case empty
        case failed(networkError: Bool)
    }

    public var phase: ApplyPhase = .loading {
        didSet {
            if oldValue != phase { applyState() }
        }
    }

    // MARK: - Init
    init(context: AccountContext) {
        self.context = context
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground
        setupUI()
        showShimmers()
    }

    private func setupUI() {
        self.view.addSubview(navigationBar)
        self.view.addSubview(collectionView)
        self.view.addSubview(searchFadeOverlay)
        self.view.addSubview(emptyView)
        self.view.addSubview(metaHeaderContainer)
        
        metaHeaderContainer.addSubview(countLabel)

        navigationBar.makeNavigationBar(
            title: DivoStrings.applicationsList.uppercased(),
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            onBackTapped: { [weak self] in self?.onBackTapped?() }
        )
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),

            metaHeaderContainer.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: DivoDesignTokens.Spacing.l),
            metaHeaderContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            metaHeaderContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            metaHeaderContainer.heightAnchor.constraint(equalToConstant: 20),
            
            searchFadeOverlay.topAnchor.constraint(equalTo: metaHeaderContainer.bottomAnchor),
            searchFadeOverlay.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            searchFadeOverlay.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            searchFadeOverlay.heightAnchor.constraint(equalToConstant: 60),

            countLabel.leadingAnchor.constraint(equalTo: metaHeaderContainer.leadingAnchor),
            countLabel.centerYAnchor.constraint(equalTo: metaHeaderContainer.centerYAnchor),

            collectionView.topAnchor.constraint(equalTo: metaHeaderContainer.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            emptyView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 20),
            emptyView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            emptyView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        setupErrorView()
    }

    private func setupErrorView() {
        self.view.addSubview(errorView)
        NSLayoutConstraint.activate([
            errorView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            errorView.topAnchor.constraint(equalTo: self.view.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        self.view.bringSubviewToFront(navigationBar)
    }

    override func layout() {
        super.layout()
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        self.savedNavBarHeight = navigationBarHeight
        self.layoutIfNeeded()
    }

    private func applyState() {
        switch phase {
        case .loading:
            collectionView.isHidden = true
            metaHeaderContainer.isHidden = true
            emptyView.isHidden = true
            errorView.isHidden = true
            showShimmers()
            
        case .content:
            collectionView.isHidden = false
            metaHeaderContainer.isHidden = false
            emptyView.isHidden = true
            errorView.isHidden = true
            hideShimmers()
            
        case .empty:
            collectionView.isHidden = true
            metaHeaderContainer.isHidden = true
            emptyView.isHidden = false
            errorView.isHidden = true
            hideShimmers()
            
            emptyView.configure(.init(
                style: .largeIcon(icon: DivoImage.emptyApplications),
                title: DivoStrings.noApplicationsYet,
                subtitle: ""
            ))
            
        case .failed(let networkError):
            collectionView.isHidden = true
            metaHeaderContainer.isHidden = true
            emptyView.isHidden = true
            hideShimmers()
            
            errorView.configure(
                title: networkError ? DivoStrings.profileTabErrorNetworkTitle : DivoStrings.eventDetailErrorTitle,
                subtitle: DivoStrings.profileTabErrorSubtitle,
                onRetry: { [weak self] in self?.onRetry?() }
            )
            errorView.isHidden = false
        }
    }

    private func showShimmers() {
        hideShimmers()
        let startY = savedNavBarHeight + 32 + 18 + 20 + 10 // отступ под навбаром и сегментом
        let rowHeight: CGFloat = 72
        
        for i in 0..<6 {
            let rowShimmer = UIView()
            rowShimmer.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
            rowShimmer.layer.cornerRadius = 16
            rowShimmer.translatesAutoresizingMaskIntoConstraints = false
            
            self.view.addSubview(rowShimmer)
            shimmerViews.append(rowShimmer)
            
            NSLayoutConstraint.activate([
                rowShimmer.topAnchor.constraint(equalTo: self.view.topAnchor, constant: startY + CGFloat(i) * rowHeight),
                rowShimmer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
                rowShimmer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                rowShimmer.heightAnchor.constraint(equalToConstant: 64)
            ])
            rowShimmer.startShimmering()
        }
    }

    private func hideShimmers() {
        shimmerViews.forEach {
            $0.stopShimmering()
            $0.removeFromSuperview()
        }
        shimmerViews.removeAll()
    }

    func update(items: [ApplicantItem], totalCount: Int) {
        self.items = items
        self.countLabel.text = DivoStrings.currentApplied(totalCount)
        self.collectionView.reloadData()
    }
}

// MARK: - UICollectionView Delegate & DataSource
extension ApplicationsListNode: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.item < items.count else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: ApplicationsListCell.reuseIdentifier, for: indexPath)
        }
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ApplicationsListCell.reuseIdentifier, for: indexPath) as? ApplicationsListCell else {
            return UICollectionViewCell()
        }
        let item = items[indexPath.item]
        cell.configure(with: item)
        
        cell.onSelectionTapped = { [weak self] in
            self?.onSelectionTapped?(item.id)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < items.count else { return }
        onApplicantTapped?(items[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 72)
    }
}
