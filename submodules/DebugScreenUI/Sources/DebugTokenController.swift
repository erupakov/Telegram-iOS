import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import DivoCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import TelegramBaseController

public final class DebugTokenController: TelegramBaseController {
    private let context: AccountContext
    private var presentationData: PresentationData

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(
            context: context,
            navigationBarPresentationData: NavigationBarPresentationData(
                theme: DebugTheme.navTheme(),
                strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)
            )
        )

        self.title = DivoStrings.debugAccessToken
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = DebugTokenNode()
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        (self.displayNode as? DebugTokenNode)?.containerLayoutUpdated(layout, navigationBarHeight: navHeight)
    }
}

// MARK: - Node

private final class DebugTokenNode: ASDisplayNode {
    private let scrollView = UIScrollView()

    // Current token
    private let currentHeader = UILabel()
    private let currentTokenContainer = UIView()
    private let currentTokenLabel = UILabel()
    private let copyButton = UIButton(type: .system)

    // Presets
    private let presetsHeader = UILabel()
    private let presetsContainer = UIView()
    private let agencyRow = PresetTokenRow()
    private let presetSeparator = UIView()
    private let modelRow = PresetTokenRow()

    // Custom
    private let customHeader = UILabel()
    private let customContainer = UIView()
    private let customTextField = UITextField()
    private let applyButton = UIButton(type: .system)

    override init() {
        super.init()
        self.backgroundColor = DebugTheme.background
    }

