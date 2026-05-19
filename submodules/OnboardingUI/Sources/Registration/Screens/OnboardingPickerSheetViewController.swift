import UIKit
import Display
import DivoCore
import DivoUIKit

/// Bottom-sheet single-select. Используется для полей `.picker(...)` /  `.country` /
/// `.multiPicker(...)` (если в текущей итерации появится).
///
/// Михаил при вёрстке оставляет API (`init(options:selectedId:onSelect:)`) и
/// callback `onSelect` неизменным; меняет только стилистику ячейки и поведение
/// pull-to-dismiss.
public final class OnboardingPickerSheetViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let titleKey: String
    private let options: [FormPickerOption]
    private var selectedId: String?
    private let onSelect: (String?) -> Void

    private let titleLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)

    public init(titleKey: String, options: [FormPickerOption], selectedId: String?, onSelect: @escaping (String?) -> Void) {
        self.titleKey = titleKey
        self.options = options
        self.selectedId = selectedId
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DivoColorPalette.sheetBackgroundLight
        setupUI()
    }

    private func setupUI() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Font.helveticaNeue(17)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.textAlignment = .center
        titleLabel.text = OnboardingStrings.resolve(titleKey)

        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
        confirmButton.tintColor = DivoColorPalette.accent
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(OnboardingPickerCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .clear
        tableView.separatorInset = .zero
        tableView.separatorColor = DivoColorPalette.separatorLight
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false

        view.addSubview(titleLabel)
        view.addSubview(confirmButton)
        view.addSubview(tableView)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            confirmButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            confirmButton.widthAnchor.constraint(equalToConstant: 32),
            confirmButton.heightAnchor.constraint(equalToConstant: 32),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
        ])
    }

    @objc private func confirmTapped() {
        onSelect(selectedId)
        dismiss(animated: true)
    }

    // MARK: - UITableView

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return options.count }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! OnboardingPickerCell
        let option = options[indexPath.row]
        cell.configure(option: option, isSelected: option.id == selectedId)
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let option = options[indexPath.row]
        selectedId = option.id
        tableView.reloadData()
    }
}

private final class OnboardingPickerCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Font.helveticaNeue(15)
        titleLabel.textColor = DivoColorPalette.primaryText

        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.tintColor = DivoColorPalette.accent
        checkmark.contentMode = .scaleAspectFit

        contentView.addSubview(titleLabel)
        contentView.addSubview(checkmark)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            checkmark.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            checkmark.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmark.widthAnchor.constraint(equalToConstant: 18),
            checkmark.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(option: FormPickerOption, isSelected: Bool) {
        titleLabel.text = OnboardingStrings.resolve(option.titleKey)
        checkmark.isHidden = !isSelected
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        applyDivoListHighlight(highlighted)
    }
}
