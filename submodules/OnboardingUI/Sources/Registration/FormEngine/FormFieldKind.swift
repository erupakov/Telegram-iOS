import Foundation

/// Тип поля формы — это то, что Михаил вёрстает как UITableViewCell.
/// Каждый case описывает данные + ограничения, не визуал.
public enum FormFieldKind {

    /// Однострочный текст. `minLength`/`maxLength` — `nil` означает «без ограничения».
    case text(minLength: Int? = nil, maxLength: Int? = nil)

    /// Многострочный текст (описание, биография).
    case multilineText(minLength: Int? = nil, maxLength: Int? = nil)

    case email
    case url(scheme: URLScheme = .anyHttp)
    case phone

    case date(min: Date? = nil, max: Date? = nil, presentation: DatePresentation = .full)

    /// Single-select bottom sheet. `options` фиксированный, `allowsCustom` пока не используется.
    case picker(options: [FormPickerOption])

    /// Multi-select.
    case multiPicker(options: [FormPickerOption], minSelections: Int = 0, maxSelections: Int? = nil)

    /// Спецпикер списка стран. UI отрисует флаг + название.
    case country

    /// Город. По плану — 22 мая Михаил заменит на CityPickerField; пока обычное text-поле.
    /// Расположение между Country и остальными полями диктуется FormSchema.
    case city

    /// Загрузка фото/логотипа. `aspect` — ориентир пропорций, не жёсткое требование.
    case photo(aspect: PhotoAspect, allowCamera: Bool = true, allowLibrary: Bool = true)

    // MARK: - Helpers

    public enum URLScheme {
        case anyHttp           // http/https
        case instagram         // @handle или ссылка инстаграма
        case anyLink           // любая текстовая ссылка
    }

    public enum DatePresentation {
        /// Полная дата — день/месяц/год (4.B step 2 date of birth и т.п.).
        case full
        case monthYear
        case yearOnly
    }

    public enum PhotoAspect {
        case square            // логотип компании, аватар фана
        case portrait          // профиль модели (предпочтительно вертикальное фото)
        case landscape         // главное помещение студии (4.C2 step 3)
    }
}

/// Опция для picker/multiPicker (например, role, gender, country).
public struct FormPickerOption: Equatable, Hashable {
    /// ID опции — записывается в `FormFieldValue.option(...)`.
    public let id: String
    /// Локализационный ключ заголовка.
    public let titleKey: String
    /// Иконка (SF Symbol или ассет из DivoImage). Используется в дизайне саб-роли.
    public let iconAssetName: String?

    public init(id: String, titleKey: String, iconAssetName: String? = nil) {
        self.id = id
        self.titleKey = titleKey
        self.iconAssetName = iconAssetName
    }
}
