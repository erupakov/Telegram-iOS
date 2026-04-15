import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown
import SolidRoundedButtonNode
import AuthorizationUtils
import DivoUIKit

class AgeSliderNode: ASDisplayNode {
    private let titleNode: ASTextNode
    private let valueNode: ASTextNode
    public let slider: UISlider

    private let minAgeNode: ASTextNode
    private let maxAgeNode: ASTextNode
    private let type: String

    init(title: String, type: String, defaultValue: Int, minimumValue: Int, maximumValue: Int) {
        self.type = type
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(16), textColor: .white)
        self.titleNode.displaysAsynchronously = false

        self.valueNode = ASTextNode()
        self.valueNode.attributedText = NSAttributedString(string: String(defaultValue) + " " + type, font: Font.bold(16), textColor: .white)
        self.valueNode.displaysAsynchronously = false

        self.slider = UISlider()
        self.slider.minimumValue = Float(minimumValue)
        self.slider.maximumValue = Float(maximumValue)
        self.slider.value = Float(defaultValue)
        self.slider.tintColor = DivoColorPalette.accentCopperWarm

        // Кастомизация ползунка: меньший размер с цветным border
        let thumbSize: CGFloat = 16.0
        let borderColor = DivoColorPalette.accentCopperWarm
        let thumbImage = generateImage(CGSize(width: thumbSize, height: thumbSize), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            // Рисуем круг с border
            let borderRect = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
            let path = UIBezierPath(ovalIn: borderRect)
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(2.0)
            context.addPath(path.cgPath)
            context.strokePath()
            // Белая середина (без просвета)
            let innerRect = CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4)
            let innerPath = UIBezierPath(ovalIn: innerRect)
            context.setFillColor(UIColor.white.cgColor)
            context.addPath(innerPath.cgPath)
            context.fillPath()
        })
        self.slider.setThumbImage(thumbImage, for: .normal)
        self.slider.setThumbImage(thumbImage, for: .highlighted)

        self.minAgeNode = ASTextNode()
        self.minAgeNode.attributedText = NSAttributedString(string: String(minimumValue), font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
        self.minAgeNode.displaysAsynchronously = false

        self.maxAgeNode = ASTextNode()
        self.maxAgeNode.attributedText = NSAttributedString(string: String(maximumValue), font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
        self.maxAgeNode.displaysAsynchronously = false

        super.init()

        self.slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        self.addSubnode(titleNode)
        self.addSubnode(valueNode)
        self.view.addSubview(self.slider)

        self.addSubnode(self.minAgeNode)
        self.addSubnode(self.maxAgeNode)
    }
    
    override func layout() {
        super.layout()

        let sideInset: CGFloat = 16.0
        let maximumWidth: CGFloat = self.bounds.width
//        let maxHeight: CGFloat = self.bounds.height

        let titleSize = self.titleNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(x: sideInset, y: 0, width: titleSize.width, height: titleSize.height)

        let valueSize = self.valueNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.valueNode.frame = CGRect(x: maximumWidth - sideInset - valueSize.width, y: 0, width: valueSize.width, height: valueSize.height)

        let sliderWidth = maximumWidth - sideInset * 2.0
        let sliderHeight: CGFloat = 30.0 // Фиксированная высота для слайдера
        let sliderY = titleSize.height
        self.slider.frame = CGRect(x: sideInset, y: sliderY, width: sliderWidth, height: sliderHeight)

        let minSize = self.minAgeNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.minAgeNode.frame = CGRect(x: sideInset, y: sliderY + sliderHeight, width: minSize.width, height: minSize.height)

        let maxSize = self.maxAgeNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.maxAgeNode.frame = CGRect(x: maximumWidth - sideInset - maxSize.width, y: sliderY + sliderHeight, width: maxSize.width, height: maxSize.height)
    }
    
    @objc private func sliderValueChanged() {
        let roundedValue = Int(self.slider.value.rounded())
        self.valueNode.attributedText = NSAttributedString(string: "\(roundedValue) " + type, font: Font.bold(16), textColor: .white)
        self.setNeedsLayout()
    }
}

class CheckboxNode: ASButtonNode {
    private let checkboxSize: CGSize
    
    init(size: CGSize = CGSize(width: 20, height: 20)) {
        self.checkboxSize = size
        super.init()
        self.updateAppearance()
    }
    
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }
    
    private func updateAppearance() {
        let normalImage = DivoImage.checkbox
        let selectedImage = DivoImage.checkboxSelected
        
        self.setImage(normalImage, for: .normal)
        self.setImage(selectedImage, for: .selected)
        self.setImage(selectedImage, for: .highlighted)
    }
}



final class ButtonWithIconNode: ASControlNode {
    private let textNode: ASTextNode
    private let iconNode: ASImageNode
    private let spacing: CGFloat
    private let imageSize: CGSize
    var showsSearchBar: Bool = true

