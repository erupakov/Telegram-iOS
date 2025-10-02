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

final class ProfileScreenNode: ASDisplayNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let eventData: String
    
    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    private var collectionView: UICollectionView!
    
    init(context: AccountContext, eventData: String, presentationData: PresentationData) {
        self.context = context
        self.eventData = eventData
        self.presentationData = presentationData
        
        super.init()
        
        let flowLayout = UICollectionViewFlowLayout()
        
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        self.collectionView.backgroundColor = .clear
//        self.collectionView.dataSource = self
//        self.collectionView.delegate = self
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        
        self.view.addSubview(self.collectionView)
        
        self.collectionView.reloadData()
        
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
        
        let itemWidth = floor((layout.size.width - safeAreaInsets.left - safeAreaInsets.right - 30) / 2.0)
//        let itemHeight = itemWidth * 1.5
        
        if let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = CGSize(width: itemWidth, height: 230)
            flowLayout.sectionInset = UIEdgeInsets(top: navigationBarHeight + 10, left: safeAreaInsets.left + 10, bottom: insets.bottom + 10, right: safeAreaInsets.right + 10)
        }
        
        self.collectionView.frame = CGRect(origin: .zero, size: layout.size)
    }
}
