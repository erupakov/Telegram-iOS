import UIKit
import Display
import AsyncDisplayKit

final class DivoActionSheetHeaderItem: ActionSheetItem {
    let title: String
    let subtitle: String

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = DivoActionSheetHeaderNode(theme: theme)
        node.setItem(self)
        return node
    }

    func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? DivoActionSheetHeaderNode else { return }
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

private final class DivoActionSheetHeaderNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let titleLabel: ImmediateTextNode
    private let subtitleLabel: ImmediateTextNode

    override init(theme: ActionSheetControllerTheme) {
        self.theme = theme

        self.titleLabel = ImmediateTextNode()
        self.titleLabel.maximumNumberOfLines = 0
        self.titleLabel.displaysAsynchronously = false
        self.titleLabel.textAlignment = .center
        self.titleLabel.isUserInteractionEnabled = false

        self.subtitleLabel = ImmediateTextNode()
        self.subtitleLabel.maximumNumberOfLines = 0
        self.subtitleLabel.displaysAsynchronously = false
        self.subtitleLabel.textAlignment = .center
        self.subtitleLabel.isUserInteractionEnabled = false

        super.init(theme: theme)

        self.addSubnode(self.titleLabel)
        self.addSubnode(self.subtitleLabel)
    }

    func setItem(_ item: DivoActionSheetHeaderItem) {
        let baseFontSize = self.theme.baseFontSize
        let titleFont = Font.semibold(floor(baseFontSize * 13.0 / 17.0))
        let subtitleFont = Font.regular(floor(baseFontSize * 13.0 / 17.0))

        self.titleLabel.attributedText = NSAttributedString(
            string: item.title,
            font: titleFont,
            textColor: self.theme.primaryTextColor,
            paragraphAlignment: .center
        )

        self.subtitleLabel.attributedText = NSAttributedString(
            string: item.subtitle,
            font: subtitleFont,
            textColor: self.theme.secondaryTextColor,
            paragraphAlignment: .center
        )
    }

    override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let horizontalPadding: CGFloat = 10.0
        let contentWidth = max(1.0, constrainedSize.width - horizontalPadding * 2)
        let spacing: CGFloat = 4.0
        let verticalPadding: CGFloat = 14.0

        let titleSize = self.titleLabel.updateLayout(CGSize(width: contentWidth, height: constrainedSize.height))
        let subtitleSize = self.subtitleLabel.updateLayout(CGSize(width: contentWidth, height: constrainedSize.height))

        let totalHeight = verticalPadding + titleSize.height + spacing + subtitleSize.height + verticalPadding
        let size = CGSize(width: constrainedSize.width, height: totalHeight)

        let titleOrigin = CGPoint(
            x: floorToScreenPixels((size.width - titleSize.width) / 2.0),
            y: verticalPadding
        )
        self.titleLabel.frame = CGRect(origin: titleOrigin, size: titleSize)

        let subtitleOrigin = CGPoint(
            x: floorToScreenPixels((size.width - subtitleSize.width) / 2.0),
            y: titleOrigin.y + titleSize.height + spacing
        )
        self.subtitleLabel.frame = CGRect(origin: subtitleOrigin, size: subtitleSize)

        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
