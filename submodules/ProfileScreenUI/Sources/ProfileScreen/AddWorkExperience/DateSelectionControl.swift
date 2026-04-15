import UIKit
import Display
import DivoCore
import DivoUIKit

final class DateSelectionControl: UIControl {
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.4)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(bundleImageName: "Components/Calendar")
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    
    private let hiddenTextField = UITextField()
    let datePicker = UIDatePicker()
    private let placeholder: String
    
    var onDateSelected: ((Int32) -> Void)?
    
    var onBeginEditing: (() -> Void)?
    
    var isActive: Bool {
        return hiddenTextField.isFirstResponder
    }
    
    init(placeholder: String) {
        self.placeholder = placeholder
        super.init(frame: .zero)
        
        setupUI()
        setupDatePicker()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        self.backgroundColor = .white
        self.layer.cornerRadius = 23
        self.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(valueLabel)
        addSubview(iconImageView)
        
        valueLabel.text = placeholder
        
        NSLayoutConstraint.activate([
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            iconImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconImageView.leadingAnchor, constant: -DivoDesignTokens.Spacing.s)
        ])
        
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for:[.touchUpInside, .touchUpOutside, .touchCancel])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    
    private func setupDatePicker() {
        addSubview(hiddenTextField)
        hiddenTextField.isHidden = true
        
        datePicker.datePickerMode = .date
        if #available(iOS 14.0, *) {
            datePicker.preferredDatePickerStyle = .inline
        }
        
        let container = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 380))
        container.backgroundColor = .systemBackground
        
        datePicker.frame = CGRect(x: DivoDesignTokens.Spacing.m, y: DivoDesignTokens.Spacing.m, width: container.bounds.width - DivoDesignTokens.Spacing.xl, height: container.bounds.height - DivoDesignTokens.Spacing.xl)
        datePicker.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(datePicker)
        
        hiddenTextField.inputView = container
 
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        hiddenTextField.addTarget(self, action: #selector(editingDidBegin), for: .editingDidBegin)
    }
    
    func setDate(timestamp: Int32?, localeIdentifier: String) {
        guard let timestamp = timestamp, timestamp > 0 else {
            valueLabel.text = placeholder
            valueLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.4)
            return
        }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.dateFormat = "d MMM yyyy"
        valueLabel.text = formatter.string(from: date)
        valueLabel.textColor = DivoColorPalette.primaryText
        datePicker.date = date
    }
    
    @objc private func editingDidBegin() {
        onBeginEditing?()
    }
    
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1) { self.alpha = 0.7; self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96) }
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.2) { self.alpha = 1.0; self.transform = .identity }
    }
    
    @objc private func tapped() {
        hiddenTextField.becomeFirstResponder()
    }
    
    @objc private func doneTapped() {
        hiddenTextField.resignFirstResponder()
        onDateSelected?(Int32(datePicker.date.timeIntervalSince1970))
    }
    
    @objc private func dateChanged() {
        onDateSelected?(Int32(datePicker.date.timeIntervalSince1970))
    }
}
