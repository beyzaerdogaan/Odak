import Foundation

// MARK: - Sounds

public enum SoundID: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case rain, forest, waves, fire, brownNoise, winterNight, library, summerNight, stream, distantStorm
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rain: "Yağmur"
        case .forest: "Orman"
        case .waves: "Dalga"
        case .fire: "Şömine"
        case .brownNoise: "Kahverengi gürültü"
        case .winterNight: "Kış gecesi"
        case .library: "Kütüphane"
        case .summerNight: "Yaz gecesi"
        case .stream: "Dere"
        case .distantStorm: "Uzak fırtına"
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
            "Açılma koşulu: \(Catalog.constellation(cid)?.name ?? cid) tamamlandıktan sonra \(minutes) dk'lık oturum"
        case let .totalHours(h): "Açılma koşulu: toplam \(h) saat odak"
        case let .completedSessions(n): "Açılma koşulu: \(n) tamamlanmış oturum"
        case let .constellation(cid): "Açılma koşulu: \(Catalog.constellation(cid)?.name ?? cid) takımyıldızını tamamla"
        }
    }
}

public enum DeepSky {
    /// Messier catalogue size; the first release ships a handful of objects.
    public static let catalogueSize = 110

    public static let objects: [DeepSkyObject] = [
        DeepSkyObject(id: "m42", name: "Avcı Bulutsusu", designation: "M42",
                      about: ["Yeni yıldızların doğduğu dev bir gaz ve toz bulutu. Avcı'nın Kemeri'nin hemen altında, “kılıç” bölgesinde.",
                              "Karanlık bir gecede çıplak gözle bulanık bir leke gibi görünür. Dürbünle çok daha belirgindir."],
                      requirement: .sessionAfter(constellation: "orion", minutes: 90), light: 300, theme: .nebula),
        DeepSkyObject(id: "m45", name: "Ülker", designation: "M45",
                      about: ["Yedi Kız Kardeş olarak da bilinen genç ve sıcak yıldızlardan oluşan bir küme.",
                              "Çıplak gözle altı ya da yedi yıldızı seçilir, dürbünle onlarcası."],
                      requirement: .constellation("taurus"), light: 250, theme: nil),
        DeepSkyObject(id: "m13", name: "Herkül Kümesi", designation: "M13",
                      about: ["Yüz binlerce yıldızın top gibi toplandığı bir küresel küme.",
                              "Karanlık bir gökyüzünde dürbünle bulanık bir yıldız gibi görünür."],
                      requirement: .completedSessions(50), light: 250, theme: nil),
        DeepSkyObject(id: "m31", name: "Andromeda Galaksisi", designation: "M31",
                      about: ["Samanyolu'na en yakın büyük sarmal galaksi.",
                              "Işığının yola çıkması yaklaşık 2,5 milyon yıl önceydi."],
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
        Planet(id: "moon", name: "Ay", hours: 5), Planet(id: "mercury", name: "Merkür", hours: 10),
        Planet(id: "venus", name: "Venüs", hours: 25), Planet(id: "mars", name: "Mars", hours: 50),
        Planet(id: "jupiter", name: "Jüpiter", hours: 100), Planet(id: "saturn", name: "Satürn", hours: 250),
        Planet(id: "uranus", name: "Uranüs", hours: 500), Planet(id: "neptune", name: "Neptün", hours: 1000),
    ]
}

// MARK: - Işık yolculuğu (layer 5)

public struct JourneyStop: Hashable, Identifiable, Sendable {
    public enum Reward: Hashable, Sendable {
        case badge(Badge), light(Int), sound(SoundID), theme(SkyTheme)
    }
    public var id: String { name }
    public let name: String
    /// Distance from the Sun in light-years; must be checked against an astronomy source before release.
    public let lightYears: Double
    public let story: String
    public let rewardText: String
    public let reward: Reward
}

public enum Journey {
    /// One focus hour carries the traveller one light-year.
    public static let lightYearsPerHour = 1.0

