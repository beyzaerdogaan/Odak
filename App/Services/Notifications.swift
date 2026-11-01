import Foundation
import OdakCore
import UserNotifications

/// Local notifications: the end of a session and meteor shower peak nights.
enum Notifications {
    static let sessionID = "derin.session.end"

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func scheduleSessionEnd(at date: Date, task: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Yıldızın hazır")
        content.body = task.isEmpty ? String(localized: "Odak süren doldu. Hangi yıldızı yaktığını gör.") : String(localized: "\(task) için odak süren doldu. Hangi yıldızı yaktığını gör.")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: sessionID, content: content, trigger: trigger))
    }

    static func cancelSessionEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [sessionID])
    }

    /// A reminder for an eclipse, planet event or supermoon from the sky calendar.
    static func remind(_ event: SkyEvent, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.astro?.tip ?? String(localized: "Gökyüzüne bakma zamanı.")
        await scheduleSky(id: "derin.sky.\(event.id)", content: content, at: date)
    }

    static func remindPeak(name: String, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(name) zirvede")
        content.body = String(localized: "Bu gece meteor yağmurunun zirvesi var. Şehir ışıklarından uzakta, gece yarısından sonra gökyüzüne bak.")
        await scheduleSky(id: "derin.peak.\(name)", content: content, at: date)
    }

    /// Sky reminders fire after a fixed number of seconds rather than on matching calendar fields,
    /// so a reminder can only ever arrive at the moment it was set for, never on some other day.
    private static func scheduleSky(id: String, content: UNMutableNotificationContent, at date: Date) async {
        guard date > .now else { return }
        await requestPermission()
        content.sound = .default
        content.userInfo["at"] = date.timeIntervalSince1970
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Builds before this fix set sky reminders as calendar triggers, and one of those reached a phone
    /// eleven days after the Orionid peak it was meant for. At launch, each such reminder still pending
    /// is moved to a timer if its date is ahead and iOS agrees on when it fires, and dropped otherwise.
    static func repairSkyReminders() async {
        let center = UNUserNotificationCenter.current()
        var stale: [String] = []
        for request in await center.pendingNotificationRequests()
        where request.identifier.hasPrefix("derin.peak.") || request.identifier.hasPrefix("derin.sky.") {
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { continue }
            let comps = trigger.dateComponents
            if comps.year != nil, let at = Calendar.current.date(from: comps), at > .now,
               let next = trigger.nextTriggerDate(), abs(next.timeIntervalSince(at)) < 60,
               let content = request.content.mutableCopy() as? UNMutableNotificationContent {
                content.userInfo["at"] = at.timeIntervalSince1970
                let timer = UNTimeIntervalNotificationTrigger(timeInterval: max(1, at.timeIntervalSinceNow), repeats: false)
                try? await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: timer))
            } else {
                stale.append(request.identifier)
            }
        }
        if !stale.isEmpty { center.removePendingNotificationRequests(withIdentifiers: stale) }
    }
}
