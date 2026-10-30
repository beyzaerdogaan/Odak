import UIKit

/// iOS does not let apps silence calls and messages. Instead the user creates a "Derin" Focus and two
/// Shortcuts once ("Derin Başlat" turns the Focus on, "Derin Bitir" turns it off); the app runs them
/// at the start and end of each session and Shortcuts sends the user straight back.
enum FocusModeShortcuts {
    static let startName = "Derin Başlat"
    static let endName = "Derin Bitir"

    /// Ready-made copies of the two shortcuts shared from iCloud, so setup is one "Add Shortcut" tap each.
    static let startShareURL = URL(string: "https://www.icloud.com/shortcuts/37aeb34462f94c87bb604415091e7867")!
    static let endShareURL = URL(string: "https://www.icloud.com/shortcuts/PLACEHOLDER_END")!

    static func url(for name: String) -> URL? {
        var c = URLComponents(string: "shortcuts://x-callback-url/run-shortcut")!
        c.queryItems = [.init(name: "name", value: name), .init(name: "x-success", value: "derin://focus"),
                        .init(name: "x-error", value: "derin://focus")]
        return c.url
    }

    @MainActor static func run(_ name: String) {
        guard let url = url(for: name) else { return }
        UIApplication.shared.open(url)
    }

    static let focusSettingsURL = URL(string: UIApplication.openSettingsURLString)!
}
