import UIKit
import Display
import TelegramCore

final class EventParametersSheetController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var sheetTitle: String { DivoStrings.parametersTitle }
    private var allParameters = EventParameter.allCases
    private var selectedParameters: Set<EventParameter>
    private let onSave: (Set<EventParameter>) -> Void
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let titleLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    private let accentColor = UIColor(hexString: "#BF7A54") ?? .orange
    
    init(selectedParameters: Set<EventParameter>, onSave: @escaping (Set<EventParameter>) -> Void) {
        self.selectedParameters = selectedParameters
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
        
        modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
        
        titleLabel.text = sheetTitle
        titleLabel.font = Font.bold(20)
        titleLabel.textColor = UIColor(hexString: "#222222")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        cancelButton.setTitle(DivoStrings.cancel, for: .normal)
        cancelButton.setTitleColor(accentColor, for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        saveButton.setTitle(DivoStrings.save, for: .normal)
        saveButton.setTitleColor(accentColor, for: .normal)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)
        
        let subtitle = UILabel()
        subtitle.text = DivoStrings.chooseParametersForApplying
        subtitle.font = Font.semibold(16)
        subtitle.textColor = UIColor(hexString: "#17181C")
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitle)
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ParameterCell.self, forCellReuseIdentifier: ParameterCell.reuseId)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            cancelButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            saveButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            subtitle.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            subtitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            tableView.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        onSave(selectedParameters)
        dismiss(animated: true)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allParameters.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ParameterCell.reuseId, for: indexPath) as? ParameterCell else {
            return UITableViewCell()
        }
        
        if indexPath.row == 0 {
            let isAllSelected = selectedParameters.count == allParameters.count
            cell.configure(title: DivoStrings.allMembers, isSelected: isAllSelected)
        } else {
            let param = allParameters[indexPath.row - 1]
            let isSelected = selectedParameters.contains(param)
            cell.configure(title: param.localizedTitle, isSelected: isSelected)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 36.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            if selectedParameters.count == allParameters.count {
                selectedParameters.removeAll()
            } else {
                selectedParameters = Set(allParameters)
            }
        } else {
            let param = allParameters[indexPath.row - 1]
            if selectedParameters.contains(param) {
                selectedParameters.remove(param)
            } else {
                selectedParameters.insert(param)
            }
        }
        
        tableView.reloadData()
    }
}