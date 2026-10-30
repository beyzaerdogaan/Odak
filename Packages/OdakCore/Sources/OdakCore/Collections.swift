import Foundation

// MARK: - Sounds

public enum SoundID: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case rain, forest, waves, fire, brownNoise, winterNight, library, summerNight, stream, distantStorm
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rain: loc("Yağmur")
        case .forest: loc("Orman")
        case .waves: loc("Dalga")
        case .fire: loc("Şömine")
        case .brownNoise: loc("Kahverengi gürültü")
        case .winterNight: loc("Kış gecesi")
        case .library: loc("Kütüphane")
        case .summerNight: loc("Yaz gecesi")
        case .stream: loc("Dere")
        case .distantStorm: loc("Uzak fırtına")
        }
    }

    /// Free from the start. The rest come from the shop, a constellation, or Zenit.
    public var isFree: Bool { [.rain, .forest, .waves, .fire, .brownNoise].contains(self) }
}

// MARK: - Deep sky objects (layer 3)

public struct DeepSkyObject: Hashable, Identifiable, Sendable {
    public enum Requirement: Hashable, Sendable {
        /// Complete a constellation, then finish one session at least this long.
        case sessionAfter(constellation: String, minutes: Int)
        case totalHours(Int)
        case completedSessions(Int)
        case constellation(String)
    }

    public let id: String
    public let name: String
    public let designation: String
    public let about: [String]
    public let requirement: Requirement
    public let light: Int
    public let theme: SkyTheme?

    public var requirementText: String {
        switch requirement {
        case let .sessionAfter(cid, minutes):
            loc("\(Catalog.constellation(cid)?.name ?? cid) takımyıldızını tamamladıktan sonra \(minutes) dakikalık bir oturumla açılır.")
        case let .totalHours(h): loc("Toplam \(h) saat odaklanınca açılır.")
        case let .completedSessions(n): loc("\(n) oturum tamamlayınca açılır.")
        case let .constellation(cid): loc("\(Catalog.constellation(cid)?.name ?? cid) takımyıldızını tamamlayınca açılır.")
        }
    }
}

public enum DeepSky {
    /// Messier catalogue size; the first release ships a handful of objects.
    public static let catalogueSize = 110

    public static let objects: [DeepSkyObject] = [
        DeepSkyObject(id: "m42", name: loc("Avcı Bulutsusu"), designation: "M42",
                      about: [loc("Yeni yıldızların doğduğu dev bir gaz ve toz bulutudur. Avcı'nın Kemeri'nin hemen altında, “kılıç” denen bölgede yer alır."),
                              loc("Karanlık bir gecede çıplak gözle bulanık bir leke gibi görünür, dürbünle bakınca çok daha belirginleşir.")],
                      requirement: .sessionAfter(constellation: "orion", minutes: 90), light: 300, theme: .nebula),
        DeepSkyObject(id: "m45", name: loc("Ülker"), designation: "M45",
                      about: [loc("Yedi Kız Kardeş olarak da bilinen, genç ve sıcak yıldızlardan oluşan bir kümedir."),
                              loc("Çıplak gözle altı ya da yedi yıldızı seçilebilir, dürbünle bakınca onlarcası görünür.")],
                      requirement: .constellation("taurus"), light: 250, theme: nil),
        DeepSkyObject(id: "m13", name: loc("Herkül Kümesi"), designation: "M13",
                      about: [loc("Yüz binlerce yıldızın top gibi bir araya toplandığı küresel bir kümedir."),
                              loc("Karanlık bir gökyüzünde dürbünle bulanık bir yıldız gibi görünür.")],
                      requirement: .completedSessions(50), light: 250, theme: nil),
        DeepSkyObject(id: "m31", name: loc("Andromeda Galaksisi"), designation: "M31",
                      about: [loc("Samanyolu'na en yakın büyük sarmal galaksidir."),
                              loc("Bugün gördüğümüz ışığı yaklaşık 2,5 milyon yıl önce yola çıktı.")],
                      requirement: .totalHours(100), light: 500, theme: nil),
    ]
}

// MARK: - Planets (layer 4)

public struct Planet: Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let hours: Int
}

