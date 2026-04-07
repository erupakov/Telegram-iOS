import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import DivoCore
import TelegramPresentationData
import AccountContext
import TelegramBaseController

final class DebugLanguageController: TelegramBaseController {
    private let context: AccountContext
    private var presentationData: PresentationData

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(
            context: context,
            navigationBarPresentationData: NavigationBarPresentationData(
                theme: DebugTheme.navTheme(),
                strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)
            )
        )

        self.title = DivoStrings.debugLocale

        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.title = DivoStrings.debugLocale
        }
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        let node = DebugLanguageNode()
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        (self.displayNode as? DebugLanguageNode)?.containerLayoutUpdated(layout, navigationBarHeight: navHeight)
    }
}

// MARK: - Node

private final class DebugLanguageNode: ASDisplayNode, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private struct Row {
        let title: String
        let subtitle: String
        let isSelected: Bool
        let action: () -> Void
    }

    private var sections: [(header: String?, rows: [Row])] = []

    override init() {
        super.init()
        self.backgroundColor = DebugTheme.background
    }

    override func didLoad() {
        super.didLoad()
        tableView.backgroundColor = DebugTheme.background
        tableView.separatorColor = DebugTheme.separator
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.view.addSubview(tableView)
        buildSections()
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        tableView.frame = CGRect(x: 0, y: navigationBarHeight, width: layout.size.width, height: layout.size.height - navigationBarHeight)
    }

    private func applyLanguage(_ lang: DivoStrings.Language) {
        DivoStrings.current = lang
        buildSections()
        tableView.reloadData()
    }

    private func applyAutoLanguage() {
        DivoStrings.resetToDeviceLanguage()
        buildSections()
        tableView.reloadData()
    }

    private func buildSections() {
        let currentLang = DivoStrings.current
        let isOverridden = DivoStrings.isOverridden

        let languageRows: [Row] = DivoStrings.Language.allCases.map { lang in
            Row(
                title: lang.displayName,
                subtitle: lang.rawValue.uppercased(),
                isSelected: isOverridden && lang == currentLang,
                action: { [weak self] in
                    self?.applyLanguage(lang)
                }
            )
        }

        let autoRow = Row(
            title: "Auto",
            subtitle: DivoStrings.deviceLanguage.displayName,
            isSelected: !isOverridden,
            action: { [weak self] in
                self?.applyAutoLanguage()
            }
        )

        sections = [
            (header: nil, rows: [autoRow]),
            (header: nil, rows: languageRows),
        ]
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]
        cell.textLabel?.text = row.title
        cell.textLabel?.textColor = DebugTheme.primaryText
        cell.detailTextLabel?.text = row.subtitle
        cell.backgroundColor = DebugTheme.cellBackground
        cell.accessoryType = row.isSelected ? .checkmark : .none
        cell.tintColor = DebugTheme.accent
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        sections[indexPath.section].rows[indexPath.row].action()
    }
}
