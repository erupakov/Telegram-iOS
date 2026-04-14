import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import DivoUIKit

final class DivoTextView: UIView, UITextViewDelegate {

    private let inactiveBorderColor = UIColor.clear.cgColor
    private let activeBorderColor = UIColor(hexString: "#FF772D")?.cgColor ?? UIColor.systemOrange.cgColor
    
    // MARK: - UI Elements
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(hexString: "#222222")?.withAlphaComponent(0.6) ?? .gray
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
    
    let textView: UITextView = {
        let tv = UITextView()
        tv.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        tv.textColor = UIColor(hexString: "#222222") ?? .black
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Properties
    
    var text: String {
        get { return textView.text }
        set { textView.text = newValue }
    }
    
    var onBeginEditing: (() -> Void)?
    var onEndEditing: (() -> Void)?
    var onTextChange: ((String) -> Void)?

    // MARK: - Init
    
    init(title: String, initialText: String = "") {
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        
        self.titleLabel.text = title
        self.textView.text = initialText
        
        setupUI()
    }
    
// <<<<<<< HEAD
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
// =======
//     private func setupNodes() {
//         backgroundNode.backgroundColor = .clear
//         backgroundNode.borderWidth = 1.0
//         backgroundNode.borderColor = DivoColorPalette.overlayDarkFieldBorderLight.cgColor
//         backgroundNode.cornerRadius = 11.0
//         addSubnode(backgroundNode)
        
//         titleNode.attributedText = NSAttributedString(
//             string: title,
//             attributes: [
//                 .font: Font.regular(14.0),
//                 .foregroundColor: DivoColorPalette.textOnDarkTertiary
//             ]
//         )
//         addSubnode(titleNode)
        
//         textNode.delegate = self
//         textNode.textView.font = Font.regular(16.0)
//         textNode.textView.textColor = .white
//         textNode.textView.backgroundColor = .clear
// //        textNode.textView.typingAttributes = [
// //            NSAttributedString.Key.font.rawValue: Font.regular(16.0),
// //            NSAttributedString.Key.foregroundColor.rawValue: UIColor.white
// //        ]
        
//         textNode.textView.textContainerInset = .zero
//         textNode.textView.textContainer.lineFragmentPadding = 0
        
//         addSubnode(textNode)
// >>>>>>> dev
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
            
            backgroundContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            backgroundContainer.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            backgroundContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            backgroundContainer.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            textView.topAnchor.constraint(equalTo: backgroundContainer.topAnchor, constant: 10),
            textView.bottomAnchor.constraint(equalTo: backgroundContainer.bottomAnchor, constant: -10),
            textView.leadingAnchor.constraint(equalTo: backgroundContainer.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: backgroundContainer.trailingAnchor, constant: -16)
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
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        animateBorderColor(to: activeBorderColor)
        onBeginEditing?()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        animateBorderColor(to: inactiveBorderColor)
        onEndEditing?()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        onTextChange?(textView.text)
    }
}
