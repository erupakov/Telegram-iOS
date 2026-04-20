import UIKit
import Display

public final class DivoLoadingOverlay: UIView {

    private let spinner = DivoSegmentedSpinner()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(14)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.85)
        isUserInteractionEnabled = true
        alpha = 0

        spinner.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spinner)
        stackView.addArrangedSubview(messageLabel)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 32),
            spinner.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    public func show(in parentView: UIView, message: String) {
        messageLabel.text = message
        frame = parentView.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parentView.addSubview(self)
        spinner.startAnimating()
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
    }

    public func hide() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }) { _ in
            self.spinner.stopAnimating()
            self.removeFromSuperview()
        }
    }
}
