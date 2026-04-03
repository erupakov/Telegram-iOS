import AsyncDisplayKit
import Display
import TelegramCore

final class DashedUploadNode: ASControlNode {
    private let titleNode = ASTextNode()
    private let iconNode = ASImageNode()
    private let dashedLayer = CAShapeLayer()
    
    override init() {
        super.init()
        
        let copperColor = UIColor(hexString: "#BF7A54") ?? .black
        
        let plusImg = generateTintedImage(image: UIImage(bundleImageName: "Profile/Plus"), color: copperColor)
        iconNode.image = plusImg
        
        iconNode.contentMode = .center
        
        // Настройка текста
        titleNode.attributedText = NSAttributedString(
            string: DivoStrings.uploadPhoto,
            font: Font.regular(16),
            textColor: UIColor(hexString: "#3C3C43")?.withAlphaComponent(0.6) ?? .gray
        )
        
        addSubnode(iconNode)
        addSubnode(titleNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let copperColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        dashedLayer.strokeColor = copperColor.cgColor
        dashedLayer.lineDashPattern = [6, 4]
        dashedLayer.fillColor = nil
        dashedLayer.lineWidth = 1.0
        self.layer.addSublayer(dashedLayer)
    }
    
    override func layout() {
        super.layout()
        
        let path = UIBezierPath(roundedRect: self.bounds, cornerRadius: 12)
        dashedLayer.path = path.cgPath
        dashedLayer.frame = self.bounds
        
        let iconSize = CGSize(width: 30, height: 30)
        let titleSize = titleNode.measure(CGSize(width: self.bounds.width, height: .greatestFiniteMagnitude))
        
        let totalHeight = iconSize.height + 8 + titleSize.height
        let startY = (self.bounds.height - totalHeight) / 2.0
        
        iconNode.frame = CGRect(x: (self.bounds.width - iconSize.width) / 2.0, y: startY, width: iconSize.width, height: iconSize.height)
        titleNode.frame = CGRect(x: (self.bounds.width - titleSize.width) / 2.0, y: iconNode.frame.maxY + 8, width: titleSize.width, height: titleSize.height)
    }
}