    override func didLoad() {
        super.didLoad()

        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        self.view.addSubview(scrollView)

        // MARK: Current Token
        setupSectionHeader(currentHeader, text: DivoStrings.debugCurrentToken)
        scrollView.addSubview(currentHeader)

        currentTokenContainer.backgroundColor = DebugTheme.cellBackground
        currentTokenContainer.layer.cornerRadius = 10
        currentTokenContainer.clipsToBounds = true
        scrollView.addSubview(currentTokenContainer)

        currentTokenLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        currentTokenLabel.textColor = DebugTheme.secondaryText
        currentTokenLabel.numberOfLines = 0
        currentTokenContainer.addSubview(currentTokenLabel)

        copyButton.setTitle(DivoStrings.debugCopy, for: .normal)
        copyButton.setTitleColor(DebugTheme.accent, for: .normal)
        copyButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        currentTokenContainer.addSubview(copyButton)

        // MARK: Presets
        setupSectionHeader(presetsHeader, text: DivoStrings.debugPresets)
        scrollView.addSubview(presetsHeader)

        presetsContainer.backgroundColor = DebugTheme.cellBackground
        presetsContainer.layer.cornerRadius = 10
        presetsContainer.clipsToBounds = true
        scrollView.addSubview(presetsContainer)

        agencyRow.configure(title: DivoStrings.debugAgency, tokenPreview: tokenPreview(DivoConfig.agencyToken))
        agencyRow.onTap = { [weak self] in self?.selectPreset(.agency) }
        presetsContainer.addSubview(agencyRow)

        presetSeparator.backgroundColor = DebugTheme.separator
        presetsContainer.addSubview(presetSeparator)

        modelRow.configure(title: DivoStrings.debugModel, tokenPreview: tokenPreview(DivoConfig.modelToken))
        modelRow.onTap = { [weak self] in self?.selectPreset(.model) }
        presetsContainer.addSubview(modelRow)

        // MARK: Custom Token
        setupSectionHeader(customHeader, text: DivoStrings.debugCustomToken)
        scrollView.addSubview(customHeader)

        customContainer.backgroundColor = DebugTheme.cellBackground
        customContainer.layer.cornerRadius = 10
        customContainer.clipsToBounds = true
        scrollView.addSubview(customContainer)

        customTextField.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        customTextField.textColor = DebugTheme.primaryText
        customTextField.attributedPlaceholder = NSAttributedString(
            string: DivoStrings.debugPasteToken,
            attributes: [.foregroundColor: DebugTheme.separator]
        )
        customTextField.backgroundColor = .clear
        customTextField.autocorrectionType = .no
        customTextField.autocapitalizationType = .none
        customContainer.addSubview(customTextField)

        applyButton.setTitle(DivoStrings.debugApplyCustomToken, for: .normal)
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        applyButton.backgroundColor = DebugTheme.accent
        applyButton.layer.cornerRadius = 10
        applyButton.addTarget(self, action: #selector(applyCustom), for: .touchUpInside)
        scrollView.addSubview(applyButton)

        updateCurrentTokenDisplay()
        updatePresetSelection()
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        let bounds = CGRect(origin: .zero, size: layout.size)
        let insets = layout.safeInsets
        scrollView.frame = CGRect(x: 0, y: navigationBarHeight, width: bounds.width, height: bounds.height - navigationBarHeight)

        let pad: CGFloat = 16 + insets.left
        let w = bounds.width - pad * 2
        var y: CGFloat = 8

        currentHeader.frame = CGRect(x: pad + 4, y: y, width: w, height: 30)
        y += 30

        let tokenText = DivoConfig.accessToken
        let tokenHeight = heightForText(tokenText, font: .monospacedSystemFont(ofSize: 13, weight: .regular), width: w - 32)
        let containerH = max(tokenHeight + 52, 80)
        currentTokenContainer.frame = CGRect(x: pad, y: y, width: w, height: containerH)
        currentTokenLabel.frame = CGRect(x: 16, y: 12, width: w - 32, height: tokenHeight + 4)
        copyButton.sizeToFit()
        copyButton.frame = CGRect(x: w - copyButton.frame.width - 16, y: containerH - 36, width: copyButton.frame.width, height: 28)
        y += containerH + 20

        presetsHeader.frame = CGRect(x: pad + 4, y: y, width: w, height: 30)
        y += 30

        let rowH: CGFloat = 52
        presetsContainer.frame = CGRect(x: pad, y: y, width: w, height: rowH * 2 + 0.5)
        agencyRow.frame = CGRect(x: 0, y: 0, width: w, height: rowH)
        presetSeparator.frame = CGRect(x: 16, y: rowH, width: w - 16, height: 0.5)
        modelRow.frame = CGRect(x: 0, y: rowH + 0.5, width: w, height: rowH)
        y += rowH * 2 + 0.5 + 20

        customHeader.frame = CGRect(x: pad + 4, y: y, width: w, height: 30)
        y += 30

        let fieldH: CGFloat = 48
        customContainer.frame = CGRect(x: pad, y: y, width: w, height: fieldH)
        customTextField.frame = CGRect(x: 16, y: 0, width: w - 32, height: fieldH)
        y += fieldH + 16

        let btnH: CGFloat = 50
        applyButton.frame = CGRect(x: pad, y: y, width: w, height: btnH)
        y += btnH + 20

        scrollView.contentSize = CGSize(width: bounds.width, height: y + insets.bottom)
    }

    // MARK: - Actions

    @objc private func copyTapped() {
        UIPasteboard.general.string = DivoConfig.accessToken
        let original = copyButton.title(for: .normal)
        copyButton.setTitle(DivoStrings.debugCopied, for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyButton.setTitle(original, for: .normal)
        }
    }

    private func selectPreset(_ preset: TokenPreset) {
        switch preset {
        case .agency:
            DivoConfig.accessToken = DivoConfig.agencyToken
            DivoConfig.currentUserRole = .agency
        case .model:
            DivoConfig.accessToken = DivoConfig.modelToken
            DivoConfig.currentUserRole = .model
        }
        updateCurrentTokenDisplay()
        updatePresetSelection()
    }

    @objc private func applyCustom() {
        guard let text = customTextField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        DivoConfig.accessToken = text.trimmingCharacters(in: .whitespacesAndNewlines)
        customTextField.resignFirstResponder()
        customTextField.text = ""
        updateCurrentTokenDisplay()
        updatePresetSelection()
    }

    // MARK: - Helpers

    private func updateCurrentTokenDisplay() {
        currentTokenLabel.text = DivoConfig.accessToken
    }

    private func updatePresetSelection() {
        let current = DivoConfig.accessToken
        agencyRow.setSelected(current == DivoConfig.agencyToken)
        modelRow.setSelected(current == DivoConfig.modelToken)
    }

    private func tokenPreview(_ token: String) -> String {
        return "\(token.prefix(8))...\(token.suffix(4))"
    }

    private func heightForText(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
    }

    private func setupSectionHeader(_ label: UILabel, text: String) {
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = DebugTheme.secondaryText
        label.text = text
    }
}

// MARK: - Preset Row

private enum TokenPreset {
    case agency
    case model
}

private final class PresetTokenRow: UIView {
    private let titleLabel = UILabel()
    private let previewLabel = UILabel()
    private let checkmark = UIImageView()

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DebugTheme.cellBackground

        titleLabel.font = .systemFont(ofSize: 17, weight: .regular)
        titleLabel.textColor = DebugTheme.primaryText
        addSubview(titleLabel)

        previewLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        previewLabel.textColor = DebugTheme.secondaryText
        addSubview(previewLabel)

        checkmark.image = UIImage(systemName: "checkmark")
        checkmark.tintColor = DebugTheme.accent
        checkmark.contentMode = .scaleAspectFit
        checkmark.isHidden = true
        addSubview(checkmark)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, tokenPreview: String) {
        titleLabel.text = title
        previewLabel.text = tokenPreview
    }

    func setSelected(_ selected: Bool) {
        checkmark.isHidden = !selected
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        let pad: CGFloat = 16
        checkmark.frame = CGRect(x: bounds.width - pad - 20, y: (h - 20) / 2, width: 20, height: 20)
        titleLabel.frame = CGRect(x: pad, y: 6, width: bounds.width - pad * 2 - 28, height: 22)
        previewLabel.frame = CGRect(x: pad, y: 28, width: bounds.width - pad * 2 - 28, height: 18)
    }

    @objc private func tapped() {
        UIView.animate(withDuration: 0.1, animations: { self.alpha = 0.6 }) { _ in
            UIView.animate(withDuration: 0.15) { self.alpha = 1 }
        }
        onTap?()
    }
}
