import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import DivoCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import TelegramBaseController

public final class DebugMenuController: TelegramBaseController {
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

        self.title = DivoStrings.debug
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = DebugMenuNode(context: context)
        node.onPush = { [weak self] controller in
            self?.push(controller)
        }
        node.onPresent = { [weak self] controller in
            self?.present(controller, in: .window(.root))
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (self.displayNode as? DebugMenuNode)?.refresh()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        (self.displayNode as? DebugMenuNode)?.containerLayoutUpdated(layout, navigationBarHeight: navHeight)
    }
}

// MARK: - Node

private final class DebugMenuNode: ASDisplayNode, UITableViewDataSource, UITableViewDelegate {
    private let context: AccountContext
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    var onPush: ((ViewController) -> Void)?
    var onPresent: ((ViewController) -> Void)?

    private struct Row {
        let icon: String
        let title: String
        let subtitle: () -> String
        let accessory: AccessoryType
        let action: () -> Void

        enum AccessoryType {
            case chevron
            case toggle(Bool, (Bool) -> Void)
            case none
        }
    }

    private var sections: [(header: String?, rows: [Row])] = []

    init(context: AccountContext) {
        self.context = context
        super.init()
        self.backgroundColor = DebugTheme.background
    }

    override func didLoad() {
        super.didLoad()

        tableView.backgroundColor = DebugTheme.background
        tableView.separatorColor = DebugTheme.separator
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DebugMenuTableCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DebugMenuToggleCell.self, forCellReuseIdentifier: "Toggle")
        tableView.register(DebugInfoTableCell.self, forCellReuseIdentifier: "Info")
        self.view.addSubview(tableView)

