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

struct WorkExperienceItem {
    let companyName: String
    let period: String
    let logoName: String?
}

final class ExperienceCell: UICollectionViewCell {
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let optionsButton = UIButton(type: .custom)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    private func setupLayout() {
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 28
        iconImageView.clipsToBounds = true
        iconImageView.layer.borderWidth = 1
        iconImageView.layer.borderColor = UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.14).cgColor
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        titleLabel.textColor = .black
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        dateLabel.font = UIFont.systemFont(ofSize: 14)
        dateLabel.textColor = .gray
        dateLabel.numberOfLines = 2
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let moreImage = UIImage(bundleImageName: "Contact List/moreIcon")?.withRenderingMode(.alwaysTemplate)
        optionsButton.setImage(moreImage, for: .normal)
        optionsButton.tintColor = UIColor(rgb: 0x8E8E93)
        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(optionsButton)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 56),
            iconImageView.heightAnchor.constraint(equalToConstant: 56),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 4),
            
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            dateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            optionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            optionsButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            optionsButton.widthAnchor.constraint(equalToConstant: 24),
            optionsButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func configure(with item: WorkExperienceItem) {
        titleLabel.text = item.companyName
        dateLabel.text = item.period
        if let logo = item.logoName {
            iconImageView.image = UIImage(named: logo)
        } else {
            iconImageView.image = UIImage(bundleImageName: "Models/DefWork")
        }
    }
}

final class WorkExperience: ASDisplayNode {
    
    private let model: ProfileModel
    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
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
//        WorkExperienceItem(companyName: "La model management", period: "May 2024 - Present · 1 year", logoName: nil),
//        WorkExperienceItem(companyName: "IMG Models", period: "April 2023 - May 2024 · 2 years", logoName: nil),
//        WorkExperienceItem(companyName: "Models 1 | Europe's Leading Model Agency", period: "May 2018 - April 2023 · 5 years 2 months", logoName: nil)
//    ]
    
    init(controller: ViewController, context: AccountContext, presentationData: PresentationData, model: ProfileModel) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        self.model = model
        self.addExperienceButton = ButtonWithIconNode(title: "Add Work Experience", icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        
        super.init()
        
        self.backgroundColor = .white
        self.addExperienceButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        self.addSubnode(self.addExperienceButton)
    }
    
    public func reloadEvents(items: [WorkExperienceItem]) {
        self.items = items
        updateEmptyState()
        self.collectionView.reloadData()
    }
    
    private func updateEmptyState() {
        let isEmpty = items.isEmpty
        emptyStateContainer.isHidden = !isEmpty
        addExperienceButton.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
    }
    
    override func didLoad() {
        super.didLoad()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ExperienceCell.self, forCellWithReuseIdentifier: "ExperienceCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let iconView = UIImageView(image: UIImage(bundleImageName: "Models/BadgeBaseWork"))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center
        titleLabel.attributedText = Font.helveticaNeue("THERE ARE NO WORK\nEXPERIENCE YET.", 34)
        titleLabel.textColor = .black
        
        let subLabel = UILabel()
        subLabel.attributedText = NSAttributedString(
            string: "Click the button below\nto add your work\nexperience",
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
        
        updateEmptyState()
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        transition.updateFrame(view: collectionView, frame: CGRect(origin: .zero, size: layout.size))
        collectionView.collectionViewLayout.invalidateLayout()
    }
}

extension WorkExperience: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ExperienceCell", for: indexPath) as! ExperienceCell
        cell.configure(with: items[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 90)
    }
}
