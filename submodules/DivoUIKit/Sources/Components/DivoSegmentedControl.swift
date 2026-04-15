import UIKit
import DivoCore

public final class DivoSegmentedControl: UIView {

    public var onTabSelected: ((Int) -> Void)?

    public private(set) var selectedIndex: Int = 0

    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.masksToBounds = true
        return view
    }()

    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.layer.masksToBounds = true
        return view
    }()

    private var tabButtons: [UIButton] = []
    private var titles: [String]

    public init(titles: [String]) {
        self.titles = titles
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        addSubview(backgroundView)
        backgroundView.addSubview(indicatorView)

        for (index, title) in titles.enumerated() {
            let button = UIButton(type: .custom)
            button.setAttributedTitle(Self.attributedTitle(title, active: index == 0), for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            backgroundView.addSubview(button)
            tabButtons.append(button)
        }
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.frame = bounds
        backgroundView.layer.cornerRadius = bounds.height / 2
        layoutIndicator()
    }

    private func layoutIndicator() {
        guard selectedIndex < tabButtons.count else { return }
        let tabCount = CGFloat(tabButtons.count)
        let padding: CGFloat = 2
        let segmentWidth = (bounds.width - padding * 2) / tabCount
        let indicatorX = padding + CGFloat(selectedIndex) * segmentWidth
        let indicatorHeight = bounds.height - padding * 2

        indicatorView.frame = CGRect(x: indicatorX, y: padding, width: segmentWidth, height: indicatorHeight)
        indicatorView.layer.cornerRadius = indicatorHeight / 2

        for (i, button) in tabButtons.enumerated() {
            button.frame = CGRect(x: padding + CGFloat(i) * segmentWidth, y: 0, width: segmentWidth, height: bounds.height)
        }
    }

    // MARK: - User Tap

    @objc private func tabTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedIndex else { return }
        selectedIndex = index

        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
            self.layoutIndicator()
        }
        updateButtonColors(animated: true)
        onTabSelected?(index)
    }

    // MARK: - Programmatic Selection

    public func setSelectedIndex(_ index: Int, animated: Bool) {
        guard index != selectedIndex, index >= 0, index < tabButtons.count else { return }
        selectedIndex = index

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
                self.layoutIndicator()
            }
            updateButtonColors(animated: true)
        } else {
            layoutIndicator()
            updateButtonColors(animated: false)
        }
    }

    /// Continuous indicator tracking driven by scroll progress (0.0 … tabCount-1).
    public func setIndicatorProgress(_ progress: CGFloat) {
        guard bounds.width > 0, !tabButtons.isEmpty else { return }
        let tabCount = CGFloat(tabButtons.count)
        let padding: CGFloat = 2
        let segmentWidth = (bounds.width - padding * 2) / tabCount
        let indicatorX = padding + progress * segmentWidth
        indicatorView.frame.origin.x = indicatorX
    }

    // MARK: - Titles

    public func updateTitles(_ newTitles: [String]) {
        titles = newTitles
        for (i, button) in tabButtons.enumerated() where i < newTitles.count {
            button.setAttributedTitle(Self.attributedTitle(newTitles[i], active: i == selectedIndex), for: .normal)
        }
    }

    // MARK: - Helpers

    private func updateButtonColors(animated: Bool) {
        for button in tabButtons {
            let isSelected = button.tag == selectedIndex
            let title = titles[button.tag]
            let attributed = Self.attributedTitle(title, active: isSelected)
            if animated {
                UIView.transition(with: button, duration: 0.2, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                    button.setAttributedTitle(attributed, for: .normal)
                }
            } else {
                button.setAttributedTitle(attributed, for: .normal)
            }
        }
    }

    private static func attributedTitle(_ title: String, active: Bool) -> NSAttributedString {
        let font = UIFont(name: "HelveticaNeue-CondensedBold", size: 10) ?? UIFont.systemFont(ofSize: 10, weight: .bold)
        let color: UIColor = DivoColorPalette.primaryText
        return NSAttributedString(string: title.uppercased(), attributes: [
            .font: font,
            .foregroundColor: color,
            .kern: 0.5
        ])
    }
}
