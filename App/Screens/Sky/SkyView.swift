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
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Spacer(minLength: 12)
                    Picker("Dönem", selection: $period) {
                        Text("Gün").tag(SkyProgress.Period.day)
                        Text("Hafta").tag(SkyProgress.Period.week)
                        Text("Tümü").tag(SkyProgress.Period.all)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    NavigationLink(value: Route.skyCalendar) {
                        Image(systemName: "calendar").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.accentInk)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Gökyüzü takvimi")
                }
                .padding(.horizontal, 22)
                .fadesOnScroll()

                SkyChart(progress: p)

                StatStrip(items: [
                    (stats.minutes.minutesText, period == .day ? String(localized: "bugün") : period == .week ? String(localized: "bu hafta") : String(localized: "toplam")),
                    ("\(stats.stars)", String(localized: "yıldız")),
                    (String(localized: "\(model.streak) gün"), String(localized: "seri")),
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
                    NavigationLink(value: Route.skyCalendar) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar").font(.system(size: 20)).foregroundStyle(Theme.accentInk)
                            Text("Gökyüzü etkinlikleri").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentInk)
                        }
                        .frame(minHeight: 62)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Theme.hair)
                    HStack(spacing: 12) {
                        Image(systemName: "cloud").font(.system(size: 22)).foregroundStyle(Theme.ice)
                        Text("\(p.count(.cloud)) seri koruyucu bulut").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
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
            // Never wider than the screen: content that overflows sideways (the header row on narrow
            // phones) would otherwise let the whole page be dragged left and right.
            .containerRelativeFrame(.horizontal)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .defaultScrollAnchor(Demo.screen == "badges" ? .bottom : .top)
        .collapsingTitle(String(localized: "Gökyüzüm"))
        .background(StarField(seed: 5, count: 150, depth: 1, grid: false, theme: p.selectedTheme))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showZenit) { ZenitSheet() }
    }

    @ViewBuilder private func detailedStats(_ p: SkyProgress) -> some View {
        if model.isZenit || !SubscriptionStore.isOffered {
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
                Text("Toplam \(total.sessions) oturum yaptın ve bir oturum ortalama \(total.sessions == 0 ? 0 : total.minutes / max(1, total.sessions)) dakika sürdü. Telefona hiç bakmadan bitirdiğin oturumların oranı %\(noLookShare(p)).")
                    .small()
            }
            .plate()
        } else {
            Button { showZenit = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis").foregroundStyle(Theme.accentInk)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ayrıntılı istatistikler").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                        Text("Günlük grafikleri ve odak alışkanlıklarını Zenit ile görebilirsin").small()
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

/// The sky chart, three constellations at a time. The first page holds the latest finished one and those still
/// open; swiping sideways turns the dome to the rest of the catalog, and wraps around after the last page.
struct SkyChart: View {
    var progress: SkyProgress
    /// Copies of the page ring laid side by side, so the pager can keep turning either way.
    private static let laps = 200
    @State private var position: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pages: [[Constellation]] {
        let first = Array((progress.completedConstellations.suffix(1) + progress.openConstellations).compactMap(Catalog.constellation(_:)).prefix(3))
        let shown = Set(first.map(\.id))
        let rest = Catalog.constellations.filter { !shown.contains($0.id) }
        return (first.isEmpty ? [] : [first]) + stride(from: 0, to: rest.count, by: 3).map { Array(rest[$0..<min($0 + 3, rest.count)]) }
    }

    var body: some View {
        let pages = pages
        let count = pages.count
        let start = count * (Self.laps / 2)
        let current = ((position ?? start) % count + count) % count
        let bends = !reduceMotion
        VStack(spacing: 4) {
            ZStack {
                Canvas { ctx, size in
                    var grid = Path()
                    for r in [420.0, 520, 620] {
                        grid.addEllipse(in: CGRect(x: size.width / 2 - r, y: 640 - r, width: r * 2, height: r * 2))
                    }
                    ctx.stroke(grid, with: .color(Theme.star.opacity(0.07)))
                }
                .allowsHitTesting(false)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(0..<(count * Self.laps), id: \.self) { i in
                            SkyChartPage(constellations: pages[i % count], progress: progress)
                                .containerRelativeFrame(.horizontal)
                                .visualEffect { content, proxy in
                                    // Pages bend away like the inside of a dome as they slide off.
                                    let turn = bends ? proxy.frame(in: .scrollView).minX / max(proxy.size.width, 1) : 0
                                    return content
                                        .rotation3DEffect(.degrees(-turn * 35), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                                        .offset(y: abs(turn) * 24)
                                        .opacity(1 - min(abs(turn), 1) * 0.5)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $position)
                .scrollIndicators(.hidden)
                .onAppear { if position == nil { position = start } }
            }
            .frame(height: 300)

            if count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<count, id: \.self) { i in
                        Circle().fill(i == current ? Theme.accentInk : Theme.paper3.opacity(0.5))
                            .frame(width: 5, height: 5)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text("Gökyüzü sayfası \(current + 1) / \(count), diğer takımyıldızlar için yana kaydır"))
            }
        }
    }
}

/// One page of the sky chart: up to three constellations in fixed slots, each labelled with its progress.
private struct SkyChartPage: View {
    let constellations: [Constellation]
    var progress: SkyProgress

    var body: some View {
        let slots = [CGRect(x: 0.04, y: 0.08, width: 0.40, height: 0.32), CGRect(x: 0.50, y: 0.10, width: 0.42, height: 0.52),
                     CGRect(x: 0.08, y: 0.62, width: 0.40, height: 0.26)]
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    for (i, c) in constellations.enumerated() {
                        let s = slots[i]
                        SkyDrawing.draw(c, lit: { progress.isLit($0) }, in: CGRect(x: s.minX * w, y: s.minY * h, width: s.width * w, height: s.height * h),
                                        ctx: ctx, accent: Theme.accent, ink: Theme.star, missing: Theme.ember)
                    }
                }
                ForEach(Array(constellations.enumerated()), id: \.offset) { i, c in
                    // The figure itself opens the constellation too, not only its label.
                    NavigationLink(value: Route.constellation(c.id)) {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: slots[i].width * w, height: slots[i].height * h)
                    .position(x: slots[i].midX * w, y: slots[i].midY * h)
                    .accessibilityHidden(true)
                    NavigationLink(value: Route.constellation(c.id)) {
                        HStack(spacing: 6) {
                            Text(c.name).font(.serif(13, italic: true)).foregroundStyle(Theme.paper)
                            Text(progress.isComplete(c.id) ? String(localized: "tamam") : "\(progress.litCount(in: c))/\(c.stars.count)")
                                .font(.system(size: 11)).foregroundStyle(Theme.paper2)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .position(x: slots[i].midX * w, y: slots[i].maxY * h + 14)
                }
            }
        }
    }
}

