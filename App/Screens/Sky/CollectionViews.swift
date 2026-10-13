import OdakCore
import SwiftUI

/// "Koleksiyon haritası": the five layers of the sky and the current sky event.
struct CollectionMapView: View {
    @Environment(AppModel.self) private var model

    private struct Layer: Identifiable {
        enum Status { case here, parallel, locked, done }
        let n: Int
        let title: String
        let right: String
        let bar: Double?
        let text: String
        let color: Color
        let state: Status
        let route: Route?
        var id: Int { n }
    }

    private var layers: [Layer] {
        let p = model.progress
        let total = Catalog.constellations.count
        let starterDone = p.completedConstellations.count >= total
        let planets = p.unlockedPlanets.count
        let nextPlanet = p.nextPlanet
        let hours = p.totalFocusedMinutes / 60
        return [
            Layer(n: 1, title: "Başlangıç göğü", right: "\(p.completedConstellations.count) / \(total)",
                  bar: Double(p.completedConstellations.count) / Double(total),
                  text: starterDone ? "16 tanınmış takımyıldızın hepsini yaktın." : "16 tanınmış takımyıldız. Şu an buradasın.",
                  color: Theme.accent, state: starterDone ? .done : .here, route: nil),
            Layer(n: 2, title: "Tüm gökyüzü", right: "Yakında",
                  bar: nil, text: "Kalan 72 takımyıldız: Kuzey göğü, sonra Güney seferi. Bir sonraki sürümle gelecek.",
                  color: Theme.paper3, state: .locked, route: nil),
            Layer(n: 3, title: "Derin gök nesneleri", right: "\(p.deepSky.count) / \(DeepSky.catalogueSize)",
                  bar: nil, text: "Paralel ilerler. Nebulalar, galaksiler, kümeler. İlk nesne: Avcı Bulutsusu, Avcı tamamlandıktan sonra 90 dk'lık bir oturumla.",
                  color: Theme.nebula, state: .parallel, route: .deepSky),
            Layer(n: 4, title: "Gezegenler ve Ay", right: "\(planets) / \(Planets.all.count)",
                  bar: nextPlanet.map { Double(p.totalFocusedMinutes) / Double($0.hours * 60) },
                  text: nextPlanet.map { "Paralel ilerler. Sıradaki: \($0.name), \($0.hours) saat (sen \(hours) saattesin)." } ?? "Bütün gezegenler açıldı.",
                  color: Theme.ice, state: .parallel, route: .deepSky),
            Layer(n: 5, title: "Işık yolculuğu", right: p.journeyUnlocked ? "\(p.reachedStops.count) durak" : "Kilitli",
                  bar: nil, text: "Başlangıç göğü bitince gerçek yıldız sistemlerine yolculuk başlar. Her odak saati 1 ışık yılı, rota hiç bitmez.",
                  color: p.journeyUnlocked ? Theme.accent : Theme.paper3, state: p.journeyUnlocked ? .parallel : .locked, route: .journey),
        ]
    }

