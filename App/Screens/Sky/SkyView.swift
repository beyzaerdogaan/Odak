import Charts
import OdakCore
import SwiftUI

/// "Gökyüzüm": the constellations in progress, stats for the chosen period, clouds and badges.
struct SkyView: View {
    @Environment(AppModel.self) private var model
    @State private var period: SkyProgress.Period = .week
    @State private var showZenit = false

    var body: some View {
        let p = model.progress
        let stats = p.stats(period, now: .now)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Gökyüzüm").font(.serif(34)).foregroundStyle(Theme.paper)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 12)
                    Picker("Dönem", selection: $period) {
                        Text("Gün").tag(SkyProgress.Period.day)
                        Text("Hafta").tag(SkyProgress.Period.week)
                        Text("Tümü").tag(SkyProgress.Period.all)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }
                .padding(.horizontal, 22)

                SkyChart(progress: p)
                    .frame(height: 300)

                StatStrip(items: [
                    (stats.minutes.minutesText, period == .day ? "bugün" : period == .week ? "bu hafta" : "toplam"),
                    ("\(stats.stars)", "yıldız"),
                    ("\(model.streak) gün", "seri"),
                ], size: 23)
                .padding(.horizontal, 22)

                VStack(spacing: 0) {
                    NavigationLink(value: Route.collection) {
                        HStack {
                            Text("Takımyıldız koleksiyonu").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                            Spacer()
                            Text("\(p.completedConstellations.count) / \(Catalog.constellations.count) tamam")
                                .font(.system(size: 14)).foregroundStyle(Theme.accentInk)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentInk)
                        }
                        .frame(minHeight: 56)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Theme.hair)
                    HStack(spacing: 12) {
                        Image(systemName: "cloud").font(.system(size: 22)).foregroundStyle(Theme.ice)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(p.count(.cloud)) seri koruyucu bulut").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                            Text("Odaklanamadığın bir günü otomatik kapatır").small()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                }
                .padding(.horizontal, 22)

                detailedStats(p)
                    .padding(.horizontal, 22)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Rozetler").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                    let shelf = Badge.shelf + Badge.allCases.filter { !Badge.shelf.contains($0) && p.hasBadge($0) }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
                        ForEach(shelf) { badge in BadgeView(badge: badge, earned: p.hasBadge(badge)) }
                    }
                }
                .padding(.horizontal, 22)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(StarField(seed: 5, count: 60, depth: 0.45, grid: false, theme: p.selectedTheme))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showZenit) { ZenitSheet() }
    }

    @ViewBuilder private func detailedStats(_ p: SkyProgress) -> some View {
        if model.isZenit {
            let days = last7Days(p)
            VStack(alignment: .leading, spacing: 10) {
                Text("Son 7 gün").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                Chart(days) { d in
                    BarMark(x: .value("Gün", d.day, unit: .day), y: .value("Dakika", d.minutes))
                        .foregroundStyle(Theme.accent)
                        .cornerRadius(4)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                .frame(height: 140)
                let total = p.stats(.all, now: .now)
                Text("Toplam \(total.sessions) oturum, ortalama \(total.sessions == 0 ? 0 : total.minutes / max(1, total.sessions)) dk. Telefona hiç bakmadan biten: %\(noLookShare(p))")
                    .small()
            }
            .plate()
        } else {
            Button { showZenit = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis").foregroundStyle(Theme.accentInk)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ayrıntılı istatistikler").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                        Text("Günlük grafikler ve odak alışkanlıkların, Zenit ile").small()
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.paper3)
                }
                .plate(padding: 14)
            }
            .buttonStyle(.plain)
        }
    }

    private struct DayMinutes: Identifiable {
        let day: Date
        let minutes: Int
        var id: Date { day }
    }

    private func last7Days(_ p: SkyProgress) -> [DayMinutes] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<7).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let minutes = p.records.filter { cal.isDate($0.end, inSameDayAs: day) }.reduce(0) { $0 + $1.focusedMinutes }
            return DayMinutes(day: day, minutes: minutes)
        }
    }

    private func noLookShare(_ p: SkyProgress) -> Int {
        let done = p.records.filter(\.completed)
        guard !done.isEmpty else { return 0 }
        return done.filter { !$0.lookedAway }.count * 100 / done.count
    }
}

/// Up to three constellations on one chart: the latest finished one and those still open.
struct SkyChart: View {
    var progress: SkyProgress

