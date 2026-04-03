import UIKit
import AsyncDisplayKit
import Display

final class DropdownNode: ASDisplayNode {

    private let backgroundNode: ASDisplayNode
    private let apperTitleNode: ASTextNode
    private let titleNode: ASTextNode
    private let arrowNode: ASImageNode

    var options: [String] = []
    private let placeholder: String
    private let placeholderColor: UIColor?
    private let title: String
    private let titleColor: UIColor?
    
    var showsSearchBar: Bool = false
    var allowsMultipleSelection: Bool = false

    var onSelect: ((String) -> Void)?
    var onSelectMultiple: (([String]) -> Void)?

    weak var activeSheet: DropdownListSheetController?

    var isLoading: Bool = false {
        didSet { updateTitleText() }
    }

    var selectedValue: String? {
        didSet { updateTitleText() }
    }
    
    var selectedValues: [String] = [] {
        didSet { updateTitleText() }
    }

    init(
        title: String,
        placeholder: String,
        options: [String],
        backgroundColor: UIColor? = nil,
        placeholderColor: UIColor? = .white.withAlphaComponent(0.6),
        titleColor: UIColor? = .white,
        arrowColor: UIColor? = .white,
        apperTitleColor: UIColor? = .white,
        allowsMultipleSelection: Bool = false
    ) {
        self.title = title
        self.titleColor = titleColor
        self.placeholder = placeholder
        self.placeholderColor = placeholderColor
        self.options = options
        self.allowsMultipleSelection = allowsMultipleSelection

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.borderWidth = 1.0
        self.backgroundNode.backgroundColor = backgroundColor != nil ? backgroundColor : .clear
        self.backgroundNode.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        self.backgroundNode.cornerRadius = 10.0

        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1

        self.arrowNode = ASImageNode()
        self.arrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/InlineTextDownArrow"), color: arrowColor ?? .white)
        self.arrowNode.contentMode = .center

        self.apperTitleNode = ASTextNode()
        self.apperTitleNode.maximumNumberOfLines = 1
        self.apperTitleNode.attributedText = NSAttributedString(
            string: title,
            font: Font.regular(16.0),
            textColor: apperTitleColor ?? .white
        )

        super.init()

        self.addSubnode(apperTitleNode)
        self.addSubnode(backgroundNode)
        self.addSubnode(titleNode)
        self.addSubnode(arrowNode)

        updateTitleText()
    }

    override func didLoad() {
        super.didLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        self.view.addGestureRecognizer(tap)
        self.isUserInteractionEnabled = true
    }

    func updateOptions(_ newOptions: [String]) {
        self.options = newOptions
        self.isLoading = false
        self.activeSheet?.updateOptions(newOptions)
    }

    private func updateTitleText() {
        let text: String
        if isLoading {
            text = "Loading..."
        } else if allowsMultipleSelection {
            if selectedValues.isEmpty {
                text = placeholder
            } else if selectedValues.count == 1 {
                text = selectedValues[0]
            } else {
                text = "\(selectedValues.count) selected"
            }
        } else {
            text = selectedValue ?? placeholder
        }
        
        let hasValue = allowsMultipleSelection ? !selectedValues.isEmpty : (selectedValue != nil)
        let color: UIColor = (isLoading || !hasValue) ? placeholderColor! : titleColor!
        
        titleNode.attributedText = NSAttributedString(string: text, font: Font.regular(16.0), textColor: color)
        setNeedsLayout()
    }

    @objc private func tapped() {
        guard !isLoading || !options.isEmpty else { return }
        guard let viewController = findViewController() else { return }

        let sheet = DropdownListSheetController(
            title: title,
            options: options,
            selectedValue: selectedValue,
            selectedValues: selectedValues,
            allowsMultipleSelection: allowsMultipleSelection,
            showsSearchBar: showsSearchBar
        ) {[weak self] selected in
            if self?.allowsMultipleSelection == true {
                self?.selectedValues = selected
                self?.onSelectMultiple?(selected)
            } else {
                self?.selectedValue = selected.first
                self?.onSelect?(selected.first ?? "")
            }
        }

        self.activeSheet = sheet
        viewController.present(sheet, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self.view
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }

    override func layout() {
        super.layout()

        let bounds = self.bounds

        let apperTitleSize = apperTitleNode.measure(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        apperTitleNode.frame = CGRect(
            x: 0,
            y: 0,
            width: apperTitleSize.width,
            height: apperTitleSize.height
        )

        let spacing: CGFloat = 10.0

        let backgroundY = apperTitleNode.frame.maxY + spacing
        let backgroundHeight = bounds.height - backgroundY

        backgroundNode.frame = CGRect(
            x: 0,
            y: backgroundY,
            width: bounds.width,
            height: backgroundHeight
        )

        let arrowSize = CGSize(width: 20, height: 20)
        arrowNode.frame = CGRect(
            x: backgroundNode.frame.maxX - 16 - arrowSize.width,
            y: backgroundNode.frame.minY + (backgroundHeight - arrowSize.height) / 2.0,
            width: arrowSize.width,
            height: arrowSize.height
        )

        let titleSize = titleNode.measure(CGSize(width: bounds.width - 32 - arrowSize.width - 10, height: .greatestFiniteMagnitude))
        titleNode.frame = CGRect(
            x: backgroundNode.frame.minX + 16,
            y: backgroundNode.frame.minY + (backgroundHeight - titleSize.height) / 2.0,
            width: titleSize.width,
            height: titleSize.height
        )
    }
}

final class DropdownListSheetController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    private var allOptions: [String]
    private var filteredOptions: [String]

    private let selectedValue: String?
    private let selectedValues: [String]
    private let allowsMultipleSelection: Bool
    private var selectedIndices: Set<Int> = []
    
    private let onSelect: ([String]) -> Void

    private let sheetTitle: String
    private let showsSearchBar: Bool
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchBar = UISearchBar()
    private let titleLabel = UILabel()
    private let handleView = UIView()

    private let cellReuseId = "OptionCell"
    private let accentColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)