public enum Planets {
    public static let all: [Planet] = [
        Planet(id: "moon", name: loc("Ay"), hours: 5), Planet(id: "mercury", name: loc("Merkür"), hours: 10),
        Planet(id: "venus", name: loc("Venüs"), hours: 25), Planet(id: "mars", name: loc("Mars"), hours: 50),
        Planet(id: "jupiter", name: loc("Jüpiter"), hours: 100), Planet(id: "saturn", name: loc("Satürn"), hours: 250),
        Planet(id: "uranus", name: loc("Uranüs"), hours: 500), Planet(id: "neptune", name: loc("Neptün"), hours: 1000),
    ]
}

// MARK: - Işık yolculuğu (layer 5)

public struct JourneyStop: Hashable, Identifiable, Sendable {
    public enum Reward: Hashable, Sendable {
        case badge(Badge), light(Int), sound(SoundID), theme(SkyTheme)
    }
    /// The stop's Turkish name, kept in `SkyProgress.reachedStops`.
    public let id: String
    public let name: String
    /// Distance from the Sun in light-years; must be checked against an astronomy source before release.
    public let lightYears: Double
    public let story: String
    public let rewardText: String
    public let reward: Reward

    init(id: String, name: String, lightYears: Double, story: String, rewardText: String, reward: Reward) {
        self.id = id; self.name = name; self.lightYears = lightYears; self.story = story
        self.rewardText = rewardText; self.reward = reward
    }
}

public enum Journey {
    /// One focus hour carries the traveller one light-year.
    public static let lightYearsPerHour = 1.0

    public static let stops: [JourneyStop] = [
        JourneyStop(id: "Alfa Centauri", name: loc("Alfa Centauri"), lightYears: 4.4, story: loc("Güneş'e en yakın yıldız sistemidir. Üç yıldızından biri olan Proxima, bize en yakın yıldızdır."),
                    rewardText: loc("Proxima rozeti ve üçlü yıldız sisteminin hikâyesi"), reward: .badge(.proxima)),
        JourneyStop(id: "Sirius", name: loc("Sirius"), lightYears: 8.6, story: loc("Gece gökyüzünün en parlak yıldızıdır ve yanında sönük bir beyaz cüce eşi vardır."),
                    rewardText: loc("300 Işık"), reward: .light(300)),
        JourneyStop(id: "Vega", name: loc("Vega"), lightYears: 25, story: loc("Lir takımyıldızının kalbidir ve binlerce yıl sonra kutup yıldızı olacak."),
                    rewardText: loc("Yeni bir ses paketi"), reward: .sound(.library)),
        JourneyStop(id: "TRAPPIST-1", name: loc("TRAPPIST-1"), lightYears: 41, story: loc("Yedi gezegeni olan küçük bir kırmızı cüce sistemidir."),
                    rewardText: loc("“Kırmızı cüce” gök teması"), reward: .theme(.redDwarf)),
        JourneyStop(id: "Ülker", name: loc("Ülker"), lightYears: 444, story: loc("Yedi Kız Kardeş olarak bilinen bir yıldız kümesidir. Buradan bakınca Güneş artık sönük bir nokta gibi görünür."),
                    rewardText: loc("Yedi Kız Kardeş rozeti"), reward: .badge(.pleiades)),
    ]
}

// MARK: - Meteor showers (always on)

