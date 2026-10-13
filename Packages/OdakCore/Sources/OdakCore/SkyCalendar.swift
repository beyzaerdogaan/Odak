import Foundation

/// The sky's dated events: meteor shower windows from the IMO's yearly Meteor Shower Calendar, and
/// eclipses (NASA's tables) and planet events (computed from VSOP87) as seen from Turkey. The app
/// ships a copy (`Resources/sky-calendar.json`) and can swap in a newer one fetched from the
/// repository, so next year's dates arrive without a release. Outside the dates it covers,
/// `MeteorShower` falls back to its fixed month/day table.
public struct SkyCalendar: Codable, Equatable, Sendable {
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
    /// Eclipses, planet events and supermoons. Optional so an older copy without them still loads.
    public let events: [AstroEvent]?

    /// The events the app knows how to show; kinds added by a newer calendar are skipped.
    public var astroEvents: [AstroEvent] { (events ?? []).filter { $0.kind != nil }.sorted { $0.peak < $1.peak } }

    public static func decode(_ data: Data) throws -> SkyCalendar {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let c = try decoder.decode(SkyCalendar.self, from: data)
        guard c.version == 1 else { throw Invalid.version }
        guard !c.occurrences.isEmpty else { throw Invalid.empty }
        let gregorian = Calendar(identifier: .gregorian)
        for o in c.occurrences {
            for day in [o.start, o.end] where Self.day(day, gregorian) == nil { throw Invalid.badDay(day) }
        }
        return c
    }

    /// The copy bundled with the app.
    public static let bundled: SkyCalendar? = Bundle.module.url(forResource: "sky-calendar", withExtension: "json")
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

/// One eclipse, planet event or supermoon.
public struct AstroEvent: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Sendable {
        case lunarEclipse, solarEclipse, opposition, conjunction, elongation, supermoon
    }

    /// When in the day to look.
    public enum Sky: String, Codable, Sendable { case morning, evening, night, day }

    public let id: String
    /// Stored as text so a calendar with kinds this version does not know still decodes.
    let kindName: String
    public let title: String
    /// The moment of the event: greatest eclipse, opposition, closest approach, full moon.
    public let peak: Date
    public let sky: Sky
    /// "sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn".
    public let bodies: [String]
    public let detail: String
    public let tip: String
    /// Eclipses only: the fraction of the Sun's diameter covered, or the Moon's umbral magnitude
    /// (negative for a penumbral eclipse, above 1 for a total one).
    public let magnitude: Double?

    public var kind: Kind? { Kind(rawValue: kindName) }

    enum CodingKeys: String, CodingKey {
        case id, kindName = "kind", title, peak, sky, bodies, detail, tip, magnitude
    }
}

/// How lit the Moon is at `date`, from 0 (new) to 100 (full). A mean synodic month from a known new
/// moon is good to a few percent, enough to say whether moonlight will wash out faint meteors.
public enum Moon {
    static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440) // 2000-01-06 18:14 UT
    static let synodicDays = 29.530588853

    public static func illumination(at date: Date) -> Int {
        Int((50 * (1 - cos(2 * .pi * phase(at: date)))).rounded())
    }

    /// Where in its cycle the Moon is: 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter.
    public static func phase(at date: Date) -> Double {
        let days = date.timeIntervalSince(referenceNewMoon) / 86_400
        let age = days.truncatingRemainder(dividingBy: synodicDays)
        return (age < 0 ? age + synodicDays : age) / synodicDays
    }
}
