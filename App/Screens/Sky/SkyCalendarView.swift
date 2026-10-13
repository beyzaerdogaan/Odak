import OdakCore
import SwiftUI

/// "Gökyüzü takvimi": the coming year's sky events. A ribbon across the months shows when each
/// shower is active, then the events follow month by month with their peak night, how full the
/// Moon will be and a reminder for the peak.
struct SkyCalendarView: View {
    @State private var reminded: Set<String> = []

    private let cal = Calendar.current
    private let now = Date.now

    private var months: [Date] {
        let first = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        return (0..<12).compactMap { cal.date(byAdding: .month, value: $0, to: first) }
    }

    private var events: [SkyEvent] {
        guard let first = months.first, let last = months.last,
              let end = cal.date(byAdding: .month, value: 1, to: last) else { return [] }
        return MeteorShowers.schedule(from: max(first, cal.startOfDay(for: now)), to: end, calendar: cal)
    }

    var body: some View {
        let events = events
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                YearRibbon(months: months, events: events, now: now)
                    .padding(.top, 8)
                ForEach(months, id: \.self) { month in
                    let inMonth = events.filter { cal.isDate($0.peakNight, equalTo: month, toGranularity: .month) }
                    if !inMonth.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(monthTitle(month)).font(.serif(22)).foregroundStyle(Theme.paper)
                            ForEach(inMonth) { e in row(e) }
                        }
                    }
                }
                Text("Tarihler Uluslararası Meteor Örgütü'nün (IMO) yıllık takviminden. Saatte görülen meteor sayısı, şehir ışıklarından uzak, karanlık bir gökyüzü için.")
                    .font(.system(size: 12)).foregroundStyle(Theme.paper3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
        }
        .pinnedHeader { BackHeader(title: "Gökyüzü takvimi", subtitle: nil) }
        .background(StarField(seed: 47, count: 90, grid: false))
        .toolbar(.hidden, for: .navigationBar)
    }

    private func row(_ e: SkyEvent) -> some View {
        let tint = MeteorStyle(e.shower).tint
        let comps = cal.dateComponents([.day, .month], from: e.peakNight)
        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text("\(comps.day ?? 1)").font(.serif(26)).foregroundStyle(Theme.paper).monospacedDigit()
                Text(MeteorShower.monthNames[(comps.month ?? 1) - 1].prefix(3).uppercased(with: Locale(identifier: "tr_TR")))
                    .font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(tint)
            }
            .frame(width: 46, height: 58)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.3)))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(e.shower.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.paper)
                    Spacer(minLength: 0)
                    Text(status(e)).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(e.contains(now) ? Theme.onAccent : tint)
                        .padding(.horizontal, 8).frame(height: 22)
                        .background(e.contains(now) ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.12)), in: Capsule())
                }
                Text("Zirve \(e.peakText(calendar: cal)) · \(e.shower.radiant) yönü")
                    .font(.system(size: 13)).foregroundStyle(Theme.paper2)
                HStack(spacing: 6) {
                    MoonGlyph(phase: Moon.phase(at: e.peak)).frame(width: 13, height: 13)
                    Text(moonText(e.moon) + (e.zhr.map { " · saatte ~\($0) meteor" } ?? ""))
                        .font(.system(size: 12)).foregroundStyle(Theme.paper3)
                    Spacer(minLength: 0)
                    Button {
                        guard let at = e.reminderDate(calendar: cal) else { return }
                        Task { await Notifications.remindPeak(name: e.shower.name, at: at); reminded.insert(e.id) }
                    } label: {
                        Image(systemName: reminded.contains(e.id) ? "bell.fill" : "bell")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(reminded.contains(e.id))
                    .accessibilityLabel(reminded.contains(e.id) ? "Hatırlatma kuruldu" : "Zirve gecesi için hatırlat")
                }
            }
        }
        .plate(radius: 20, padding: 12)
    }

    private func status(_ e: SkyEvent) -> String {
        if e.contains(now) { return "Sürüyor" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: e.start).day ?? 0
        return days <= 1 ? "Yarın" : "\(days) gün sonra"
    }

    private func moonText(_ moon: Int) -> String {
        moon >= 70 ? "Ay %\(moon), parlak" : moon <= 30 ? "Ay %\(moon), karanlık gök" : "Ay %\(moon)"
    }

    private func monthTitle(_ month: Date) -> String {
        let c = cal.dateComponents([.year, .month], from: month)
        return "\(MeteorShower.monthNames[(c.month ?? 1) - 1]) \(c.year ?? 0)"
    }
}

