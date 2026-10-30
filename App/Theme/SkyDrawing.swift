import OdakCore
import SwiftUI

/// Draws constellations the way the design's star atlas does: lit stars in the accent colour with a
/// soft halo and solid lines, missing stars as dashed rings joined by dotted lines.
enum SkyDrawing {
    /// Star positions mapped into `rect`, keeping the figure's aspect ratio.
    static func layout(_ c: Constellation, in rect: CGRect) -> [String: CGPoint] {
        let xs = c.stars.map { CGFloat($0.x) }, ys = c.stars.map { CGFloat($0.y) }
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 1, minY = ys.min() ?? 0, maxY = ys.max() ?? 1
        let w = max(1, maxX - minX), h = max(1, maxY - minY)
        let scale = min(rect.width / w, rect.height / h)
        let ox = rect.minX + (rect.width - w * scale) / 2, oy = rect.minY + (rect.height - h * scale) / 2
        var out: [String: CGPoint] = [:]
        for s in c.stars { out[s.id] = CGPoint(x: ox + (CGFloat(s.x) - minX) * scale, y: oy + (CGFloat(s.y) - minY) * scale) }
        return out
    }

    static func draw(_ c: Constellation, lit: (String) -> Bool, in rect: CGRect, ctx: GraphicsContext,
                     accent: Color, ink: Color, missing: Color, starScale: CGFloat = 1, hidden: Set<String> = []) {
        let pts = layout(c, in: rect)
        for line in c.lines {
            guard let a = pts[line.from], let b = pts[line.to] else { continue }
            var p = Path()
            p.move(to: a); p.addLine(to: b)
            if lit(line.from) && lit(line.to) && !hidden.contains(line.from) && !hidden.contains(line.to) {
                ctx.stroke(p, with: .color(accent.opacity(0.55)), lineWidth: 1.2)
            } else {
                ctx.stroke(p, with: .color(ink.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
            }
        }
        for s in c.stars {
            guard let pt = pts[s.id], !hidden.contains(s.id) else { continue }
            let r = (1.6 + CGFloat(s.size)) * starScale
            if lit(s.id) {
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r * 2.2, y: pt.y - r * 2.2, width: r * 4.4, height: r * 4.4)), with: .color(accent.opacity(0.13)))
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r * 0.8, y: pt.y - r * 0.8, width: r * 1.6, height: r * 1.6)), with: .color(accent))
            } else {
                let rr = r * 1.1
                ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - rr, y: pt.y - rr, width: rr * 2, height: rr * 2)),
                           with: .color(s.isBright ? missing.opacity(0.75) : ink.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
        }
    }
}

/// One constellation, optionally with a freshly lit star igniting.
struct ConstellationFigure: View {
    let constellation: Constellation
    var progress: SkyProgress
    var highlight: String?
    var showLabels = true
    /// When set, lit stars can be tapped (e.g. to see the session that earned them).
    var onTapStar: ((CatalogStar) -> Void)?
    @State private var ignited = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: 26, dy: 18)
            let pts = SkyDrawing.layout(constellation, in: rect)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    SkyDrawing.draw(constellation, lit: { progress.isLit($0) }, in: rect, ctx: ctx, accent: Theme.accent,
                                    ink: Theme.star, missing: Theme.ember, starScale: 1.15,
                                    hidden: highlight.map { [$0] } ?? [])
                }
                if showLabels {
                    ForEach(constellation.stars.filter { $0.id == highlight || (!progress.isLit($0.id) && $0.isBright) }) { s in
                        if let p = pts[s.id] {
                            Text(s.id == highlight ? s.name : "\(s.name)?")
                                .font(.serif(12, italic: true))
                                .foregroundStyle(s.id == highlight ? Theme.paper : Theme.ember)
                                .fixedSize()
                                .position(x: p.x, y: p.y + 18)
                        }
                    }
                }
                if let onTapStar {
                    ForEach(constellation.stars.filter { progress.isLit($0.id) }) { s in
                        if let p = pts[s.id] {
                            Button { onTapStar(s) } label: { Color.clear.frame(width: 44, height: 44).contentShape(Circle()) }
                                .buttonStyle(.plain)
                                .position(p)
                                .accessibilityLabel(Text(s.name))
                        }
                    }
                }
                if let h = highlight, let p = pts[h] {
                    Flare(radius: 4)
                        .scaleEffect(ignited || reduceMotion ? 1 : 0.2)
                        .rotationEffect(.degrees(ignited || reduceMotion ? 0 : -30))
                        .opacity(ignited || reduceMotion ? 1 : 0)
                        .position(p)
                }
            }
        }
        .onAppear { withAnimation(.spring(response: 1, dampingFraction: 0.6).delay(0.3)) { ignited = true } }
        .accessibilityElement(children: onTapStar == nil ? .ignore : .contain)
        .accessibilityLabel(Text("\(constellation.name) takımyıldızı, \(constellation.stars.count) yıldızdan \(progress.litCount(in: constellation)) tanesi yanık"))
    }
}