    var body: some View {
        let shown = Array((progress.completedConstellations.suffix(1) + progress.openConstellations).compactMap(Catalog.constellation(_:)).prefix(3))
        let slots = [CGRect(x: 0.04, y: 0.08, width: 0.40, height: 0.32), CGRect(x: 0.50, y: 0.10, width: 0.42, height: 0.52),
                     CGRect(x: 0.08, y: 0.62, width: 0.40, height: 0.26)]
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    var grid = Path()
                    for r in [420.0, 520, 620] {
                        grid.addEllipse(in: CGRect(x: size.width / 2 - r, y: 640 - r, width: r * 2, height: r * 2))
                    }
                    ctx.stroke(grid, with: .color(Theme.star.opacity(0.07)))
                    for (i, c) in shown.enumerated() {
                        let s = slots[i]
                        SkyDrawing.draw(c, lit: { progress.isLit($0) }, in: CGRect(x: s.minX * w, y: s.minY * h, width: s.width * w, height: s.height * h),
                                        ctx: ctx, accent: Theme.accent, ink: Theme.star, missing: Theme.ember)
                    }
                }
                ForEach(Array(shown.enumerated()), id: \.offset) { i, c in
                    NavigationLink(value: Route.constellation(c.id)) {
                        HStack(spacing: 6) {
                            Text(c.name).font(.serif(13, italic: true)).foregroundStyle(Theme.paper)
                            Text(progress.isComplete(c.id) ? "tamam" : "\(progress.litCount(in: c))/\(c.stars.count)")
                                .font(.system(size: 11)).foregroundStyle(Theme.paper2)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .position(x: slots[i].midX * w, y: slots[i].maxY * h + 14)
                }
                HStack(spacing: 6) {
                    Circle().strokeBorder(Theme.star.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2])).frame(width: 9, height: 9)
                    Text("Kesikli: henüz yanmadı")
                }
                .small()
                .position(x: w - 90, y: 8)
            }
        }
    }
}

struct BadgeView: View {
    let badge: Badge
    let earned: Bool

    private var icon: String {
        switch badge {
        case .firstLight: "sun.max"
        case .marathon90: "timer"
        case .streak7: "flame"
        case .nightOwl: "moon"
        case .proxima: "location.north"
        case .pleiades: "sparkles"
        case .meteor: "sparkle"
        }
    }

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: earned ? icon : "lock")
                .font(.system(size: earned ? 22 : 18))
                .foregroundStyle(earned ? Theme.accentInk : Theme.paper3)
                .frame(width: 56, height: 56)
                .background {
                    if earned {
                        Circle().fill(RadialGradient(colors: [Theme.accent.opacity(0.32), Theme.accent.opacity(0.08)],
                                                     center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 40))
                    }
                }
                .overlay {
                    Circle().strokeBorder(earned ? Theme.accent.opacity(0.45) : Theme.star.opacity(0.22),
                                          style: StrokeStyle(lineWidth: 1, dash: earned ? [] : [3, 3]))
                }
            Text(badge.title).font(.system(size: 12)).multilineTextAlignment(.center)
                .foregroundStyle(earned ? Theme.paper : Theme.paper3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(badge.title), \(earned ? "kazanıldı" : badge.detail)"))
    }
}

/// A constellation from the chart: its figure, facts and where to look.
struct ConstellationDetailView: View {
    let id: String
    @Environment(AppModel.self) private var model

    var body: some View {
        if let c = Catalog.constellation(id) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(c.latin).font(.serif(16, italic: true)).foregroundStyle(Theme.paper2)
                    ConstellationFigure(constellation: c, progress: model.progress)
                        .frame(height: 220)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(c.stars) { s in
                            HStack {
                                Image(systemName: model.progress.isLit(s.id) ? "sparkle" : "circle.dashed")
                                    .foregroundStyle(model.progress.isLit(s.id) ? Theme.accentInk : Theme.paper3)
                                Text(s.name).foregroundStyle(Theme.paper)
                                if s.isBright { Text("parlak").small() }
                                Spacer()
                            }
                            .font(.system(size: 14))
                        }
                    }
                    .plate()
                    ConstellationFacts(constellation: c)
                    Label(c.whereToLook, systemImage: "location.north.line").font(.system(size: 14)).foregroundStyle(Theme.paper2)
                }
                .padding(22)
            }
            .pinnedHeader { BackHeader(title: c.name, subtitle: "\(model.progress.litCount(in: c)) / \(c.stars.count) yıldız") }
            .background(StarField(seed: 9, count: 80, grid: false, theme: model.progress.selectedTheme))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
