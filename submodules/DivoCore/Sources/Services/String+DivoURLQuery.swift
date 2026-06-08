import Foundation

public extension String {
    /// Percent-кодирует строку для безопасной подстановки в значение query-параметра URL.
    /// Без этого `URL(string:)` на iOS 13–16 возвращает nil для значений с пробелами/не-ASCII
    /// (имена городов: «New York, US», «São Paulo», «Москва») → краш на force-unwrap в `DivoAPIClient`.
    var divoURLQueryEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .divoURLQueryValueAllowed) ?? self
    }
}

public extension CharacterSet {
    /// `urlQueryAllowed` без sub-delimiter'ов, имеющих смысл внутри query (`&=+?#`), —
    /// чтобы такие символы в значении не ломали структуру строки запроса.
    static let divoURLQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=+?#")
        return set
    }()
}
