import Foundation
import OdakCore

/// Keeps the meteor shower dates current without an app release: the IMO calendar JSON in the
/// repository is fetched at launch and kept in Application Support. A copy only replaces the one
/// in use when its `updated` date is newer, so a broken or stale download changes nothing.
enum SkyCalendarUpdater {
    static let remote = URL(string: "https://raw.githubusercontent.com/beyzaerdogaan/Odak/main/Packages/OdakCore/Sources/OdakCore/Resources/sky-calendar.json")!

    static var cacheURL: URL { URL.applicationSupportDirectory.appending(path: "sky-calendar.json") }

    /// Applies the last downloaded calendar, if it is newer than the bundled one.
    static func loadCached() {
        guard let data = try? Data(contentsOf: cacheURL), let calendar = try? SkyCalendar.decode(data) else { return }
        MeteorShowers.adopt(calendar)
    }

    static func refresh() async {
        guard let fetched = try? await URLSession.shared.data(from: remote) else { return }
        let (data, response) = fetched
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let calendar = try? SkyCalendar.decode(data),
              MeteorShowers.adopt(calendar) else { return }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }
}
