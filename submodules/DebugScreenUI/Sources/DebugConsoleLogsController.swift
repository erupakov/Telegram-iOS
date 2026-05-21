import UIKit
import Display
import AsyncDisplayKit
import DivoCore
import TelegramPresentationData
import AccountContext
import TelegramBaseController

public final class DebugConsoleLogsController: TelegramBaseController {
    private let context: AccountContext

    public init(context: AccountContext) {
        self.context = context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(
            context: context,
            navigationBarPresentationData: NavigationBarPresentationData(
                theme: DebugTheme.navTheme(),
                strings: NavigationBarStrings(presentationStrings: presentationData.strings)
            )
        )

        self.title = "Console Logs"

        let clearButton = UIBarButtonItem(title: DivoStrings.debugClear, style: .plain, target: self, action: #selector(clearLogs))
        clearButton.setTitleTextAttributes([.foregroundColor: DebugTheme.accent], for: .normal)
        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareAllLogs)
        )
        shareButton.tintColor = DebugTheme.accent
        self.navigationItem.rightBarButtonItems = [clearButton, shareButton]
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = DebugConsoleLogsNode()
        node.onEntrySelected = { [weak self] entry in
            guard let self else { return }
            let detail = DebugConsoleLogDetailController(context: self.context, entry: entry)
            self.push(detail)
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (self.displayNode as? DebugConsoleLogsNode)?.reload()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        (self.displayNode as? DebugConsoleLogsNode)?.containerLayoutUpdated(layout, navigationBarHeight: navHeight)
    }

    @objc private func clearLogs() {
        DivoConsoleLogger.shared.clear()
        (self.displayNode as? DebugConsoleLogsNode)?.reload()
    }

    @objc private func shareAllLogs() {
        let entries = DivoConsoleLogger.shared.getEntries()
        guard !entries.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let header = "Console Logs — \(entries.count) entries (latest first)\n\n"
        let body = entries.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] \(entry.file):\(entry.line)\n\(entry.message)"
        }.joined(separator: "\n\n")
        let text = header + body + "\n"
        let ac = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popover = ac.popoverPresentationController {
            popover.barButtonItem = self.navigationItem.rightBarButtonItems?.last
        }
        self.view.window?.rootViewController?.present(ac, animated: true)
    }
}

// MARK: - List Node

private final class DebugConsoleLogsNode: ASDisplayNode, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var entries: [DivoConsoleLogEntry] = []
    private var observer: Any?

    var onEntrySelected: ((DivoConsoleLogEntry) -> Void)?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    override init() {
        super.init()
        self.backgroundColor = DebugTheme.background
    }

    override func didLoad() {
        super.didLoad()

        tableView.backgroundColor = DebugTheme.background
        tableView.separatorColor = DebugTheme.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ConsoleLogCell.self, forCellReuseIdentifier: "ConsoleLog")
        self.view.addSubview(tableView)

        observer = NotificationCenter.default.addObserver(
            forName: DivoConsoleLogger.newEntryNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }

        reload()
    }

    func reload() {
        entries = DivoConsoleLogger.shared.getEntries()
        tableView.reloadData()
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        let bounds = CGRect(origin: .zero, size: layout.size)
        tableView.frame = CGRect(x: 0, y: navigationBarHeight, width: bounds.width, height: bounds.height - navigationBarHeight)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConsoleLog", for: indexPath) as! ConsoleLogCell
        cell.configure(with: entries[indexPath.row], timeFormatter: DebugConsoleLogsNode.timeFormatter)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        52
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onEntrySelected?(entries[indexPath.row])
    }
}

// MARK: - Cell

private final class ConsoleLogCell: UITableViewCell {
    private let levelLabel = UILabel()
    private let messageLabel = UILabel()
    private let metaLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = DebugTheme.cellBackground
        let selectedBg = UIView()
        selectedBg.backgroundColor = DebugTheme.background
        selectedBackgroundView = selectedBg