    /// How far the layer rail runs past the last layer to reach the bottom edge of the screen.
    @State private var railTail: CGFloat = 22

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                let active = MeteorShowers.active(on: .now)
                NavigationLink(value: Route.event) {
                    EventBanner(shower: active ?? MeteorShowers.upcoming(after: .now, count: 1).first ?? MeteorShowers.all[0], active: active != nil)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(layers) { layer in row(layer) }
                }
                .background(alignment: .leading) {
                    // The rail runs on past the last layer to the bottom edge of the screen and fades out there.
                    LinearGradient(colors: [Theme.accent, Theme.star.opacity(0.14), Theme.star.opacity(0.14)], startPoint: .top, endPoint: .bottom)
                        .mask {
                            VStack(spacing: 0) {
                                Color.black
                                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 140)
                            }
                        }
                        .frame(width: 1).padding(.leading, 14.5)
                        .padding(.top, 20).padding(.bottom, -railTail)
                }
            }
            .padding(22)
        }
        .onScrollGeometryChange(for: CGFloat.self) { g in
            // Bottom padding + the inset under the content + any empty space left below it on a tall screen.
            22 + g.contentInsets.bottom + max(0, g.containerSize.height - g.contentInsets.top - g.contentInsets.bottom - g.contentSize.height)
        } action: { _, tail in
            railTail = tail
        }
        .pinnedHeader {
            BackHeader(title: "Koleksiyon haritası", subtitle: nil) {
                HStack(spacing: 5) { Spark(size: 10); Text("\(model.progress.totalFocusedMinutes / 60) sa") }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentInk)
                    .padding(.horizontal, 11).frame(height: 30)
                    .glassEffect(.regular.tint(Theme.accent.opacity(0.15)), in: .capsule)
            }
        }
        .background(StarField(seed: 7, count: 70, grid: false, theme: model.progress.selectedTheme))
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private func row(_ L: Layer) -> some View {
        let card = VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(L.state == .locked ? Theme.paper2 : Theme.paper)
                Spacer()
                HStack(spacing: 4) {
                    if L.state == .locked { Image(systemName: "lock").font(.system(size: 11)) }
                    Text(L.right).monospacedDigit()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(L.state == .locked ? Theme.paper3 : L.color)
            }
            if let bar = L.bar { ProgressBar(value: bar, color: L.color) }
            Text(L.text).font(.system(size: 12.5)).foregroundStyle(Theme.paper2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background {
            if L.state == .here {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.accent.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.accent.opacity(0.35)))
            }
        }
        HStack(alignment: .top, spacing: 14) {
            Text("\(L.n)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(L.state == .here || L.state == .done ? Theme.onAccent : L.state == .parallel ? L.color : Theme.paper3)
                .frame(width: 30, height: 30)
                .background(L.state == .here || L.state == .done ? Theme.accent : Theme.night2, in: Circle())
                .overlay { if L.state != .here && L.state != .done { Circle().strokeBorder(L.state == .parallel ? L.color : Theme.star.opacity(0.2), lineWidth: 1.5) } }
                .shadow(color: L.state == .here ? Theme.accent.opacity(0.5) : .clear, radius: 11)
            if let route = L.route {
                NavigationLink(value: route) { card }.buttonStyle(.plain).padding(.top, -8)
            } else {
                card.padding(.top, -8)
            }
        }
    }
}

