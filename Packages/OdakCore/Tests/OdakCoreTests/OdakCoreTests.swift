import XCTest
@testable import OdakCore

final class OdakCoreTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 20) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func input(_ minutes: Int, at end: Date, strict: Bool = false, lookedAway: Bool = false) -> FocusInput {
        FocusInput(task: "Tez", start: end.addingTimeInterval(TimeInterval(-minutes * 60)), end: end,
                   plannedMinutes: minutes, focusedMinutes: minutes, strict: strict, lookedAway: lookedAway)
    }

    func testCatalogHasSixteenConstellationsWithValidLines() {
        XCTAssertEqual(Catalog.constellations.count, 16)
        XCTAssertEqual(Set(Catalog.constellations.map(\.id)).count, 16)
        for c in Catalog.constellations {
            let ids = Set(c.stars.map(\.id))
            XCTAssertEqual(ids.count, c.stars.count, c.id)
            for l in c.lines {
                XCTAssertTrue(ids.contains(l.from) && ids.contains(l.to), "\(c.id): \(l)")
            }
            XCTAssertFalse(c.facts.isEmpty)
        }
        XCTAssertEqual(Catalog.constellation("orion")?.stars.filter(\.isBright).map(\.name), ["Betelgeuse", "Rigel"])
    }

    func testLedgerMatchesDesignExample() {
        // 45 minutes, never looked, 6th streak day: 45 + 9 + 5 = 59 (Ödül anı screen).
        let l = LightRules.ledger(minutes: 45, noLook: true, streakDays: 6, strict: false, doubled: false)
        XCTAssertEqual(l.lines.map(\.amount), [45, 9, 5])
        XCTAssertEqual(l.total, 59)
        XCTAssertEqual(l.lines[2].label, "Seri bonusu, 6. gün %10")
    }

    func testStreakBonusCapsAtTwentyPercent() {
        XCTAssertEqual(LightRules.streakPercent(days: 1), 0)
        XCTAssertEqual(LightRules.streakPercent(days: 30), 20)
    }

    func testStrictAndDoubling() {
        let l = LightRules.ledger(minutes: 60, noLook: false, streakDays: 1, strict: true, doubled: true)
        XCTAssertEqual(l.total, (60 + 30) * 2)
    }

    func testShortSessionsNeverDropBrightStars() {
        var p = SkyProgress()
        for s in Catalog.constellation("orion")!.stars where !s.isBright { p.litStars[s.id] = .now }
        p.openConstellations = ["orion"]
        var rng = SeededGenerator(seed: 7)
        XCTAssertNil(StarDraw.pick(progress: p, minutes: 45, strict: false, rng: &rng))
        XCTAssertNotNil(StarDraw.pick(progress: p, minutes: 60, strict: false, rng: &rng))
        XCTAssertNotNil(StarDraw.pick(progress: p, minutes: 25, strict: true, rng: &rng))
        p.dryStreak = StarDraw.pityAfter
        XCTAssertNotNil(StarDraw.pick(progress: p, minutes: 25, strict: false, rng: &rng))
    }

    func testEverySessionLightsANewStarUntilConstellationsComplete() {
        var p = SkyProgress()
        var rng = SeededGenerator(seed: 42)
        var day = date(2026, 10, 1)
        var seen = Set<String>()
        for _ in 0..<40 {
            let s = p.complete(input(60, at: day), calendar: cal, rng: &rng)
            if let id = s.star?.id { XCTAssertTrue(seen.insert(id).inserted, "star \(id) dropped twice") }
            day = cal.date(byAdding: .hour, value: 12, to: day)!
        }
        XCTAssertEqual(seen.count, 40)
        XCTAssertGreaterThanOrEqual(p.completedConstellations.count, 2)
        XCTAssertEqual(p.openConstellations.count, 3)
    }

    func testCompletingConstellationPaysRewardAndOpensNext() {
        var p = SkyProgress()
        let orion = Catalog.constellation("orion")!
        for s in orion.stars.dropLast() { p.litStars[s.id] = .now }
        p.telescopeTarget = orion.stars.last!.id
        var rng = SeededGenerator(seed: 1)
        let before = p.light
        let s = p.complete(input(60, at: date(2026, 10, 3)), calendar: cal, rng: &rng)
        XCTAssertEqual(s.completedConstellation?.id, "orion")
        XCTAssertTrue(p.ownedSounds.contains(.winterNight))
        XCTAssertEqual(p.light - before, s.ledger.total + LightRules.constellationReward)
        XCTAssertFalse(p.openConstellations.contains("orion"))
        XCTAssertEqual(p.openConstellations.count, 3)
        XCTAssertNil(p.telescopeTarget)
    }

    func testOrionNebulaNeedsLongSessionAfterOrion() {
        var p = SkyProgress()
        p.completedConstellations = ["orion"]
        var rng = SeededGenerator(seed: 3)
        _ = p.complete(input(60, at: date(2026, 10, 4)), calendar: cal, rng: &rng)
        XCTAssertNil(p.deepSky["m42"])
        let s = p.complete(input(90, at: date(2026, 10, 5)), calendar: cal, rng: &rng)
        XCTAssertEqual(s.newDeepSky.map(\.id), ["m42"])
        XCTAssertTrue(p.ownedThemes.contains(.nebula))
    }

    func testStreakAndClouds() {
        var p = SkyProgress()
        var rng = SeededGenerator(seed: 5)
        _ = p.complete(input(25, at: date(2026, 10, 1)), calendar: cal, rng: &rng)
        _ = p.complete(input(25, at: date(2026, 10, 2)), calendar: cal, rng: &rng)
        XCTAssertEqual(p.streak(on: date(2026, 10, 2), calendar: cal), 2)
        XCTAssertEqual(p.streak(on: date(2026, 10, 3), calendar: cal), 2) // today not done yet
        // Missed 3rd and 4th; two clouds cover them.
        let s = p.complete(input(25, at: date(2026, 10, 5)), calendar: cal, rng: &rng)
        XCTAssertEqual(p.count(.cloud), 0)
        XCTAssertEqual(s.streak, 5)
    }

    func testTooManyMissedDaysBreakStreakWithoutSpendingClouds() {
        var p = SkyProgress()
        var rng = SeededGenerator(seed: 5)
        _ = p.complete(input(25, at: date(2026, 10, 1)), calendar: cal, rng: &rng)
        let s = p.complete(input(25, at: date(2026, 10, 6)), calendar: cal, rng: &rng)
        XCTAssertEqual(p.count(.cloud), 2)
        XCTAssertEqual(s.streak, 1)
    }

    func testAbandonCountsMinutesButNoStarOrLight() {
        var p = SkyProgress()
        p.abandon(input(20, at: date(2026, 10, 1)))
        XCTAssertEqual(p.totalFocusedMinutes, 20)
        XCTAssertEqual(p.starCount, 0)
        XCTAssertEqual(p.light, 0)
    }

    func testOrionidsCountAndBadge() {
        var p = SkyProgress()
        var rng = SeededGenerator(seed: 9)
        var last: SessionSummary?
        for i in 0..<10 { last = p.complete(input(25, at: date(2026, 10, 10 + i)), calendar: cal, rng: &rng) }
        XCTAssertEqual(last?.meteorShower?.id, "orionids")
        XCTAssertEqual(p.meteorProgress["orionids-2026"], 10)
        XCTAssertTrue(p.hasBadge(.meteor))
        XCTAssertTrue(p.ownedDials.contains(.meteor))
    }

    func testQuadrantidsSeasonKeySpansNewYear() {
        let q = MeteorShowers.all.first { $0.id == "quadrantids" }!
        XCTAssertTrue(q.isActive(on: date(2027, 1, 2), calendar: cal))
        XCTAssertEqual(q.seasonKey(for: date(2027, 1, 2), calendar: cal), "quadrantids-2026")
        XCTAssertFalse(q.isActive(on: date(2026, 6, 1), calendar: cal))
    }

    func testShopAndBoosters() throws {
        var p = SkyProgress()
        XCTAssertThrowsError(try p.buy(.booster(.telescope))) { XCTAssertEqual($0 as? ShopError, .notEnoughLight) }
        p.light = 1000
        try p.buy(.booster(.shootingStar))
        XCTAssertEqual(p.light, 850)
        XCTAssertTrue(p.use(.shootingStar))
        XCTAssertFalse(p.use(.shootingStar))
        try p.buy(.sound(.library))
        XCTAssertThrowsError(try p.buy(.sound(.library)))
        XCTAssertThrowsError(try p.buy(.sound(.winterNight))) { XCTAssertEqual($0 as? ShopError, .notForSale) }
        var rng = SeededGenerator(seed: 2)
        let s = p.complete(input(30, at: date(2026, 9, 1)), calendar: cal, rng: &rng)
        XCTAssertEqual(s.ledger.lines.last?.label, "Kayan yıldız, ×2")
        XCTAssertFalse(p.armedShootingStar)
    }

    func testPromiseLimitAndProgress() throws {
        var p = SkyProgress()
        let now = date(2026, 10, 1)
        try p.addPromise(SelfPromise(title: "Kitap", goal: .focusHours(1), createdAt: now, baselineMinutes: 0), unlimited: false)
        try p.addPromise(SelfPromise(title: "Kahvaltı", goal: .streakDays(7), createdAt: now, baselineMinutes: 0), unlimited: false)
        XCTAssertThrowsError(try p.addPromise(SelfPromise(title: "X", goal: .streakDays(3), createdAt: now, baselineMinutes: 0), unlimited: false))
        XCTAssertNoThrow(try p.addPromise(SelfPromise(title: "X", goal: .streakDays(3), createdAt: now, baselineMinutes: 0), unlimited: true))
        var rng = SeededGenerator(seed: 4)
        let s = p.complete(input(60, at: now), calendar: cal, rng: &rng)
        XCTAssertEqual(s.promisesKept.map(\.title), ["Kitap"])
    }

    func testJourneyOpensAfterWholeSkyAndPaysStops() {
        var p = SkyProgress()
        for c in Catalog.constellations { for s in c.stars { p.litStars[s.id] = .now }; p.completedConstellations.append(c.id) }
        p.openConstellations = []
        var rng = SeededGenerator(seed: 8)
        let first = p.complete(input(60, at: date(2026, 10, 1)), calendar: cal, rng: &rng)
        XCTAssertTrue(first.journeyStarted)
        XCTAssertNil(first.star)
        let s = p.complete(input(300, at: date(2026, 10, 2)), calendar: cal, rng: &rng)
        XCTAssertEqual(s.reachedStops.map(\.name), ["Alfa Centauri"])
        XCTAssertTrue(p.hasBadge(.proxima))
    }

    func testProgressDecodesOldPayloadWithDefaults() throws {
        let data = #"{"light": 1440}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(SkyProgress.self, from: data)
        XCTAssertEqual(p.light, 1440)
        XCTAssertEqual(p.openConstellations, ["ursa-major", "orion", "cassiopeia"])
        XCTAssertEqual(p.count(.cloud), 2)
        let round = try JSONDecoder().decode(SkyProgress.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(round, p)
    }
}
