import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle

final class EventDetailControllerNode: ASDisplayNode {
    private let context: AccountContext
    private var eventData: EventData? = nil
    private var presentationData: PresentationData
    
    private let scrollView: UIScrollView!
    private let contentView: UIView!
    
    private let backgroundImageView = UIImageView()
    private let gradientOverlayView = GradientView()
    private let eventTitleLabel = UILabel()
    private let eventSubtitleLabel = UILabel()
    
    private let castingBadgeLabel = UILabel()
    private let secondSeparator = UIView()
    private let heightSeparator = UIView()
    private let ageSeparator = UIView()
    
    private let heightView = UIView()
    private let heightIcon = UIImageView()
    private let heightLabel = UILabel()
    private let heightValueLabel = UILabel()
    
    private let ageView = UIView()
    private let ageIcon = UIImageView()
    private let ageLabel = UILabel()
    private let ageValueLabel = UILabel()
    
    private let genderView = UIView()
    private let genderIcon = UIImageView()
    private let genderLabel = UILabel()
    private let genderValueLabel = UILabel()
    
    private let participantsLabel = UILabel()
    private let participantsSubtitleLabel = UILabel()
    private let viewsLabel = UILabel()
    private let viewsSubtitleLabel = UILabel()
    private let applyButton = UIButton(type: .system)
    
    private let profileImageView = UIImageView()
    private let profileNameLabel = UILabel()
    private let onlineStatusLabel = UILabel()
    private let organizationLabel = UILabel()
    
    private let aboutTitleLabel = UILabel()
    private let aboutDescriptionLabel = UILabel()
    
    private let parametersTitleLabel = UILabel()
    
    private let previousEventsTitleLabel = UILabel()
    private let imageGalleryCollectionView: UICollectionView
    let previousEventsCollectionView: UICollectionView
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let supportPeerDisposable = MetaDisposable()
    private let addEventPhotoDisposable = MetaDisposable()
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData
        