        levelLabel.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        levelLabel.textAlignment = .center
        levelLabel.layer.cornerRadius = 4
        levelLabel.clipsToBounds = true
        contentView.addSubview(levelLabel)

        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = DebugTheme.primaryText
        messageLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(messageLabel)

        metaLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        metaLabel.textColor = DebugTheme.secondaryText
        contentView.addSubview(metaLabel)
    }

    func configure(with entry: DivoConsoleLogEntry, timeFormatter: DateFormatter) {
        levelLabel.text = " \(entry.level.rawValue) "
        levelLabel.textColor = .white
        levelLabel.backgroundColor = colorForLevel(entry.level)

        messageLabel.text = entry.message
        metaLabel.text = "\(timeFormatter.string(from: entry.timestamp))  \(entry.file):\(entry.line)"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = contentView.bounds.width
        let pad: CGFloat = 16

        levelLabel.sizeToFit()
        let levelW = max(levelLabel.bounds.width + 4, 50)
        levelLabel.frame = CGRect(x: pad, y: 8, width: levelW, height: 18)

        messageLabel.frame = CGRect(x: pad + levelW + 8, y: 6, width: w - pad * 2 - levelW - 8, height: 20)
        metaLabel.frame = CGRect(x: pad, y: 30, width: w - pad * 2, height: 16)
    }

    private func colorForLevel(_ level: DivoConsoleLogEntry.Level) -> UIColor {
        switch level {
        case .debug: return DebugTheme.secondaryText
        case .info: return UIColor(rgb: 0x007AFF)
        case .warning: return DebugTheme.warning
        case .error: return DebugTheme.destructive
        }
    }
}

// MARK: - Detail Controller

final class DebugConsoleLogDetailController: TelegramBaseController {
    private let entry: DivoConsoleLogEntry
    private var detailText: String = ""

    init(context: AccountContext, entry: DivoConsoleLogEntry) {
        self.entry = entry
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(
            context: context,
            navigationBarPresentationData: NavigationBarPresentationData(
                theme: DebugTheme.navTheme(),
                strings: NavigationBarStrings(presentationStrings: presentationData.strings)
            )
        )

        self.title = entry.level.rawValue
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        let node = DebugConsoleLogDetailNode(entry: entry)
        self.detailText = node.fullText
        self.displayNode = node
        self.displayNodeDidLoad()

        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareTapped)
        )
        shareButton.tintColor = DebugTheme.accent
        self.navigationItem.rightBarButtonItem = shareButton
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        (self.displayNode as? DebugConsoleLogDetailNode)?.containerLayoutUpdated(layout, navigationBarHeight: navHeight)
    }

    @objc private func shareTapped() {
        let ac = UIActivityViewController(activityItems: [detailText], applicationActivities: nil)
        if let popover = ac.popoverPresentationController {
            popover.barButtonItem = self.navigationItem.rightBarButtonItem
        }
        self.view.window?.rootViewController?.present(ac, animated: true)
    }
}

// MARK: - Detail Node

private final class DebugConsoleLogDetailNode: ASDisplayNode {
    private let textView = UITextView()
    let fullText: String

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    init(entry: DivoConsoleLogEntry) {
        var text = ""
        text += "Уровень:  \(entry.level.rawValue)\n"
        text += "Время:    \(DebugConsoleLogDetailNode.formatter.string(from: entry.timestamp))\n"
        text += "Файл:     \(entry.file):\(entry.line)\n"
        text += "\n--- СООБЩЕНИЕ ---\n"
        text += entry.message
        text += "\n"

        self.fullText = text
        super.init()
        self.backgroundColor = DebugTheme.cellBackground
    }

    override func didLoad() {
        super.didLoad()

        textView.isEditable = false
        textView.backgroundColor = DebugTheme.cellBackground
        textView.textColor = DebugTheme.primaryText
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.text = fullText
        self.view.addSubview(textView)
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        let bounds = CGRect(origin: .zero, size: layout.size)
        textView.frame = CGRect(x: 0, y: navigationBarHeight, width: bounds.width, height: bounds.height - navigationBarHeight)
    }
}
