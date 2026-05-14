import UIKit
import Display
import DivoCore

public final class DateSelectionControl: UIControl {
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.4)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let placeholderTimestamp: Int32
    private let localeIdentifier: String
    private var placeholderString: String = ""
    private let isTime: Bool
    
    public var hasSelection = false
    
    // Новое событие для открытия пикера
    public var onTap: (() -> Void)?
    
    public init(placeholder: Int32, localeIdentifier: String, isTime: Bool = false) {
        self.placeholderTimestamp = placeholder
        self.localeIdentifier = localeIdentifier
        self.isTime = isTime
        super.init(frame: .zero)
        
        let date = Date(timeIntervalSince1970: TimeInterval(placeholder))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.dateFormat = isTime ? "HH:mm" : "d MMM yyyy"
        self.placeholderString = formatter.string(from: date)
        
        iconImageView.image = isTime ? DivoImage.timeIcon : DivoImage.calendar
        
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        self.backgroundColor = DivoColorPalette.cardBackground
        self.layer.cornerRadius = 23
        self.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(valueLabel)
        addSubview(iconImageView)
        
        valueLabel.text = placeholderString
        
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
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    
    public func setDate(timestamp: Int32?) {
        guard let timestamp = timestamp, timestamp > 0 else {
            hasSelection = false
            valueLabel.text = placeholderString
            valueLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.4)
            return
        }
        hasSelection = true
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.dateFormat = isTime ? "HH:mm" : "d MMM yyyy"
        valueLabel.text = formatter.string(from: date)
        valueLabel.textColor = DivoColorPalette.primaryText
    }
    
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1) { self.alpha = 0.7; self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96) }
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.2) { self.alpha = 1.0; self.transform = .identity }
    }
    
    @objc private func tapped() {
        onTap?()
    }
}