/// Twelve months side by side, each shower a coloured band across the days it is active, a bright
/// tick on its peak and a gold line for today: the year's sky at a glance.
private struct YearRibbon: View {
    let months: [Date]
    let events: [SkyEvent]
    let now: Date

    private let cal = Calendar.current

    var body: some View {
        let lanes = laneAssignment()
        let laneCount = max(1, (lanes.values.max() ?? 0) + 1)
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let span = interval
                let x: (Date) -> CGFloat = { d in
                    CGFloat(d.timeIntervalSince(span.start) / span.duration) * w
                }
                ZStack(alignment: .topLeading) {
                    ForEach(Array(months.enumerated()), id: \.offset) { i, m in
                        Rectangle().fill(i.isMultiple(of: 2) ? Theme.plate : .clear)
                            .frame(width: max(0, x(next(m)) - x(m)))
                            .offset(x: x(m))
                    }
                    ForEach(events) { e in
                        let tint = MeteorStyle(e.shower).tint
                        let x0 = max(0, x(e.start)), x1 = min(w, x(e.end))
                        let y = CGFloat(lanes[e.id] ?? 0) * 14 + 8
                        Capsule().fill(tint.opacity(0.55))
                            .frame(width: max(4, x1 - x0), height: 6)
                            .offset(x: x0, y: y)
                        Circle().fill(tint).frame(width: 9, height: 9)
                            .shadow(color: tint.opacity(0.8), radius: 4)
                            .offset(x: x(e.peak) - 4.5, y: y - 1.5)
                    }
                    Rectangle().fill(Theme.accent).frame(width: 1.5)
                        .offset(x: x(now))
                }
            }
            .frame(height: CGFloat(laneCount) * 14 + 14)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 0) {
                ForEach(months, id: \.self) { m in
                    Text(MeteorShower.monthNames[cal.component(.month, from: m) - 1].prefix(1))
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.paper3)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .plate(radius: 20, padding: 14)
        .accessibilityHidden(true)
    }

    private var interval: DateInterval {
        let start = months.first ?? now
        return DateInterval(start: start, end: months.last.map(next) ?? now)
    }

    private func next(_ month: Date) -> Date { cal.date(byAdding: .month, value: 1, to: month) ?? month }

    /// Overlapping showers (Orionidler and Leonidler, say) go on separate lanes.
    private func laneAssignment() -> [String: Int] {
        var laneEnds: [Date] = []
        var result: [String: Int] = [:]
        for e in events.sorted(by: { $0.start < $1.start }) {
            if let free = laneEnds.firstIndex(where: { $0 <= e.start }) {
                laneEnds[free] = e.end; result[e.id] = free
            } else {
                laneEnds.append(e.end); result[e.id] = laneEnds.count - 1
            }
        }
        return result
    }
}

/// The Moon at a given phase: the lit part between the limb and the terminator, the rest a faint disc.
struct MoonGlyph: View {
    let phase: Double

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Theme.paper3.opacity(0.35)))
            let waxing = phase < 0.5
            // Terminator offset as a fraction of the half-width at each height.
            let t = waxing ? cos(2 * .pi * phase) : -cos(2 * .pi * phase)
            let limb: Double = waxing ? 1 : -1
            var lit = Path()
            let steps = 24
            for i in 0...steps {
                let y = -1 + 2 * Double(i) / Double(steps)
                let s = sqrt(max(0, 1 - y * y))
                let p = CGPoint(x: c.x + CGFloat(limb * s) * r, y: c.y + CGFloat(y) * r)
                i == 0 ? lit.move(to: p) : lit.addLine(to: p)
            }
            for i in stride(from: steps, through: 0, by: -1) {
                let y = -1 + 2 * Double(i) / Double(steps)
                let s = sqrt(max(0, 1 - y * y))
                lit.addLine(to: CGPoint(x: c.x + CGFloat(t * s) * r, y: c.y + CGFloat(y) * r))
            }
            lit.closeSubpath()
            ctx.fill(lit, with: .color(Theme.paper))
        }
        .accessibilityHidden(true)
    }
}