        let flowLayoutGallery = UICollectionViewFlowLayout()
        flowLayoutGallery.scrollDirection = .horizontal
        flowLayoutGallery.minimumLineSpacing = 0
        flowLayoutGallery.minimumInteritemSpacing = 0
        self.imageGalleryCollectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayoutGallery)
        
        let flowLayoutPreviousEvents = UICollectionViewFlowLayout()
        flowLayoutPreviousEvents.scrollDirection = .horizontal
        self.previousEventsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayoutPreviousEvents)
        
        self.scrollView = UIScrollView()
        self.contentView = UIView()
        
        super.init()
        
        setupUI()
        setupConstraints()
    }
    
    deinit {
        self.supportPeerDisposable.dispose()
        self.addEventPhotoDisposable.dispose()
    }
    
    private func setupUI() {
        self.backgroundColor = .white
        
        imageGalleryCollectionView.backgroundColor = .clear
        imageGalleryCollectionView.dataSource = self
        imageGalleryCollectionView.delegate = self
        imageGalleryCollectionView.register(ImageGalleryCell.self, forCellWithReuseIdentifier: "ImageGalleryCell")
        imageGalleryCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        
        gradientOverlayView.configure(
            colors: [
                UIColor(white: 0.0, alpha: 0.2),
                UIColor.black
            ],
            direction: .vertical
        )
        
        castingBadgeLabel.text = "Casting"
        castingBadgeLabel.font = .systemFont(ofSize: 12)
        castingBadgeLabel.textColor = .white
        castingBadgeLabel.backgroundColor = UIColor(white: 1.0, alpha: 0.3)
        castingBadgeLabel.layer.cornerRadius = 10
        castingBadgeLabel.layer.masksToBounds = true
        castingBadgeLabel.textAlignment = .center
        castingBadgeLabel.clipsToBounds = true
        
        eventTitleLabel.text = "FASHION MODEL EVENT"
        eventTitleLabel.font = Font.helveticaNeue(30)
        eventTitleLabel.textColor = .white
        eventTitleLabel.textAlignment = .center
        
        eventSubtitleLabel.text = "May 27 · 5:00 PM · 🇺🇸 New York"
        eventSubtitleLabel.font = .systemFont(ofSize: 14)
        eventSubtitleLabel.textColor = .white.withAlphaComponent(0.7)
        eventSubtitleLabel.textAlignment = .center
        
        participantsLabel.text = "1024"
        participantsLabel.font = .systemFont(ofSize: 24, weight: .regular)
        participantsLabel.textColor = .white
        
        participantsSubtitleLabel.text = "participants"
        participantsSubtitleLabel.font = .systemFont(ofSize: 14)
        participantsSubtitleLabel.textColor = .white.withAlphaComponent(0.5)
        
        viewsLabel.text = "2.4k"
        viewsLabel.font = .systemFont(ofSize: 24, weight: .regular)
        viewsLabel.textColor = .white
        
        viewsSubtitleLabel.text = "views"
        viewsSubtitleLabel.font = .systemFont(ofSize: 14)
        viewsSubtitleLabel.textColor = .white.withAlphaComponent(0.5)
        
        applyButton.setTitle("Apply", for: .normal)
        applyButton.titleLabel?.font = Font.helveticaNeue(14)
        applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.layer.cornerRadius = 6
        applyButton.clipsToBounds = true
        
        secondSeparator.backgroundColor = UIColor(red: 236/255.0, green: 236/255.0, blue: 236/255.0, alpha: 1.0)
        heightSeparator.backgroundColor = UIColor(red: 236/255.0, green: 236/255.0, blue: 236/255.0, alpha: 1.0)
        ageSeparator.backgroundColor = UIColor(red: 236/255.0, green: 236/255.0, blue: 236/255.0, alpha: 1.0)
        
        profileImageView.image = UIImage(bundleImageName: "Components/Model")
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 20
        
        profileNameLabel.text = "@nyfw"
        profileNameLabel.font = .systemFont(ofSize: 14, weight: .regular)
        profileNameLabel.textColor = UIColor(red: 0.73, green: 0.44, blue: 0.28, alpha: 1)
        
        onlineStatusLabel.text = "Online"
        onlineStatusLabel.font = .systemFont(ofSize: 14)
        onlineStatusLabel.textColor = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.00)
        
        organizationLabel.text = "Organizatior"
        organizationLabel.font = .systemFont(ofSize: 14)
        organizationLabel.textColor = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.00)
        
        aboutTitleLabel.text = "About"
        aboutTitleLabel.font = .systemFont(ofSize: 10, weight: .regular)
        aboutTitleLabel.textColor = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.00)
        