public struct MeteorShower: Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    /// Active window and peak as (month, day). Only a fallback: where `MeteorShowers.calendar`
    /// (the IMO calendar) covers a date, its dated windows are used instead.
    public let start: (Int, Int)
    public let end: (Int, Int)
    public let peak: (Int, Int)
    /// Peak wording for dates the calendar does not cover.
    public let approxPeakText: String
    public let radiant: String
    public let watchTip: String

    public init(id: String, name: String, start: (Int, Int), end: (Int, Int), peak: (Int, Int), peakText: String,
                radiant: String, watchTip: String) {
        self.id = id; self.name = name; self.start = start; self.end = end; self.peak = peak
        self.approxPeakText = peakText; self.radiant = radiant; self.watchTip = watchTip
    }

    public static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }

    /// Sessions needed during the shower for its badge.
    public static let sessionGoal = 10
    /// Chance a completed session on the shower's peak days catches a shooting star (×2 Işık).
    public static let shootingStarChance = 0.25

    /// The calendar's window under way at `date`, or else its next one. Nil when the calendar does
    /// not cover `date` or has no later window for this shower; callers then use the fixed table.
    public func window(around date: Date, calendar: Calendar = .current) -> SkyCalendar.Window? {
        guard let c = MeteorShowers.calendar, c.covers(date, calendar: calendar) else { return nil }
        return c.windows(of: id, calendar: calendar).first { date < $0.end }
    }

    public func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        if let c = MeteorShowers.calendar, c.covers(date, calendar: calendar) {
            return window(around: date, calendar: calendar)?.contains(date) ?? false
        }
        let c = calendar.dateComponents([.month, .day], from: date)
        let today = (c.month ?? 1) * 100 + (c.day ?? 1)
        let s = start.0 * 100 + start.1, e = end.0 * 100 + end.1
        return s <= e ? (today >= s && today <= e) : (today >= s || today <= e)
    }

    /// Whether `date` falls on the peak night's two days: the evening it starts and the morning after.
    /// Only then can a session catch a shooting star.
    public func isPeak(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isActive(on: date, calendar: calendar), let peak = peakDate(around: date, calendar: calendar) else { return false }
        let night = calendar.startOfDay(for: peak)
        let days = calendar.dateComponents([.day], from: night, to: calendar.startOfDay(for: date)).day ?? -1
        return days == 0 || days == 1
    }

    /// Key for per-year progress, using the year the shower started in.
    public func seasonKey(for date: Date, calendar: Calendar = .current) -> String {
        if let w = window(around: date, calendar: calendar), w.contains(date) {
            return "\(id)-\(calendar.component(.year, from: w.start))"
        }
        var year = calendar.component(.year, from: date)
        if start.0 > end.0, calendar.component(.month, from: date) <= end.0 { year -= 1 }
        return "\(id)-\(year)"
    }

    public func nextStart(after date: Date, calendar: Calendar = .current) -> Date {
        if let w = window(around: date, calendar: calendar), w.start > date { return w.start }
        let year = calendar.component(.year, from: date)
        for y in [year, year + 1] {
            if let d = calendar.date(from: DateComponents(year: y, month: start.0, day: start.1)), d > date { return d }
        }
        return date
    }

    /// 23:00 on the evening the peak night begins, for the reminder.
    public func peakDate(around date: Date, calendar: Calendar = .current) -> Date? {
        if let w = window(around: date, calendar: calendar) {
            let night = Self.peakNight(of: w.peak, calendar: calendar)
            return calendar.date(bySettingHour: 23, minute: 0, second: 0, of: night)
        }
        var year = calendar.component(.year, from: date)
        if start.0 > peak.0, calendar.component(.month, from: date) >= start.0 { year += 1 }
        return calendar.date(from: DateComponents(year: year, month: peak.0, day: peak.1, hour: 23))
    }

    /// "21–22 Ekim gecesi" from the calendar, else the approximate wording.
    public func peakText(around date: Date = Date(), calendar: Calendar = .current) -> String {
        guard let w = window(around: date, calendar: calendar) else { return approxPeakText }
        return Self.nightText(of: w.peak, calendar: calendar)
    }

    /// Month names in the app's language, January first.
    public static var monthNames: [String] { AppLanguage.monthNames }

    /// "21–22 Ekim gecesi" for the night that holds `peak`.
    public static func nightText(of peak: Date, calendar: Calendar) -> String {
        let night = peakNight(of: peak, calendar: calendar)
        let next = calendar.date(byAdding: .day, value: 1, to: night) ?? night
        let a = calendar.dateComponents([.month, .day], from: night), b = calendar.dateComponents([.month, .day], from: next)
        let span = AppLanguage.dayRange((a.day ?? 1, a.month ?? 1), (b.day ?? 1, b.month ?? 1))
        return loc("\(span) gecesi")
    }

    /// Every window of this shower that overlaps `from..<to`: the calendar's dated ones, and the fixed
    /// table's for the years the calendar does not cover (their peak is put at 23:00 on the table's day).
    public func windows(from: Date, to: Date, calendar: Calendar = .current) -> [SkyCalendar.Window] {
        let dated = MeteorShowers.calendar
        var all = dated?.windows(of: id, calendar: calendar) ?? []
        let first = calendar.component(.year, from: from), last = calendar.component(.year, from: to)
        for y in (first - 1)...last {
            guard let s = calendar.date(from: DateComponents(year: y, month: start.0, day: start.1)),
                  let lastDay = calendar.date(from: DateComponents(year: start.0 > end.0 ? y + 1 : y, month: end.0, day: end.1)),
                  let e = calendar.date(byAdding: .day, value: 1, to: lastDay),
                  let p = calendar.date(from: DateComponents(year: start.0 > peak.0 ? y + 1 : y, month: peak.0, day: peak.1, hour: 23))
            else { continue }
            if dated?.covers(s, calendar: calendar) == true { continue }
            all.append(SkyCalendar.Window(start: s, end: e, peak: p, zhr: nil))
        }
        return all.filter { $0.end > from && $0.start < to }.sorted { $0.start < $1.start }
    }

    /// Moon illumination (0–100) at the peak, so the event can warn when moonlight hides faint meteors.
    public func moonAtPeak(around date: Date = Date(), calendar: Calendar = .current) -> Int? {
        if let w = window(around: date, calendar: calendar) { return Moon.illumination(at: w.peak) }
        return peakDate(around: date, calendar: calendar).map(Moon.illumination(at:))
    }

    /// The local day whose evening starts the night of `peak`: a peak before noon belongs to the night before.
    static func peakNight(of peak: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: peak)
        guard calendar.component(.hour, from: peak) < 12 else { return day }
        return calendar.date(byAdding: .day, value: -1, to: day) ?? day
    }
}

