import UIKit
import AsyncDisplayKit

public final class CapsuleBarButtonView: UIView {
    public var onSearchTapped: (() -> Void)?
    public var onAddTapped: (() -> Void)?
    
    public init(image: UIImage) {
        super.init(frame: CGRect(x: 0, y: 0, width: 88, height: 40))
        
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: -8, y: -8, width: 104, height: 56)
        self.addSubview(imageView)
        
        let searchButton = UIButton(type: .custom)
        searchButton.frame = CGRect(x: 2, y: 0, width: 42, height: 40)
        searchButton.addTarget(self, action: #selector(self.searchPressed), for: .touchUpInside)
        self.addSubview(searchButton)
        
        let addButton = UIButton(type: .custom)
        addButton.frame = CGRect(x: 44, y: 0, width: 42, height: 40)
        addButton.addTarget(self, action: #selector(self.addPressed), for: .touchUpInside)
        self.addSubview(addButton)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func searchPressed() {
        onSearchTapped?()
    }
    
    @objc private func addPressed() {
        onAddTapped?()
    }
}

public final class CapsuleNavigationButtonNode: ASDisplayNode {
    private let capsuleView: CapsuleBarButtonView
    
    public init(image: UIImage, onSearch: @escaping () -> Void, onAdd: @escaping () -> Void) {
        self.capsuleView = CapsuleBarButtonView(image: image)
        self.capsuleView.onSearchTapped = onSearch
        self.capsuleView.onAddTapped = onAdd
        
        super.init()
        
        self.style.preferredSize = CGSize(width: 88, height: 40)
    }
    
    public override func didLoad() {
        super.didLoad()
        self.capsuleView.frame = CGRect(x: 0, y: 0, width: 88, height: 40)
        self.view.addSubview(self.capsuleView)
    }
}