struct BadgeView: View {
    let badge: Badge
    let earned: Bool

    var body: some View {
        VStack(spacing: 7) {
            BadgeMedal(badge: badge, earned: earned, size: 60)
            Text(badge.title).font(.system(size: 12)).multilineTextAlignment(.center)
                .foregroundStyle(earned ? Theme.paper : Theme.paper3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(badge.title), \(earned ? String(localized: "kazanıldı") : badge.detail)"))
    }
}

/// A constellation from the chart: its figure, facts and where to look.
struct ConstellationDetailView: View {
    let id: String
    @Environment(AppModel.self) private var model
    @State private var shownStar: CatalogStar?

    var body: some View {
        if let c = Catalog.constellation(id) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(c.latin).font(.serif(16, italic: true)).foregroundStyle(Theme.paper2)
                    ConstellationFigure(constellation: c, progress: model.progress, onTapStar: { shownStar = $0 })
                        .frame(height: 220)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(c.stars) { s in
                            let lit = model.progress.isLit(s.id)
                            Button { shownStar = s } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    Image(systemName: lit ? "sparkle" : "circle.dashed")
                                        .foregroundStyle(lit ? Theme.accentInk : Theme.paper3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(s.name).foregroundStyle(Theme.paper)
                                            if s.isBright { Text("parlak").small() }
                                        }
                                        if let r = model.progress.record(forStar: s.id) {
                                            Text(r.task).font(.system(size: 12)).foregroundStyle(Theme.paper2).lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    if lit { Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.paper3) }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!lit)
                            .font(.system(size: 14))
                        }
                    }
                    .plate()
                    ConstellationFacts(constellation: c)
                    Label(c.whereToLook, systemImage: "location.north.line").font(.system(size: 14)).foregroundStyle(Theme.paper2)
                }
                .padding(22)
            }
            .pinnedHeader { BackHeader(title: c.name, subtitle: String(localized: "\(model.progress.litCount(in: c)) / \(c.stars.count) yıldız")) }
            .background(StarField(seed: 9, count: 80, grid: false, theme: model.progress.selectedTheme))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $shownStar) { s in StarStorySheet(star: s, constellation: c) }
            .onAppear { if Demo.screen == "star" { shownStar = c.stars.first { $0.name == "Rigel" } } }
        }
    }
}

/// A lit star's story: what the user was focusing on when it dropped, and when.
struct StarStorySheet: View {
    let star: CatalogStar
    let constellation: Constellation
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// Height of the content, so the sheet hugs it instead of leaving a half-empty screen.
    @State private var contentHeight: CGFloat = 220

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let r = model.progress.record(forStar: star.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Odaklandığın konu").small()
                        Text(r.task).font(.serif(22)).foregroundStyle(Theme.paper)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label(r.end.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(AppLanguage.locale)),
                              systemImage: "calendar")
                        Label("\(r.focusedMinutes) dakika odak", systemImage: "hourglass")
                        if r.strict { Label("Katı mod", systemImage: "lock") }
                        if r.light > 0 { Label("+\(r.light) Işık", systemImage: "sparkles") }
                    }
                    .font(.system(size: 14)).foregroundStyle(Theme.paperBody)
                } else if let lit = model.progress.litStars[star.id] {
                    Text("Bu yıldız \(lit.formatted(.dateTime.day().month(.wide).year().locale(AppLanguage.locale))) tarihinde yandı, ama hangi odakla kazanıldığı kayıtlı değil.")
                        .font(.system(size: 14)).foregroundStyle(Theme.paperBody)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 22)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(star.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam", systemImage: "checkmark") { dismiss() } } }
        }
        // The navigation bar and the bottom safe area sit outside the measured content.
        .presentationDetents([.height(contentHeight + 90)])
    }
}