public enum MeteorShowers {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var current: SkyCalendar? = SkyCalendar.bundled

    /// The dated IMO calendar in use: the bundled copy, or a newer one adopted at run time.
    public static var calendar: SkyCalendar? {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    /// Switches to `candidate` when it is newer than the calendar in use. Returns whether it did.
    @discardableResult
    public static func adopt(_ candidate: SkyCalendar) -> Bool {
        lock.withLock {
            if let c = current, c.updated >= candidate.updated { return false }
            current = candidate
            return true
        }
    }

    public static let all: [MeteorShower] = [
        MeteorShower(id: "quadrantids", name: loc("Kuadrantidler"), start: (12, 28), end: (1, 12), peak: (1, 3), peakText: loc("Ocak başı"),
                     radiant: loc("Çoban'ın kuzeyi"), watchTip: loc("Zirvesi kısa sürer, bu yüzden gece yarısından sonra kuzeydoğuya bak.")),
        MeteorShower(id: "lyrids", name: loc("Liridler"), start: (4, 14), end: (4, 30), peak: (4, 22), peakText: loc("Nisan sonu"),
                     radiant: loc("Lir"), watchTip: loc("Meteorlar Vega'nın yakınından geliyor gibi görünür. En iyi izleme zamanı şafaktan hemen öncesidir.")),
        MeteorShower(id: "perseids", name: loc("Perseidler"), start: (7, 17), end: (8, 24), peak: (8, 12), peakText: loc("Ağustos ortası"),
                     radiant: loc("Perseus"), watchTip: loc("Yazın en bereketli meteor yağmurudur. Gece yarısından sonra kuzeydoğuya bak.")),
        MeteorShower(id: "orionids", name: loc("Orionidler"), start: (10, 2), end: (11, 7), peak: (10, 21), peakText: loc("21–22 Ekim civarı"),
                     radiant: loc("Avcı"), watchTip: loc("Meteorlar Avcı yönünden geliyor gibi görünür. En iyisi gece yarısından sonra, şehir ışıklarından uzak bir yerden izlemektir.")),
        MeteorShower(id: "leonids", name: loc("Leonidler"), start: (11, 6), end: (11, 30), peak: (11, 17), peakText: loc("Kasım ortası"),
                     radiant: loc("Aslan"), watchTip: loc("Aslan takımyıldızı yükseldikten sonra, gece yarısından şafağa kadar izleyebilirsin.")),
        MeteorShower(id: "geminids", name: loc("Geminidler (İkizler)"), start: (12, 4), end: (12, 20), peak: (12, 13), peakText: loc("Aralık ortası"),
                     radiant: loc("İkizler"), watchTip: loc("Akşamdan itibaren izlenebilir ama en iyi zaman gece yarısı civarıdır.")),
    ]

    /// The sky calendar: every shower window and astronomical event overlapping `from..<to`, in date order.
    public static func schedule(from: Date, to: Date, calendar: Calendar = .current) -> [SkyEvent] {
        let showers = all.flatMap { shower in
            shower.windows(from: from, to: to, calendar: calendar).map { w in
                SkyEvent(source: .shower(shower), start: w.start, end: w.end, peak: w.peak,
                         day: MeteorShower.peakNight(of: w.peak, calendar: calendar), zhr: w.zhr)
            }
        }
        let astro = (MeteorShowers.calendar?.astroEvents ?? []).map { SkyEvent(astro: $0, calendar: calendar) }
            .filter { $0.end > from && $0.start < to }
        return (showers + astro).sorted { $0.day < $1.day }
    }

    /// The astronomical event with this id, from the calendar in use.
    public static func astroEvent(id: String) -> AstroEvent? {
        calendar?.astroEvents.first { $0.id == id }
    }

    public static func active(on date: Date, calendar: Calendar = .current) -> MeteorShower? {
        all.first { $0.isActive(on: date, calendar: calendar) }
    }

    public static func upcoming(after date: Date, count: Int = 3, calendar: Calendar = .current) -> [MeteorShower] {
        all.filter { !$0.isActive(on: date, calendar: calendar) }
            .sorted { $0.nextStart(after: date, calendar: calendar) < $1.nextStart(after: date, calendar: calendar) }
            .prefix(count).map { $0 }
    }
}

/// One entry on the sky calendar: a dated meteor shower window, or an eclipse, planet event or supermoon.
public struct SkyEvent: Identifiable, Hashable, Sendable {
    public enum Source: Hashable, Sendable {
        case shower(MeteorShower)
        case astro(AstroEvent)
    }

