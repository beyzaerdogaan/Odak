import Foundation

public struct FocusRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var task: String
    public var start: Date
    public var end: Date
    public var plannedMinutes: Int
    public var focusedMinutes: Int
    public var completed: Bool
    public var strict: Bool
    public var lookedAway: Bool
    public var starID: String?
    public var light: Int

    public init(id: UUID = UUID(), task: String, start: Date, end: Date, plannedMinutes: Int, focusedMinutes: Int,
                completed: Bool, strict: Bool, lookedAway: Bool, starID: String? = nil, light: Int = 0) {
        self.id = id; self.task = task; self.start = start; self.end = end
        self.plannedMinutes = plannedMinutes; self.focusedMinutes = focusedMinutes
        self.completed = completed; self.strict = strict; self.lookedAway = lookedAway
        self.starID = starID; self.light = light
    }
}

/// "Kendine söz": a real-life reward the user promises themselves.
public struct SelfPromise: Codable, Hashable, Identifiable, Sendable {
    public enum Goal: Codable, Hashable, Sendable {
        case focusHours(Int)
        case streakDays(Int)
        case constellation(String)
    }

    public var id: UUID
    public var title: String
    public var goal: Goal
    public var createdAt: Date
    /// Focus minutes already banked when the promise was made; hour goals count from here.
    public var baselineMinutes: Int
    public var celebratedAt: Date?

    public init(id: UUID = UUID(), title: String, goal: Goal, createdAt: Date, baselineMinutes: Int) {
        self.id = id; self.title = title; self.goal = goal; self.createdAt = createdAt; self.baselineMinutes = baselineMinutes
    }

    public var goalText: String {
        switch goal {
        case let .focusHours(h): "Hedef: toplam \(h) saat odak"
        case let .streakDays(d): "Hedef: \(d) günlük seri"
        case let .constellation(id): "Hedef: \(Catalog.constellation(id)?.name ?? id) takımyıldızını tamamla"
        }
    }
}

public enum DialStyle: String, Codable, CaseIterable, Hashable, Sendable {
    case classic, analog, meteor
}

/// Everything the user has earned. Persisted as JSON; every field decodes with a default so
/// later releases can add fields without losing anyone's sky.
public struct SkyProgress: Codable, Hashable, Sendable {
    public var light = 0
    public var litStars: [String: Date] = [:]
    public var openConstellations: [String] = Array(Catalog.constellations.prefix(3).map(\.id))
    public var completedConstellations: [String] = []
    public var records: [FocusRecord] = []
    /// Completed sessions in a row that brought no star (only bright ones were left); 4 triggers the guarantee.
    public var dryStreak = 0
    public var boosters: [String: Int] = [Booster.cloud.rawValue: 2]
    public var armedShootingStar = false
    public var armedBrightTicket = false
    public var telescopeTarget: String?
    public var ownedSounds: Set<SoundID> = Set(SoundID.allCases.filter(\.isFree))
    public var ownedThemes: Set<SkyTheme> = [.night]
    public var selectedTheme: SkyTheme = .night
    public var ownedDials: Set<DialStyle> = [.classic]
    public var selectedDial: DialStyle = .classic
    public var ownsAppIcon = false
    public var badges: [String: Date] = [:]
    public var promises: [SelfPromise] = []
    public var deepSky: [String: Date] = [:]
    /// Days (yyyy-MM-dd) a cloud kept the streak alive.
    public var coveredDays: Set<String> = []
    public var meteorProgress: [String: Int] = [:]
    public var journeyStartMinutes: Int?
    public var reachedStops: [String] = []

    public init() {}

    public func count(_ booster: Booster) -> Int { boosters[booster.rawValue] ?? 0 }
    public mutating func add(_ booster: Booster, _ n: Int = 1) {
        boosters[booster.rawValue] = min(booster.maxCount, max(0, count(booster) + n))
    }

    public func hasBadge(_ b: Badge) -> Bool { badges[b.rawValue] != nil }
    public func isLit(_ starID: String) -> Bool { litStars[starID] != nil }
    public func isComplete(_ constellationID: String) -> Bool { completedConstellations.contains(constellationID) }

    public func litCount(in c: Constellation) -> Int { c.stars.filter { isLit($0.id) }.count }

    public var totalFocusedMinutes: Int { records.reduce(0) { $0 + $1.focusedMinutes } }
    public var completedSessions: Int { records.filter(\.completed).count }
    public var starCount: Int { litStars.count }

