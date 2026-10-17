import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import Observation

/// App blocking through Apple's Screen Time API (FamilyControls, ManagedSettings, DeviceActivity).
///
/// It is compiled in only for the Screen Time build (project-screentime.yml), because App Store
/// distribution needs Apple's Family Controls approval. Without it the app still runs every session,
/// tracks whether the user left the app and pays out stars and Işık; it just cannot lock other apps.
@MainActor @Observable
final class ScreenTimeController {
    private(set) var isAuthorized = false

    var selection = FamilyActivitySelection() { didSet { SharedStore.selectionData = try? JSONEncoder().encode(selection) } }
    /// Apps that stay open even in "Tümü" mode (for example Spotify).
    var exemptions = FamilyActivitySelection() { didSet { SharedStore.exemptionData = try? JSONEncoder().encode(exemptions) } }
    @ObservationIgnored private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(SharedStore.storeName))
    static var isAvailable: Bool { BuildFlags.screenTime }

    init() {
        if let d = SharedStore.selectionData, let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: d) { selection = s }
        if let d = SharedStore.exemptionData, let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: d) { exemptions = s }
        #if SCREEN_TIME
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        #endif
    }

    /// "4 uygulama, 2 kategori"
    var selectionSummary: String {
        #if SCREEN_TIME
        var parts: [String] = []
        if !selection.applicationTokens.isEmpty { parts.append("\(selection.applicationTokens.count) uygulama") }
        if !selection.categoryTokens.isEmpty { parts.append("\(selection.categoryTokens.count) kategori") }
        if !selection.webDomainTokens.isEmpty { parts.append("\(selection.webDomainTokens.count) site") }
        return parts.isEmpty ? "Henüz seçilmedi" : parts.joined(separator: ", ")
        #else
        return "Ekran Süresi izni gerekiyor"
        #endif
    }

    var blockedCount: Int {
        #if SCREEN_TIME
        selection.applicationTokens.count + selection.categoryTokens.count
        #else
        0
        #endif
    }

    func requestAuthorization() async {
        #if SCREEN_TIME
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // The user declined or the entitlement is missing; blocking stays off.
        }
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        #endif
    }

    func begin(mode: BlockMode, strict: Bool, until end: Date) {
        SharedStore.shieldAttempts = 0
        #if SCREEN_TIME
        guard isAuthorized, mode != .none else { return }
        switch mode {
        case .selected:
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        case .all:
            store.shield.applicationCategories = .all(except: exemptions.applicationTokens)
            store.shield.webDomainCategories = .all()
        case .none:
            break
        }
        if strict { store.application.denyAppRemoval = true }
        SharedStore.sessionEnd = end
        schedule(until: end)
        #endif
    }

    /// Moves the automatic unlock when a break pushes the end time.
    func extend(until end: Date) {
        #if SCREEN_TIME
        guard SharedStore.sessionEnd != nil else { return }
        SharedStore.sessionEnd = end
        schedule(until: end)
        #endif
    }

    func end() {
        #if SCREEN_TIME
        store.clearAllSettings()
        DeviceActivityCenter().stopMonitoring([DeviceActivityName(SharedStore.activityName)])
        SharedStore.sessionEnd = nil
        #endif
    }

    /// Shields left over from a session that ended while the app was closed.
    func clearIfExpired(now: Date = .now) {
        #if SCREEN_TIME
        if let end = SharedStore.sessionEnd, end <= now { self.end() }
        #endif
    }

    #if SCREEN_TIME
    private func schedule(until end: Date) {
        // The monitor extension lifts the shields at the end even if the app is closed.
        // DeviceActivity needs at least 15 minutes; shorter sessions are unlocked by the app itself.
        let cal = Calendar.current
        let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(intervalStart: cal.dateComponents(comps, from: .now),
                                              intervalEnd: cal.dateComponents(comps, from: end), repeats: false)
        let center = DeviceActivityCenter()
        center.stopMonitoring([DeviceActivityName(SharedStore.activityName)])
        try? center.startMonitoring(DeviceActivityName(SharedStore.activityName), during: schedule)
    }
    #endif
}

enum BuildFlags {
    #if SCREEN_TIME
    static let screenTime = true
    #else
    static let screenTime = false
    #endif
}
