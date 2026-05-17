import UIKit
import DivoUIKit

/// Градиент-оверлей внизу экрана, который «прячет» проскролленный контент под кнопкой Continue/Done.
///
/// Тот же визуальный паттерн, что в `EditProfileNode` (см. `bottomFadeOverlay`): прозрачный сверху,
/// `DivoColorPalette.screenBackground` снизу, переход на 45 % высоты.
///
/// Используется в `OnboardingQuizViewController` и `OnboardingFormStepViewController`. `scrollView`
/// в этих контроллерах протянут до низа экрана, `contentInset.bottom` поднимает контент так, чтобы
/// последняя строка не оказывалась под кнопкой — а fade-оверлей сверху делает визуально мягкий
/// переход.
final class OnboardingBottomFadeOverlay: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    /// Высота, при которой fade «срабатывает». 160 — то же значение, что в EditProfile, согласовано
    /// с дизайн-системой.
    static let defaultHeight: CGFloat = 160

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false
        if let gradient = layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.withAlphaComponent(0).cgColor,
                DivoColorPalette.screenBackground.cgColor,
            ]
            gradient.locations = [0, 0.45]
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }
}