/// The user's own sky as a planisphere: the pole star in the centre, an hour ring on the rim, the
/// constellations they are working on placed around it and the Moon and planets on the ecliptic.
struct Planisphere: View {
    var progress: SkyProgress
    @State private var shownBurntOut: FocusRecord.ID?

    private var shown: [Constellation] {
        let done = progress.completedConstellations.suffix(2).compactMap(Catalog.constellation(_:))
        let open = progress.openConstellations.compactMap(Catalog.constellation(_:))
        return Array((done + open).suffix(4))
    }

    // Slots around the pole, as fractions of the disc's bounding box.
    private let slots: [CGRect] = [
        CGRect(x: 0.14, y: 0.22, width: 0.36, height: 0.24), CGRect(x: 0.56, y: 0.26, width: 0.30, height: 0.20),
        CGRect(x: 0.50, y: 0.58, width: 0.30, height: 0.28), CGRect(x: 0.18, y: 0.56, width: 0.28, height: 0.22),
    ]

    /// Constellation slots plus room for their labels, which burnt-out stars stay out of.
    private var occupied: [DiscRect] {
        slots.map { DiscRect(x: $0.minX, y: $0.minY, width: $0.width, height: $0.height + 0.06) }
    }

    /// Burnt-out stars with their place in the disc.
    private func burntOut(in disc: CGRect) -> [(record: FocusRecord, point: CGPoint)] {
        let occupied = occupied
        return progress.burntOutStars.map { r in
            let u = BurntOutStarLayout.point(for: r.id, avoiding: occupied)
            return (r, CGPoint(x: disc.minX + u.x * disc.width, y: disc.minY + u.y * disc.height))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let R = side / 2 - 22
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let disc = CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2)
            let burnt = burntOut(in: disc)
            ZStack {
                Canvas { ctx, _ in
                    let ink = Theme.star
                    ctx.stroke(Path(ellipseIn: disc.insetBy(dx: -20, dy: -20)), with: .color(ink.opacity(0.14)))
                    ctx.fill(Path(ellipseIn: disc), with: .color(Theme.night2))
                    ctx.stroke(Path(ellipseIn: disc), with: .color(ink.opacity(0.22)))
                    for h in 0..<24 {
                        let a = CGFloat(Angle.degrees(Double(h) * 15 - 90).radians)
                        let r2 = R + (h % 2 == 0 ? 8 : 5)
                        var p = Path()
                        p.move(to: CGPoint(x: c.x + (R + 2) * cos(a), y: c.y + (R + 2) * sin(a)))
                        p.addLine(to: CGPoint(x: c.x + r2 * cos(a), y: c.y + r2 * sin(a)))
                        ctx.stroke(p, with: .color(ink.opacity(0.4)))
                        if h % 2 == 0 {
                            ctx.draw(Text("\(h)s").font(.system(size: 9.5)).foregroundStyle(Theme.paper3),
                                     at: CGPoint(x: c.x + (R + 14) * cos(a), y: c.y + (R + 14) * sin(a)))
                        }
                    }
                    var inner = ctx
                    inner.clip(to: Path(ellipseIn: disc))
                    for r in [R * 0.25, R * 0.5, R * 0.75] {
                        inner.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(ink.opacity(0.07)))
                    }
                    var rng = SeededGenerator(seed: 77)
                    for _ in 0..<150 {
                        let rr = R * sqrt(CGFloat.random(in: 0...1, using: &rng)), aa = CGFloat.random(in: 0...(2 * .pi), using: &rng)
                        let s: CGFloat = [0.6, 0.8, 1, 1.2].randomElement(using: &rng)!
                        inner.fill(Path(ellipseIn: CGRect(x: c.x + rr * cos(aa) - s, y: c.y + rr * sin(aa) - s, width: s * 2, height: s * 2)),
                                   with: .color(ink.opacity(Double(CGFloat.random(in: 0.18...0.5, using: &rng)))))
                    }
                    // Sessions given up on stay as stars that have gone out: a cooled, rust-red cinder with
                    // a faint glow inside the thin shell of gas a dying star throws off. Each shell is tilted
                    // and stretched by its record's id, so no two look stamped out of the same mould.
                    for b in burnt {
                        let p = b.point
                        let bytes = b.record.id.uuid
                        var shell = inner
                        shell.translateBy(x: p.x, y: p.y)
                        shell.rotate(by: .degrees(Double(bytes.0) / 255 * 180))
                        shell.scaleBy(x: 1, y: 0.72 + CGFloat(bytes.1) / 255 * 0.22)
                        let shellR: CGFloat = 11
                        shell.fill(Path(ellipseIn: CGRect(x: -shellR, y: -shellR, width: shellR * 2, height: shellR * 2)),
                                   with: .radialGradient(Gradient(stops: [
                                       .init(color: Theme.cinder.opacity(0), location: 0.35),
                                       .init(color: Theme.cinder.opacity(0.22), location: 0.68),
                                       .init(color: Theme.nebula.opacity(0.10), location: 0.82),
                                       .init(color: Theme.cinder.opacity(0), location: 1),
                                   ]), center: .zero, startRadius: 0, endRadius: shellR))
                        let glowR: CGFloat = 6
                        inner.fill(Path(ellipseIn: CGRect(x: p.x - glowR, y: p.y - glowR, width: glowR * 2, height: glowR * 2)),
                                   with: .radialGradient(Gradient(colors: [Theme.cinder.opacity(0.45), Theme.cinder.opacity(0)]),
                                                         center: p, startRadius: 0, endRadius: glowR))
                        let coreR: CGFloat = 2.1
                        inner.fill(Path(ellipseIn: CGRect(x: p.x - coreR, y: p.y - coreR, width: coreR * 2, height: coreR * 2)),
                                   with: .radialGradient(Gradient(colors: [Theme.ember.opacity(0.85), Theme.cinder.opacity(0.9)]),
                                                         center: p, startRadius: 0, endRadius: coreR))
                    }
                    // ecliptic
                    var ecl = inner
                    ecl.translateBy(x: c.x, y: c.y + R * 0.2)
                    ecl.rotate(by: .degrees(-16))
                    ecl.stroke(Path(ellipseIn: CGRect(x: -R * 1.18, y: -R * 0.55, width: R * 2.36, height: R * 1.1)),
                               with: .color(Theme.ice.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                    for (i, slot) in slots.enumerated() where i < shown.count {
                        let rect = CGRect(x: disc.minX + slot.minX * disc.width, y: disc.minY + slot.minY * disc.height,
                                          width: slot.width * disc.width, height: slot.height * disc.height)
                        SkyDrawing.draw(shown[i], lit: { progress.isLit($0) }, in: rect, ctx: inner, accent: Theme.accent,
                                        ink: ink, missing: Theme.ember, starScale: 0.75)
                    }
                    // planets on the ecliptic
                    for (i, planet) in Planets.all.enumerated() {
                        let t = CGFloat(Angle.degrees(200 + Double(i) * 22).radians)
                        var pt = CGPoint(x: R * 1.18 * cos(t), y: R * 0.55 * sin(t))
                        let rot = CGFloat(Angle.degrees(-16).radians)
                        pt = CGPoint(x: pt.x * cos(rot) - pt.y * sin(rot) + c.x, y: pt.x * sin(rot) + pt.y * cos(rot) + c.y + R * 0.2)
                        let unlocked = progress.unlockedPlanets.contains(planet)
                        let r: CGFloat = planet.id == "moon" ? 8 : 4.5
                        let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                        if unlocked {
                            inner.fill(Path(ellipseIn: rect), with: .color(Color(hex: planet.id == "moon" ? 0xE8E4DB : 0xB8B2A8)))
                        } else if planet == progress.nextPlanet {
                            inner.stroke(Path(ellipseIn: rect), with: .color(Theme.ice.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        }
                    }
                }
                Flare(radius: 2.2, color: Theme.star).position(c)
                ForEach(Array(shown.enumerated()), id: \.offset) { i, con in
                    let slot = slots[i]
                    let done = progress.isComplete(con.id)
                    HStack(spacing: 6) {
                        Text(con.name).font(.serif(12.5, italic: true)).foregroundStyle(Theme.paper)
                        Text(done ? String(localized: "tamam") : "\(progress.litCount(in: con))/\(con.stars.count)").font(.system(size: 10)).foregroundStyle(Theme.paper2)
                    }
                    .fixedSize()
                    .position(x: disc.minX + slot.midX * disc.width, y: disc.minY + slot.maxY * disc.height + 10)
                }
                // Tapping a burnt-out star shows the sentence written for that session. Anywhere else the
                // disc keeps opening the collection.
                // Smaller targets once there are many, so they don't cover the whole disc and its link.
                let target: CGFloat = burnt.count > 15 ? 24 : 44
                ForEach(burnt, id: \.record.id) { b in
                    Color.clear
                        .frame(width: target, height: target)
                        .contentShape(Circle())
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) { shownBurntOut = shownBurntOut == b.record.id ? nil : b.record.id }
                        }
                        .position(b.point)
                        .accessibilityHidden(true)
                }
                // The same slim bubble as the Odak screen's info, just above the star and kept inside the view.
                if let b = burnt.first(where: { $0.record.id == shownBurntOut }) {
                    Text(b.record.task)
                        .font(.system(size: 12)).foregroundStyle(Theme.paper)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 200)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Theme.night2, in: .rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hair))
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                        .fixedSize()
                        .position(x: min(max(b.point.x, 110), geo.size.width - 110), y: max(b.point.y - 24, 14))
                        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { shownBurntOut = nil } }
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
        }
        .aspectRatio(1.05, contentMode: .fit)
        .onAppear { if Demo.info { shownBurntOut = progress.burntOutStars.first?.id } }
        .task(id: shownBurntOut) {
            guard shownBurntOut != nil, !Demo.info else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.15)) { shownBurntOut = nil }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var accessibilitySummary: String {
        let parts = shown.map { c in
            progress.isComplete(c.id) ? String(localized: "\(c.name) tamam")
                : String(localized: "\(c.name) \(c.stars.count) yıldızdan \(progress.litCount(in: c))")
        }
        let burnt = progress.burntOutStars.count
        let sky = parts.joined(separator: ", ")
        return burnt > 0 ? String(localized: "Senin gökyüzün: \(sky) ve \(burnt) sönmüş yıldız") : String(localized: "Senin gökyüzün: \(sky)")
    }
}
