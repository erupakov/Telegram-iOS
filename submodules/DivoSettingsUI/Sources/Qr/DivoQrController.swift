import Foundation
import UIKit
import Display
import AsyncDisplayKit

public final class DivoQrController: ViewController {
    private var qrNode: DivoQrNode {
        return self.displayNode as! DivoQrNode
    }

    private let shareURL: String

    public init(shareURL: String) {
        self.shareURL = shareURL
        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
    }

    override public func loadDisplayNode() {
        self.displayNode = DivoQrNode(shareURL: shareURL)

        self.qrNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        self.qrNode.onShareTapped = { [weak self] in
            self?.presentShare()
        }

        self.displayNodeDidLoad()
    }

    private func presentShare() {
        let items: [Any] = URL(string: shareURL).map { [$0] } ?? [shareURL]
        let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY - 80, width: 0, height: 0)
        }
        self.present(activityController, animated: true)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}