    public let source: Source
    /// When it is on: a shower's active days, or the local day of a one-night event (end exclusive).
    public let start: Date
    public let end: Date
    public let peak: Date
    /// Start of the local day it is listed under: a shower's peak evening, else the day of `peak`.
    public let day: Date
    /// Meteors per hour under a perfect dark sky, when the calendar gives it.
    public let zhr: Int?

    init(source: Source, start: Date, end: Date, peak: Date, day: Date, zhr: Int?) {
        self.source = source; self.start = start; self.end = end; self.peak = peak; self.day = day; self.zhr = zhr
    }

    /// A one-night event, on the local day of its peak.
    public init(astro a: AstroEvent, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: a.peak)
        self.init(source: .astro(a), start: day, end: calendar.date(byAdding: .day, value: 1, to: day) ?? day,
                  peak: a.peak, day: day, zhr: nil)
    }

    public var shower: MeteorShower? { if case let .shower(s) = source { s } else { nil } }
    public var astro: AstroEvent? { if case let .astro(a) = source { a } else { nil } }

    public var id: String {
        switch source {
        case let .shower(s): "\(s.id)-\(Int(start.timeIntervalSince1970))"
        case let .astro(a): a.id
        }
    }

    public var title: String {
        switch source {
        case let .shower(s): loc("\(s.name) meteor yağmuru")
        case let .astro(a): a.title
        }
    }

    public var moon: Int { Moon.illumination(at: peak) }
    public func contains(_ date: Date) -> Bool { start <= date && date < end }

    /// "21–22 Ekim gecesi" for a shower; "21 Şubat, 02:13" for an eclipse; the day for the rest.
    public func whenText(calendar: Calendar = .current) -> String {
        switch source {
        case .shower: return MeteorShower.nightText(of: peak, calendar: calendar)
        case let .astro(a):
            let c = calendar.dateComponents([.month, .day, .hour, .minute], from: peak)
            let day = AppLanguage.dayMonth(day: c.day ?? 1, month: c.month ?? 1)
            switch a.kind {
            case .lunarEclipse?, .solarEclipse?: return day + String(format: ", %02d:%02d", c.hour ?? 0, c.minute ?? 0)
            default:
                switch a.sky {
                case .morning: return loc("\(day), şafaktan önce")
                case .evening: return loc("\(day), gün batımından sonra")
                case .night: return loc("\(day), gece")
                case .day: return day
                }
            }
        }
    }

