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
        guard date > .now else { return }
        await requestPermission()
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.astro?.tip ?? String(localized: "Gökyüzüne bakma zamanı.")
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "derin.sky.\(event.id)", content: content, trigger: trigger))
    }

    static func remindPeak(name: String, at date: Date) async {
        guard date > .now else { return }
        await requestPermission()
        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(name) zirvede")
        content.body = String(localized: "Bu gece meteor yağmurunun zirvesi var. Şehir ışıklarından uzakta, gece yarısından sonra gökyüzüne bak.")
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "derin.peak.\(name)", content: content, trigger: trigger))
    }
}
