import OdakCore
import SwiftUI

/// "Gökyüzü takvimi": a real calendar of the sky, by month or by week. Each day shows the events on
/// it in their own colour: a shower's active days as a soft band with its peak night filled, an
/// eclipse or planet event as a dot. Below the calendar the period's events follow as cards with
/// when to look, how full the Moon will be and a reminder; tapping a day narrows them to that day.
struct SkyCalendarView: View {
    enum Mode: String, CaseIterable {
        case month = "Ay", week = "Hafta"
        var title: String { self == .month ? String(localized: "Ay") : String(localized: "Hafta") }
    }

    @State private var reminded: Set<String> = []
    @State private var mode: Mode = .month
    /// The first day of the month or week on screen.
    @State private var anchor: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    @State private var selected: Date?

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // Pazartesi
        return c
    }
    private let now = Date.now

    /// Everything from this month to the end of the data, so paging needs no reload.
    private var events: [SkyEvent] {
        let first = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let end = cal.date(byAdding: .month, value: 27, to: first) ?? now
        return MeteorShowers.schedule(from: first, to: end, calendar: cal)
    }

    private var period: DateInterval {
        let unit: Calendar.Component = mode == .month ? .month : .weekOfYear
        return cal.dateInterval(of: unit, for: anchor) ?? DateInterval(start: anchor, duration: 86_400)
    }

    var body: some View {
        let events = events
        let period = period
        let shown = events.filter { e in
            if let selected { return occurs(e, on: selected) }
            return e.day >= period.start && e.day < period.end || (e.shower != nil && e.start < period.end && e.end > period.start)
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Görünüm", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.top, 8)
                .onChange(of: mode) { _, new in
                    selected = nil
                    let unit: Calendar.Component = new == .month ? .month : .weekOfYear
                    let focus = new == .week && cal.isDate(now, equalTo: anchor, toGranularity: .month) ? now : anchor
                    anchor = cal.dateInterval(of: unit, for: focus)?.start ?? anchor
                }

                VStack(spacing: 12) {
                    pager(period)
                    weekdayHeader
                    let days = mode == .month ? monthDays(period) : weekDays(period)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                        ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                            if let day { dayCell(day, events: events) } else { Color.clear.frame(height: cellHeight) }
                        }
                    }
                }
                .plate(radius: 22, padding: 14)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(selected.map(dayTitle) ?? (mode == .month ? String(localized: "Bu ay") : String(localized: "Bu hafta")))
                            .font(.serif(22)).foregroundStyle(Theme.paper)
                        Spacer()
                        if selected != nil {
                            Button("Tümü") { selected = nil }.font(.system(size: 13, weight: .semibold)).tint(Theme.accent)
                        }
                    }
                    if shown.isEmpty {
                        Text("Bu tarihlerde bir gökyüzü etkinliği yok.").font(.system(size: 14)).foregroundStyle(Theme.paper3)
                    }
                    ForEach(shown) { e in row(e) }
                }

                Text("Meteor yağmurları Uluslararası Meteor Örgütü'nün (IMO) yıllık takviminden, tutulmalar ise NASA'nın tutulma tablolarından alındı. Gezegen olayları ve saatler Türkiye'den görüldüğü gibi hesaplandı. Saatte görülen meteor sayısı karanlık bir gökyüzü için geçerlidir.")
                    .font(.system(size: 12)).foregroundStyle(Theme.paper3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
        }
        .pinnedHeader { BackHeader(title: String(localized: "Gökyüzü takvimi"), subtitle: nil) }
        .background(StarField(seed: 47, count: 90, grid: false))
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Calendar grid

    private var cellHeight: CGFloat { mode == .month ? 48 : 86 }

    private func pager(_ period: DateInterval) -> some View {
        let unit: Calendar.Component = mode == .month ? .month : .weekOfYear
        return HStack {
            Button { step(-1, unit) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }
                .accessibilityLabel("Önceki")
            Spacer()
            Text(periodTitle(period)).font(.serif(20)).foregroundStyle(Theme.paper)
            Spacer()
            Button { step(1, unit) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }
                .accessibilityLabel("Sonraki")
        }
        .font(.system(size: 15, weight: .semibold))
        .tint(Theme.accent)
    }

    private func step(_ by: Int, _ unit: Calendar.Component) {
        selected = nil
        anchor = cal.date(byAdding: unit, value: by, to: anchor) ?? anchor
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(AppLanguage.isEnglish ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] : ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"], id: \.self) { d in
                Text(d).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.paper3).frame(maxWidth: .infinity)
            }
        }
    }

    /// The month's days, padded with blanks so the 1st lands on its weekday.
    private func monthDays(_ period: DateInterval) -> [Date?] {
        let lead = (cal.component(.weekday, from: period.start) - cal.firstWeekday + 7) % 7
        let count = cal.range(of: .day, in: .month, for: period.start)?.count ?? 30
        let days: [Date?] = (0..<count).map { cal.date(byAdding: .day, value: $0, to: period.start) }
        return Array(repeating: nil, count: lead) + days
    }

    private func weekDays(_ period: DateInterval) -> [Date?] {
        (0..<7).map { cal.date(byAdding: .day, value: $0, to: period.start) }
    }

    private func occurs(_ e: SkyEvent, on day: Date) -> Bool {
        if e.shower != nil { return e.contains(cal.date(byAdding: .hour, value: 12, to: cal.startOfDay(for: day)) ?? day) }
        return cal.isDate(e.day, inSameDayAs: day)
    }

    private func dayCell(_ day: Date, events: [SkyEvent]) -> some View {
        let here = events.filter { occurs($0, on: day) }
        let showers = here.filter { $0.shower != nil }
        // A peak night runs from one evening into the next morning, so it marks both days:
        // the evening it begins in full, the morning it ends in a lighter tone.
        let peaks = showers.filter { cal.isDate($0.day, inSameDayAs: day) }
        let peakMornings = showers.filter { e in
            cal.date(byAdding: .day, value: 1, to: e.day).map { cal.isDate($0, inSameDayAs: day) } ?? false
        }
        let astro = here.filter { $0.astro != nil }
        let isToday = cal.isDateInToday(day)
        let isSelected = selected.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let band = showers.first.map(Self.tint)
        let peak = peaks.first.map(Self.tint) ?? peakMornings.first.map { Self.tint($0).opacity(0.55) }
        return Button {
            selected = isSelected ? nil : day
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 15, weight: isToday || peak != nil ? .bold : .regular)).monospacedDigit()
                    .foregroundStyle(peak != nil ? Theme.onAccent : Theme.paper)
                    .frame(width: 30, height: 30)
                    .background { if let peak { Circle().fill(peak) } }
                    .overlay { if isToday { Circle().strokeBorder(Theme.accent, lineWidth: 1.5) } }
                if mode == .week {
                    VStack(spacing: 2) {
                        // Only the peak night and one-night events get a name; the rest of a shower's
                        // weeks-long active window is the colour band alone.
                        ForEach((peaks + peakMornings + astro).prefix(3)) { e in
                            Text(e.shower?.name ?? AstroEventView.kindName(e.astro?.kind))
                                .font(.system(size: 9, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                                .foregroundStyle(Self.tint(e))
                        }
                    }
                } else {
                    HStack(spacing: 3) {
                        ForEach(astro.prefix(3)) { e in Circle().fill(Self.tint(e)).frame(width: 5, height: 5) }
                    }
                    .frame(height: 5)
                }
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight, alignment: .top)
            .padding(.top, 4)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(band.map { $0.opacity(0.14) } ?? .clear)
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.paper2, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayTitle(day) + (here.isEmpty ? "" : ", " + here.map(\.title).joined(separator: ", ")))
    }

    private func periodTitle(_ p: DateInterval) -> String {
        if mode == .month { return monthTitle(p.start) }
        let last = cal.date(byAdding: .day, value: 6, to: p.start) ?? p.start
        let a = cal.dateComponents([.day, .month], from: p.start), b = cal.dateComponents([.day, .month], from: last)
        return AppLanguage.dayRange((a.day ?? 1, a.month ?? 1), (b.day ?? 1, b.month ?? 1))
    }

    private func dayTitle(_ day: Date) -> String {
        let c = cal.dateComponents([.day, .month], from: day)
        return AppLanguage.dayMonth(day: c.day ?? 1, month: c.month ?? 1)
    }

    private func row(_ e: SkyEvent) -> some View {
        let tint = Self.tint(e)
        let comps = cal.dateComponents([.day, .month], from: e.day)
        return NavigationLink(value: e.shower.map { Route.meteor($0.id) } ?? Route.astro(e.id)) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Text("\(comps.day ?? 1)").font(.serif(26)).foregroundStyle(Theme.paper).monospacedDigit()
                    Text(MeteorShower.monthNames[(comps.month ?? 1) - 1].prefix(3).uppercased(with: AppLanguage.locale))
                        .font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(tint)
                }
                .frame(width: 46, height: 58)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.3)))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(e.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.paper)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Text(status(e)).font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(e.contains(now) ? Theme.onAccent : tint)
                            .padding(.horizontal, 8).frame(height: 22)
                            .background(e.contains(now) ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.12)), in: Capsule())
                    }
                    Text(subtitle(e)).font(.system(size: 13)).foregroundStyle(Theme.paper2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        MoonGlyph(phase: Moon.phase(at: e.peak)).frame(width: 13, height: 13)
                        Text(footnote(e)).font(.system(size: 12)).foregroundStyle(Theme.paper3)
                        Spacer(minLength: 0)
                        Color.clear.frame(width: 32, height: 32) // room for the bell, laid over the link

                    }
                }
            }
            .plate(radius: 20, padding: 12)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) { bell(e, tint: tint).padding(12) }
    }

    private func bell(_ e: SkyEvent, tint: Color) -> some View {
        let at = e.reminderDate(calendar: cal)
        let done = reminded.contains(e.id)
        return Button {
            guard let at else { return }
            Task {
                if let shower = e.shower { await Notifications.remindPeak(name: shower.name, at: at) }
                else { await Notifications.remind(e, at: at) }
                reminded.insert(e.id)
            }
        } label: {
            Image(systemName: done ? "bell.fill" : "bell")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(done)
        .opacity((at ?? .distantPast) > now ? 1 : 0)
        .allowsHitTesting((at ?? .distantPast) > now)
        .accessibilityHidden((at ?? .distantPast) <= now)
        .accessibilityLabel(done ? "Hatırlatma kuruldu" : "Hatırlat")
    }

    private func subtitle(_ e: SkyEvent) -> String {
        if let shower = e.shower { return String(localized: "Zirve \(e.whenText(calendar: cal)) · \(shower.radiant) yönü") }
        return "\(AstroEventView.kindName(e.astro?.kind)) · \(e.whenText(calendar: cal))"
    }

    private func footnote(_ e: SkyEvent) -> String {
        if e.shower != nil { return moonText(e.moon) + (e.zhr.map { String(localized: " · saatte ~\($0) meteor") } ?? "") }
        if e.astro?.kind == .solarEclipse { return String(localized: "Ay, Güneş'in önünden geçiyor") }
        return moonText(e.moon)
    }

    static func tint(_ e: SkyEvent) -> Color {
        if let shower = e.shower { return MeteorStyle(shower).tint }
        return e.astro.map(AstroStyle.tint) ?? Theme.meteor
    }

    private func status(_ e: SkyEvent) -> String {
        if e.contains(now) { return e.shower != nil ? String(localized: "Sürüyor") : String(localized: "Bugün") }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: e.start).day ?? 0
        return days <= 1 ? String(localized: "Yarın") : String(localized: "\(days) gün sonra")
    }

    private func moonText(_ moon: Int) -> String {
        moon >= 70 ? String(localized: "Ay %\(moon), parlak") : moon <= 30 ? String(localized: "Ay %\(moon), karanlık gök") : String(localized: "Ay %\(moon)")
    }

    private func monthTitle(_ month: Date) -> String {
        let c = cal.dateComponents([.year, .month], from: month)
        return "\(MeteorShower.monthNames[(c.month ?? 1) - 1]) \(c.year ?? 0)"
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
