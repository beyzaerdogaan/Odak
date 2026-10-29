# Sönmüş yıldız Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Giving up a focus session (after a 10-second grace) leaves a permanent grey "sönmüş yıldız" on the Home planisphere; tapping it shows only that session's task sentence.

**Architecture:** No new stored data (types are named `DiscPoint`/`DiscRect` to avoid clashing with SwiftUI's `UnitPoint`). Burnt-out stars are derived from `FocusRecord`s with `completed == false`. OdakCore owns the grace rule and a deterministic placement function (pure, `Double`-based, unit-tested); the app draws and hit-tests them inside `Planisphere`.

**Tech Stack:** Swift, SwiftUI (iOS 26), OdakCore Swift package, XCTest. The cloud container has no Swift toolchain: `swift test` and the app build run in CI (`.github/workflows/ios.yml`) on push.

**Spec:** `docs/superpowers/specs/2026-10-29-sonmus-yildiz-design.md`

## Global Constraints

- Grace period: exactly 10 seconds (`end - start < 10` → nothing recorded).
- Only hold-to-give-up creates a burnt-out star. No change to leaving/closing the app, Işık, streak or clouds.
- Tap shows only `record.task`. No date, minutes or "vazgeçtin" wording.
- Shown only on Home `Planisphere`, not on Gökyüzüm `SkyChart`.
- Dark-only UI; colours from `Theme`.
- Turkish copy: full natural sentences, exact strings from the spec.

## Review Focus

1. Many burnt-out stars (e.g. 60+): placement must stay inside the disc and off constellation slots, and drawing must not slow the Home screen. → Task 1 test with 200 ids.
2. Records that existed before this feature (abandoned before, any length) show as burnt-out stars. → Task 1 test that `burntOutStars` returns pre-existing `completed: false` records.
3. Giving up at exactly 10 seconds records the session (boundary). → Task 1 test.
4. Tap on empty disc area (no star within 22 pt) shows nothing and does not open a constellation. → Task 2 manual check on the demo screenshot build.
5. Sync merge of two devices keeps each burnt-out star once and at the same spot (placement depends only on `id`). → Task 1 determinism test; `Merge` already dedupes by `id`.

---

### Task 1: Rules and placement in OdakCore

**Files:**
- Modify: `Packages/OdakCore/Sources/OdakCore/Engine.swift:181-189` (`abandon`)
- Create: `Packages/OdakCore/Sources/OdakCore/BurntOutStars.swift`
- Test: `Packages/OdakCore/Tests/OdakCoreTests/OdakCoreTests.swift`

**Interfaces:**
- Produces:
  - `extension SkyProgress { public static let abandonGrace: TimeInterval /* 10 */; @discardableResult public mutating func abandon(_ input: FocusInput) -> Bool; public var burntOutStars: [FocusRecord] }`
  - `public struct DiscPoint: Equatable, Sendable { public var x, y: Double }` (0…1 in the disc's bounding square, centre 0.5,0.5)
  - `public struct DiscRect: Sendable { public var x, y, width, height: Double; public func contains(_ p: DiscPoint) -> Bool }`
  - `public enum BurntOutStarLayout { public static func point(for id: UUID, avoiding: [DiscRect]) -> DiscPoint }`

- [ ] **Step 1: Write the failing tests**

```swift
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
    var p = SkyProgress(); var rng = SeededGenerator(seed: 1)
    _ = p.complete(input(25, at: date(2026, 10, 1)), calendar: cal, rng: &rng)
    p.records.append(FocusRecord(task: "Eski", start: date(2026, 9, 1), end: date(2026, 9, 1, 21), plannedMinutes: 60,
                                 focusedMinutes: 5, completed: false, strict: false, lookedAway: false))
    XCTAssertEqual(p.burntOutStars.map(\.task), ["Eski"])
}

func testBurntOutStarLayoutIsStableInsideDiscAndOffSlots() {
    let slots = [DiscRect(x: 0.14, y: 0.22, width: 0.36, height: 0.24), DiscRect(x: 0.56, y: 0.26, width: 0.30, height: 0.20),
                 DiscRect(x: 0.50, y: 0.58, width: 0.30, height: 0.28), DiscRect(x: 0.18, y: 0.56, width: 0.28, height: 0.22)]
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
```

- [ ] **Step 2: Implement**

`abandon`: guard `input.end.timeIntervalSince(input.start) >= Self.abandonGrace` else return `false`; existing body; return `true`. `burntOutStars = records.filter { !$0.completed }`.

`BurntOutStarLayout.point`: seed `SeededGenerator` (already in OdakCore) from the UUID's 16 bytes folded into a `UInt64`; up to 64 candidates with radius `sqrt(u) * 0.46` (rejecting `< 0.06`) and uniform angle around (0.5, 0.5); return the first not inside any slot; after 64 tries return the last candidate. The 200-id test pins that the fallback is never needed for these slots.

Update the existing `testAbandonCountsMinutesButNoStarOrLight` only if it fails to compile (it uses a 20-minute session, so it still records).

- [ ] **Step 3: Verify**

Push the branch; in the `ios.yml` run, step "swift test" must pass, including the four new tests.

- [ ] **Step 4: Commit** — `git commit -m "OdakCore: grace period and burnt-out star placement"`

### Task 2: Draw and tap burnt-out stars on the planisphere

**Files:**
- Modify: `App/Theme/SkyDrawing.swift` (`Planisphere`, lines ~106-209)
- Modify: `App/Model/DemoData.swift` (add two abandoned records)

**Interfaces:**
- Consumes: `progress.burntOutStars`, `BurntOutStarLayout.point(for:avoiding:)`, `DiscRect` (Task 1).

- [ ] **Step 1: Implement drawing**

In `Planisphere`, derive `DiscRect`s from the existing `slots` (convert each `CGRect` field to `Double`; extend each slot's height by 0.06 to cover its label). For each burnt-out record, map the unit point to `disc.minX + x * disc.width`, `disc.minY + y * disc.height`; draw into `inner` after the background stars and before the constellations: a filled circle r = 2.5 in `Theme.paper3.opacity(0.55)` and a dashed ring r = 5, `lineWidth: 0.75`, `dash: [1.5, 2]`, `Theme.paper3.opacity(0.35)`. No `Flare`.

- [ ] **Step 2: Implement tap**

Add `@State private var shownBurntOut: FocusRecord.ID?`. Overlay the disc with `Color.clear.contentShape(Circle())` sized to `disc` and `.onTapGesture { location in ... }` (coordinate space of the overlay): pick the nearest burnt-out star within 22 pt, else set `nil`. Anchor a `.popover(item:)` with `.presentationCompactAdaptation(.popover)` at that star's position showing only `Text(record.task)` in `.serif(15)`, `Theme.paper`. Do not add hit targets when `burntOutStars` is empty.

- [ ] **Step 3: Accessibility**

Append to `accessibilitySummary`: when `n = progress.burntOutStars.count > 0`, `" ve \(n) sönmüş yıldız"`.

- [ ] **Step 4: Demo data**

In `DemoData`, add two `FocusRecord(..., completed: false, ...)` with tasks "Makale okuma" and "İngilizce kelime", 12 and 7 focused minutes, on days 3 and 9 before today.

- [ ] **Step 5: Verify**

Push; `ios.yml` must build. Fetch the `ci-screenshots` branch and look at the Home screenshot: two small grey ringed dots inside the disc, not overlapping a constellation or its label.

- [ ] **Step 6: Commit** — `git commit -m "Show burnt-out stars on the home sky"`

### Task 3: Session screen and copy

**Files:**
- Modify: `App/Model/AppModel.swift:128-133` (`abandon`)
- Modify: `App/Screens/Focus/ActiveSessionView.swift:86` (warning text)
- Modify: `App/Screens/Home/HomeView.swift:117` (first-run detail)

**Interfaces:**
- Consumes: `SkyProgress.abandon(_:) -> Bool`, `SkyProgress.abandonGrace` (Task 1).

- [ ] **Step 1: AppModel**

`abandon()` keeps calling `progress.abandon(...)` (result discarded) then `wrapUp()`; no other change.

- [ ] **Step 2: Warning text**

Inside the existing `TimelineView`, use `context.date.timeIntervalSince(s.start) < SkyProgress.abandonGrace` to choose between exactly:
- `"Şimdi vazgeçersen gökyüzünde iz kalmaz."`
- `"Vazgeçersen gökyüzüne sönmüş bir yıldız düşer, ama odaklandığın dakikalar yine de sayılır."`

Pass `context.date` (or the session) into the footer if the text is outside the `TimelineView` closure. Also change the hold button's `accessibilityHint` to `"Oturumu bitirir ve gökyüzüne sönmüş bir yıldız düşer"`.

- [ ] **Step 3: Home copy**

`"Tamamladığın her oturum gökyüzüne bir yıldız ekler. Vazgeçersen gökyüzüne sönmüş bir yıldız düşer ama odaklandığın dakikalar yine de sayılır."`

- [ ] **Step 4: Verify** — push; `ios.yml` build and tests green.

- [ ] **Step 5: Commit** — `git commit -m "Explain burnt-out stars on the session screen"`
