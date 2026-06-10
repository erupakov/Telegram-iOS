import Foundation

/// Продуктовое требование (2026-06-10): в выборе гендера остаются только
/// «Мужской», «Женский» и «Не указывать». «Не указывать» = словарный id "other"
/// с локальным тайтлом; прочие значения словаря/сервера в UI не показываются.
public enum DivoGender {
    public static let male = "male"
    public static let female = "female"
    public static let notSpecified = "other"

    /// Опции для шторок выбора: male/female с серверными тайтлами, "other" — как
    /// «Не указывать». Пункт «Не указывать» появляется только если "other" есть в словаре.
    public static func pickerOptions(from dictionary: [GenderOption]) -> [GenderOption] {
        return dictionary.compactMap { option in
            switch option.id {
            case male, female:
                return option
            case notSpecified:
                return GenderOption(id: notSpecified, title: DivoStrings.genderNotSpecified)
            default:
                return nil
            }
        }
    }

    /// Серверное значение для показа/подсветки: male/female — как есть, любой иной id
    /// (legacy-значения вроде небинарного) — «Не указывать».
    public static func display(for gender: UserGender?) -> (id: String, title: String)? {
        guard let gender else { return nil }
        switch gender.id {
        case male, female:
            return (gender.id, gender.title)
        default:
            return (notSpecified, DivoStrings.genderNotSpecified)
        }
    }
}