//        aboutDescriptionLabel.text = "Casting of models for a contract with the magazine on the initiative of the NYFW magazine in NY"
        aboutDescriptionLabel.font = .systemFont(ofSize: 14)
        aboutDescriptionLabel.textColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        aboutDescriptionLabel.numberOfLines = 0
        
        parametersTitleLabel.text = "Parameters for Applying"
        parametersTitleLabel.font = .systemFont(ofSize: 10, weight: .regular)
        parametersTitleLabel.textColor = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.00)
        
        heightLabel.text = "Height"
        heightLabel.font = .systemFont(ofSize: 14)
        heightLabel.textColor = .black
        heightValueLabel.text = "1,72 - 2,1 cm"
        heightValueLabel.font = .systemFont(ofSize: 14)
        heightValueLabel.textColor = .black
        heightIcon.image = UIImage(bundleImageName: "Chat/heightIcon")
        heightIcon.tintColor = .black
        
        ageLabel.text = "Age"
        ageLabel.font = .systemFont(ofSize: 14)
        ageLabel.textColor = .black
        ageValueLabel.text = "20-25 y.o"
        ageValueLabel.font = .systemFont(ofSize: 14)
        ageValueLabel.textColor = .black
        ageIcon.image = UIImage(bundleImageName: "Chat/ageIcon")
        ageIcon.tintColor = .black
        
        genderLabel.text = "Gender"
        genderLabel.font = .systemFont(ofSize: 14)
        genderLabel.textColor = .black
        genderValueLabel.text = "Only womans"
        genderValueLabel.font = .systemFont(ofSize: 14)
        genderValueLabel.textColor = .black
        genderIcon.image = UIImage(bundleImageName: "Chat/genderIcon")
        genderIcon.contentMode = .scaleAspectFit
        genderIcon.tintColor = .black
        
        heightView.addSubview(heightIcon)
        heightView.addSubview(heightLabel)
        heightView.addSubview(heightValueLabel)
        
        ageView.addSubview(ageIcon)
        ageView.addSubview(ageLabel)
        ageView.addSubview(ageValueLabel)
        
        genderView.addSubview(genderIcon)
        genderView.addSubview(genderLabel)
        genderView.addSubview(genderValueLabel)
        
        previousEventsTitleLabel.text = "PREVIOUS EVENTS"
        previousEventsTitleLabel.font = Font.helveticaNeue(20)
        previousEventsTitleLabel.textColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        
        previousEventsCollectionView.backgroundColor = .clear
        previousEventsCollectionView.dataSource = self
        previousEventsCollectionView.delegate = self
        previousEventsCollectionView.register(EventPreviousCollectionViewCell.self, forCellWithReuseIdentifier: "EventPreviousCollectionViewCell")
        previousEventsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(backgroundImageView)
        contentView.addSubview(gradientOverlayView)
        contentView.addSubview(castingBadgeLabel)
        contentView.addSubview(eventTitleLabel)
        contentView.addSubview(eventSubtitleLabel)
        contentView.addSubview(participantsLabel)
        contentView.addSubview(participantsSubtitleLabel)
        contentView.addSubview(viewsLabel)
        contentView.addSubview(viewsSubtitleLabel)
        contentView.addSubview(applyButton)
        contentView.addSubview(profileImageView)
        contentView.addSubview(profileNameLabel)
        contentView.addSubview(onlineStatusLabel)
        contentView.addSubview(organizationLabel)
        contentView.addSubview(secondSeparator)
        contentView.addSubview(aboutTitleLabel)
        contentView.addSubview(aboutDescriptionLabel)
        contentView.addSubview(parametersTitleLabel)
        
        contentView.addSubview(heightView)
        contentView.addSubview(heightSeparator)
        contentView.addSubview(ageView)
        contentView.addSubview(ageSeparator)
        contentView.addSubview(genderView)
        
        contentView.addSubview(imageGalleryCollectionView)
        contentView.addSubview(previousEventsTitleLabel)
        contentView.addSubview(previousEventsCollectionView)
        
        scrollView.addSubview(contentView)
        self.view.addSubview(scrollView)
    }
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        gradientOverlayView.translatesAutoresizingMaskIntoConstraints = false
        castingBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        eventTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        eventSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        participantsLabel.translatesAutoresizingMaskIntoConstraints = false
        participantsSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        viewsLabel.translatesAutoresizingMaskIntoConstraints = false
        viewsSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        secondSeparator.translatesAutoresizingMaskIntoConstraints = false
        heightSeparator.translatesAutoresizingMaskIntoConstraints = false
        ageSeparator.translatesAutoresizingMaskIntoConstraints = false
        
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        onlineStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        organizationLabel.translatesAutoresizingMaskIntoConstraints = false
        aboutTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        aboutDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        parametersTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        heightView.translatesAutoresizingMaskIntoConstraints = false
        heightIcon.translatesAutoresizingMaskIntoConstraints = false
        heightLabel.translatesAutoresizingMaskIntoConstraints = false
        heightValueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        ageView.translatesAutoresizingMaskIntoConstraints = false
        ageIcon.translatesAutoresizingMaskIntoConstraints = false
        ageLabel.translatesAutoresizingMaskIntoConstraints = false
        ageValueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        genderView.translatesAutoresizingMaskIntoConstraints = false
        genderIcon.translatesAutoresizingMaskIntoConstraints = false
        genderLabel.translatesAutoresizingMaskIntoConstraints = false
        genderValueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        previousEventsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        imageGalleryCollectionView.translatesAutoresizingMaskIntoConstraints = false
        previousEventsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -70),
            backgroundImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundImageView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        NSLayoutConstraint.activate([
            gradientOverlayView.topAnchor.constraint(equalTo: backgroundImageView.topAnchor),
            gradientOverlayView.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor),
            gradientOverlayView.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor),
            gradientOverlayView.bottomAnchor.constraint(equalTo: backgroundImageView.bottomAnchor)
        ])
        
        NSLayoutConstraint.activate([
            applyButton.bottomAnchor.constraint(equalTo: backgroundImageView.bottomAnchor, constant: -20),
            applyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            applyButton.heightAnchor.constraint(equalToConstant: 40),
            applyButton.widthAnchor.constraint(equalToConstant: 100),
            
            
            participantsLabel.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor),
            participantsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            participantsSubtitleLabel.leadingAnchor.constraint(equalTo: participantsLabel.trailingAnchor, constant: 5),
            participantsSubtitleLabel.bottomAnchor.constraint(equalTo: participantsLabel.bottomAnchor),
            
            viewsLabel.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor),
            viewsLabel.leadingAnchor.constraint(equalTo: participantsSubtitleLabel.trailingAnchor, constant: 15),
            
            viewsSubtitleLabel.leadingAnchor.constraint(equalTo: viewsLabel.trailingAnchor, constant: 5),
            viewsSubtitleLabel.bottomAnchor.constraint(equalTo: viewsLabel.bottomAnchor),
            
            eventSubtitleLabel.bottomAnchor.constraint(equalTo: participantsLabel.topAnchor, constant: -20),
            eventSubtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            eventSubtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            eventTitleLabel.bottomAnchor.constraint(equalTo: eventSubtitleLabel.topAnchor, constant: -5),
            eventTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            eventTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            castingBadgeLabel.bottomAnchor.constraint(equalTo: eventTitleLabel.topAnchor, constant: -10),
            castingBadgeLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            castingBadgeLabel.heightAnchor.constraint(equalToConstant: 25),
            castingBadgeLabel.widthAnchor.constraint(equalToConstant: 80),
            
            profileImageView.topAnchor.constraint(equalTo: backgroundImageView.bottomAnchor, constant: 20),
            profileImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            profileImageView.widthAnchor.constraint(equalToConstant: 40),
            profileImageView.heightAnchor.constraint(equalToConstant: 40),
            
            profileNameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 10),
            profileNameLabel.topAnchor.constraint(equalTo: profileImageView.topAnchor, constant: 5),
            
            onlineStatusLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 10),
            onlineStatusLabel.topAnchor.constraint(equalTo: profileNameLabel.bottomAnchor, constant: 2),
            
            organizationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            organizationLabel.centerYAnchor.constraint(equalTo: onlineStatusLabel.centerYAnchor),
            
            secondSeparator.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 20),
            secondSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            secondSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            secondSeparator.heightAnchor.constraint(equalToConstant: 1),
            
            aboutTitleLabel.topAnchor.constraint(equalTo: secondSeparator.bottomAnchor, constant: 20),
            aboutTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            aboutDescriptionLabel.topAnchor.constraint(equalTo: aboutTitleLabel.bottomAnchor, constant: 10),
            aboutDescriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            aboutDescriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            parametersTitleLabel.topAnchor.constraint(equalTo: aboutDescriptionLabel.bottomAnchor, constant: 20),
            parametersTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            heightView.topAnchor.constraint(equalTo: parametersTitleLabel.bottomAnchor, constant: 10),
            heightView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            heightView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            heightView.heightAnchor.constraint(equalToConstant: 30),
            
            heightIcon.leadingAnchor.constraint(equalTo: heightView.leadingAnchor),
            heightIcon.centerYAnchor.constraint(equalTo: heightView.centerYAnchor),
            heightIcon.widthAnchor.constraint(equalToConstant: 20),
            heightIcon.heightAnchor.constraint(equalToConstant: 20),
            
            heightLabel.leadingAnchor.constraint(equalTo: heightIcon.trailingAnchor, constant: 10),
            heightLabel.centerYAnchor.constraint(equalTo: heightView.centerYAnchor),
            
            heightValueLabel.trailingAnchor.constraint(equalTo: heightView.trailingAnchor),
            heightValueLabel.centerYAnchor.constraint(equalTo: heightView.centerYAnchor),
            
            heightSeparator.topAnchor.constraint(equalTo: heightView.bottomAnchor, constant: 10),
            heightSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            heightSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            heightSeparator.heightAnchor.constraint(equalToConstant: 1),
            
            ageView.topAnchor.constraint(equalTo: heightSeparator.bottomAnchor, constant: 10),
            ageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            ageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            ageView.heightAnchor.constraint(equalToConstant: 30),
            
            ageIcon.leadingAnchor.constraint(equalTo: ageView.leadingAnchor),
            ageIcon.centerYAnchor.constraint(equalTo: ageView.centerYAnchor),
            ageIcon.widthAnchor.constraint(equalToConstant: 20),
            ageIcon.heightAnchor.constraint(equalToConstant: 20),
            
            ageLabel.leadingAnchor.constraint(equalTo: ageIcon.trailingAnchor, constant: 10),
            ageLabel.centerYAnchor.constraint(equalTo: ageView.centerYAnchor),
            
            ageValueLabel.trailingAnchor.constraint(equalTo: ageView.trailingAnchor),
            ageValueLabel.centerYAnchor.constraint(equalTo: ageView.centerYAnchor),
            
            ageSeparator.topAnchor.constraint(equalTo: ageView.bottomAnchor, constant: 10),
            ageSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            ageSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            ageSeparator.heightAnchor.constraint(equalToConstant: 1),
            
            genderView.topAnchor.constraint(equalTo: ageSeparator.bottomAnchor, constant: 10),
            genderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            genderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            genderView.heightAnchor.constraint(equalToConstant: 30),
            
            genderIcon.leadingAnchor.constraint(equalTo: genderView.leadingAnchor),
            genderIcon.centerYAnchor.constraint(equalTo: genderView.centerYAnchor),
            genderIcon.widthAnchor.constraint(equalToConstant: 20),
            genderIcon.heightAnchor.constraint(equalToConstant: 20),
            
            genderLabel.leadingAnchor.constraint(equalTo: genderIcon.trailingAnchor, constant: 10),
            genderLabel.centerYAnchor.constraint(equalTo: genderView.centerYAnchor),
            
            genderValueLabel.trailingAnchor.constraint(equalTo: genderView.trailingAnchor),
            genderValueLabel.centerYAnchor.constraint(equalTo: genderView.centerYAnchor),
            
            imageGalleryCollectionView.topAnchor.constraint(equalTo: genderView.bottomAnchor, constant: 20),
            imageGalleryCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageGalleryCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageGalleryCollectionView.heightAnchor.constraint(equalToConstant: 140),
            
            previousEventsTitleLabel.topAnchor.constraint(equalTo: imageGalleryCollectionView.bottomAnchor, constant: 20),
            previousEventsTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            previousEventsCollectionView.topAnchor.constraint(equalTo: previousEventsTitleLabel.bottomAnchor, constant: 10),
            previousEventsCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previousEventsCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previousEventsCollectionView.heightAnchor.constraint(equalToConstant: 310),
            
            previousEventsCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    override func layout() {
        super.layout()
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    override func didLoad() {
        super.didLoad()
        
        applyButton.addTarget(self, action: #selector(applyButtonTapped(_:)), for: .touchUpInside)
    }
    
    @objc private func applyButtonTapped(_ sender: UIButton) {

//        if let id = eventData?.id {
//            let supportPeer = Promise<String?>()
//            supportPeer.set(context.engine.eventsEngine.addEventPhoto(eventId: Int64(id), photoId: 2018334237668675584))
//            self.addEventPhotoDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { peerId in
//                print("🔕", peerId ?? "")
//            }))
//        }
    }
    
    func updateEventData(_ newEventData: EventData) {
        self.eventData = newEventData
        
        setImage(newEventData.coverPhoto, for: backgroundImageView)
        
        eventTitleLabel.text = newEventData.title
        eventSubtitleLabel.text = newEventData.timeRemaining
        castingBadgeLabel.text = newEventData.type
        aboutDescriptionLabel.text = newEventData.subtitle
        
        profileNameLabel.text = newEventData.profileName
        
        setImage(newEventData.profilePhoto, for: profileImageView)
    }
    
    private func setImage(_ image: TelegramMediaImage?, for imageView: UIImageView) {
        if let image = image {
            guard let representation = largestImageRepresentation(image.representations) else {
                return
            }
            
            let resourceData = context.account.postbox.mediaBox.resourceData(representation.resource)
            let _ = (resourceData
                     |> deliverOnMainQueue).start(next: { data in
                if data.complete {
                    if let uiImage = UIImage(contentsOfFile: data.path) {
                        UIView.transition(with: imageView,
                                          duration: 0.3,
                                          options: .transitionCrossDissolve,
                                          animations: {
                            imageView.image = uiImage
                        }, completion: nil)
                    }
                    
                } else {
                    let _ = self.context.account.postbox.mediaBox.fetchedResource(representation.resource, parameters: nil).start()
                }
            })
        } else {
            imageView.image = UIImage(bundleImageName: "Components/Model")
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
    }
}

extension EventDetailControllerNode: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    private var previousEvents: [EventData] {
        return [
            EventData(title: "fashion model event", subtitle: "May 27 · 5:00 PM · NY NYFW Magazine", imageName: "Components/NewTalent", profileImageName: "", profileName: "", timeRemaining: "", type: "Conference"),
            EventData(title: "Previous Event 2", subtitle: "", imageName: "Components/Agencies", profileImageName: "", profileName: "", timeRemaining: "", type: "Casting"),
            EventData(title: "Previous Event 3", subtitle: "", imageName: "Components/Model", profileImageName: "", profileName: "", timeRemaining: "", type: "Casting")
        ]
    }
    
    private var imageGalleryItems: [String] {
        return ["Components/NewTalent", "Components/Agencies", "Components/Model", "Components/NewTalent", "Components/Agencies", "Components/Model"]
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
         return 1
     }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == imageGalleryCollectionView {
            return imageGalleryItems.count
        } else if collectionView == previousEventsCollectionView {
            return previousEvents.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == imageGalleryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageGalleryCell", for: indexPath) as? ImageGalleryCell else {
                fatalError("Unable to dequeue ImageGalleryCell")
            }
            cell.configure(with: imageGalleryItems[indexPath.item])
            return cell
        } else if collectionView == previousEventsCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EventPreviousCollectionViewCell", for: indexPath) as? EventPreviousCollectionViewCell else {
                fatalError("Unable to dequeue EventPreviousCollectionViewCell")
            }
            let event = previousEvents[indexPath.item]
            cell.configure(with: event)
            return cell
        }
        fatalError("Unknown collection view")
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == imageGalleryCollectionView {
            let totalWidth = collectionView.bounds.width
            let itemWidth = totalWidth / 3.0
            return CGSize(width: itemWidth, height: 140)
        } else if collectionView == previousEventsCollectionView {
            return CGSize(width: 240, height: 290)
        }
        return .zero
    }
}
