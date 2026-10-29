import Foundation

/// The app's language. Texts are written in Turkish, the base language, and translated in the
/// string catalogs (`Resources/Localizable.xcstrings` here, `Localization/` in the app). OdakCore
/// follows the app's own choice rather than its package bundle's, so the rules and the screens
/// always speak the same language.
public enum AppLanguage {
    /// "tr" or "en": the app's language, which iOS picks from the user's preferred languages.
    nonisolated(unsafe) public static var current: String = Bundle.main.preferredLocalizations.first.map(code(for:)) ?? "tr"

    public static var isEnglish: Bool { current == "en" }

    /// For dates and numbers in the app's language.
    public static var locale: Locale { Locale(identifier: isEnglish ? "en_US" : "tr_TR") }

    static func code(for localization: String) -> String { localization.hasPrefix("en") ? "en" : "tr" }

    /// The package's translations for `current`; nil for Turkish, whose texts are the source.
    static var bundle: Bundle? {
        guard current != "tr" else { return nil }
        return Bundle.module.path(forResource: current, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    static let turkishMonths = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
    static let englishMonths = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    /// Month names, January first.
    public static var monthNames: [String] { isEnglish ? englishMonths : turkishMonths }

    /// "21 Ekim" or "October 21".
    public static func dayMonth(day: Int, month: Int) -> String {
        let name = monthNames[max(1, min(12, month)) - 1]
        return isEnglish ? "\(name) \(day)" : "\(day) \(name)"
    }

    /// "21–22 Ekim" or "October 21–22"; across a month end "31 Ekim–1 Kasım" or "October 31–November 1".
    public static func dayRange(_ a: (day: Int, month: Int), _ b: (day: Int, month: Int)) -> String {
        if a.month == b.month {
            let name = monthNames[max(1, min(12, a.month)) - 1]
            return isEnglish ? "\(name) \(a.day)–\(b.day)" : "\(a.day)–\(b.day) \(name)"
        }
        return dayMonth(day: a.day, month: a.month) + "–" + dayMonth(day: b.day, month: b.month)
    }
}

/// `text`, written in Turkish, in the app's language.
func loc(_ text: String.LocalizationValue) -> String {
    guard let bundle = AppLanguage.bundle else { return String(localized: text, table: "Source", bundle: .module) }
    return String(localized: text, bundle: bundle)
}

/// For a text whose Turkish wording is also another text's key (such as Perseus, both a name and a Latin
/// name): looked up by its own `key`, and `turkish` as it is in Turkish.
func loc(key: String, turkish: String) -> String {
    AppLanguage.bundle?.localizedString(forKey: key, value: turkish, table: nil) ?? turkish
}