        buildSections()

        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        buildSections()
        tableView.reloadData()
    }

    private func buildSections() {
        let overlayEnabled = UserDefaults.standard.bool(forKey: "DivoNetworkOverlay.enabled")

        sections = [
            (header: DivoStrings.debugTools, rows: [
                Row(icon: "key.fill", title: DivoStrings.debugAccessToken, subtitle: { self.currentTokenLabel() }, accessory: .chevron, action: { [weak self] in
                    guard let self = self else { return }
                    let c = DebugTokenController(context: self.context)
                    self.onPush?(c)
                }),
                Row(icon: "person.badge.key", title: "User Role", subtitle: { DivoConfig.currentUserRole.displayName }, accessory: .chevron, action: { [weak self] in
                    self?.showRolePicker()
                }),
                Row(icon: "list.bullet.rectangle", title: DivoStrings.debugRequestLogs, subtitle: {
                    let count = DivoRequestLogger.shared.getEntries().count
                    return "\(count)"
                }, accessory: .chevron, action: { [weak self] in
                    guard let self = self else { return }
                    let c = DebugRequestLogsController(context: self.context)
                    self.onPush?(c)
                }),
                Row(icon: "terminal", title: "Console Logs", subtitle: {
                    let count = DivoConsoleLogger.shared.getEntries().count
                    return "\(count)"
                }, accessory: .chevron, action: { [weak self] in
                    guard let self = self else { return }
                    let c = DebugConsoleLogsController(context: self.context)
                    self.onPush?(c)
                }),
                Row(icon: "person.crop.circle", title: DivoStrings.debugUser, subtitle: { "" }, accessory: .chevron, action: { [weak self] in
                    guard let self = self else { return }
                    let c = DebugUserInfoController(context: self.context)
                    self.onPush?(c)
                }),
            ]),
            (header: "Reset Flags", rows: [
                Row(icon: "face.smiling", title: "Face Search Info", subtitle: {
                    UserDefaults.standard.bool(forKey: "Divo.faceSearchInfoShown") ? "Shown" : "Not shown"
                }, accessory: .toggle(UserDefaults.standard.bool(forKey: "Divo.faceSearchInfoShown"), { [weak self] enabled in
                    UserDefaults.standard.set(enabled, forKey: "Divo.faceSearchInfoShown")
                    self?.buildSections()
                    self?.tableView.reloadData()
                }), action: {}),
            ]),
            (header: DivoStrings.debugNetwork, rows: [
                Row(icon: "speedometer", title: DivoStrings.debugNetworkOverlay, subtitle: { "" }, accessory: .toggle(overlayEnabled, { [weak self] enabled in
                    UserDefaults.standard.set(enabled, forKey: "DivoNetworkOverlay.enabled")
                    if enabled {
                        DivoNetworkOverlay.shared.show()
                    } else {
                        DivoNetworkOverlay.shared.hide()
                    }
                    self?.buildSections()
                    self?.tableView.reloadData()
                }), action: {}),
                Row(icon: "server.rack", title: "Mock API", subtitle: { DivoConfig.isMockEnabled ? "ON" : "OFF" }, accessory: .toggle(DivoConfig.isMockEnabled, { [weak self] enabled in
                    DivoConfig.isMockEnabled = enabled
                    self?.buildSections()
                    self?.tableView.reloadData()
                }), action: {}),
                Row(icon: "tortoise.fill", title: DivoStrings.debugNetworkDelay, subtitle: {
                    self.delayLabel()
                }, accessory: .chevron, action: { [weak self] in
                    self?.showDelayPicker()
                }),
            ]),
            (header: DivoStrings.debugCache, rows: [
                Row(icon: "photo.on.rectangle", title: DivoStrings.debugImageCache, subtitle: {
                    self.cacheSizeLabel()
                }, accessory: .chevron, action: { [weak self] in
                    self?.clearImageCache()
                }),
            ]),
            (header: DivoStrings.debugInfo, rows:
                self.infoRows()
            ),
        ]
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        let bounds = CGRect(origin: .zero, size: layout.size)
        tableView.frame = CGRect(x: 0, y: navigationBarHeight, width: bounds.width, height: bounds.height - navigationBarHeight)
    }

    // MARK: - UITableView

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]

        switch row.accessory {
        case .toggle(let isOn, let handler):
            let cell = tableView.dequeueReusableCell(withIdentifier: "Toggle", for: indexPath) as! DebugMenuToggleCell
            cell.configure(icon: row.icon, title: row.title, isOn: isOn, onToggle: handler)
            return cell
        case .chevron:
            if sections[indexPath.section].header == DivoStrings.debugInfo {
                let cell = tableView.dequeueReusableCell(withIdentifier: "Info", for: indexPath) as! DebugInfoTableCell
                cell.configure(title: row.title, value: row.subtitle())
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! DebugMenuTableCell
            cell.configure(icon: row.icon, title: row.title, subtitle: row.subtitle())
            cell.accessoryType = .disclosureIndicator
            return cell
        case .none:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! DebugMenuTableCell
            cell.configure(icon: row.icon, title: row.title, subtitle: row.subtitle())
            cell.accessoryType = .none
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        if case .toggle = row.accessory { return }
        row.action()
    }

    // MARK: - Helpers

    private func currentTokenLabel() -> String {
        let token = DivoConfig.accessToken
        if token == DivoConfig.agencyToken { return DivoStrings.debugAgency }
        if token == DivoConfig.modelToken { return DivoStrings.debugModel }
        return DivoStrings.debugCustom
    }

    private func delayLabel() -> String {
        let d = DivoConfig.simulatedDelay
        if d <= 0 { return DivoStrings.debugOff }
        if d < 1 { return DivoStrings.debugDelayMs(Int(d * 1000)) }
        return DivoStrings.debugDelaySec(Int(d))
    }

    private func cacheSizeLabel() -> String {
        let cache = URLCache.shared
        let bytes = cache.currentDiskUsage + cache.currentMemoryUsage
        if bytes == 0 { return DivoStrings.debugEmpty }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func infoRows() -> [Row] {
        let items: [(String, String, String)] = [
            ("link", "Base URL", DivoConfig.baseURL.absoluteString),
            ("info.circle", DivoStrings.debugVersion, DivoConfig.appVersion),
            ("apple.logo", DivoStrings.debugPlatform, DivoConfig.appPlatform),
            ("number", "Bundle ID", Bundle.main.bundleIdentifier ?? "—"),
            ("iphone", DivoStrings.debugDevice, deviceName()),
            ("gear", "iOS", UIDevice.current.systemVersion),
        ]
        var rows = items.map { item in
            Row(icon: item.0, title: item.1, subtitle: { item.2 }, accessory: .chevron, action: {})
        }
        let localeSubtitle = DivoStrings.isOverridden
            ? "\(DivoStrings.current.displayName) (override)"
            : "\(DivoStrings.current.displayName) (auto)"
        rows.append(Row(icon: "globe", title: DivoStrings.debugLocale, subtitle: { localeSubtitle }, accessory: .chevron, action: { [weak self] in
            guard let self = self else { return }
            let c = DebugLanguageController(context: self.context)
            self.onPush?(c)
        }))
        return rows
    }

    private func showDelayPicker() {
        let alert = UIAlertController(title: DivoStrings.debugNetworkDelayTitle, message: DivoStrings.debugNetworkDelayMessage, preferredStyle: .actionSheet)
        let options: [(String, TimeInterval)] = [
            (DivoStrings.debugOff, 0),
            (DivoStrings.debugDelayMs(100), 0.1),
            (DivoStrings.debugDelayMs(500), 0.5),
            (DivoStrings.debugDelaySec(2), 2.0),
            (DivoStrings.debugDelaySec(5), 5.0),
        ]
        let current = DivoConfig.simulatedDelay
        for (title, value) in options {
            let checkmark = (value == current) ? " ✓" : ""
            alert.addAction(UIAlertAction(title: title + checkmark, style: .default) { [weak self] _ in
                DivoConfig.simulatedDelay = value
                self?.buildSections()
                self?.tableView.reloadData()
            })
        }
        alert.addAction(UIAlertAction(title: DivoStrings.cancel, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }

        if let vc = self.closestViewController {
            vc.present(alert, animated: true)
        }
    }

    private func showRolePicker() {
        let alert = UIAlertController(title: "User Role", message: "Select the current user role", preferredStyle: .actionSheet)
        let current = DivoConfig.currentUserRole
        for role in DivoConfig.UserRole.allCases {
            let checkmark = (role == current) ? " ✓" : ""
            alert.addAction(UIAlertAction(title: role.displayName + checkmark, style: .default) { [weak self] _ in
                DivoConfig.currentUserRole = role
                switch role {
                case .agency:
                    DivoConfig.accessToken = DivoConfig.agencyToken
                case .model, .fan, .newFace:
                    DivoConfig.accessToken = DivoConfig.modelToken
                }
                self?.buildSections()
                self?.tableView.reloadData()
            })
        }
        alert.addAction(UIAlertAction(title: DivoStrings.cancel, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        if let vc = self.closestViewController {
            vc.present(alert, animated: true)
        }
    }

    private func clearImageCache() {
        let cache = URLCache.shared
        let bytes = cache.currentDiskUsage + cache.currentMemoryUsage
        if bytes == 0 { return }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let sizeStr = formatter.string(fromByteCount: Int64(bytes))

        let alert = UIAlertController(title: DivoStrings.debugClearCache, message: DivoStrings.debugCurrentSize(sizeStr), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: DivoStrings.debugClear, style: .destructive) { [weak self] _ in
            URLCache.shared.removeAllCachedResponses()
            self?.buildSections()
            self?.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: DivoStrings.cancel, style: .cancel))

        if let vc = self.closestViewController {
            vc.present(alert, animated: true)
        }
    }

    private func deviceName() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        return String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters) ?? UIDevice.current.model
    }
}

// MARK: - Cells

private final class DebugMenuTableCell: UITableViewCell {
    private let iconView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        backgroundColor = DebugTheme.cellBackground
        iconView.tintColor = DebugTheme.accent
        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: String, title: String, subtitle: String) {
        iconView.image = UIImage(systemName: icon)
        textLabel?.text = title
        textLabel?.textColor = DebugTheme.primaryText
        detailTextLabel?.text = subtitle
        detailTextLabel?.textColor = DebugTheme.secondaryText
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = contentView.bounds.height
        iconView.frame = CGRect(x: 16, y: (h - 22) / 2, width: 22, height: 22)
        var frame = textLabel?.frame ?? .zero
        frame.origin.x = 48
        textLabel?.frame = frame
    }
}

