import Foundation

/// Deterministic random source so the star draw can be tested.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    public mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}

// MARK: - Işık

public struct LightLedger: Hashable, Sendable {
    public struct Line: Hashable, Sendable {
        public let label: String
        public let amount: Int
    }
    public var lines: [Line]
    public var total: Int { lines.reduce(0) { $0 + $1.amount } }
}

public enum LightRules {
    public static let noLookPercent = 20
    public static let streakStepPercent = 2
    public static let streakCapPercent = 20
    public static let strictExtraPercent = 50
    public static let constellationReward = 200

    /// Streak bonus grows 2% for every day after the first, up to 20%.
    public static func streakPercent(days: Int) -> Int { min(streakCapPercent, max(0, days - 1) * streakStepPercent) }

    /// Integer percentage, rounded half up, so 4.5 Işık is always 5.
    static func percent(_ value: Int, _ pct: Int) -> Int { (value * pct + 50) / 100 }

    public static func ledger(minutes: Int, noLook: Bool, streakDays: Int, strict: Bool, doubled: Bool, doubledBy: String = loc("Kayan yıldız")) -> LightLedger {
        var lines = [LightLedger.Line(label: loc("Odak süresi, \(minutes) dk"), amount: minutes)]
        if noLook { lines.append(.init(label: loc("Hiç telefona bakmadın, %\(noLookPercent)"), amount: percent(minutes, noLookPercent))) }
        let pct = streakPercent(days: streakDays)
        if pct > 0 { lines.append(.init(label: loc("Seri bonusu, \(streakDays). gün %\(pct)"), amount: percent(minutes, pct))) }
        var subtotal = lines.reduce(0) { $0 + $1.amount }
        if strict {
            let extra = percent(subtotal, strictExtraPercent)
            lines.append(.init(label: loc("Katı mod, ×1,5"), amount: extra))
            subtotal += extra
        }
        if doubled { lines.append(.init(label: loc("\(doubledBy), ×2"), amount: subtotal)) }
        return LightLedger(lines: lines)
    }
}

// MARK: - Streak

