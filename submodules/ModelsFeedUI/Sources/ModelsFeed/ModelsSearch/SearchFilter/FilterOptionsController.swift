//
//  FilterOptionsController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import Display
import UIKit
import DivoCore

final class FilterOptionsController: UIViewController {
    
    private var allOptions: [FilterOptionItem]
    private var filteredOptions: [FilterOptionItem]
    private var selectedOptionIds: Set<String>
    private let isMultiSelect: Bool
    private let showSearch: Bool
        
    var onSave: (([FilterOptionItem]) -> Void)?
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.backgroundColor = .clear
        return stackView
    }()
    
    private let customNavBar: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = UIColor(hexString: "#222222")
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = UIImage(systemName: "chevron.left", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = UIColor(hexString: "#222222")
        
        button.setTitle(DivoStrings.back, for: .normal)
        button.setTitleColor(UIColor(hexString: "#222222"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 20)
        
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 12
        button.layer.masksToBounds = false
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let searchFieldContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.masksToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let searchIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(bundleImageName: "SearchIcon") ?? UIImage(systemName: "magnifyingglass")
        imageView.tintColor = UIColor(hexString: "#222222")?.withAlphaComponent(0.6)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let searchTextField: UITextField = {
        let field = UITextField()
        field.font = Font.regular(14)
        field.textColor = UIColor(hexString: "#222222")
        field.tintColor = UIColor(hexString: "#BF7A54")
        field.placeholder = DivoStrings.feedSearchCountry
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
        
    private let saveButton: UIButton = {
        let saveButton = UIButton(type: .custom)
        saveButton.backgroundColor = UIColor(hexString: "#FF772D")
        saveButton.layer.cornerRadius = 20
        saveButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        saveButton.tintColor = .white
        saveButton.layer.shadowColor = UIColor.black.cgColor
        saveButton.layer.shadowOpacity = 0.08
        saveButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        saveButton.layer.shadowRadius = 12
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        return saveButton
    }()
    
    private let deleteButton: UIButton = {
        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle(DivoStrings.feedSearchResetParameter, for: .normal)
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.titleLabel?.font = Font.helveticaNeue(18)
        deleteButton.backgroundColor = UIColor(hexString: "#343434")
        deleteButton.layer.cornerRadius = 24
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        return deleteButton
    }()
    
    init(title: String, options: [FilterOptionItem], selectedOptionIds: [String], isMultiSelect: Bool = false, showSearch: Bool = false) {
        self.titleLabel.text = title
        self.allOptions = options
        self.filteredOptions = options
        self.selectedOptionIds = Set(selectedOptionIds)
        self.isMultiSelect = isMultiSelect
        self.showSearch = showSearch
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(hexString: "#F0F0F0")
        
        setupCustomNavBar()
        setupSearchField()
        setupScrollView()
        setupConstraints()
        
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        closeButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        closeButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        saveButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        deleteButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        reloadOptions()
    }
    
    private func setupCustomNavBar() {
        view.addSubview(customNavBar)
        customNavBar.addSubview(closeButton)
        customNavBar.addSubview(titleLabel)
        customNavBar.addSubview(saveButton)
    }
    
    private func setupSearchField() {
        if showSearch {
            view.addSubview(searchFieldContainer)
            searchFieldContainer.addSubview(searchIcon)
            searchFieldContainer.addSubview(searchTextField)
        }
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.addSubview(deleteButton)
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        backgroundView.layer.cornerRadius = 16
        backgroundView.clipsToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.tag = 999
        scrollView.insertSubview(backgroundView, belowSubview: stackView)
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: stackView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            customNavBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            customNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customNavBar.heightAnchor.constraint(equalToConstant: 50),
            
            closeButton.leadingAnchor.constraint(equalTo: customNavBar.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.centerXAnchor.constraint(equalTo: customNavBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
            
            saveButton.trailingAnchor.constraint(equalTo: customNavBar.trailingAnchor, constant: -16),
            saveButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 40),
            saveButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        if showSearch {
            NSLayoutConstraint.activate([
                searchFieldContainer.topAnchor.constraint(equalTo: customNavBar.bottomAnchor, constant: 20),
                searchFieldContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                searchFieldContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                searchFieldContainer.heightAnchor.constraint(equalToConstant: 40),
                
                searchIcon.leadingAnchor.constraint(equalTo: searchFieldContainer.leadingAnchor, constant: 14),
                searchIcon.centerYAnchor.constraint(equalTo: searchFieldContainer.centerYAnchor),
                searchIcon.widthAnchor.constraint(equalToConstant: 20),
                searchIcon.heightAnchor.constraint(equalToConstant: 20),
                
                searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
                searchTextField.trailingAnchor.constraint(equalTo: searchFieldContainer.trailingAnchor, constant: -14),
                searchTextField.topAnchor.constraint(equalTo: searchFieldContainer.topAnchor),
                searchTextField.bottomAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor)
            ])
        }
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: showSearch ? searchFieldContainer.bottomAnchor : customNavBar.bottomAnchor, constant: showSearch ? 10.0 : 20.0),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            
            deleteButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 32),
            deleteButton.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            deleteButton.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            deleteButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    private func reloadOptions() {
        // Очищаем stackView
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let allOptionId = allOptions.first?.id ?? ""
        
        for (index, option) in filteredOptions.enumerated() {
            let cell = createOptionCell(
                option: option,
                isSelected: selectedOptionIds.contains(option.id) || (selectedOptionIds.isEmpty && option.id == allOptionId),
                isLast: index == filteredOptions.count - 1
            )
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(optionTapped(_:)))
            cell.addGestureRecognizer(tapGesture)
            cell.tag = index
            
            stackView.addArrangedSubview(cell)
        }
    }
    
    private func createOptionCell(option: FilterOptionItem, isSelected: Bool, isLast: Bool) -> UIView {
        let cell = UIView()
        cell.backgroundColor = .clear
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.heightAnchor.constraint(equalToConstant: 50).isActive = true
        cell.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width - 32).isActive = true
        
        let label = UILabel()
        label.text = option.title
        label.font = Font.regular(16)
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        
        let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
        checkmark.tintColor = UIColor(hexString: "#FF772D")
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = !isSelected
        cell.addSubview(checkmark)
        
        if !isLast {
            let separator = UIView()
            separator.backgroundColor = UIColor(hexString: "#E5E5EA")
            separator.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(separator)
            
            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 16),
                separator.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -16),
                separator.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: checkmark.leadingAnchor, constant: -8),
            
            checkmark.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -16),
            checkmark.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            checkmark.widthAnchor.constraint(equalToConstant: 20),
            checkmark.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return cell
    }
    
    @objc private func optionTapped(_ gesture: UITapGestureRecognizer) {
        guard let cell = gesture.view, let index = cell.tag as Int? else { return }
        let option = filteredOptions[index]
        let allOptionId = allOptions.first?.id ?? ""
        
        if isMultiSelect {
            if option.id == allOptionId {
                selectedOptionIds.removeAll()
            } else {
                if selectedOptionIds.contains(option.id) {
                    selectedOptionIds.remove(option.id)
                } else {
                    selectedOptionIds.insert(option.id)
                }
            }
            reloadOptions()
        } else {
            selectedOptionIds = [option.id]
        }
    }
    
    @objc private func searchTextChanged() {
        let text = searchTextField.text ?? ""
        
        if text.isEmpty {
            filteredOptions = allOptions
        } else {
            filteredOptions = allOptions.filter { $0.title.lowercased().contains(text.lowercased()) }
        }
        
        reloadOptions()
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func buttonPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            sender.alpha = 0.6
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        })
    }
    
    @objc private func buttonReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, animations: {
            sender.alpha = 1.0
            sender.transform = .identity
        })
    }
    
    @objc private func saveTapped() {
        if selectedOptionIds.isEmpty {
            onSave?([])
        } else {
            let selectedItems = allOptions.filter { selectedOptionIds.contains($0.id) }
            onSave?(selectedItems)
        }
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func deleteTapped() {
        onSave?([])
        navigationController?.popViewController(animated: true)
    }
}


// MARK: - UITextFieldDelegate

extension FilterOptionsController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