/// "Derin gök + gezegenler": the latest deep-sky object (or the next one to find) and the planet path.
struct DeepSkyView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let p = model.progress
        let found = DeepSky.objects.filter { p.deepSky[$0.id] != nil }.sorted { (p.deepSky[$0.id] ?? .distantPast) > (p.deepSky[$1.id] ?? .distantPast) }
        let obj = found.first ?? DeepSky.objects[0]
        let unlocked = !found.isEmpty
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 2) {
                    Text(unlocked ? "Derin gök nesnesi keşfettin" : "İlk keşfin seni bekliyor")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.nebula)
                    Text(obj.name).font(.serif(44)).foregroundStyle(Theme.paper).multilineTextAlignment(.center)
                    Text("\(obj.designation), \(DeepSky.catalogueSize) nesneden \(p.deepSky.count) tanesi bulundu").meta()
                }
                .frame(maxWidth: .infinity)
                NebulaArt()
                    .frame(height: 180)
                    .saturation(unlocked ? 1 : 0.2)
                    .opacity(unlocked ? 1 : 0.55)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bu ne?").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                    ForEach(obj.about, id: \.self) { Text($0).font(.system(size: 14)).foregroundStyle(Theme.paperBody) }
                    Text(obj.requirementText).small()
                }
                HStack(spacing: 18) {
                    HStack(spacing: 8) {
                        HStack(spacing: 5) { Spark(size: 13); Text("+\(obj.light)") }.font(.serif(24)).foregroundStyle(Theme.accentInk)
                        Text("Işık").small()
                    }
                    if let theme = obj.theme {
                        Rectangle().fill(Theme.hair).frame(width: 1, height: 28)
                        HStack(spacing: 8) {
                            Text(theme.title).font(.serif(20, italic: true)).foregroundStyle(Theme.nebula)
                            Text("gök teması").small()
                        }
                    }
                }
                planets(p)
                if unlocked, let theme = obj.theme, model.canUse(theme) {
                    PrimaryButton(title: p.selectedTheme == theme ? "Tema uygulandı" : "Temayı uygula") { model.selectTheme(theme) }
                        .disabled(p.selectedTheme == theme)
                }
                if found.count < DeepSky.objects.count {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sıradaki keşifler").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.paper2)
                        ForEach(DeepSky.objects.filter { p.deepSky[$0.id] == nil && $0 != obj }) { o in
                            HStack {
                                Text(o.name).font(.serif(17, italic: true)).foregroundStyle(Theme.paper)
                                Spacer()
                                Text(o.requirementText.replacingOccurrences(of: "Açılma koşulu: ", with: "")).small().multilineTextAlignment(.trailing)
                            }
                            .frame(minHeight: 40)
                        }
                    }
                }
            }
            .padding(22)
        }
        .pinnedHeader { BackHeader(title: "Derin gök", subtitle: nil) }
        .background(StarField(seed: 8, count: 110, grid: false, theme: p.selectedTheme))
        .toolbar(.hidden, for: .navigationBar)
    }

    private func planets(_ p: SkyProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Gezegenler ve Ay").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                Text("toplam odak saatiyle").small()
            }
            HStack(alignment: .top, spacing: 2) {
                ForEach(Planets.all) { planet in
                    let done = p.unlockedPlanets.contains(planet)
                    let next = planet == p.nextPlanet
                    VStack(spacing: 5) {
                        ZStack {
                            if done {
                                Circle().fill(RadialGradient(colors: [Color(hex: 0xF2EFE8), Color(hex: 0x9C988F)], center: .init(x: 0.35, y: 0.35), startRadius: 0, endRadius: 14))
                            } else if next {
                                Circle().trim(from: 0, to: min(1, Double(p.totalFocusedMinutes) / Double(planet.hours * 60)))
                                    .stroke(Theme.accent, lineWidth: 2).rotationEffect(.degrees(-90))
                                Circle().fill(RadialGradient(colors: [Color(hex: 0xF6E2B0), Color(hex: 0xB48A4A)], center: .init(x: 0.35, y: 0.35), startRadius: 0, endRadius: 12)).padding(3)
                            } else {
                                Circle().strokeBorder(Theme.star.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            }
                        }
                        .frame(width: planet.id == "jupiter" ? 26 : 20, height: planet.id == "jupiter" ? 26 : 20)
                        .frame(height: 28)
                        Text(planet.name).font(.system(size: 10.5, weight: next ? .semibold : .regular))
                            .foregroundStyle(done || next ? Theme.paper : Theme.paper3).lineLimit(1).minimumScaleFactor(0.8)
                        Text("\(planet.hours) sa").font(.system(size: 10)).monospacedDigit()
                            .foregroundStyle(next ? Theme.accentInk : Theme.paper3)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .plate(padding: 14)
    }
}

/// Soft nebula painted with blurred gradients (artwork, same in both modes).
struct NebulaArt: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededGenerator(seed: 42)
            let colors = [Color(hex: 0xE6A6C7), Color(hex: 0x7FB6E0), Color(hex: 0xF2C9A0)]
            ctx.addFilter(.blur(radius: 10))
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            for _ in 0..<9 {
                let w = CGFloat.random(in: 60...180, using: &rng), h = CGFloat.random(in: 28...80, using: &rng)
                let x = c.x + CGFloat.random(in: -90...60, using: &rng), y = c.y + CGFloat.random(in: -45...40, using: &rng)
                let color = colors.randomElement(using: &rng)!
                ctx.fill(Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)),
                         with: .radialGradient(Gradient(colors: [color.opacity(0.8), color.opacity(0)]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: w / 2))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 20, y: c.y - 14, width: 40, height: 28)), with: .color(Color(hex: 0xFFF3E0, opacity: 0.4)))
        }
        .overlay { Flare(radius: 2.6, color: .white) }
        .accessibilityLabel("Avcı Bulutsusu çizimi")
    }
}

/// "Meteor yağmuru": the current (or next) shower, its rules and the real-sky viewing tip.
struct MeteorEventView: View {
    @Environment(AppModel.self) private var model
    @State private var reminded = false

