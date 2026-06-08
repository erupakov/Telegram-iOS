import Foundation

public extension String {
    /// Percent-кодирует значение query-параметра: без этого `URL(string:)` на iOS 13–16
    /// возвращает nil на пробелах/не-ASCII → краш force-unwrap в `DivoAPIClient`.
    var divoURLQueryEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .divoURLQueryValueAllowed) ?? self
    }
}

public extension CharacterSet {
    /// `urlQueryAllowed` минус sub-delimiter'ы (`&=+?#`), чтобы они в значении не ломали query.
    static let divoURLQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=+?#")
        return set
    }()
}
