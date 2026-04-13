import UIKit

/// Токены дизайн-системы DIVO.
///
/// Единый источник правды для повторяющихся числовых значений (радиусы, параметры теней, отступы).
/// Наполняется по мере редизайна UI: сейчас покрывает ModelsFeed/ModelsSearch.
/// ProfileScreenUI/EventsUI будут подключены после их редизайна.
public enum DivoDesignTokens {

    // MARK: - Radius

    /// Радиусы скруглений DIVO-компонентов.
    ///
    /// Шкала построена по текущему редизайну (лента моделей, поиск). Значения, не попадающие в шкалу,
    /// оставляются сырыми с `// TODO: DS alignment` до подтверждения дизайном.
    public enum Radius {
        /// 4 — мелкие элементы (чипы, мини-индикаторы).
        public static let xs: CGFloat = 4
        /// 8 — инпуты, малые кнопки.
        public static let s: CGFloat = 8
        /// 12 — средние контейнеры.
        public static let m: CGFloat = 12
        /// 16 — крупные контейнеры.
        public static let l: CGFloat = 16
        /// 20 — pill-кнопки (close/filter в поиске).
        public static let pill: CGFloat = 20
        /// 24 — карточки (результаты поиска).
        public static let card: CGFloat = 24
        /// 34 — модалки/большие карточки.
        public static let sheet: CGFloat = 34
    }

    // MARK: - Shadow

    /// Параметры теней DIVO-компонентов.
    ///
    /// По умолчанию используется «карточная» тень: `opacityLight` + `radiusSmall` + `offset`.
    /// Применять через `CALayer.applyDivoShadow(...)`.
    public enum Shadow {
        /// 0.08 — стандартная непрозрачность карточной тени.
        public static let opacityLight: Float = 0.08
        /// 0.10 — усиленная тень (кнопки primary, акцентные элементы).
        public static let opacityMedium: Float = 0.10
        /// 12 — радиус размытия карточной тени.
        public static let radiusSmall: CGFloat = 12
        /// 16 — радиус размытия для крупных контейнеров.
        public static let radiusLarge: CGFloat = 16
        /// (0, 4) — смещение карточной тени.
        public static let offset = CGSize(width: 0, height: 4)
        /// (0, 2) — смещение для компактных контролов (slider thumb, кружки).
        public static let thumbOffset = CGSize(width: 0, height: 2)
        /// 4 — радиус размытия для компактных контролов.
        public static let thumbRadius: CGFloat = 4
    }

    // MARK: - Spacing

    /// Базовая шкала отступов DIVO.
    public enum Spacing {
        /// 4
        public static let xs: CGFloat = 4
        /// 8
        public static let s: CGFloat = 8
        /// 16 — стандартный боковой/блочный отступ.
        public static let m: CGFloat = 16
        /// 24
        public static let l: CGFloat = 24
        /// 32 — крупные разделители между блоками.
        public static let xl: CGFloat = 32
    }
}

// MARK: - CALayer + DivoShadow

public extension CALayer {
    /// Применяет стандартную тень DIVO.
    ///
    /// Цвет фиксирован через `DivoColorPalette.shadow`. По умолчанию — «карточный» вариант
    /// (`opacity = 0.08`, `radius = 12`, `offset = (0, 4)`).
    ///
    /// - Parameters:
    ///   - opacity: непрозрачность тени; по умолчанию `Shadow.opacityLight`.
    ///   - radius: радиус размытия; по умолчанию `Shadow.radiusSmall`.
    ///   - offset: смещение; по умолчанию `Shadow.offset`.
    func applyDivoShadow(
        opacity: Float = DivoDesignTokens.Shadow.opacityLight,
        radius: CGFloat = DivoDesignTokens.Shadow.radiusSmall,
        offset: CGSize = DivoDesignTokens.Shadow.offset
    ) {
        shadowColor = DivoColorPalette.shadow.cgColor
        shadowOpacity = opacity
        shadowRadius = radius
        shadowOffset = offset
        masksToBounds = false
    }
}