    var body: some View {
        let active = MeteorShowers.active(on: .now)
        let shower = active ?? MeteorShowers.upcoming(after: .now, count: 1).first ?? MeteorShowers.all[0]
        let done = model.progress.meteorProgress[shower.seasonKey(for: .now)] ?? 0
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(shower.name)\nmeteor yağmuru").font(.serif(42)).foregroundStyle(Theme.paper)
                    Text(active != nil ? "Etkinlik sürüyor, zirve \(shower.peakText())" : "Başlangıç: \(shower.nextStart(after: .now).formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "tr_TR"))))")
                        .font(.system(size: 13)).foregroundStyle(Theme.meteor2)
                }
                .padding(.top, 24)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Etkinlik boyunca").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                    Text("Her oturumda %25 şansla kayan yıldız düşer: o oturumun Işığı ×2.")
                    Text("\(MeteorShower.sessionGoal) oturum tamamla, \(shower.name) rozetini ve “Meteor izi” sayaç stilini kazan.")
                    HStack {
                        Text("İlerleme").foregroundStyle(Theme.meteor2)
                        Spacer()
                        Text("\(min(done, MeteorShower.sessionGoal)) / \(MeteorShower.sessionGoal) oturum").fontWeight(.semibold).monospacedDigit()
                    }
                    .font(.system(size: 13))
                    HStack(spacing: 4) {
                        ForEach(0..<MeteorShower.sessionGoal, id: \.self) { i in
                            Capsule().fill(i < done ? Theme.meteor : Theme.meteor.opacity(0.16)).frame(height: 6)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .font(.system(size: 14)).foregroundStyle(Theme.paperBody)
                .plate(radius: 22, fill: Theme.meteor.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gerçekte de izle").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                    Text(shower.watchTip).font(.system(size: 14)).foregroundStyle(Theme.paperBody)
                    if let moon = shower.moonAtPeak() {
                        Text(moon >= 50 ? "Zirve gecesi Ay %\(moon) dolu olacak; sönük meteorlar ay ışığında kaybolabilir."
                                        : "Zirve gecesi Ay yalnızca %\(moon) dolu, gökyüzü karanlık olacak.")
                            .font(.system(size: 13)).foregroundStyle(Theme.meteor2)
                    }
                    Button {
                        guard let peak = shower.peakDate(around: .now) else { return }
                        Task { await Notifications.remindPeak(name: shower.name, at: peak); reminded = true }
                    } label: {
                        Label(reminded ? "Hatırlatma kuruldu" : "Zirve gecesi için hatırlat", systemImage: reminded ? "checkmark" : "bell")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .tint(Theme.meteor)
                    .disabled(reminded)
                }
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Sıradaki etkinlikler").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.paper2)
                        Spacer()
                        NavigationLink(value: Route.skyCalendar) {
                            Label("Takvim", systemImage: "calendar").font(.system(size: 13, weight: .semibold))
                        }
                        .tint(Theme.meteor)
                    }
                    ForEach(MeteorShowers.upcoming(after: .now, count: 3).filter { $0 != shower }) { s in
                        HStack {
                            Text(s.name).font(.system(size: 15)).foregroundStyle(Theme.paper)
                            Spacer()
                            Text(s.peakText()).font(.system(size: 13)).foregroundStyle(Theme.paper2)
                        }
                        .frame(minHeight: 40)
                        Divider().overlay(Theme.hair)
                    }
                }
            }
            .padding(22)
        }
        .pinnedHeader(fade: .clear) { BackHeader(title: "Gökyüzü etkinliği", subtitle: nil) }
        .background { EventBackdrop(shower: shower, active: active != nil) }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// "Işık yolculuğu": after the starter sky, every focus hour carries the user one light-year.
