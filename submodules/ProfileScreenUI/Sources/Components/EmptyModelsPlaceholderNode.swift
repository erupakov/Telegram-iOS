import UIKit
import PhotosUI
import UniformTypeIdentifiers
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import TelegramBaseController
import LegacyMediaPickerUI
import Postbox
import MapResourceToAvatarSizes
import ContextUI
import GalleryUI

final class EmptyModelsPlaceholderNode: ASDisplayNode {
    private let iconContainerNode = ASDisplayNode()
    
    private let tagContainer: GradientTagView = {
        let view = GradientTagView()
        view.apply(style: .bronzeGradient)
        return view
    }()
    
    private let tagIcon: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 34, weight: .regular)
        iv.image = UIImage(bundleImageName: "Models/AssociatedModels")?.withRenderingMode(.alwaysTemplate)
        iv.tintColor = .white
        iv.contentMode = .center
        return iv
    }()
    
    private let titleLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.textInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
        label.font = Font.helveticaNeue(26)
        label.textColor = UIColor(hexString: "#000000") ?? .black
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let subtitleLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.textInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
        label.font = Font.medium(16)
        label.textColor = UIColor(hexString: "#222222") ?? .black
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    let addButton: ButtonWithIconNode
    
    init(theme: PresentationTheme) {
        self.addButton = ButtonWithIconNode(
            title: DivoStrings.addModel,
            icon: nil,
            theme: theme,
            spacing: 10,
            imageSize: CGSize(width: 24, height: 24)
        )
        self.addButton.backgroundColor = UIColor(hexString: "#BF7A54") ?? .orange
        
        super.init()
        
        self.backgroundColor = .white
        
        titleLabel.text = DivoStrings.emptyTitleAddModel
        subtitleLabel.text = DivoStrings.emptySubTitleAddModel
        
        addSubnode(iconContainerNode)
        addSubnode(addButton)
    }
    
    override func didLoad() {
        super.didLoad()
        
        iconContainerNode.view.addSubview(tagContainer)
        tagContainer.addSubview(tagIcon)
        
        tagContainer.layer.cornerRadius = 34
        tagContainer.clipsToBounds = true
        
        self.view.addSubview(titleLabel)
        self.view.addSubview(subtitleLabel)
    }
    
    override func layout() {
        super.layout()
        
        let width = bounds.width
        let height = bounds.height
        let padding: CGFloat = 20
        
        let safeWidth = max(0, width - padding * 2)
        
        let iconSize = CGSize(width: 68, height: 68)
        
        let titleSize = titleLabel.sizeThatFits(CGSize(width: safeWidth, height: .greatestFiniteMagnitude))
        let subtitleSize = subtitleLabel.sizeThatFits(CGSize(width: safeWidth, height: .greatestFiniteMagnitude))
        let buttonHeight: CGFloat = 50
        
        let bottomPadding: CGFloat = 30
        
        let buttonY = height - buttonHeight - bottomPadding
        addButton.frame = CGRect(x: padding, y: buttonY, width: safeWidth, height: buttonHeight)
        
        let spacing1: CGFloat = 24
        let spacing2: CGFloat = 12
        
        let topContentHeight = iconSize.height + spacing1 + titleSize.height + spacing2 + subtitleSize.height
        
        let availableHeightForTopContent = buttonY
        
        var currentY = (availableHeightForTopContent - topContentHeight) / 2.0
        if currentY < 20 { currentY = 20 }
        
        let iconX = max(0, (width - iconSize.width) / 2.0)
        let titleX = max(0, (width - titleSize.width) / 2.0)
        let subtitleX = max(0, (width - subtitleSize.width) / 2.0)
        
        iconContainerNode.frame = CGRect(x: iconX, y: currentY, width: iconSize.width, height: iconSize.height)
        
        tagContainer.frame = iconContainerNode.bounds
        tagIcon.frame = tagContainer.bounds
        
        currentY += iconSize.height + spacing1
        
        titleLabel.frame = CGRect(x: titleX, y: currentY, width: titleSize.width, height: titleSize.height)
        currentY += titleSize.height + spacing2
        
        subtitleLabel.frame = CGRect(x: subtitleX, y: currentY, width: subtitleSize.width, height: subtitleSize.height)
    }
}