    /// When to remind: 23:00 on a shower's peak evening, half an hour before an eclipse, and for the
    /// rest a time that fits when it is seen.
    public func reminderDate(calendar: Calendar = .current) -> Date? {
        switch source {
        case .shower: return calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day)
        case let .astro(a):
            if a.kind == .lunarEclipse || a.kind == .solarEclipse { return peak.addingTimeInterval(-30 * 60) }
            let (h, m) = switch a.sky {
            case .morning: (5, 30)
            case .evening: (18, 30)
            case .night: (21, 0)
            case .day: (9, 0)
            }
            return calendar.date(bySettingHour: h, minute: m, second: 0, of: day)
        }
    }
}

// MARK: - Badges

public enum Badge: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case firstLight, marathon90, streak7, nightOwl, proxima, pleiades, meteor
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .firstLight: loc("İlk ışık")
        case .marathon90: loc("90 dk maraton")
        case .streak7: loc("7 gün seri")
        case .nightOwl: loc("Gece kuşu")
        case .proxima: loc("Proxima")
        case .pleiades: loc("Yedi Kız Kardeş")
        case .meteor: loc("Meteor avcısı")
        }
    }

    public var detail: String {
        switch self {
        case .firstLight: loc("İlk oturumunu tamamla")
        case .marathon90: loc("90 dakikalık bir oturumu bitir")
        case .streak7: loc("7 gün üst üste odaklan")
        case .nightOwl: loc("22.00 ile 04.00 arasında bir oturum bitir")
        case .proxima: loc("Işık yolculuğunda Alfa Centauri'ye var")
        case .pleiades: loc("Işık yolculuğunda Ülker'e var")
        case .meteor: loc("Bir meteor yağmuru boyunca 10 oturum tamamla")
        }
    }

    /// Shown on the Gökyüzüm screen even before they are earned.
    public static let shelf: [Badge] = [.firstLight, .marathon90, .streak7, .nightOwl]
}

// MARK: - Shop

public enum SkyTheme: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case night, aurora, twilight, nebula, redDwarf
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .night: loc("Gece")
        case .aurora: loc("Kutup ışığı göğü")
        case .twilight: loc("Alacakaranlık göğü")
        case .nebula: loc("Bulutsu göğü")
        case .redDwarf: loc("Kırmızı cüce göğü")
        }
    }
}

public enum Booster: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case telescope, shootingStar, cloud, brightTicket
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .telescope: loc("Teleskop")
        case .shootingStar: loc("Kayan yıldız")
        case .cloud: loc("Seri koruyucu bulut")
        case .brightTicket: loc("Parlak yıldız bileti")
        }
    }
    public var detail: String {
        switch self {
        case .telescope: loc("Sonraki yıldızı sen seç")
        case .shootingStar: loc("Sonraki oturumda Işığın iki katına çıkar")
        case .cloud: loc("En fazla 3 tane taşıyabilirsin")
        case .brightTicket: loc("Bir parlak yıldızı 45 dakikalık bir oturumda düşürür")
        }
    }
    public var price: Int {
        switch self {
        case .telescope: 400
        case .shootingStar: 150
        case .cloud: 250
        case .brightTicket: 500
        }
    }
    public var maxCount: Int { self == .cloud ? 3 : 9 }
}

public enum ShopItem: Hashable, Sendable, Identifiable {
    case booster(Booster), sound(SoundID), theme(SkyTheme), analogDial, appIcon
    public var id: String {
        switch self {
        case let .booster(b): "booster.\(b.rawValue)"
        case let .sound(s): "sound.\(s.rawValue)"
        case let .theme(t): "theme.\(t.rawValue)"
        case .analogDial: "look.analog"
        case .appIcon: "look.icon"
        }
    }
    public var price: Int? {
        switch self {
        case let .booster(b): b.price
        case .sound(.library), .sound(.summerNight), .sound(.stream), .sound(.distantStorm): 300
        case .sound: nil
        case .theme(.aurora): 600
        case .theme(.twilight): 400
        case .theme: nil
        case .analogDial: 200
        case .appIcon: 150
        }
    }
}