    public static let stops: [JourneyStop] = [
        JourneyStop(name: "Alfa Centauri", lightYears: 4.4, story: "Güneş'e en yakın yıldız sistemi. Üç yıldızdan biri, Proxima, en yakın komşumuz.",
                    rewardText: "Üçlü yıldız sisteminin hikâyesi, Proxima rozeti", reward: .badge(.proxima)),
        JourneyStop(name: "Sirius", lightYears: 8.6, story: "Gece gökyüzünün en parlak yıldızı, yanında sönük bir beyaz cüce eşi var.",
                    rewardText: "Gecenin en parlak yıldızı, +300 Işık", reward: .light(300)),
        JourneyStop(name: "Vega", lightYears: 25, story: "Lir'in kalbi. Binlerce yıl sonra kutup yıldızı olacak.",
                    rewardText: "Lir'in kalbi, yeni bir ses paketi", reward: .sound(.library)),
        JourneyStop(name: "TRAPPIST-1", lightYears: 41, story: "Yedi gezegenli küçük bir kırmızı cüce sistemi.",
                    rewardText: "Yedi gezegenli sistem, “Kırmızı cüce” gök teması", reward: .theme(.redDwarf)),
        JourneyStop(name: "Ülker", lightYears: 444, story: "Yedi Kız Kardeş kümesi. Buradan Güneş artık sönük bir nokta.",
                    rewardText: "Yedi Kız Kardeş kümesi, özel rozet", reward: .badge(.pleiades)),
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
    /// Chance a completed session during the shower catches a shooting star (×2 Işık).
    public static let shootingStarChance = 0.25

    /// The calendar's window under way at `date`, or else its next one. Nil when the calendar does
    /// not cover `date` or has no later window for this shower; callers then use the fixed table.
    public func window(around date: Date, calendar: Calendar = .current) -> MeteorCalendar.Window? {
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
        let night = Self.peakNight(of: w.peak, calendar: calendar)
        guard let next = calendar.date(byAdding: .day, value: 1, to: night) else { return approxPeakText }
        let a = calendar.dateComponents([.month, .day], from: night), b = calendar.dateComponents([.month, .day], from: next)
        let months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
        let ma = months[(a.month ?? 1) - 1], mb = months[(b.month ?? 1) - 1]
        let span = a.month == b.month ? "\(a.day ?? 1)–\(b.day ?? 1) \(mb)" : "\(a.day ?? 1) \(ma)–\(b.day ?? 1) \(mb)"
        return "\(span) gecesi"
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
    nonisolated(unsafe) private static var current: MeteorCalendar? = MeteorCalendar.bundled

    /// The dated IMO calendar in use: the bundled copy, or a newer one adopted at run time.
    public static var calendar: MeteorCalendar? {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    /// Switches to `candidate` when it is newer than the calendar in use. Returns whether it did.
    @discardableResult
    public static func adopt(_ candidate: MeteorCalendar) -> Bool {
        lock.withLock {
            if let c = current, c.updated >= candidate.updated { return false }
            current = candidate
            return true
        }
    }

    public static let all: [MeteorShower] = [
        MeteorShower(id: "quadrantids", name: "Kuadrantidler", start: (12, 28), end: (1, 12), peak: (1, 3), peakText: "Ocak başı",
                     radiant: "Çoban'ın kuzeyi", watchTip: "Zirve kısa sürer; gece yarısından sonra kuzeydoğuya bak."),
        MeteorShower(id: "lyrids", name: "Liridler", start: (4, 14), end: (4, 30), peak: (4, 22), peakText: "Nisan sonu",
                     radiant: "Lir", watchTip: "Vega'nın yakınından geliyor gibi görünürler. En iyi saat şafaktan önce."),
        MeteorShower(id: "perseids", name: "Perseidler", start: (7, 17), end: (8, 24), peak: (8, 12), peakText: "Ağustos ortası",
                     radiant: "Perseus", watchTip: "Yazın en bereketli yağmuru. Gece yarısından sonra kuzeydoğuya bak."),
        MeteorShower(id: "orionids", name: "Orionidler", start: (10, 2), end: (11, 7), peak: (10, 21), peakText: "21–22 Ekim civarı",
                     radiant: "Avcı", watchTip: "Meteorlar Avcı yönünden geliyor gibi görünür. En iyi zaman gece yarısından sonra, şehir ışıklarından uzakta."),
        MeteorShower(id: "leonids", name: "Leonidler", start: (11, 6), end: (11, 30), peak: (11, 17), peakText: "Kasım ortası",
                     radiant: "Aslan", watchTip: "Aslan yükseldikten sonra, gece yarısından şafağa kadar."),
        MeteorShower(id: "geminids", name: "Geminidler (İkizler)", start: (12, 4), end: (12, 20), peak: (12, 13), peakText: "Aralık ortası",
                     radiant: "İkizler", watchTip: "Akşamdan itibaren izlenebilir, en iyisi gece yarısı civarı."),
    ]

    public static func active(on date: Date, calendar: Calendar = .current) -> MeteorShower? {
        all.first { $0.isActive(on: date, calendar: calendar) }
    }

    public static func upcoming(after date: Date, count: Int = 3, calendar: Calendar = .current) -> [MeteorShower] {
        all.filter { !$0.isActive(on: date, calendar: calendar) }
            .sorted { $0.nextStart(after: date, calendar: calendar) < $1.nextStart(after: date, calendar: calendar) }
            .prefix(count).map { $0 }
    }
}

// MARK: - Badges

public enum Badge: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case firstLight, marathon90, streak7, nightOwl, proxima, pleiades, meteor
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .firstLight: "İlk ışık"
        case .marathon90: "90 dk maraton"
        case .streak7: "7 gün seri"
        case .nightOwl: "Gece kuşu"
        case .proxima: "Proxima"
        case .pleiades: "Yedi Kız Kardeş"
        case .meteor: "Meteor avcısı"
        }
    }

    public var detail: String {
        switch self {
        case .firstLight: "İlk oturumunu tamamla"
        case .marathon90: "90 dakikalık bir oturumu bitir"
        case .streak7: "7 gün üst üste odaklan"
        case .nightOwl: "22.00 ile 04.00 arasında bir oturum bitir"
        case .proxima: "Işık yolculuğunda Alfa Centauri'ye var"
        case .pleiades: "Işık yolculuğunda Ülker'e var"
        case .meteor: "Bir meteor yağmuru boyunca 10 oturum tamamla"
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
        case .night: "Gece"
        case .aurora: "Kutup ışığı göğü"
        case .twilight: "Alacakaranlık göğü"
        case .nebula: "Bulutsu göğü"
        case .redDwarf: "Kırmızı cüce göğü"
        }
    }
}

public enum Booster: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case telescope, shootingStar, cloud, brightTicket
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .telescope: "Teleskop"
        case .shootingStar: "Kayan yıldız"
        case .cloud: "Seri koruyucu bulut"
        case .brightTicket: "Parlak yıldız bileti"
        }
    }
    public var detail: String {
        switch self {
        case .telescope: "Sonraki yıldızı sen seç"
        case .shootingStar: "Sonraki oturumda Işık ×2"
        case .cloud: "En fazla 3 tane taşıyabilirsin"
        case .brightTicket: "Bir parlak yıldızı 45 dk'da düşür"
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
