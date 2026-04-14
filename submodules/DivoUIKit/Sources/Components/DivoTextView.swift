import Display
import UIKit

public final class DivoTextView: UIView, UITextViewDelegate {

    private let inactiveBorderColor = UIColor.clear.cgColor
    private let activeBorderColor = DivoColorPalette.accent.cgColor
    
    // MARK: - UI Elements
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let backgroundContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16.0
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.clear.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    public let textView: UITextView = {
        let tv = UITextView()
        tv.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        tv.textColor = DivoColorPalette.primaryText
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Properties
    
    public var text: String {
        get { return textView.text }
        set { textView.text = newValue }
    }
    
    public var onBeginEditing: (() -> Void)?
    public var onEndEditing: (() -> Void)?
    public var onTextChange: ((String) -> Void)?

    // MARK: - Init
    
    public init(title: String, initialText: String = "") {
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        
        self.titleLabel.text = title
        self.textView.text = initialText
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        addSubview(titleLabel)
        addSubview(backgroundContainer)
        backgroundContainer.addSubview(textView)
        
        textView.delegate = self
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: self.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            
            backgroundContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            backgroundContainer.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            backgroundContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            backgroundContainer.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            textView.topAnchor.constraint(equalTo: backgroundContainer.topAnchor, constant: 10),
            textView.bottomAnchor.constraint(equalTo: backgroundContainer.bottomAnchor, constant: -10),
            textView.leadingAnchor.constraint(equalTo: backgroundContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            textView.trailingAnchor.constraint(equalTo: backgroundContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m)
        ])
    }
    
    // MARK: - Border Animation Helper
    
    private func animateBorderColor(to color: CGColor) {
        let animation = CABasicAnimation(keyPath: "borderColor")
        animation.fromValue = backgroundContainer.layer.borderColor
        animation.toValue = color
        animation.duration = 0.2
        
        backgroundContainer.layer.borderColor = color
        backgroundContainer.layer.add(animation, forKey: "borderColor")
    }
    
    // MARK: - UITextViewDelegate
    
    public func textViewDidBeginEditing(_ textView: UITextView) {
        animateBorderColor(to: activeBorderColor)
        onBeginEditing?()
    }
    
    public func textViewDidEndEditing(_ textView: UITextView) {
        animateBorderColor(to: inactiveBorderColor)
        onEndEditing?()
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        onTextChange?(textView.text)
    }
}