    init(title: String, options: [String], selectedValue: String?, selectedValues: [String], allowsMultipleSelection: Bool, showsSearchBar: Bool = true, onSelect: @escaping ([String]) -> Void) {
        self.sheetTitle = title
        self.allOptions = options
        self.filteredOptions = options
        self.selectedValue = selectedValue
        self.selectedValues = selectedValues
        self.allowsMultipleSelection = allowsMultipleSelection
        self.showsSearchBar = showsSearchBar
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)

        // Инициализируем выбранные индексы
        if allowsMultipleSelection {
            for (index, option) in allOptions.enumerated() {
                if selectedValues.contains(option) {
                    selectedIndices.insert(index)
                }
            }
        } else {
            if let selectedValue = selectedValue, let index = allOptions.firstIndex(of: selectedValue) {
                selectedIndices.insert(index)
            }
        }

        tableView.showsVerticalScrollIndicator = false
        modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 20
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateOptions(_ newOptions: [String]) {
        DispatchQueue.main.async {
            let oldCount = self.allOptions.count
            let newCount = newOptions.count

            self.allOptions = newOptions

            let searchText = self.searchBar.text ?? ""

            if searchText.isEmpty {
                self.filteredOptions = self.allOptions

                if oldCount == 0 || newCount <= oldCount {
                    self.tableView.reloadData()
                } else {
                    let indexPaths = (oldCount..<newCount).map { IndexPath(row: $0, section: 0) }
                    self.tableView.performBatchUpdates({
                        self.tableView.insertRows(at: indexPaths, with: .fade)
                    }, completion: nil)
                }
            } else {
                self.filteredOptions = self.allOptions.filter { $0.lowercased().contains(searchText.lowercased()) }
                self.tableView.reloadData()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)

        handleView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        handleView.layer.cornerRadius = 2.5
        handleView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(handleView)

        titleLabel.text = sheetTitle
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseId)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        if showsSearchBar {
            searchBar.searchBarStyle = .minimal
            searchBar.placeholder = "Search..."
            searchBar.delegate = self
            searchBar.barStyle = .black
            searchBar.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(searchBar)
        }

        NSLayoutConstraint.activate([
            handleView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            handleView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handleView.widthAnchor.constraint(equalToConstant: 36),
            handleView.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        if showsSearchBar {
            NSLayoutConstraint.activate([
                searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
                searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
                searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

                tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }

    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredOptions = allOptions
        } else {
            filteredOptions = allOptions.filter { $0.lowercased().contains(searchText.lowercased()) }
        }
        tableView.reloadData()
    }

    // MARK: - UITableView
    // Используем filteredOptions вместо options
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredOptions.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId, for: indexPath)
        let option = filteredOptions[indexPath.row]
        
        // Находим оригинальный индекс в allOptions для проверки выбора
        let originalIndex = allOptions.firstIndex(of: option) ?? indexPath.row
        let isSelected = selectedIndices.contains(originalIndex)

        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.textLabel?.text = option
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: isSelected ? .semibold : .regular)
        cell.textLabel?.textColor = isSelected ? accentColor : .white
        
        if allowsMultipleSelection {
            cell.accessoryType = isSelected ? .checkmark : .none
        } else {
            cell.accessoryType = isSelected ? .checkmark : .none
        }
        
        cell.tintColor = accentColor

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let option = filteredOptions[indexPath.row]
        let originalIndex = allOptions.firstIndex(of: option) ?? indexPath.row
        
        if allowsMultipleSelection {
            // Toggle selection
            if selectedIndices.contains(originalIndex) {
                selectedIndices.remove(originalIndex)
            } else {
                selectedIndices.insert(originalIndex)
            }
            
            // Обновляем видимые ячейки
            tableView.reloadRows(at: [indexPath], with: .none)
            
            // Возвращаем выбранные значения
            let selectedOptions = selectedIndices.map { allOptions[$0] }
            onSelect(selectedOptions)
        } else {
            // Одиночный выбор - закрываем sheet
            onSelect([option])
            searchBar.resignFirstResponder()
            dismiss(animated: true)
        }
    }
}