public enum Days {
    public static func key(_ date: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

extension SkyProgress {
    func activeDays(_ cal: Calendar) -> Set<String> {
        Set(records.filter(\.completed).map { Days.key($0.end, cal) }).union(coveredDays)
    }

    /// Consecutive days with a completed session (or a cloud), counting back from today, or from
    /// yesterday when today has nothing yet.
    public func streak(on now: Date, calendar cal: Calendar = .current) -> Int {
        let days = activeDays(cal)
        var day = cal.startOfDay(for: now)
        if !days.contains(Days.key(day, cal)) {
            guard let y = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var n = 0
        while days.contains(Days.key(day, cal)) {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    /// Spends clouds on missed days between the last active day and today, if there are enough.
    /// Returns how many days were covered.
    @discardableResult
    public mutating func reconcileClouds(now: Date, calendar cal: Calendar = .current) -> Int {
        let days = activeDays(cal)
        guard !days.isEmpty else { return 0 }
        let today = cal.startOfDay(for: now)
        var missing: [String] = []
        var day = cal.date(byAdding: .day, value: -1, to: today)!
        while !days.contains(Days.key(day, cal)) {
            missing.append(Days.key(day, cal))
            guard missing.count <= Booster.cloud.maxCount, let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        guard !missing.isEmpty, missing.count <= count(.cloud) else { return 0 }
        coveredDays.formUnion(missing)
        add(.cloud, -missing.count)
        return missing.count
    }
}

// MARK: - Star draw

public enum StarDraw {
    public static let brightMinutes = 60
    public static let ticketMinutes = 45
    public static let pityAfter = 4

    public static func brightAllowed(minutes: Int, strict: Bool, ticket: Bool) -> Bool {
        minutes >= brightMinutes || strict || (ticket && minutes >= ticketMinutes)
    }

    /// Picks an unlit star from one of the open constellations. Constellations closer to completion
    /// are a little likelier, so every session moves the user toward a finish. Returns nil only when
    /// every remaining star is bright and this session cannot earn one.
    public static func pick<R: RandomNumberGenerator>(progress p: SkyProgress, minutes: Int, strict: Bool, rng: inout R) -> String? {
        if let t = p.telescopeTarget, !p.isLit(t), let c = Catalog.constellation(containing: t), p.openConstellations.contains(c.id) {
            return t
        }
        let bright = brightAllowed(minutes: minutes, strict: strict, ticket: p.armedBrightTicket) || p.dryStreak >= pityAfter
        var pools: [(weight: Double, stars: [CatalogStar])] = []
        for id in p.openConstellations {
            guard let c = Catalog.constellation(id) else { continue }
            let stars = c.stars.filter { !p.isLit($0.id) && (bright || !$0.isBright) }
            guard !stars.isEmpty else { continue }
            let done = Double(p.litCount(in: c)) / Double(c.stars.count)
            pools.append((1 + 2 * done, stars))
        }
        guard !pools.isEmpty else { return nil }
        let total = pools.reduce(0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<total, using: &rng)
        for pool in pools {
            if roll < pool.weight { return pool.stars.randomElement(using: &rng)?.id }
            roll -= pool.weight
        }
        return pools.last?.stars.randomElement(using: &rng)?.id
    }
}

// MARK: - Session outcome

public struct SessionSummary: Hashable, Sendable {
    public var record: FocusRecord
    public var star: CatalogStar?
    public var constellation: Constellation?
    public var completedConstellation: Constellation?
    public var ledger: LightLedger
    public var bonusLight: Int
    public var newBadges: [Badge] = []
    public var newDeepSky: [DeepSkyObject] = []
    public var newPlanets: [Planet] = []
    public var reachedStops: [JourneyStop] = []
    public var journeyStarted = false
    public var meteorShower: MeteorShower?
    public var caughtShootingStar = false
    public var promisesKept: [SelfPromise] = []
    public var streak: Int
}

public struct FocusInput: Sendable {
    public var task: String
    public var start: Date
    public var end: Date
    public var plannedMinutes: Int
    public var focusedMinutes: Int
    public var strict: Bool
    public var lookedAway: Bool

    public init(task: String, start: Date, end: Date, plannedMinutes: Int, focusedMinutes: Int, strict: Bool, lookedAway: Bool) {
        self.task = task; self.start = start; self.end = end; self.plannedMinutes = plannedMinutes
        self.focusedMinutes = focusedMinutes; self.strict = strict; self.lookedAway = lookedAway
    }
}

public enum ShopError: Error, Equatable { case notEnoughLight, alreadyOwned, notForSale, limitReached }

extension SkyProgress {
    /// Giving up this soon after starting leaves no record and no burnt-out star.
    public static let abandonGrace: TimeInterval = 10

    /// Gives up a session: the star goes out and a burnt-out star stays in the sky, but the minutes count toward
    /// hours, planets and the journey. Returns false when it was within the grace period and nothing was recorded.
    @discardableResult
    public mutating func abandon(_ input: FocusInput) -> Bool {
        guard input.end.timeIntervalSince(input.start) >= Self.abandonGrace else { return false }
        records.append(FocusRecord(task: input.task, start: input.start, end: input.end, plannedMinutes: input.plannedMinutes,
                                   focusedMinutes: input.focusedMinutes, completed: false, strict: input.strict,
                                   lookedAway: input.lookedAway))
        afterMinutesChanged(now: input.end)
        return true
    }

    public mutating func complete<R: RandomNumberGenerator>(_ input: FocusInput, calendar cal: Calendar = .current, rng: inout R) -> SessionSummary {
        let now = input.end
        reconcileClouds(now: now, calendar: cal)
        let planetsBefore = Set(unlockedPlanets.map(\.id))
        let completedBefore = Set(completedConstellations)

        // Star
        let starID = StarDraw.pick(progress: self, minutes: input.focusedMinutes, strict: input.strict, rng: &rng)
        var star: CatalogStar?
        var constellation: Constellation?
        var finished: Constellation?
        if let starID, let c = Catalog.constellation(containing: starID) {
            star = c.star(starID)
            constellation = c
            if star?.isBright == true, !StarDraw.brightAllowed(minutes: input.focusedMinutes, strict: input.strict, ticket: false) {
                armedBrightTicket = false
            }
            if telescopeTarget == starID { telescopeTarget = nil }
            litStars[starID] = now
            dryStreak = 0
            if litCount(in: c) == c.stars.count {
                finished = c
                completeConstellation(c, now: now)
            }
        } else {
            dryStreak += 1
        }

        // Işık
        let record = FocusRecord(task: input.task, start: input.start, end: input.end, plannedMinutes: input.plannedMinutes,
                                 focusedMinutes: input.focusedMinutes, completed: true, strict: input.strict,
                                 lookedAway: input.lookedAway, starID: starID)
        records.append(record)
        let streakDays = streak(on: now, calendar: cal)
        let shower = MeteorShowers.active(on: now, calendar: cal)
        var caught = false
        if let shower {
            meteorProgress[shower.seasonKey(for: now, calendar: cal), default: 0] += 1
            caught = !armedShootingStar && shower.isPeak(on: now, calendar: cal)
                && Double.random(in: 0..<1, using: &rng) < MeteorShower.shootingStarChance
        }
        let doubled = armedShootingStar || caught
        let ledger = LightRules.ledger(minutes: input.focusedMinutes, noLook: !input.lookedAway, streakDays: streakDays,
                                       strict: input.strict, doubled: doubled,
                                       doubledBy: armedShootingStar ? loc("Kayan yıldız") : loc("Meteor yağmuru"))
        armedShootingStar = false
        light += ledger.total
        records[records.count - 1].light = ledger.total

        var summary = SessionSummary(record: records[records.count - 1], star: star, constellation: constellation,
                                     completedConstellation: finished, ledger: ledger,
                                     bonusLight: finished == nil ? 0 : LightRules.constellationReward,
                                     meteorShower: shower, caughtShootingStar: caught, streak: streakDays)

        // Badges
        let hour = cal.component(.hour, from: now)
        var earned: [Badge] = [.firstLight]
        if input.focusedMinutes >= 90 { earned.append(.marathon90) }
        if streakDays >= 7 { earned.append(.streak7) }
        if hour >= 22 || hour < 4 { earned.append(.nightOwl) }
        if let shower, (meteorProgress[shower.seasonKey(for: now, calendar: cal)] ?? 0) >= MeteorShower.sessionGoal {
            earned.append(.meteor)
            ownedDials.insert(.meteor)
        }
        for b in earned where !hasBadge(b) {
            badges[b.rawValue] = now
            summary.newBadges.append(b)
        }

        // Deep sky
        for obj in DeepSky.objects where deepSky[obj.id] == nil {
            let ok: Bool
            switch obj.requirement {
            case let .sessionAfter(cid, minutes): ok = completedBefore.contains(cid) && input.focusedMinutes >= minutes
            case let .totalHours(h): ok = totalFocusedMinutes >= h * 60
            case let .completedSessions(n): ok = completedSessions >= n
            case let .constellation(cid): ok = isComplete(cid)
            }
            guard ok else { continue }
            deepSky[obj.id] = now
            light += obj.light
            if let t = obj.theme { ownedThemes.insert(t) }
            summary.newDeepSky.append(obj)
        }

        summary.newPlanets = unlockedPlanets.filter { !planetsBefore.contains($0.id) }
        let journey = afterMinutesChanged(now: now)
        summary.journeyStarted = journey.started
        summary.reachedStops = journey.stops

        for i in promises.indices where promises[i].celebratedAt == nil && promiseProgress(promises[i], now: now, calendar: cal) >= 1 {
            promises[i].celebratedAt = now
            summary.promisesKept.append(promises[i])
        }
        return summary
    }

    /// Opens the journey once the whole starter sky is lit and pays out any stops now reached.
    @discardableResult
    private mutating func afterMinutesChanged(now: Date) -> (started: Bool, stops: [JourneyStop]) {
        var started = false
        if journeyStartMinutes == nil, completedConstellations.count >= Catalog.constellations.count {
            journeyStartMinutes = totalFocusedMinutes
            started = true
        }
        guard journeyStartMinutes != nil else { return (false, []) }
        var reached: [JourneyStop] = []
        for stop in Journey.stops where !reachedStops.contains(stop.id) && lightYearsTravelled >= stop.lightYears {
            reachedStops.append(stop.id)
            switch stop.reward {
            case let .badge(b): if badges[b.rawValue] == nil { badges[b.rawValue] = now }
            case let .light(n): light += n
            case let .sound(s): ownedSounds.insert(s)
            case let .theme(t): ownedThemes.insert(t)
            }
            reached.append(stop)
        }
        return (started, reached)
    }

    mutating func completeConstellation(_ c: Constellation, now: Date) {
        guard !completedConstellations.contains(c.id) else { return }
        completedConstellations.append(c.id)
        light += LightRules.constellationReward
        if let s = c.unlocksSound { ownedSounds.insert(s) }
        openConstellations.removeAll { $0 == c.id }
        if let next = Catalog.constellations.first(where: { !isComplete($0.id) && !openConstellations.contains($0.id) }) {
            openConstellations.append(next.id)
        }
    }

    /// The constellation whose next star is closest, for the "bir yıldız kaldı" nudge.
    public var nearestConstellation: Constellation? {
        openConstellations.compactMap(Catalog.constellation(_:)).max {
            Double(litCount(in: $0)) / Double($0.stars.count) < Double(litCount(in: $1)) / Double($1.stars.count)
        }
    }

    // MARK: Promises

    public func promiseProgress(_ p: SelfPromise, now: Date, calendar: Calendar = .current) -> Double {
        switch p.goal {
        case let .focusHours(h): return min(1, Double(totalFocusedMinutes - p.baselineMinutes) / Double(max(1, h * 60)))
        case let .streakDays(d): return min(1, Double(streak(on: now, calendar: calendar)) / Double(max(1, d)))
        case let .constellation(id):
            guard let c = Catalog.constellation(id) else { return 0 }
            return Double(litCount(in: c)) / Double(c.stars.count)
        }
    }

    public func promiseValueText(_ p: SelfPromise, now: Date, calendar: Calendar = .current) -> String {
        switch p.goal {
        case let .focusHours(h):
            let done = max(0, totalFocusedMinutes - p.baselineMinutes) / 60
            return loc("\(min(done, h)) / \(h) sa")
        case let .streakDays(d): return loc("\(min(streak(on: now, calendar: calendar), d)) / \(d) gün")
        case let .constellation(id):
            guard let c = Catalog.constellation(id) else { return "" }
            return "\(c.name) \(litCount(in: c)) / \(c.stars.count)"
        }
    }

    public static let freePromiseLimit = 2

    public mutating func addPromise(_ p: SelfPromise, unlimited: Bool) throws {
        let active = promises.filter { $0.celebratedAt == nil }.count
        guard unlimited || active < Self.freePromiseLimit else { throw ShopError.limitReached }
        promises.append(p)
    }

    // MARK: Shop

    public func owns(_ item: ShopItem) -> Bool {
        switch item {
        case .booster: false
        case let .sound(s): ownedSounds.contains(s)
        case let .theme(t): ownedThemes.contains(t)
        case .analogDial: ownedDials.contains(.analog)
        case .appIcon: ownsAppIcon
        }
    }

    public mutating func buy(_ item: ShopItem) throws {
        guard let price = item.price else { throw ShopError.notForSale }
        guard !owns(item) else { throw ShopError.alreadyOwned }
        if case let .booster(b) = item, count(b) >= b.maxCount { throw ShopError.limitReached }
        guard light >= price else { throw ShopError.notEnoughLight }
        light -= price
        switch item {
        case let .booster(b): add(b)
        case let .sound(s): ownedSounds.insert(s)
        case let .theme(t): ownedThemes.insert(t)
        case .analogDial: ownedDials.insert(.analog)
        case .appIcon: ownsAppIcon = true
        }
    }

    /// Arms a booster for the next session. Telescope needs the chosen star.
    public mutating func use(_ booster: Booster, target: String? = nil) -> Bool {
        guard count(booster) > 0 else { return false }
        switch booster {
        case .telescope:
            guard let target, !isLit(target), let c = Catalog.constellation(containing: target),
                  openConstellations.contains(c.id) else { return false }
            telescopeTarget = target
        case .shootingStar:
            guard !armedShootingStar else { return false }
            armedShootingStar = true
        case .brightTicket:
            guard !armedBrightTicket else { return false }
            armedBrightTicket = true
        case .cloud:
            return false // clouds are spent automatically
        }
        add(booster, -1)
        return true
    }

    // MARK: Stats

    public enum Period: String, CaseIterable, Sendable { case day, week, all }

    public func stats(_ period: Period, now: Date, calendar cal: Calendar = .current) -> (minutes: Int, stars: Int, sessions: Int) {
        let from: Date
        switch period {
        case .day: from = cal.startOfDay(for: now)
        case .week: from = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
        case .all: from = .distantPast
        }
        let rs = records.filter { $0.end >= from }
        return (rs.reduce(0) { $0 + $1.focusedMinutes }, rs.filter { $0.starID != nil }.count, rs.filter(\.completed).count)
    }
}
