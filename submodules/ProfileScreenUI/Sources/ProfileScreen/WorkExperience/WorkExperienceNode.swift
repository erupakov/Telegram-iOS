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

final class WorkExperience: ASDisplayNode {

    private let model: ProfileModel
    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    var showItemOptions: ((WorkHistoryItem) -> Void)?
    var openAddWorkExperience: (() -> Void)?

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .white
        return cv
    }()

    private let emptyStateContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true
        return stack
    }()

    private let addExperienceButton: ASControlNode

    private var items: [WorkExperienceItem] = []
    private var rawItems: [WorkHistoryItem] = []
    private var hasStructuredData = false
    private var isLoading = true
    private let shimmerCount = 4
    private var collectionViewTopConstraint: NSLayoutConstraint?

    init(controller: ViewController, context: AccountContext, presentationData: PresentationData, model: ProfileModel) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        self.model = model
        self.addExperienceButton = ButtonWithIconNode(title: DivoStrings.addWorkExperience, icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))

        super.init()

        self.backgroundColor = .white
        self.addExperienceButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)

        self.addSubnode(self.addExperienceButton)
    }

    func setLoading(_ loading: Bool) {
        self.isLoading = loading
        updateEmptyState()
        self.collectionView.reloadData()
    }

    public func reloadWorkHistory(items: [WorkHistoryItem]) {
        self.isLoading = false
        self.rawItems = items
        self.hasStructuredData = true
        self.items = items.map { item in
            let logoURL: URL?
            if let urlStr = item.agencyPhoto?.fullUrl, let url = URL(string: urlStr) {
                logoURL = url
            } else {
                logoURL = nil
            }
            return WorkExperienceItem(
                id: item.id,
                companyName: item.agencyDisplayName ?? item.agencyName ?? DivoStrings.unknownAgency,
                period: Self.formatWorkPeriod(startDate: item.startDate, endDate: item.endDate, isCurrent: item.isCurrent),
                logoURL: logoURL
            )
        }
        updateEmptyState()
        self.collectionView.reloadData()
    }

    public func reloadLegacyWorkHistory(model: UserDetail) {
        self.isLoading = false
        self.rawItems = []
        self.hasStructuredData = false
        let experienceString = model.model?.workExperience ?? ""
        let experienceNames = experienceString
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        self.items = experienceNames.enumerated().map { index, name in
            WorkExperienceItem(
                id: index,
                companyName: name,
                period: DivoStrings.pastExperience,
                logoURL: nil
            )
        }
        updateEmptyState()
        self.collectionView.reloadData()
    }

    private func updateEmptyState() {
        if isLoading {
            emptyStateContainer.isHidden = true
            addExperienceButton.isHidden = true
            collectionView.isHidden = false
        } else if items.isEmpty {
            emptyStateContainer.isHidden = false
            addExperienceButton.isHidden = !model.isMyProfile
            collectionView.isHidden = true
        } else {
            emptyStateContainer.isHidden = true
            addExperienceButton.isHidden = true
            collectionView.isHidden = false
        }
    }

    override func didLoad() {
        super.didLoad()

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ExperienceCell.self, forCellWithReuseIdentifier: "ExperienceCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        let topConstraint = collectionView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0)
        self.collectionViewTopConstraint = topConstraint

        NSLayoutConstraint.activate([
            topConstraint,
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let iconView = UIImageView(image: UIImage(bundleImageName: "Components/BadgeBaseWork"))
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center
        titleLabel.attributedText = Font.helveticaNeue(DivoStrings.noWorkExperienceYet, 34)
        titleLabel.textColor = .black

        let subLabel = UILabel()
        subLabel.attributedText = NSAttributedString(
            string: DivoStrings.noWorkExperienceSubtitle,
            font: Font.regular(16.0),
            textColor: .white.withAlphaComponent(0.6),
            paragraphAlignment: .center)
        subLabel.numberOfLines = 3
        subLabel.textAlignment = .center
        subLabel.textColor = .black

        emptyStateContainer.addArrangedSubview(iconView)
        emptyStateContainer.addArrangedSubview(titleLabel)
        emptyStateContainer.addArrangedSubview(subLabel)

        view.addSubview(emptyStateContainer)

        let buttonView = addExperienceButton.view
        buttonView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 70),
            iconView.heightAnchor.constraint(equalToConstant: 70),

            emptyStateContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            emptyStateContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            buttonView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            buttonView.heightAnchor.constraint(equalToConstant: 56)
        ])

        view.bringSubviewToFront(buttonView)

        updateEmptyState()

        self.addExperienceButton.addTarget(self, action: #selector(self.addWorkExperience), forControlEvents: .touchUpInside)
    }

    @objc private func addWorkExperience() {
        openAddWorkExperience?()
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        self.collectionViewTopConstraint?.constant = navigationBarHeight + 12
    }

    // MARK: - Period Formatting

    private static func formatWorkPeriod(startDate: String?, endDate: String?, isCurrent: Bool?) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let startStr = startDate, let start = inputFormatter.date(from: startStr) else {
            return "—"
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM yyyy"
        displayFormatter.locale = Locale(identifier: DivoStrings.current.localeIdentifier)

        let startString = displayFormatter.string(from: start)
        let endString: String
        let end: Date

        if isCurrent == true {
            end = Date()
            endString = DivoStrings.present
        } else if let endStr = endDate, let endDate = inputFormatter.date(from: endStr) {
            end = endDate
            endString = displayFormatter.string(from: endDate)
        } else {
            end = Date()
            endString = DivoStrings.present
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: start, to: end)
        let years = components.year ?? 0
        let months = components.month ?? 0

        var durationString = ""
        if years > 0 {
            durationString += DivoStrings.yearsCount(years)
        }
        if months > 0 {
            if !durationString.isEmpty {
                durationString += " "
            }
            durationString += DivoStrings.monthsCount(months)
        }
        if durationString.isEmpty {
            durationString = DivoStrings.oneMonth
        }

        return "\(startString) - \(endString) · \(durationString)"
    }
}

extension WorkExperience: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isLoading && items.isEmpty {
            return shimmerCount
        }
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ExperienceCell", for: indexPath) as! ExperienceCell
        if isLoading && items.isEmpty {
            cell.configureAsShimmer()
        } else {
            cell.delegate = self
            cell.configure(with: items[indexPath.item], showOptions: model.isMyProfile && hasStructuredData)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 90)
    }
}

extension WorkExperience: ExperienceCellDelegate {
    func experienceCell(_ cell: ExperienceCell, didTapOptionsButton button: UIButton) {
        guard let indexPath = collectionView.indexPath(for: cell),
              indexPath.item < rawItems.count else { return }
        showItemOptions?(rawItems[indexPath.item])
    }
}
