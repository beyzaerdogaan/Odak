import UIKit

/// iOS does not let apps silence calls and messages. Instead the user creates a "Derin" Focus and two
/// Shortcuts once ("Derin Başlat" turns the Focus on, "Derin Bitir" turns it off, named in the app's
/// language); the app runs them at the start and end of each session and Shortcuts sends the user straight back.
enum FocusModeShortcuts {
    static let startName = String(localized: "Derin Başlat")
    static let endName = String(localized: "Derin Bitir")

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
