import Foundation
import OdakCore

/// Screenshot mode: `-demo -screen <name>` launches the app with the sky from the design
/// (Büyük Ayı done, Avcı 6/7, Kassiopeia 2/5, 1.440 Işık, 6-day streak) and opens one screen.
/// Nothing is saved in this mode. CI uses it to photograph every screen in light and dark.
enum Demo {
    static let arguments = ProcessInfo.processInfo.arguments
    static var isOn: Bool { arguments.contains("-demo") }
    static var screen: String? {
        guard let i = arguments.firstIndex(of: "-screen"), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    static func progress(now: Date = .now, saiphLit: Bool = true) -> SkyProgress {
        var p = SkyProgress()
        let cal = Calendar.current
        func lit(_ c: String, _ names: [String]) {
            guard let con = Catalog.constellation(c) else { return }
            for s in con.stars where names.isEmpty || names.contains(s.name) { p.litStars[s.id] = now }
        }
        lit("ursa-major", [])
        lit("orion", ["Bellatrix", "Alnitak", "Alnilam", "Mintaka", "Rigel"] + (saiphLit ? ["Saiph"] : []))
        lit("cassiopeia", ["Caph", "Schedar"])
        p.completedConstellations = ["ursa-major"]
        p.openConstellations = ["orion", "cassiopeia", "cygnus"]
        lit("cygnus", ["Deneb", "Sadr", "Gienah"])
        // 23 hours over the last weeks, one session a day for the last 6 days.
        var records: [FocusRecord] = []
        for d in 0..<30 {
            let end = cal.date(byAdding: .day, value: -d, to: cal.date(bySettingHour: 20, minute: 0, second: 0, of: now)!)!
            if d >= 6 && d % 3 != 1 { continue }
            if d == 0 { continue }
            let minutes = d < 6 ? 45 : 90
            records.append(FocusRecord(task: "Tez", start: end.addingTimeInterval(TimeInterval(-minutes * 60)), end: end,
                                       plannedMinutes: minutes, focusedMinutes: minutes, completed: true, strict: false,
                                       lookedAway: d % 4 == 0, light: minutes))
        }
        let today = cal.date(bySettingHour: 9, minute: 30, second: 0, of: now)!
        records.append(FocusRecord(task: "Okuma", start: today.addingTimeInterval(-70 * 60), end: today, plannedMinutes: 70,
                                   focusedMinutes: 70, completed: true, strict: false, lookedAway: false, light: 84))
        p.records = records.sorted { $0.end < $1.end }
        let target = 23 * 60
        let extra = target - p.totalFocusedMinutes
        if extra > 0, let first = p.records.first {
            p.records.insert(FocusRecord(task: "Tez", start: first.start.addingTimeInterval(-86400 * 10), end: first.start.addingTimeInterval(-86400 * 10 + Double(extra * 60)),
                                         plannedMinutes: extra, focusedMinutes: extra, completed: true, strict: false, lookedAway: true), at: 0)
        }
        p.light = 1440
        p.badges = [Badge.firstLight.rawValue: now, Badge.marathon90.rawValue: now]
        p.deepSky = [:]
        p.promises = [
            SelfPromise(title: "Yeni bir kitap al", goal: .focusHours(10), createdAt: now, baselineMinutes: p.totalFocusedMinutes - 9 * 60),
            SelfPromise(title: "Hafta sonu kahvaltıya çık", goal: .constellation("cygnus"), createdAt: now, baselineMinutes: 0),
        ]
        if let shower = MeteorShowers.active(on: now) { p.meteorProgress[shower.seasonKey(for: now)] = 4 }
        return p
    }
}