    init(title: String, icon: UIImage?, theme: PresentationTheme, spacing: CGFloat, imageSize: CGSize) {
        self.spacing = spacing
        self.imageSize = imageSize

        self.textNode = ASTextNode()
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.bold(20.0), textColor: .white)

        self.iconNode = ASImageNode()
        self.iconNode.image = icon
        self.iconNode.contentMode = .scaleAspectFit

        super.init()

        self.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.cornerRadius = 6

        if icon != nil {
            self.addSubnode(self.iconNode)
        }
        self.addSubnode(self.textNode)
    }
    
    override func layout() {
        super.layout()
        
        let textSize = self.textNode.measure(self.bounds.size)
        
        if self.iconNode.image != nil {
            let contentWidth = self.imageSize.width + self.spacing + textSize.width
            let contentOriginX = (self.bounds.width - contentWidth) / 2.0
            
            self.iconNode.frame = CGRect(x: contentOriginX,
                                         y: (self.bounds.height - self.imageSize.height) / 2.0,
                                         width: self.imageSize.width,
                                         height: self.imageSize.height)
            
            self.textNode.frame = CGRect(x: contentOriginX + self.imageSize.width + self.spacing,
                                         y: (self.bounds.height - textSize.height) / 2.0,
                                         width: textSize.width,
                                         height: textSize.height)
        } else {
            self.textNode.frame = CGRect(x: (self.bounds.width - textSize.width) / 2.0,
                                         y: (self.bounds.height - textSize.height) / 2.0,
                                         width: textSize.width,
                                         height: textSize.height)
        }
    }
}

// MARK: - DropdownNode
final class DropdownNode: ASDisplayNode {
    
    private let backgroundNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let arrowNode: ASImageNode
    
    var options: [String] = []
    private let placeholder: String
    private let title: String
    
    var showsSearchBar: Bool = true

    var onSelect: ((String) -> Void)?

    weak var activeSheet: DropdownListSheetController?

    var isLoading: Bool = false {
        didSet { updateTitleText() }
    }

    var selectedValue: String? {
        didSet { updateTitleText() }
    }

    init(title: String, placeholder: String) {
        self.title = title
        self.placeholder = placeholder

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.borderWidth = 1.0
        self.backgroundNode.borderColor = DivoColorPalette.overlayDarkFieldBorder.cgColor
        self.backgroundNode.cornerRadius = 10.0

        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1

        self.arrowNode = ASImageNode()
        self.arrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/InlineTextDownArrow"), color: .white)
        self.arrowNode.contentMode = .center

        super.init()

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
        let text = isLoading ? "Loading..." : (selectedValue ?? placeholder)
        let color: UIColor = (selectedValue == nil || isLoading) ? DivoColorPalette.overlayDarkFieldBorder : .white
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
            showsSearchBar: showsSearchBar
        ) {[weak self] selected in
            self?.selectedValue = selected
            self?.onSelect?(selected)
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
        backgroundNode.frame = bounds
        let arrowSize = CGSize(width: 20, height: 20)
        arrowNode.frame = CGRect(x: bounds.width - 16 - arrowSize.width, y: (bounds.height - arrowSize.height) / 2.0, width: arrowSize.width, height: arrowSize.height)
        let titleSize = titleNode.measure(CGSize(width: bounds.width - 32 - arrowSize.width - 10, height: .greatestFiniteMagnitude))
        titleNode.frame = CGRect(x: 16, y: (bounds.height - titleSize.height) / 2.0, width: titleSize.width, height: titleSize.height)
    }
}

final class DropdownListSheetController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    private var allOptions: [String]
    private var filteredOptions: [String]

    private let selectedValue: String?
    private let onSelect: (String) -> Void

    private let sheetTitle: String
    private let showsSearchBar: Bool
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchBar = UISearchBar()
    private let titleLabel = UILabel()
    private let handleView = UIView()

    private let cellReuseId = "OptionCell"
    private let accentColor = DivoColorPalette.accentCopperWarm

    init(title: String, options: [String], selectedValue: String?, showsSearchBar: Bool = true, onSelect: @escaping (String) -> Void) {
        self.sheetTitle = title
        self.allOptions = options
        self.filteredOptions = options
        self.selectedValue = selectedValue
        self.showsSearchBar = showsSearchBar
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)

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
        view.backgroundColor = DivoColorPalette.dropdownBackgroundDark

        handleView.backgroundColor = DivoColorPalette.handleIndicator
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
        let isSelected = option == selectedValue
        
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.textLabel?.text = option
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: isSelected ? .semibold : .regular)
        cell.textLabel?.textColor = isSelected ? accentColor : .white
        cell.accessoryType = isSelected ? .checkmark : .none
        cell.tintColor = accentColor
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect(filteredOptions[indexPath.row])
        searchBar.resignFirstResponder()
        dismiss(animated: true)
    }
}