private final class DebugMenuToggleCell: UITableViewCell {
    private let iconView = UIImageView()
    private let toggle = UISwitch()
    private var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        backgroundColor = DebugTheme.cellBackground
        selectionStyle = .none
        iconView.tintColor = DebugTheme.accent
        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)
        toggle.onTintColor = DebugTheme.accent
        toggle.addTarget(self, action: #selector(toggled), for: .valueChanged)
        accessoryView = toggle
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: String, title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        iconView.image = UIImage(systemName: icon)
        textLabel?.text = title
        textLabel?.textColor = DebugTheme.primaryText
        toggle.isOn = isOn
        self.onToggle = onToggle
    }

    @objc private func toggled() {
        onToggle?(toggle.isOn)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = contentView.bounds.height
        iconView.frame = CGRect(x: 16, y: (h - 22) / 2, width: 22, height: 22)
        var frame = textLabel?.frame ?? .zero
        frame.origin.x = 48
        textLabel?.frame = frame
    }
}

private final class DebugInfoTableCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        backgroundColor = DebugTheme.cellBackground
        selectionStyle = .none
        accessoryType = .none
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, value: String) {
        textLabel?.text = title
        textLabel?.textColor = DebugTheme.primaryText
        textLabel?.font = .systemFont(ofSize: 15)
        detailTextLabel?.text = value
        detailTextLabel?.textColor = DebugTheme.secondaryText
        detailTextLabel?.font = .systemFont(ofSize: 15)
    }
}

// MARK: - UIView helper

private extension UIView {
    var closestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}
