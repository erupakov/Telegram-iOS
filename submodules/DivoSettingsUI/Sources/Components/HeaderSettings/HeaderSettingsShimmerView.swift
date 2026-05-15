import UIKit
import Display
import DivoCore
import DivoUIKit

final class HeaderSettingsShimmerView: UIView {

    static let avatarSize: CGFloat = 94

    private enum Layout {
        static let nameHeight: CGFloat = 22
        static let nameWidth: CGFloat = 100
        static let nameRadius: CGFloat = 11
        static let phoneHeight: CGFloat = 18
        static let phoneWidth: CGFloat = 120
        static let phoneRadius: CGFloat = 9
        static let stackSpacing: CGFloat = 12
        static let nameToPhoneSpacing: CGFloat = 6
    }

    private let avatarPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = avatarSize / 2
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let namePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = Layout.nameRadius
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let phonePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = Layout.phoneRadius
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupConstraints() {
        let textStack = UIStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = Layout.stackSpacing
        textStack.alignment = .center

        textStack.addArrangedSubview(avatarPlaceholder)
        textStack.addArrangedSubview(namePlaceholder)
        textStack.addArrangedSubview(phonePlaceholder)

        addSubview(textStack)

        NSLayoutConstraint.activate([
            textStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            avatarPlaceholder.heightAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarPlaceholder.widthAnchor.constraint(equalToConstant: Self.avatarSize),

            namePlaceholder.heightAnchor.constraint(equalToConstant: Layout.nameHeight),
            namePlaceholder.widthAnchor.constraint(equalToConstant: Layout.nameWidth),

            phonePlaceholder.heightAnchor.constraint(equalToConstant: Layout.phoneHeight),
            phonePlaceholder.widthAnchor.constraint(equalToConstant: Layout.phoneWidth),
        ])

        textStack.setCustomSpacing(Layout.nameToPhoneSpacing, after: namePlaceholder)
    }

    func startAnimation() {
        [avatarPlaceholder, namePlaceholder, phonePlaceholder].forEach {
            $0.addShimmerOverlay()
        }
    }

    func stopAnimation() {
        [avatarPlaceholder, namePlaceholder, phonePlaceholder].forEach {
            $0.removeShimmerOverlay()
        }
    }
}
