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

    func testTelescopeOnBrightStarFollowsBrightRule() {
        var p = SkyProgress()
        let orion = Catalog.constellation("orion")!
        let rigel = orion.stars.first { $0.name == "Rigel" }!
        p.openConstellations = ["orion"]
        p.telescopeTarget = rigel.id
        var rng = SeededGenerator(seed: 3)
        XCTAssertNotEqual(StarDraw.pick(progress: p, minutes: 25, strict: false, rng: &rng), rigel.id)
        XCTAssertEqual(StarDraw.pick(progress: p, minutes: 60, strict: false, rng: &rng), rigel.id)
        XCTAssertEqual(StarDraw.pick(progress: p, minutes: 25, strict: true, rng: &rng), rigel.id)
        p.armedBrightTicket = true
        XCTAssertEqual(StarDraw.pick(progress: p, minutes: 45, strict: false, rng: &rng), rigel.id)

        // A short session lights another star and keeps the telescope aimed at Rigel.
        p.armedBrightTicket = false
        _ = p.complete(input(25, at: date(2026, 10, 3)), calendar: cal, rng: &rng)
        XCTAssertFalse(p.isLit(rigel.id))
        XCTAssertEqual(p.telescopeTarget, rigel.id)
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

    func testStarRemembersTheSessionThatLitIt() throws {
        var p = SkyProgress()
        var rng = SeededGenerator(seed: 7)
        let end = date(2026, 10, 2)
        let s = p.complete(input(50, at: end), calendar: cal, rng: &rng)
        let star = try XCTUnwrap(s.star)
        let r = try XCTUnwrap(p.record(forStar: star.id))
        XCTAssertEqual(r.task, "Tez")
        XCTAssertEqual(r.focusedMinutes, 50)
        XCTAssertEqual(r.end, end)
        XCTAssertNil(p.record(forStar: "no-such-star"))
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

    func testAbandonWithinGraceLeavesNoRecord() {
        var p = SkyProgress()
        let end = date(2026, 10, 1)
        XCTAssertFalse(p.abandon(FocusInput(task: "Tez", start: end.addingTimeInterval(-9), end: end, plannedMinutes: 25,
                                            focusedMinutes: 0, strict: false, lookedAway: false)))
        XCTAssertTrue(p.records.isEmpty)
        XCTAssertTrue(p.burntOutStars.isEmpty)
    }

    func testAbandonAtGraceBoundaryLeavesBurntOutStar() {
        var p = SkyProgress()
        let end = date(2026, 10, 1)
        XCTAssertTrue(p.abandon(FocusInput(task: "Tez", start: end.addingTimeInterval(-10), end: end, plannedMinutes: 25,
                                           focusedMinutes: 0, strict: false, lookedAway: false)))
        XCTAssertEqual(p.burntOutStars.map(\.task), ["Tez"])
    }

    func testCompletedSessionIsNotBurntOut() {
        var p = SkyProgress()
        var rng = SeededGenerator(seed: 1)
        _ = p.complete(input(25, at: date(2026, 10, 1)), calendar: cal, rng: &rng)
        p.records.append(FocusRecord(task: "Eski", start: date(2026, 9, 1), end: date(2026, 9, 1, 21), plannedMinutes: 60,
                                     focusedMinutes: 5, completed: false, strict: false, lookedAway: false))
        XCTAssertEqual(p.burntOutStars.map(\.task), ["Eski"])
    }

    func testBurntOutStarLayoutIsStableInsideDiscAndOffSlots() {
        let slots = [DiscRect(x: 0.14, y: 0.22, width: 0.36, height: 0.30), DiscRect(x: 0.56, y: 0.26, width: 0.30, height: 0.26),
                     DiscRect(x: 0.50, y: 0.58, width: 0.30, height: 0.34), DiscRect(x: 0.18, y: 0.56, width: 0.28, height: 0.28)]
        for _ in 0..<200 {
            let id = UUID()
            let p = BurntOutStarLayout.point(for: id, avoiding: slots)
            XCTAssertEqual(p, BurntOutStarLayout.point(for: id, avoiding: slots))
            let r = hypot(p.x - 0.5, p.y - 0.5)
            XCTAssertLessThanOrEqual(r, 0.46)
            XCTAssertGreaterThanOrEqual(r, 0.06)
            XCTAssertFalse(slots.contains { $0.contains(p) })
        }
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

    func testShootingStarsFallOnlyOnPeakDays() {
        // Orionids 2026 peak on the night of 21–22 October.
        let o = shower("orionids")
        XCTAssertFalse(o.isPeak(on: date(2026, 10, 20, 23), calendar: cal))
        XCTAssertTrue(o.isPeak(on: date(2026, 10, 21), calendar: cal))
        XCTAssertTrue(o.isPeak(on: date(2026, 10, 22, 3), calendar: cal))
        XCTAssertFalse(o.isPeak(on: date(2026, 10, 23, 1), calendar: cal))
        // A morning peak (4 Jan 2027, 06:25) makes 3 and 4 January the peak days.
        let q = shower("quadrantids")
        XCTAssertTrue(q.isPeak(on: date(2027, 1, 3), calendar: cal))
        XCTAssertTrue(q.isPeak(on: date(2027, 1, 4, 5), calendar: cal))
        XCTAssertFalse(q.isPeak(on: date(2027, 1, 5), calendar: cal))

        var p = SkyProgress()
        var rng = SeededGenerator(seed: 3)
        var caught = 0
        for _ in 0..<30 where p.complete(input(25, at: date(2026, 10, 15)), calendar: cal, rng: &rng).caughtShootingStar { caught += 1 }
        XCTAssertEqual(caught, 0)
        // Sessions outside the peak still count toward the shower badge.
        XCTAssertEqual(p.meteorProgress["orionids-2026"], 30)
        for _ in 0..<30 where p.complete(input(25, at: date(2026, 10, 21, 22)), calendar: cal, rng: &rng).caughtShootingStar { caught += 1 }
        XCTAssertGreaterThan(caught, 0)
    }

    func testQuadrantidsSeasonKeySpansNewYear() {
        let q = MeteorShowers.all.first { $0.id == "quadrantids" }!
        XCTAssertTrue(q.isActive(on: date(2027, 1, 2), calendar: cal))
        XCTAssertEqual(q.seasonKey(for: date(2027, 1, 2), calendar: cal), "quadrantids-2026")
        XCTAssertFalse(q.isActive(on: date(2026, 6, 1), calendar: cal))
    }

    func shower(_ id: String) -> MeteorShower { MeteorShowers.all.first { $0.id == id }! }

    func testBundledSkyCalendarDrivesDates() throws {
        let c = try XCTUnwrap(SkyCalendar.bundled)
        XCTAssertTrue(c.covers(date(2026, 10, 13), calendar: cal))
        XCTAssertEqual(Set(c.occurrences.map(\.id)), Set(MeteorShowers.all.map(\.id)))
        let now = date(2026, 10, 13)
        XCTAssertEqual(MeteorShowers.active(on: now, calendar: cal)?.id, "orionids")
        XCTAssertEqual(shower("orionids").peakText(around: now, calendar: cal), "21–22 Ekim gecesi")
        XCTAssertEqual(MeteorShowers.upcoming(after: now, calendar: cal).map(\.id), ["leonids", "geminids", "quadrantids"])
        // A morning peak belongs to the night before: Quadrantids peak 4 Jan 2027, 06:25 in Istanbul.
        XCTAssertEqual(shower("quadrantids").peakText(around: now, calendar: cal), "3–4 Ocak gecesi")
        XCTAssertEqual(shower("quadrantids").peakDate(around: now, calendar: cal), date(2027, 1, 3, 23))
        XCTAssertEqual(shower("geminids").peakText(around: now, calendar: cal), "14–15 Aralık gecesi")
        XCTAssertEqual(shower("lyrids").nextStart(after: now, calendar: cal), cal.date(from: DateComponents(year: 2027, month: 4, day: 14)))
        // The last active day counts in full.
        XCTAssertTrue(shower("orionids").isActive(on: date(2026, 11, 7, 23), calendar: cal))
        XCTAssertFalse(shower("orionids").isActive(on: date(2026, 11, 8, 1), calendar: cal))
        // Moonlight at the 2026 Orionid peak: about 80 %, as in the IMO calendar.
        XCTAssertEqual(Double(try XCTUnwrap(shower("orionids").moonAtPeak(around: now, calendar: cal))), 80, accuracy: 4)
    }

    func testSkyCalendarScheduleMixesDatedAndTableWindows() {
        let from = date(2026, 10, 13), to = date(2028, 10, 13)
        let events = MeteorShowers.schedule(from: from, to: to, calendar: cal)
        XCTAssertEqual(events.first?.shower?.id, "orionids")
        XCTAssertTrue(events.first!.contains(from))
        XCTAssertEqual(events.first?.zhr, 20)
        XCTAssertEqual(events.first?.whenText(calendar: cal), "21–22 Ekim gecesi")
        // Once a year each, with no duplicate where the dated calendar and the table meet.
        XCTAssertEqual(events.filter { $0.shower?.id == "quadrantids" }.count, 2)
        XCTAssertEqual(events.filter { $0.shower?.id == "lyrids" }.count, 2)
        XCTAssertEqual(events.filter { $0.shower?.id == "orionids" }.count, 3)
        XCTAssertEqual(events.map(\.day), events.map(\.day).sorted())
        // After the calendar runs out, the table carries on: Lyrids 2028 without a ZHR.
        let lyrids2028 = events.last { $0.shower?.id == "lyrids" }
        XCTAssertEqual(cal.component(.year, from: lyrids2028!.start), 2028)
        XCTAssertNil(lyrids2028?.zhr)
        XCTAssertEqual(Moon.phase(at: events.first!.peak), 10.4 / 29.53, accuracy: 0.02)
    }

    func testSkyCalendarHasEclipsesAndPlanetEvents() throws {
        let c = try XCTUnwrap(SkyCalendar.bundled)
        let kinds = Set(c.astroEvents.compactMap(\.kind))
        XCTAssertEqual(kinds, [.lunarEclipse, .solarEclipse, .opposition, .conjunction, .elongation, .supermoon])
        XCTAssertEqual(Set(c.astroEvents.map(\.id)).count, c.astroEvents.count)
        let events = MeteorShowers.schedule(from: date(2026, 10, 13), to: date(2029, 1, 1), calendar: cal)
        // The 2027 solar eclipse, at 12:46 in Istanbul, reminded half an hour before.
        let solar = try XCTUnwrap(events.first { $0.astro?.kind == .solarEclipse })
        XCTAssertEqual(solar.whenText(calendar: cal), "2 Ağustos, 12:46")
        XCTAssertEqual(solar.reminderDate(calendar: cal), cal.date(from: DateComponents(year: 2027, month: 8, day: 2, hour: 12, minute: 16)))
        // The penumbral lunar eclipse of 20 Feb UT falls on 21 Feb in Istanbul.
        let lunar = try XCTUnwrap(events.first { $0.astro?.id == "eclipse-lunar-2027-02" })
        XCTAssertEqual(cal.component(.day, from: lunar.day), 21)
        XCTAssertEqual(MeteorShowers.astroEvent(id: "opposition-mars-2027")?.bodies, ["mars"])
        // Supermoons really are full.
        for e in events where e.astro?.kind == .supermoon { XCTAssertGreaterThan(e.moon, 97, e.id) }
    }

    func testSkyCalendarSkipsUnknownKinds() throws {
        let json = #"{"version":1,"updated":"2031-01-01","source":"t","occurrences":[{"id":"lyrids","start":"2031-04-14","end":"2031-04-30","peak":"2031-04-22T12:00:00Z"}],"events":[{"id":"x","kind":"comet","title":"Kuyrukluyıldız","peak":"2031-05-01T00:00:00Z","sky":"night","bodies":[],"detail":"","tip":""}]}"#
        let c = try SkyCalendar.decode(Data(json.utf8))
        XCTAssertEqual(c.events?.count, 1)
        XCTAssertTrue(c.astroEvents.isEmpty)
    }

    func testMeteorShowersFallBackWithoutCalendar() {
        let saved = MeteorShowers.calendar
        defer { MeteorShowers.calendar = saved }
        MeteorShowers.calendar = nil
        XCTAssertEqual(shower("orionids").peakText(around: date(2026, 10, 13), calendar: cal), "21–22 Ekim civarı")
        XCTAssertTrue(shower("orionids").isActive(on: date(2030, 10, 13), calendar: cal))
        XCTAssertEqual(shower("orionids").seasonKey(for: date(2030, 10, 13), calendar: cal), "orionids-2030")
    }

    func testSkyCalendarAdoptsOnlyNewerValidCopies() throws {
        let saved = MeteorShowers.calendar
        defer { MeteorShowers.calendar = saved }
        func json(_ updated: String, start: String = "2031-10-02") -> Data {
            Data(#"{"version":1,"updated":"\#(updated)","source":"test","occurrences":[{"id":"orionids","start":"\#(start)","end":"2031-11-07","peak":"2031-10-21T18:00:00Z"}]}"#.utf8)
        }
        XCTAssertFalse(MeteorShowers.adopt(try SkyCalendar.decode(json("2020-01-01"))))
        XCTAssertTrue(MeteorShowers.adopt(try SkyCalendar.decode(json("2099-01-01"))))
        XCTAssertEqual(MeteorShowers.calendar?.updated, "2099-01-01")
        XCTAssertThrowsError(try SkyCalendar.decode(json("2099-01-02", start: "2031-13-02")))
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

    func testRetiredSoundDoesNotDropOwnedSounds() throws {
        let data = #"{"ownedSounds": ["rain", "library", "cafe"]}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(SkyProgress.self, from: data)
        XCTAssertTrue(p.ownedSounds.contains(.library))
        XCTAssertTrue(p.ownedSounds.contains(.forest))
        XCTAssertFalse(SoundID.allCases.map(\.rawValue).contains("cafe"))
    }

    // MARK: - Merging two copies of a sky (account sync)

    func testMergeKeepsSessionsFromBothPhonesAndAddsUpLight() {
        var base = SkyProgress()
        var rng = SeededGenerator(seed: 3)
        _ = base.complete(input(45, at: date(2026, 10, 1)), calendar: cal, rng: &rng)
        var phone = base, account = base
        _ = phone.complete(input(30, at: date(2026, 10, 2)), calendar: cal, rng: &rng)
        _ = account.complete(input(60, at: date(2026, 10, 3)), calendar: cal, rng: &rng)
        account.light -= 20  // spent in the shop on the other phone

        let m = SkyProgress.merge(base: base, local: phone, remote: account)
        XCTAssertEqual(m.records.count, 3)
        XCTAssertEqual(m.records.map(\.start), m.records.map(\.start).sorted())
        XCTAssertEqual(m.light, base.light + (phone.light - base.light) + (account.light - base.light))
        XCTAssertEqual(Set(m.litStars.keys), Set(phone.litStars.keys).union(account.litStars.keys))
        XCTAssertEqual(m.totalFocusedMinutes, 135)
    }

    func testFirstSignInAddsThePhoneSkyToTheAccount() {
        var rng = SeededGenerator(seed: 9)
        var phone = SkyProgress(), account = SkyProgress()
        _ = phone.complete(input(25, at: date(2026, 10, 5)), calendar: cal, rng: &rng)
        _ = account.complete(input(50, at: date(2026, 9, 5)), calendar: cal, rng: &rng)
        account.ownedThemes.insert(.aurora)
        let m = SkyProgress.merge(base: SkyProgress(), local: phone, remote: account)
        XCTAssertEqual(m.records.count, 2)
        XCTAssertEqual(m.light, phone.light + account.light)
        XCTAssertTrue(m.ownedThemes.contains(.aurora))
        XCTAssertEqual(m.openConstellations.count, 3)
    }

    func testMergeWithAnUntouchedSideTakesTheOther() {
        var rng = SeededGenerator(seed: 1)
        var changed = SkyProgress()
        _ = changed.complete(input(45, at: date(2026, 10, 1)), calendar: cal, rng: &rng)
        XCTAssertEqual(SkyProgress.merge(base: SkyProgress(), local: SkyProgress(), remote: changed), changed)
        XCTAssertEqual(SkyProgress.merge(base: SkyProgress(), local: changed, remote: SkyProgress()), changed)
    }

    func testMergeRespectsDeletedPromisesAndSpentBoosters() {
        var base = SkyProgress()
        base.promises = [SelfPromise(title: "Sinema", goal: .focusHours(5), createdAt: date(2026, 9, 1), baselineMinutes: 0)]
        base.add(.telescope, 2)
        var phone = base, account = base
        phone.promises = []
        phone.add(.telescope, -1)
        account.add(.telescope, -1)
        account.promises.append(SelfPromise(title: "Kitap", goal: .streakDays(7), createdAt: date(2026, 9, 2), baselineMinutes: 0))
        let m = SkyProgress.merge(base: base, local: phone, remote: account)
        XCTAssertEqual(m.promises.map(\.title), ["Kitap"])
        XCTAssertEqual(m.count(.telescope), 0)
    }

    func testStarsLitOnTwoPhonesCanFinishAConstellation() {
        let orion = Catalog.constellation("orion")!
        var base = SkyProgress()
        base.openConstellations = ["orion", "cassiopeia", "cygnus"]
        var phone = base, account = base
        for (i, s) in orion.stars.enumerated() {
            if i % 2 == 0 { phone.litStars[s.id] = date(2026, 10, 1) } else { account.litStars[s.id] = date(2026, 10, 2) }
        }
        let m = SkyProgress.merge(base: base, local: phone, remote: account)
        XCTAssertTrue(m.isComplete("orion"))
        XCTAssertFalse(m.openConstellations.contains("orion"))
        XCTAssertEqual(m.openConstellations.count, 3)
        XCTAssertEqual(m.light, LightRules.constellationReward)
    }

    // MARK: - İkiz yıldız, Kıvılcım, Kuyrukluyıldız and looks

    func testTwinStarLightsTwoStarsInALongSession() throws {
        var p = SkyProgress()
        p.add(.twinStar)
        XCTAssertTrue(p.use(.twinStar))
        XCTAssertFalse(p.use(.twinStar))
        var rng = SeededGenerator(seed: 11)
        // Too short: one star, and the twin stays armed.
        let short = p.complete(input(30, at: date(2026, 10, 1)), calendar: cal, rng: &rng)
        XCTAssertNil(short.twinStar)
        XCTAssertTrue(p.armedTwinStar)
        XCTAssertEqual(p.starCount, 1)
        let s = p.complete(input(50, at: date(2026, 10, 2)), calendar: cal, rng: &rng)
        let first = try XCTUnwrap(s.star), twin = try XCTUnwrap(s.twinStar)
        XCTAssertNotEqual(first.id, twin.id)
        XCTAssertFalse(twin.isBright)
        XCTAssertFalse(p.armedTwinStar)
        XCTAssertEqual(p.starCount, 3)
        XCTAssertEqual(p.record(forStar: twin.id)?.id, p.records.last?.id)
        XCTAssertEqual(p.stats(.all, now: date(2026, 10, 2), calendar: cal).stars, 3)
    }

    func testTwinStarCanFinishAConstellation() {
        var p = SkyProgress()
        let orion = Catalog.constellation("orion")!
        let faint = orion.stars.filter { !$0.isBright }
        for s in orion.stars where s.id != faint[0].id && s.id != faint[1].id { p.litStars[s.id] = .now }
        p.openConstellations = ["orion"]
        p.armedTwinStar = true
        var rng = SeededGenerator(seed: 3)
        let before = p.light
        let s = p.complete(input(45, at: date(2026, 10, 3)), calendar: cal, rng: &rng)
        XCTAssertEqual(s.completedConstellation?.id, "orion")
        XCTAssertEqual(s.bonusLight, LightRules.constellationReward)
        XCTAssertEqual(p.light - before, s.ledger.total + LightRules.constellationReward)
    }

    func testSparkRekindlesTheLatestBurntOutStar() {
        var p = SkyProgress()
        p.add(.spark, 2)
        XCTAssertFalse(p.use(.spark)) // nothing to rekindle
        XCTAssertEqual(p.count(.spark), 2)
        p.abandon(input(20, at: date(2026, 10, 1)))
        var later = input(15, at: date(2026, 10, 2)); later.task = "Rapor"
        p.abandon(later)
        XCTAssertTrue(p.use(.spark))
        XCTAssertEqual(p.burntOutStars.map(\.task), ["Tez"])
        XCTAssertEqual(p.count(.spark), 1)
        XCTAssertEqual(p.totalFocusedMinutes, 35)
    }

    func testCometDoublesJourneyDistanceOnlyOnceTheJourneyIsOpen() {
        var p = SkyProgress()
        p.add(.comet)
        XCTAssertFalse(p.use(.comet))
        for c in Catalog.constellations { for s in c.stars { p.litStars[s.id] = .now }; p.completedConstellations.append(c.id) }
        p.openConstellations = []
        var rng = SeededGenerator(seed: 8)
        _ = p.complete(input(60, at: date(2026, 10, 1)), calendar: cal, rng: &rng)
        XCTAssertTrue(p.use(.comet))
        _ = p.complete(input(180, at: date(2026, 10, 2)), calendar: cal, rng: &rng)
        XCTAssertFalse(p.armedComet)
        XCTAssertEqual(p.lightYearsTravelled, 6, accuracy: 0.001)
        let s = p.complete(input(60, at: date(2026, 10, 3)), calendar: cal, rng: &rng)
        XCTAssertEqual(p.lightYearsTravelled, 7, accuracy: 0.001)
        XCTAssertTrue(s.reachedStops.isEmpty)
    }

    func testNewLooksAreSoldAndOldIconFlagStillCounts() throws {
        var p = SkyProgress()
        p.light = 2000
        try p.buy(.theme(.milkyWay))
        try p.buy(.dial(.moonPhase))
        try p.buy(.appIcon(.midnight))
        XCTAssertEqual(p.light, 2000 - 600 - 250 - 150)
        XCTAssertTrue(p.owns(.dial(.moonPhase)))
        XCTAssertThrowsError(try p.buy(.dial(.meteor))) { XCTAssertEqual($0 as? ShopError, .notForSale) }
        XCTAssertEqual(ShopItem.dial(.analog).id, "look.analog")
        XCTAssertEqual(ShopItem.appIcon(.dawn).id, "look.icon")

        let old = try JSONDecoder().decode(SkyProgress.self, from: #"{"ownsAppIcon": true, "ownedThemes": ["night", "aurora", "someFutureTheme"]}"#.data(using: .utf8)!)
        XCTAssertEqual(old.ownedIcons, [.dawn])
        XCTAssertEqual(old.ownedThemes, [.night, .aurora])
        let round = try JSONDecoder().decode(SkyProgress.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(round, p)
    }

    func testMergeAddsCometMinutesAndKeepsRekindledStars() {
        let base = SkyProgress()
        var phone = base, account = base
        phone.cometMinutes = 60
        account.cometMinutes = 30
        let id = UUID()
        phone.rekindled = [id]
        account.ownedIcons = [.midnight]
        let m = SkyProgress.merge(base: base, local: phone, remote: account)
        XCTAssertEqual(m.cometMinutes, 90)
        XCTAssertEqual(m.rekindled, [id])
        XCTAssertEqual(m.ownedIcons, [.midnight])
    }
}
