import Foundation

/// Dated meteor shower windows from the IMO's yearly Meteor Shower Calendar. The app ships a copy
/// (`Resources/meteor-calendar.json`) and can swap in a newer one fetched from the repository, so
/// next year's dates arrive without a release. Outside the dates it covers, `MeteorShower` falls
/// back to its fixed month/day table.
public struct MeteorCalendar: Codable, Equatable, Sendable {
    public struct Occurrence: Codable, Equatable, Sendable {
        public let id: String
        /// First and last active day, as yyyy-MM-dd in the viewer's own time zone.
        public let start: String
        public let end: String
        /// The moment of maximum activity.
        public let peak: Date
        public let zhr: Int?
    }

    /// One dated activity window, with `end` exclusive (midnight after the last day).
    public struct Window: Equatable, Sendable {
        public let start: Date
        public let end: Date
        public let peak: Date
        public let zhr: Int?

        public func contains(_ date: Date) -> Bool { start <= date && date < end }
    }

    public enum Invalid: Error { case version, empty, badDay(String) }

    public let version: Int
    /// yyyy-MM-dd; a calendar only replaces another with an older `updated`.
    public let updated: String
    public let source: String
    public let occurrences: [Occurrence]

    public static func decode(_ data: Data) throws -> MeteorCalendar {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let c = try decoder.decode(MeteorCalendar.self, from: data)
        guard c.version == 1 else { throw Invalid.version }
        guard !c.occurrences.isEmpty else { throw Invalid.empty }
        let gregorian = Calendar(identifier: .gregorian)
        for o in c.occurrences {
            for day in [o.start, o.end] where Self.day(day, gregorian) == nil { throw Invalid.badDay(day) }
        }
        return c
    }

    /// The copy bundled with the app.
    public static let bundled: MeteorCalendar? = Bundle.module.url(forResource: "meteor-calendar", withExtension: "json")
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { try? decode($0) }

    public func windows(of id: String, calendar: Calendar) -> [Window] {
        occurrences.filter { $0.id == id }.compactMap { o in
            guard let s = Self.day(o.start, calendar), let last = Self.day(o.end, calendar),
                  let e = calendar.date(byAdding: .day, value: 1, to: last) else { return nil }
            return Window(start: s, end: e, peak: o.peak, zhr: o.zhr)
        }
        .sorted { $0.start < $1.start }
    }

    /// Whether `date` falls between the first window's start and the last window's end. Inside that
    /// span the calendar is the whole truth, so a shower with no window there is simply not on.
    public func covers(_ date: Date, calendar: Calendar) -> Bool {
        let all = Set(occurrences.map(\.id)).flatMap { windows(of: $0, calendar: calendar) }
        guard let first = all.map(\.start).min(), let last = all.map(\.end).max() else { return false }
        return first <= date && date < last
    }

    static func day(_ text: String, _ calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// How lit the Moon is at `date`, from 0 (new) to 100 (full). A mean synodic month from a known new
/// moon is good to a few percent, enough to say whether moonlight will wash out faint meteors.
public enum Moon {
    static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440) // 2000-01-06 18:14 UT
    static let synodicDays = 29.530588853

    public static func illumination(at date: Date) -> Int {
        let days = date.timeIntervalSince(referenceNewMoon) / 86_400
        let age = days.truncatingRemainder(dividingBy: synodicDays)
        return Int((50 * (1 - cos(2 * .pi * age / synodicDays))).rounded())
    }
}
