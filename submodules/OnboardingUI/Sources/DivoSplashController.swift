import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData

public final class DivoSplashController: ViewController {
    private static let autoProceedDelay: TimeInterval = 2.0

    private var controllerNode: DivoSplashControllerNode {
        return self.displayNode as! DivoSplashControllerNode
    }

    public var nextPressed: ((PresentationStrings?) -> Void)?

    private var transitionTimer: SwiftSignalKit.Timer?
    private var didProceed = false

    public init() {
        super.init(navigationBarPresentationData: nil)
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        transitionTimer?.invalidate()
    }

    public override func loadDisplayNode() {
        self.displayNode = DivoSplashControllerNode()
        self.displayNodeDidLoad()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didProceed else { return }
        transitionTimer?.invalidate()
        transitionTimer = SwiftSignalKit.Timer(timeout: Self.autoProceedDelay, repeat: false, completion: { [weak self] in
            self?.proceedNext()
        }, queue: Queue.mainQueue())
        transitionTimer?.start()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        transitionTimer?.invalidate()
    }

    public func animateIn() {
        self.controllerNode.animateIn()
    }

    private func proceedNext() {
        guard !didProceed else { return }
        if let navigationController = self.navigationController, navigationController.viewControllers.last === self {
            didProceed = true
            self.nextPressed?(nil)
        }
    }
}