    public var unlockedPlanets: [Planet] { Planets.all.filter { totalFocusedMinutes >= $0.hours * 60 } }
    public var nextPlanet: Planet? { Planets.all.first { totalFocusedMinutes < $0.hours * 60 } }

    public var journeyUnlocked: Bool { journeyStartMinutes != nil }
    public var lightYearsTravelled: Double {
        guard let start = journeyStartMinutes else { return 0 }
        return Double(totalFocusedMinutes - start) / 60 * Journey.lightYearsPerHour
    }
    public var nextStop: JourneyStop? { Journey.stops.first { !reachedStops.contains($0.name) } }

    // MARK: Codable with defaults

    private enum K: String, CodingKey {
        case light, litStars, openConstellations, completedConstellations, records, dryStreak, boosters,
             armedShootingStar, armedBrightTicket, telescopeTarget, ownedSounds, ownedThemes, selectedTheme,
             ownedDials, selectedDial, ownsAppIcon, badges, promises, deepSky, coveredDays, meteorProgress,
             journeyStartMinutes, reachedStops
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        let d = SkyProgress()
        func v<T: Decodable>(_ k: K, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? fallback }
        light = v(.light, d.light)
        litStars = v(.litStars, d.litStars)
        openConstellations = v(.openConstellations, d.openConstellations)
        completedConstellations = v(.completedConstellations, d.completedConstellations)
        records = v(.records, d.records)
        dryStreak = v(.dryStreak, d.dryStreak)
        boosters = v(.boosters, d.boosters)
        armedShootingStar = v(.armedShootingStar, d.armedShootingStar)
        armedBrightTicket = v(.armedBrightTicket, d.armedBrightTicket)
        telescopeTarget = v(.telescopeTarget, d.telescopeTarget)
        // Read leniently so a sound that was later retired (e.g. "cafe") doesn't drop the others.
        ownedSounds = (try? c.decodeIfPresent([String].self, forKey: .ownedSounds))
            .map { Set($0.compactMap(SoundID.init(rawValue:))).union(d.ownedSounds) } ?? d.ownedSounds
        ownedThemes = v(.ownedThemes, d.ownedThemes)
        selectedTheme = v(.selectedTheme, d.selectedTheme)
        ownedDials = v(.ownedDials, d.ownedDials)
        selectedDial = v(.selectedDial, d.selectedDial)
        ownsAppIcon = v(.ownsAppIcon, d.ownsAppIcon)
        badges = v(.badges, d.badges)
        promises = v(.promises, d.promises)
        deepSky = v(.deepSky, d.deepSky)
        coveredDays = v(.coveredDays, d.coveredDays)
        meteorProgress = v(.meteorProgress, d.meteorProgress)
        journeyStartMinutes = v(.journeyStartMinutes, d.journeyStartMinutes)
        reachedStops = v(.reachedStops, d.reachedStops)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(light, forKey: .light)
        try c.encode(litStars, forKey: .litStars)
        try c.encode(openConstellations, forKey: .openConstellations)
        try c.encode(completedConstellations, forKey: .completedConstellations)
        try c.encode(records, forKey: .records)
        try c.encode(dryStreak, forKey: .dryStreak)
        try c.encode(boosters, forKey: .boosters)
        try c.encode(armedShootingStar, forKey: .armedShootingStar)
        try c.encode(armedBrightTicket, forKey: .armedBrightTicket)
        try c.encodeIfPresent(telescopeTarget, forKey: .telescopeTarget)
        try c.encode(ownedSounds, forKey: .ownedSounds)
        try c.encode(ownedThemes, forKey: .ownedThemes)
        try c.encode(selectedTheme, forKey: .selectedTheme)
        try c.encode(ownedDials, forKey: .ownedDials)
        try c.encode(selectedDial, forKey: .selectedDial)
        try c.encode(ownsAppIcon, forKey: .ownsAppIcon)
        try c.encode(badges, forKey: .badges)
        try c.encode(promises, forKey: .promises)
        try c.encode(deepSky, forKey: .deepSky)
        try c.encode(coveredDays, forKey: .coveredDays)
        try c.encode(meteorProgress, forKey: .meteorProgress)
        try c.encodeIfPresent(journeyStartMinutes, forKey: .journeyStartMinutes)
        try c.encode(reachedStops, forKey: .reachedStops)
    }
}
