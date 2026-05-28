import UIKit

/// Standalone debug log viewer без зависимости от AccountContext.
/// Может быть представлен с любого экрана (включая auth-флоу до получения context).
/// Открывается по shake gesture (см. DivoShakeGestureHandler).
public final class DivoStandaloneLogsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var entries: [DivoConsoleLogEntry] = []
    private var observer: Any?
    private weak var titleLabel: UILabel?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    public init() {
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // DIVO: Используем обычные UIButton с addTarget — UIControl держит direct target
        // reference и не зависит от UIResponder chain (в отличие от UIBarButtonItem в subview
        // UINavigationBar). Не оборачиваем в UINavigationController, чтобы не ломать back
        // на presenter'е после dismiss.
        let toolbar = UIView()
        toolbar.backgroundColor = UIColor(white: 0.08, alpha: 1)
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Console Logs"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel = titleLabel

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.tintColor = .systemOrange
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let clearButton = UIButton(type: .system)
        clearButton.setTitle("Clear", for: .normal)
        clearButton.tintColor = .systemOrange
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearButton.translatesAutoresizingMaskIntoConstraints = false

        let shareButton = UIButton(type: .system)
        shareButton.setTitle("Share", for: .normal)
        shareButton.tintColor = .systemOrange
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toolbar)
        toolbar.addSubview(closeButton)
        toolbar.addSubview(titleLabel)
        toolbar.addSubview(clearButton)
        toolbar.addSubview(shareButton)

        tableView.backgroundColor = .black
        tableView.separatorColor = UIColor(white: 0.2, alpha: 1)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "C")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),

            closeButton.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: toolbar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            shareButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            shareButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            clearButton.trailingAnchor.constraint(equalTo: shareButton.leadingAnchor, constant: -16),
            clearButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        observer = NotificationCenter.default.addObserver(forName: DivoConsoleLogger.newEntryNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
        reload()
    }

    private func reload() {
        entries = DivoConsoleLogger.shared.getEntries()
        tableView.reloadData()
        titleLabel?.text = "Console Logs (\(entries.count))"
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func clearTapped() {
        DivoConsoleLogger.shared.clear()
        reload()
    }

    @objc private func shareTapped() {
        guard !entries.isEmpty else { return }
        let header = "Console Logs — \(entries.count) entries (latest first)\n\n"
        let body = entries.map { e in
            "[\(Self.timeFormatter.string(from: e.timestamp))] [\(e.level.rawValue)] \(e.file):\(e.line)\n\(e.message)"
        }.joined(separator: "\n\n")
        let ac = UIActivityViewController(activityItems: [header + body + "\n"], applicationActivities: nil)
        present(ac, animated: true)
    }
}

extension DivoStandaloneLogsViewController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "C", for: indexPath)
        cell.backgroundColor = .black
        cell.selectionStyle = .none
        let entry = entries[indexPath.row]
        let timeStr = Self.timeFormatter.string(from: entry.timestamp)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        cell.textLabel?.text = "[\(timeStr)] [\(entry.level.rawValue)] \(entry.file):\(entry.line)\n\(entry.message)"
        cell.textLabel?.textColor = textColor(for: entry.level)
        return cell
    }

    private func textColor(for level: DivoConsoleLogEntry.Level) -> UIColor {
        switch level {
        case .debug: return UIColor(white: 0.6, alpha: 1)
        case .info: return .systemBlue
        case .warning: return .systemOrange
        case .error: return .systemRed
        }
    }
}

/// Подписан на "DivoDebugShake" notification (постится из NativeWindow при shake-жесте).
/// При срабатывании — открывает DivoStandaloneLogsViewController поверх любого экрана,
/// включая auth-флоу до получения AccountContext.
///
/// Регистрируется лениво при первом обращении к DivoConsoleLogger.shared (через divoLog).
public final class DivoShakeGestureHandler {
    public static let shared = DivoShakeGestureHandler()

    private var observer: Any?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("DivoDebugShake"),
            object: nil,
            queue: .main
        ) { _ in
            DivoShakeGestureHandler.presentLogsViewer()
        }
    }

    private static func presentLogsViewer() {
        guard let topVC = topmostViewController() else { return }
        if topVC is DivoStandaloneLogsViewController { return }
        let vc = DivoStandaloneLogsViewController()
        // DIVO: стандартный present без UINavigationController-обёртки. Toolbar внутри VC
        // — UIView с UIButton'ами (target/action через UIControl, не через UIResponder chain).
        // Так после dismiss back/touch у presenter'а не ломаются.
        topVC.present(vc, animated: true)
    }

    private static func topmostViewController(base: UIViewController? = nil) -> UIViewController? {
        let root: UIViewController?
        if let base = base {
            root = base
        } else {
            root = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        }
        if let nav = root as? UINavigationController {
            return topmostViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topmostViewController(base: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topmostViewController(base: presented)
        }
        return root
    }
}
