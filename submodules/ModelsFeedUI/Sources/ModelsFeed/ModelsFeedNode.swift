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

final class ModelsFeedNode: ASDisplayNode, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, CardCellDelegate {
    
    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    private var storiesCollectionView: UICollectionView!
    private var mainCollectionView: UICollectionView!
    
    private let stories: [StoryModel] = [
        StoryModel(name: "Add Story", avatarName: "Chat List/AddIcon", isLive: false, isAdd: true),
        StoryModel(name: "Jack D.", avatarName: "Models/image5", isLive: false, isAdd: false),
        StoryModel(name: "Joshua", avatarName: "", isLive: false, isAdd: false),
        StoryModel(name: "waggles", avatarName: "", isLive: true, isAdd: false),
        StoryModel(name: "steve.loves", avatarName: "", isLive: true, isAdd: false),
    ]
    
    private var cards: [CardModel] = [
        CardModel(
            name: "BRITNEY SPORTLING",
            mainImageName: "Models/image1",
            avatarImageName: "Models/image7",
            previewImagesName: ["Models/image4", "Models/image2", "Models/image3"]),
        CardModel(name: "Helen Stone", mainImageName: "Models/image6", avatarImageName: "Models/image7", previewImagesName: []),
    ]
    
    private let tabsView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    
    var showProfile: ((CardModel) -> Void)?
    
    init(controller: ViewController, context: AccountContext, presentationData: PresentationData) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        
        super.init()
        
        let storiesFlowLayout = UICollectionViewFlowLayout()
        storiesFlowLayout.scrollDirection = .horizontal
        storiesFlowLayout.minimumInteritemSpacing = 10
        storiesFlowLayout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        
        self.storiesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: storiesFlowLayout)
        self.storiesCollectionView.backgroundColor = .clear
        self.storiesCollectionView.dataSource = self
        self.storiesCollectionView.delegate = self
        self.storiesCollectionView.showsHorizontalScrollIndicator = false
        self.storiesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        self.storiesCollectionView.register(StoryCollectionViewCell.self, forCellWithReuseIdentifier: "StoryCell")
        
        let mainFlowLayout = UICollectionViewFlowLayout()
        
        self.mainCollectionView = UICollectionView(frame: .zero, collectionViewLayout: mainFlowLayout)
        self.mainCollectionView.backgroundColor = .black
        self.mainCollectionView.dataSource = self
        self.mainCollectionView.delegate = self
        self.mainCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        self.mainCollectionView.register(CardCollectionViewCell.self, forCellWithReuseIdentifier: "CardCell")
        
        self.view.addSubview(self.mainCollectionView)
        self.mainCollectionView.addSubview(self.storiesCollectionView)
        self.mainCollectionView.addSubview(self.tabsView)
        
        self.storiesCollectionView.reloadData()
        self.mainCollectionView.reloadData()
        
        self.didSetReady = true
        self._ready.set(true)
    }
    
    override func layout() {
        super.layout()
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        let insets = layout.insets(options: [.input])
        let safeAreaInsets = layout.safeInsets
        
        self.mainCollectionView.frame = CGRect(origin: .zero, size: layout.size)
        
        let storiesHeight: CGFloat = 90
        self.storiesCollectionView.frame = CGRect(x: 0,
                                                  y: navigationBarHeight + 10,
                                                  width: layout.size.width,
                                                  height: storiesHeight)
        
        let tabsHeight: CGFloat = 30
        self.tabsView.frame = CGRect(x: 0,
                                     y: self.storiesCollectionView.frame.maxY,
                                     width: layout.size.width,
                                     height: tabsHeight)
        
        if let mainFlowLayout = self.mainCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            mainFlowLayout.sectionInset = UIEdgeInsets(top: self.tabsView.frame.maxY + 10,
                                                       left: safeAreaInsets.left + 10,
                                                       bottom: insets.bottom + 10,
                                                       right: safeAreaInsets.right + 10)
            
            let cardWidth = layout.size.width - safeAreaInsets.left - safeAreaInsets.right - 20
            let cardHeight = layout.size.height - mainFlowLayout.sectionInset.top - insets.bottom - 20
            mainFlowLayout.itemSize = CGSize(width: cardWidth, height: cardHeight)
            mainFlowLayout.minimumLineSpacing = 10
        }
        
        self.mainCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === storiesCollectionView {
            return stories.count
        } else if collectionView === mainCollectionView {
            return cards.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if collectionView === storiesCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StoryCell", for: indexPath) as? StoryCollectionViewCell else {
                fatalError("Unable to dequeue StoryCollectionViewCell")
            }
            cell.configure(with: stories[indexPath.item])
            return cell
            
        } else if collectionView === mainCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CardCell", for: indexPath) as? CardCollectionViewCell else {
                fatalError("Unable to dequeue CardCollectionViewCell")
            }
            
            let card = cards[indexPath.item]
            cell.configure(with: card, delegate: self)
            
            return cell
        }
        
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if collectionView === storiesCollectionView {
            return CGSize(width: 70, height: 90)
            
        } else if collectionView === mainCollectionView {
            if let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout {
                let card = cards[indexPath.item]
                if card.previewImagesName.isEmpty {
                    return CGSize(width: flowLayout.itemSize.width, height: 360)
                }
                return flowLayout.itemSize
            }
        }
        
        return .zero
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === storiesCollectionView {
            print("didSelectItemAt Story: \(stories[indexPath.item].name)")
        } else if collectionView === mainCollectionView {
            showProfile?(cards[indexPath.item])
            print("didSelectItemAt: \(cards[indexPath.item].name)")
        }
    }
    
    func cardCell(_ cell: CardCollectionViewCell, didTapReaction reaction: ReactionType, for cardName: String, isSelected: Bool) {
        guard let indexPath = mainCollectionView.indexPath(for: cell) else { return }
        var card = self.cards[indexPath.item]
        
        if isSelected {
             card.userReaction = reaction
         } else {
             card.userReaction = nil
         }
        
        switch reaction {
        case .like:
            print("👍 didSelectItemAt 'Like': \(cardName)")
        case .heart:
            print("❤️ didSelectItemAt 'Heart': \(cardName)")
        case .dislike:
            print("👎 didSelectItemAt 'Dislike': \(cardName)")
        case .fire:
            print("🔥 didSelectItemAt 'Fire': \(cardName)")
        }
        
        self.cards[indexPath.item] = card
    }
}
