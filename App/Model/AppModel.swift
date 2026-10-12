import Foundation
import Observation
import OdakCore
import UIKit

/// The app's single source of truth: progress (stars, Işık, collection), the running session and
/// the services around it. Saved to Application Support as JSON after every change.
@MainActor @Observable
final class AppModel {
    var progress: SkyProgress { didSet { persist(progress, to: "progress.json") } }
    var settings: FocusSettings { didSet { persist(settings, to: "settings.json") } }
    private(set) var session: FocusSession? { didSet { persist(session, to: "session.json") } }
    /// Set when a session completes; drives the reward screens.
    var summary: SessionSummary? = nil
    var toast: String? = nil

    let screenTime = ScreenTimeController()
    let sounds = SoundEngine()
    let spotify = SpotifyService()
    let store = SubscriptionStore()

    @ObservationIgnored private var awaySince: Date?
    @ObservationIgnored private var lockedWhileAway = false
    @ObservationIgnored private var expectingHandOff = false
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()

    init() {
        if Demo.isOn {
            progress = Demo.progress()
            settings = FocusSettings(task: "Tez · Bölüm 3 literatür", ambient: ["rain": 0.3])
            session = nil
        } else {
            progress = Self.load(SkyProgress.self, from: "progress.json") ?? SkyProgress()
            settings = Self.load(FocusSettings.self, from: "settings.json") ?? FocusSettings()
            session = Self.load(FocusSession.self, from: "session.json")
        }
        sounds.restore(settings.ambient)
        store.start()
        screenTime.clearIfExpired()
        progress.reconcileClouds(now: .now)
        if !Demo.isOn { LiveActivityController.sync(session) }
        NotificationCenter.default.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lockedWhileAway = true }
        }
    }

    var isZenit: Bool { store.isSubscribed }
    var now: Date { .now }

    func canUse(_ sound: SoundID) -> Bool { isZenit || progress.ownedSounds.contains(sound) }
    func canUse(_ theme: SkyTheme) -> Bool { isZenit || progress.ownedThemes.contains(theme) }

    var streak: Int { progress.streak(on: .now) }
    var todayMinutes: Int { progress.stats(.day, now: .now).minutes }

    // MARK: - Session lifecycle

    func startSession() {
        let s = FocusSession(task: settings.task.trimmingCharacters(in: .whitespaces), minutes: settings.minutes,
                             strict: settings.strict, blockMode: settings.blockMode, silenceCalls: settings.silenceCalls)
        session = s
        screenTime.begin(mode: s.blockMode, strict: s.strict, until: s.end)
        Notifications.scheduleSessionEnd(at: s.end, task: s.task)
        LiveActivityController.start(s)
        Task { await Notifications.requestPermission() }
        if !sounds.volumes.isEmpty { sounds.play() }
        if s.silenceCalls, settings.focusShortcutsReady {
            expectingHandOff = true
            FocusModeShortcuts.run(FocusModeShortcuts.startName)
        }
    }

    /// Called every second by the session screen and whenever the app comes back.
    func tick(now: Date = .now) {
        guard var s = session else { return }
        if s.isOnBreak, s.breakRemaining(at: now) <= 0 {
            s.endBreak(at: now)
            session = s
            screenTime.extend(until: s.end)
            Notifications.scheduleSessionEnd(at: s.end, task: s.task)
            LiveActivityController.update(s, now: now)
        }
        if s.remaining(at: now) <= 0 { finish(at: s.end) }
    }

    func startBreak() {
        guard var s = session, !s.breakUsed else { return }
        s.startBreak(at: .now)
        session = s
        Notifications.cancelSessionEnd()
        LiveActivityController.update(s)
    }

    func endBreak() {
        guard var s = session else { return }
        s.endBreak(at: .now)
        session = s
        screenTime.extend(until: s.end)
        Notifications.scheduleSessionEnd(at: s.end, task: s.task)
        LiveActivityController.update(s)
    }

    func abandon() {
        guard let s = session else { return }
        let now = Date.now
        progress.abandon(input(for: s, end: now))
        wrapUp()
    }

    private func finish(at end: Date) {
        guard let s = session else { return }
        var p = progress
        summary = p.complete(input(for: s, end: end), rng: &rng)
        progress = p
        wrapUp()
    }

    private func input(for s: FocusSession, end: Date) -> FocusInput {
        FocusInput(task: s.task.isEmpty ? "Odak" : s.task, start: s.start, end: end, plannedMinutes: s.plannedMinutes,
                   focusedMinutes: s.focusedMinutes(at: end), strict: s.strict,
                   lookedAway: s.lookAways > 0 || SharedStore.shieldAttempts > 0)
    }

    private func wrapUp() {
        let s = session
        session = nil
        screenTime.end()
        Notifications.cancelSessionEnd()
        LiveActivityController.end()
        if settings.stopMusicAtEnd {
            sounds.stop()
            Task { await spotify.pause() }
        }
        if s?.silenceCalls == true, settings.focusShortcutsReady {
            expectingHandOff = true
            FocusModeShortcuts.run(FocusModeShortcuts.endName)
        }
    }

    /// Opening Spotify or Shortcuts from the app does not count as looking at the phone.
    func handOff() { expectingHandOff = true }

    // MARK: - Leaving the app during a session

    func didEnterBackground() {
        guard session != nil else { return }
        awaySince = .now
        lockedWhileAway = false
    }

    func didBecomeActive() {
        defer { awaySince = nil; expectingHandOff = false }
        screenTime.clearIfExpired()
        tick()
        guard var s = session, let away = awaySince else { return }
        // Locking the phone is fine; switching to another app is "looking at the phone".
        if !lockedWhileAway, !expectingHandOff, !s.isOnBreak, Date.now.timeIntervalSince(away) > 3 {
            s.lookAways += 1
            s.lastReturn = .now
            session = s
        }
    }

    /// Işık earned so far, for the live counter on the session screen.
    func liveLight(at now: Date) -> Int {
        guard let s = session else { return 0 }
        return LightRules.ledger(minutes: s.focusedMinutes(at: now), noLook: s.lookAways == 0 && SharedStore.shieldAttempts == 0,
                                 streakDays: max(1, streak + (progress.stats(.day, now: now).sessions == 0 ? 1 : 0)),
                                 strict: s.strict, doubled: progress.armedShootingStar).total
    }

    /// Estimate shown on the setup screen before starting.
    var estimatedLight: Int {
        LightRules.ledger(minutes: settings.minutes, noLook: true, streakDays: max(1, streak + (todayMinutes == 0 ? 1 : 0)),
                          strict: settings.strict, doubled: progress.armedShootingStar).total
    }

    // MARK: - Shop and promises

    func buy(_ item: ShopItem) {
        do {
            try progress.buy(item)
            toast = "Satın alındı"
        } catch ShopError.notEnoughLight {
            toast = "Yeterli Işığın yok"
        } catch ShopError.limitReached {
            toast = "Bundan en fazla bu kadar taşıyabilirsin"
        } catch {
            toast = nil
        }
    }

    func addPromise(title: String, goal: SelfPromise.Goal) -> Bool {
        do {
            try progress.addPromise(SelfPromise(title: title, goal: goal, createdAt: .now, baselineMinutes: progress.totalFocusedMinutes),
                                    unlimited: isZenit)
            return true
        } catch {
            return false
        }
    }

    func selectTheme(_ t: SkyTheme) {
        guard canUse(t) else { return }
        progress.selectedTheme = t
    }

    func setAlternateIcon(_ on: Bool) {
        guard progress.ownsAppIcon || isZenit else { return }
        UIApplication.shared.setAlternateIconName(on ? "AppIconDawn" : nil)
    }

    func resetAll() {
        progress = SkyProgress()
        session = nil
        screenTime.end()
        LiveActivityController.end()
    }

    // MARK: - Screenshot mode

    /// Puts the app on the screen named by `-screen` (see Demo).
    func applyDemoScreen() {
        guard Demo.isOn, let screen = Demo.screen else { return }
        let now = Date.now
        switch screen {
        case "active", "sounds":
            var s = FocusSession(task: settings.task, minutes: 45, strict: false, blockMode: .selected, silenceCalls: true,
                                 now: now.addingTimeInterval(-(12 * 60 + 46)))
            s.lastReturn = s.start
            settings.focusShortcutsReady = true
            session = s
        case "reward":
            var p = Demo.progress(now: now, saiphLit: false)
            p.telescopeTarget = Catalog.constellation("orion")?.stars.first { $0.name == "Saiph" }?.id
            var rng = SeededGenerator(seed: 6)
            let end = now
            summary = p.complete(FocusInput(task: settings.task, start: end.addingTimeInterval(-45 * 60), end: end, plannedMinutes: 45,
                                            focusedMinutes: 45, strict: false, lookedAway: false), rng: &rng)
            progress = p
        case "constellation":
            var p = Demo.progress(now: now)
            p.telescopeTarget = Catalog.constellation("orion")?.stars.first { $0.name == "Betelgeuse" }?.id
            var rng = SeededGenerator(seed: 6)
            summary = p.complete(FocusInput(task: settings.task, start: now.addingTimeInterval(-60 * 60), end: now, plannedMinutes: 60,
                                            focusedMinutes: 60, strict: false, lookedAway: false), rng: &rng)
            progress = p
        case "deepsky":
            progress.deepSky["m42"] = now
            progress.ownedThemes.insert(.nebula)
        case "journey":
            var p = progress
            for c in Catalog.constellations {
                for s in c.stars { p.litStars[s.id] = now }
                if !p.completedConstellations.contains(c.id) { p.completedConstellations.append(c.id) }
            }
            p.openConstellations = []
            p.journeyStartMinutes = p.totalFocusedMinutes - 156
            progress = p
        default:
            break
        }
    }

    // MARK: - Storage

    private static var folder: URL {
        let url = URL.applicationSupportDirectory.appending(path: "Derin", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: folder.appending(path: name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func persist<T: Encodable>(_ value: T?, to name: String) {
        guard !Demo.isOn else { return }
        let url = Self.folder.appending(path: name)
        guard let value, let data = try? JSONEncoder().encode(value) else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
