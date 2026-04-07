import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import DivoCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import TelegramBaseController

public final class DebugRequestLogsController: TelegramBaseController {
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

        self.title = DivoStrings.debugRequestLogs

        let clearButton = UIBarButtonItem(title: DivoStrings.debugClear, style: .plain, target: self, action: #selector(clearLogs))
        clearButton.setTitleTextAttributes([.foregroundColor: DebugTheme.accent], for: .normal)
        self.navigationItem.rightBarButtonItem = clearButton
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = DebugRequestLogsNode()
        node.onEntrySelected = { [weak self] entry in
            guard let self = self else { return }
            let detail = DebugRequestDetailController(context: self.context, entry: entry)
            self.push(detail)
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (self.displayNode as? DebugRequestLogsNode)?.reload()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        (self.displayNode as? DebugRequestLogsNode)?.containerLayoutUpdated(layout, navigationBarHeight: navHeight)
    }

    @objc private func clearLogs() {
        DivoRequestLogger.shared.clear()
        (self.displayNode as? DebugRequestLogsNode)?.reload()
    }
}

// MARK: - Logs List Node

private final class DebugRequestLogsNode: ASDisplayNode {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var entries: [DivoRequestLogEntry] = []

    var onEntrySelected: ((DivoRequestLogEntry) -> Void)?

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
        tableView.register(LogEntryCell.self, forCellReuseIdentifier: "LogEntry")
        self.view.addSubview(tableView)

        reload()
    }

    func reload() {
        entries = DivoRequestLogger.shared.getEntries()
        tableView.reloadData()
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        let bounds = CGRect(origin: .zero, size: layout.size)
        tableView.frame = CGRect(x: 0, y: navigationBarHeight, width: bounds.width, height: bounds.height - navigationBarHeight)
    }
}

extension DebugRequestLogsNode: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogEntry", for: indexPath) as! LogEntryCell
        cell.configure(with: entries[indexPath.row], timeFormatter: DebugRequestLogsNode.timeFormatter)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onEntrySelected?(entries[indexPath.row])
    }
}

// MARK: - Log Entry Cell

private final class LogEntryCell: UITableViewCell {
    private let methodLabel = UILabel()
    private let pathLabel = UILabel()
    private let statusLabel = UILabel()
    private let timeLabel = UILabel()
    private let durationLabel = UILabel()

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

        methodLabel.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        contentView.addSubview(methodLabel)

        pathLabel.font = .systemFont(ofSize: 15, weight: .regular)
        pathLabel.textColor = DebugTheme.primaryText
        pathLabel.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(pathLabel)

        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        statusLabel.textAlignment = .right
        contentView.addSubview(statusLabel)

        timeLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = DebugTheme.secondaryText
        contentView.addSubview(timeLabel)

        durationLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        durationLabel.textColor = DebugTheme.secondaryText
        durationLabel.textAlignment = .right
        contentView.addSubview(durationLabel)
    }

    func configure(with entry: DivoRequestLogEntry, timeFormatter: DateFormatter) {
        methodLabel.text = entry.method
        methodLabel.textColor = colorForMethod(entry.method)
        pathLabel.text = entry.path

        if let code = entry.statusCode {
            statusLabel.text = "\(code)"
            statusLabel.textColor = entry.isSuccess ? DebugTheme.success : DebugTheme.destructive
        } else if entry.error != nil {
            statusLabel.text = "ERR"
            statusLabel.textColor = DebugTheme.destructive
        } else {
            statusLabel.text = "—"
            statusLabel.textColor = DebugTheme.secondaryText
        }

        timeLabel.text = timeFormatter.string(from: entry.timestamp)
        durationLabel.text = String(format: "%.0fмс", entry.duration * 1000)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = contentView.bounds.height
        let w = contentView.bounds.width
        let pad: CGFloat = 16

        methodLabel.frame = CGRect(x: pad, y: 8, width: 60, height: 16)
        statusLabel.frame = CGRect(x: w - pad - 40, y: 8, width: 40, height: 16)
        pathLabel.frame = CGRect(x: pad + 64, y: 6, width: w - pad * 2 - 64 - 48, height: 20)
        timeLabel.frame = CGRect(x: pad, y: h - 22, width: 100, height: 16)
        durationLabel.frame = CGRect(x: w - pad - 60, y: h - 22, width: 60, height: 16)
    }

    private func colorForMethod(_ method: String) -> UIColor {
        switch method.uppercased() {
        case "GET": return DebugTheme.success
        case "POST": return UIColor(rgb: 0x007AFF)
        case "PUT", "PATCH": return DebugTheme.warning
        case "DELETE": return DebugTheme.destructive
        default: return DebugTheme.secondaryText
        }
    }
}

// MARK: - Request Detail Controller

final class DebugRequestDetailController: TelegramBaseController {
    private let entry: DivoRequestLogEntry
    private var detailText: String = ""

    init(context: AccountContext, entry: DivoRequestLogEntry) {
        self.entry = entry
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(
            context: context,
            navigationBarPresentationData: NavigationBarPresentationData(
                theme: DebugTheme.navTheme(),
                strings: NavigationBarStrings(presentationStrings: presentationData.strings)
            )
        )

        self.title = entry.path

        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareTapped)
        )
        shareButton.tintColor = DebugTheme.accent
        self.navigationItem.rightBarButtonItem = shareButton
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        let node = DebugRequestDetailNode(entry: entry)
        self.detailText = node.fullText
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        (self.displayNode as? DebugRequestDetailNode)?.containerLayoutUpdated(layout, navigationBarHeight: navHeight)
    }

    @objc private func shareTapped() {
        let ac = UIActivityViewController(activityItems: [detailText], applicationActivities: nil)
        if let popover = ac.popoverPresentationController {
            popover.barButtonItem = self.navigationItem.rightBarButtonItem
        }
        self.view.window?.rootViewController?.present(ac, animated: true)
    }
}

// MARK: - Request Detail Node

private final class DebugRequestDetailNode: ASDisplayNode {
    private let textView = UITextView()
    let fullText: String

    private static let detailTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    init(entry: DivoRequestLogEntry) {
        var text = ""
        text += "Метод:       \(entry.method)\n"
        text += "Путь:        \(entry.path)\n"
        text += "Статус:      \(entry.statusCode.map { "\($0)" } ?? "N/A")\n"
        text += "Длительность: \(String(format: "%.1fмс", entry.duration * 1000))\n"
        text += "Время:       \(DebugRequestDetailNode.detailTimeFormatter.string(from: entry.timestamp))\n"

        if let error = entry.error {
            text += "\n--- ОШИБКА ---\n\(error)\n"
        }
        if let reqBody = entry.requestBody {
            text += "\n--- ТЕЛО ЗАПРОСА ---\n"
            text += DebugRequestDetailNode.prettyJSON(reqBody)
            text += "\n"
        }
        if let resBody = entry.responseBody {
            text += "\n--- ТЕЛО ОТВЕТА ---\n"
            text += DebugRequestDetailNode.prettyJSON(resBody)
            text += "\n"
        }

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

    private static func prettyJSON(_ string: String) -> String {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: pretty, encoding: .utf8)
        else {
            return string
        }
        return result
    }
}
