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
import DivoUIKit

final class WorkExperience: ASDisplayNode {

    private let model: ProfileModel
    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var openAddWorkExperience: (() -> Void)?
    var onBackTapped: (() -> Void)?
    
    var onEditItem: ((WorkHistoryItem) -> Void)?
    var onDeleteItem: ((WorkHistoryItem) -> Void)?

    private let navigationBar = DivoNavigationBar()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let listBackgroundContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let listStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let emptyStateContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.m
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true
        return stack
    }()
    
    private let emptyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(26)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.noWorkExperienceYet.uppercased()
        label.numberOfLines = 2
        return label
    }()
    
    private let emptySubTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.noWorkExperienceSubtitle
        label.numberOfLines = 3
        return label
    }()
    
    private let addExperienceButton = DivoButton()
    
    private var rawItems: [WorkHistoryItem] = []
    private var hasStructuredData = false
    private var isLoading = true
    private let shimmerCount = 4
    private var experienceCells:[Int: ExperienceView] = [:]
    private var cachedLogoURLs: [Int: URL] = [:]

    
    // MARK: - Init
    
    init(controller: ViewController, context: AccountContext, presentationData: PresentationData, model: ProfileModel) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        self.model = model
        
        super.init()

        self.backgroundColor = DivoColorPalette.screenBackground
        
        navigationBar.makeNavigationBar(
            title: DivoStrings.workExperience.uppercased(),
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            rightButtonConfiguration: model.isMyProfile ? .circle(DivoColorPalette.cardBackground, DivoColorPalette.primaryText, DivoImage.plusWorkHistory, .pill) : nil,
            onBackTapped: { [weak self] in self?.onBackTapped?() },
            onCircleRightTapped: model.isMyProfile ? { [weak self] in self?.openAddWorkExperience?() } : nil
        )
        
        addExperienceButton.makeDivoButton(title: DivoStrings.addWorkExperience)
    }

    override func didLoad() {
        super.didLoad()
        setupUI()
        setupInteractions()
    }
    
    
    // MARK: - Setup
    
    private func setupUI() {
        view.addSubview(navigationBar)
        
        view.addSubview(scrollView)
        scrollView.addSubview(listBackgroundContainer)
        listBackgroundContainer.addSubview(listStackView)
        
        let iconView = UIImageView(image: DivoImage.badgeBaseWork)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 70).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 70).isActive = true
        
        emptyStateContainer.addArrangedSubview(iconView)
        emptyStateContainer.addArrangedSubview(emptyTitleLabel)
        emptyStateContainer.addArrangedSubview(emptySubTitleLabel)
        view.addSubview(emptyStateContainer)
        
        view.addSubview(addExperienceButton)
        
        setupConstraints()
        updateEmptyState()
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: safeArea.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // --- ScrollView ---
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            listBackgroundContainer.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            listBackgroundContainer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            listBackgroundContainer.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            listBackgroundContainer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
            listBackgroundContainer.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -DivoDesignTokens.Spacing.xl),
            
            listStackView.topAnchor.constraint(equalTo: listBackgroundContainer.topAnchor),
            listStackView.leadingAnchor.constraint(equalTo: listBackgroundContainer.leadingAnchor),
            listStackView.trailingAnchor.constraint(equalTo: listBackgroundContainer.trailingAnchor),
            listStackView.bottomAnchor.constraint(equalTo: listBackgroundContainer.bottomAnchor),
            
            emptyStateContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            addExperienceButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            addExperienceButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            addExperienceButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            addExperienceButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func setupInteractions() {
        addExperienceButton.addTarget(self, action: #selector(addPressed), for: .touchUpInside)
    }
    
    
    // MARK: - Data Loading
    
    func setLoading(_ loading: Bool) {
        self.isLoading = loading
        updateEmptyState()
        renderList()
    }

    func reloadWorkHistory(items: [WorkHistoryItem]) {
        self.isLoading = false
        self.rawItems = items
        self.hasStructuredData = true
        
        updateEmptyState()
        renderList()
    }

    func reloadLegacyWorkHistory(model: UserDetail) {
        self.isLoading = false
        self.rawItems = []
        self.hasStructuredData = false
        
        let experienceString = model.model?.workExperience ?? ""
        let experienceNames = experienceString
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        self.rawItems = experienceNames.map { name in
            WorkHistoryItem(
                id: 0,
                agencyId: nil,
                agencyName: name,
                agencyDisplayName: name,
                startDate: nil,
                endDate: nil,
                isCurrent: false
            )
        }
        
        updateEmptyState()
        renderList()
    }
    
    func indexOfItem(id: Int) -> Int {
        return rawItems.firstIndex(where: { $0.id == id }) ?? rawItems.count
    }

    func removeItem(id: Int) {
        rawItems.removeAll { $0.id == id }
        if let cell = experienceCells.removeValue(forKey: id) {
            cell.removeFromSuperview()
        }
        cachedLogoURLs.removeValue(forKey: id)
        updateEmptyState()
        listBackgroundContainer.isHidden = rawItems.isEmpty
    }

    func insertItem(_ item: WorkHistoryItem, at index: Int) {
        let safeIndex = min(index, rawItems.count)
        rawItems.insert(item, at: safeIndex)
        updateEmptyState()
        renderList()
    }

    func updateAgencyLogo(itemId: Int, url: URL?) {
        if let url = url {
            cachedLogoURLs[itemId] = url
        }
        guard let cell = experienceCells[itemId],
              let item = rawItems.first(where: { $0.id == itemId }) else { return }
        
        let period = item.formattedPeriod
        
        let wItem = WorkExperienceItem(
            id: item.id,
            companyName: item.agencyDisplayName ?? item.agencyName ?? DivoStrings.unknownAgency,
            period: period,
            logoURL: url
        )
        
        let showOptions = model.isMyProfile && hasStructuredData
        cell.configure(with: wItem, showOptions: showOptions, loadImage: true)
    }
    
    
    // MARK: - Rendering
    
    private func renderList() {
        listStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        experienceCells.removeAll()
        
        if isLoading && rawItems.isEmpty {
            for _ in 0..<shimmerCount {
                let cell = ExperienceView()
                cell.configureAsShimmer()
                listStackView.addArrangedSubview(cell)
            }
        } else {
            for (_, item) in rawItems.enumerated() {
                let logoURL = cachedLogoURLs[item.id]

                let period = item.formattedPeriod

                let wItem = WorkExperienceItem(
                    id: item.id,
                    companyName: item.agencyDisplayName ?? item.agencyName ?? DivoStrings.unknownAgency,
                    period: period,
                    logoURL: logoURL
                )

                let cell = ExperienceView()

                let showOptions = model.isMyProfile && hasStructuredData
                let hasLogo = logoURL != nil
                let shouldLoadImmediately = hasLogo || (item.agencyId == nil)
                cell.configure(with: wItem, showOptions: showOptions, loadImage: shouldLoadImmediately)
                
                if showOptions {
                    cell.onEditTapped = { [weak self] in
                        self?.onEditItem?(item)
                    }
                    
                    cell.onDeleteTapped = { [weak self] in
                        self?.onDeleteItem?(item)
                    }
                }
                
                experienceCells[item.id] = cell
                
                listStackView.addArrangedSubview(cell)
            }
        }
        
        listBackgroundContainer.isHidden = (isLoading && rawItems.isEmpty) ? false : rawItems.isEmpty
    }
    
    private func updateEmptyState() {
        if isLoading {
            emptyStateContainer.isHidden = true
            addExperienceButton.isHidden = true
            scrollView.isHidden = false
        } else if rawItems.isEmpty {
            emptyStateContainer.isHidden = false
            addExperienceButton.isHidden = !model.isMyProfile
            scrollView.isHidden = true
        } else {
            emptyStateContainer.isHidden = true
            addExperienceButton.isHidden = true
            scrollView.isHidden = false
        }
    }


    // MARK: - Actions
    
    @objc private func addPressed() { openAddWorkExperience?() }
    @objc private func backPressed() { onBackTapped?() }
    
    
    // MARK: - Layout Update
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
    }


    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: addExperienceButton.isHidden ? 40 : 16,
            bottomAnchor: addExperienceButton.isHidden ? view.bottomAnchor : addExperienceButton.topAnchor,
            retryTitle: retryAction != nil ? DivoStrings.retry : nil,
            retryAction: retryAction,
            persistent: persistent
        )
    }

    func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
    }
}