struct JourneyView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let p = model.progress
        let next = p.nextStop
        let prev = Journey.stops.last { p.reachedStops.contains($0.name) }?.lightYears ?? 0
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(p.journeyUnlocked
                     ? "Gökyüzünü yaktın, şimdi oraya gitme zamanı. Her odak saatin seni 1 ışık yılı ileri taşır."
                     : "Başlangıç göğünü tamamladığında yolculuk başlar. Her odak saatin seni 1 ışık yılı ileri taşıyacak.")
                    .font(.system(size: 15)).foregroundStyle(Theme.paperBody)
                RouteChart(travelled: p.lightYearsTravelled, reached: p.reachedStops)
                    .frame(height: 150)
                    .opacity(p.journeyUnlocked ? 1 : 0.5)
                if let next {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sıradaki durak: \(next.name)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                            Spacer()
                            Text("\(ly(p.lightYearsTravelled)) / \(ly(next.lightYears)) ı.y.")
                                .font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.accentInk)
                        }
                        ProgressBar(value: (p.lightYearsTravelled - prev) / max(0.1, next.lightYears - prev))
                        Text("\(next.story) \(Int((next.lightYears - p.lightYearsTravelled).rounded(.up))) saatlik odak kaldı.").small()
                    }
                    .plate(fill: Theme.accent.opacity(0.07))
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Rota").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.paper2)
                    ForEach(Journey.stops) { stop in
                        let reached = p.reachedStops.contains(stop.name)
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(stop.name).font(.serif(19, italic: true))
                                    .foregroundStyle(stop == next ? Theme.accentInk : reached ? Theme.paper2 : Theme.paper)
                                Text(stop.rewardText).small()
                            }
                            Spacer()
                            if reached { Image(systemName: "checkmark").foregroundStyle(Theme.aurora) }
                            Text("\(ly(stop.lightYears)) ı.y.").font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.paper2)
                        }
                        .frame(minHeight: 52)
                        Divider().overlay(Theme.hair)
                    }
                }
                Text("Mesafeler gerçek, rota hiç bitmez. Koleksiyonun ve Işık bakiyen olduğu gibi kalır.")
                    .small().multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
            .padding(22)
        }
        .pinnedHeader {
            BackHeader(title: "Işık yolculuğu",
                       subtitle: "\(p.completedConstellations.count) / \(Catalog.constellations.count) takımyıldız")
        }
        .background(StarField(seed: 10, count: 120, grid: false, theme: p.selectedTheme))
        .toolbar(.hidden, for: .navigationBar)
    }

    private func ly(_ d: Double) -> String {
        (d.rounded() == d ? String(Int(d)) : String(format: "%.1f", d)).replacingOccurrences(of: ".", with: ",")
    }
}

/// The voyage line from the Sun across the stops. Spacing is schematic; labels carry the real distances.
struct RouteChart: View {
    let travelled: Double
    let reached: [String]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let n = Journey.stops.count
            let xs = (0...n).map { 12 + CGFloat($0) * (w - 30) / CGFloat(n) }
            let y: (CGFloat) -> CGFloat = { x in 100 - 56 * sin((x - 12) / (w - 30) * .pi * 0.7) }
            let first = Journey.stops[0].lightYears
            let ship = travelled < first
                ? xs[0] + (xs[1] - xs[0]) * CGFloat(travelled / first)
                : xs[min(n, reached.count)]
            ZStack {
                Canvas { ctx, _ in
                    var dotted = Path(), solid = Path()
                    for i in 0...60 {
                        let x = xs[0] + (xs[n] + 10 - xs[0]) * CGFloat(i) / 60
                        if i == 0 { dotted.move(to: CGPoint(x: x, y: y(x))) } else { dotted.addLine(to: CGPoint(x: x, y: y(x))) }
                    }
                    for i in 0...20 {
                        let x = xs[0] + (ship - xs[0]) * CGFloat(i) / 20
                        if i == 0 { solid.move(to: CGPoint(x: x, y: y(x))) } else { solid.addLine(to: CGPoint(x: x, y: y(x))) }
                    }
                    ctx.stroke(dotted, with: .color(Theme.star.opacity(0.28)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2, 5]))
                    ctx.stroke(solid, with: .color(Theme.accent), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    for i in 1...n {
                        let p = CGPoint(x: xs[i], y: y(xs[i]))
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)), with: .color(Theme.night))
                        ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)),
                                   with: .color(reached.contains(Journey.stops[i - 1].name) ? Theme.accent : Theme.star.opacity(0.7)), lineWidth: 1.2)
                    }
                }
                Flare(radius: 3.2, color: Theme.ember).position(x: xs[0], y: y(xs[0]))
                Text("Güneş").font(.serif(13, italic: true)).foregroundStyle(Theme.paper).position(x: xs[0], y: y(xs[0]) + 24)
                ForEach(Array(Journey.stops.enumerated()), id: \.offset) { i, stop in
                    let x = xs[i + 1], up = i % 2 == 0
                    VStack(spacing: 0) {
                        Text(stop.name).font(.serif(13, italic: true)).foregroundStyle(Theme.paper)
                        Text("\(stop.lightYears.formatted(.number.locale(Locale(identifier: "tr_TR")))) ı.y.").font(.system(size: 10)).foregroundStyle(Theme.paper3)
                    }
                    .fixedSize()
                    .position(x: min(x, w - 34), y: y(x) + (up ? -26 : 28))
                }
                Flare(radius: 2.4).position(x: ship, y: y(ship))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Güneş'ten Ülker'e uzanan yolculuk rotası")
    }
}
