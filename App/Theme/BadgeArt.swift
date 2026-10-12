import OdakCore
import SwiftUI

/// Badges are medals: each has its own outline, colour and a drawn emblem, so no two look alike.
/// Earned medals are tinted and glow; locked ones keep their silhouette as a dashed ghost.
enum MedalOutline {
    case circle, hexagon, shield, arch, diamond, heptagon, rosette
}

extension Badge {
    var outline: MedalOutline {
        switch self {
        case .firstLight: .circle
        case .marathon90: .hexagon
        case .streak7: .shield
        case .nightOwl: .arch
        case .proxima: .diamond
        case .pleiades: .heptagon
        case .meteor: .rosette
        }
    }

    var tone: Color {
        switch self {
        case .firstLight: Theme.accentInk
        case .marathon90: Theme.aurora
        case .streak7: Theme.ember
        case .nightOwl: Theme.ice
        case .proxima: Theme.alarm
        case .pleiades: Theme.nebula
        case .meteor: Theme.meteor
        }
    }
}

struct MedalShape: Shape {
    var outline: MedalOutline
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let c = CGPoint(x: r.midX, y: r.midY), rad = min(r.width, r.height) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        switch outline {
        case .circle:
            return Path(ellipseIn: r)
        case .hexagon:
            return Self.polygon(6, center: c, radius: rad, rotation: -.pi / 2, corner: rad * 0.14)
        case .heptagon:
            return Self.polygon(7, center: c, radius: rad, rotation: -.pi / 2, corner: rad * 0.14)
        case .diamond:
            return Self.polygon(4, center: c, radius: rad * 1.04, rotation: -.pi / 2, corner: rad * 0.18)
        case .shield:
            var path = Path()
            path.move(to: p(0.5, 0.02))
            path.addQuadCurve(to: p(0.92, 0.15), control: p(0.72, 0.14))
            path.addLine(to: p(0.92, 0.5))
            path.addCurve(to: p(0.5, 0.98), control1: p(0.92, 0.76), control2: p(0.72, 0.9))
            path.addCurve(to: p(0.08, 0.5), control1: p(0.28, 0.9), control2: p(0.08, 0.76))
            path.addLine(to: p(0.08, 0.15))
            path.addQuadCurve(to: p(0.5, 0.02), control: p(0.28, 0.14))
            path.closeSubpath()
            return path
        case .arch:
            var path = Path()
            let w = r.width * 0.84
            let left = r.midX - w / 2, top = r.minY + w / 2
            path.move(to: CGPoint(x: left, y: r.maxY - w * 0.08))
            path.addLine(to: CGPoint(x: left, y: top))
            path.addArc(center: CGPoint(x: r.midX, y: top), radius: w / 2, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            path.addLine(to: CGPoint(x: left + w, y: r.maxY - w * 0.08))
            path.addQuadCurve(to: CGPoint(x: left + w - w * 0.08, y: r.maxY), control: CGPoint(x: left + w, y: r.maxY))
            path.addLine(to: CGPoint(x: left + w * 0.08, y: r.maxY))
            path.addQuadCurve(to: CGPoint(x: left, y: r.maxY - w * 0.08), control: CGPoint(x: left, y: r.maxY))
            path.closeSubpath()
            return path
        case .rosette:
            var path = Path()
            let n = 12
            func at(_ a: CGFloat, _ k: CGFloat) -> CGPoint { CGPoint(x: c.x + cos(a) * rad * k, y: c.y + sin(a) * rad * k) }
            for i in 0..<n {
                let a = CGFloat(i) / CGFloat(n) * 2 * .pi - .pi / 2
                let b = CGFloat(i + 1) / CGFloat(n) * 2 * .pi - .pi / 2
                if i == 0 { path.move(to: at(a, 0.88)) }
                path.addQuadCurve(to: at(b, 0.88), control: at((a + b) / 2, 1.06))
            }
            path.closeSubpath()
            return path
        }
    }

    /// A regular polygon with rounded corners.
    static func polygon(_ n: Int, center c: CGPoint, radius: CGFloat, rotation: CGFloat, corner: CGFloat) -> Path {
        let v = (0..<n).map { i -> CGPoint in
            let a = rotation + CGFloat(i) / CGFloat(n) * 2 * .pi
            return CGPoint(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius)
        }
        var path = Path()
        path.move(to: CGPoint(x: (v[n - 1].x + v[0].x) / 2, y: (v[n - 1].y + v[0].y) / 2))
        for i in 0..<n {
            path.addArc(tangent1End: v[i], tangent2End: v[(i + 1) % n], radius: corner)
        }
        path.closeSubpath()
        return path
    }
}

/// The medal body shared by badges and constellation medals; `emblem` draws inside the inner box.
struct MedalFace: View {
    let outline: MedalOutline
    let tone: Color
    var earned = true
    var size: CGFloat = 56
    let emblem: (GraphicsContext, CGRect, Color) -> Void

    var body: some View {
        ZStack {
            if earned {
                MedalShape(outline: outline, inset: 0.6)
                    .fill(RadialGradient(colors: [tone.opacity(0.34), tone.opacity(0.07)],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.75))
                MedalShape(outline: outline, inset: 0.6).stroke(tone.opacity(0.65), lineWidth: 1.2)
                MedalShape(outline: outline, inset: size * 0.09).stroke(tone.opacity(0.28), lineWidth: 0.8)
            } else {
                MedalShape(outline: outline, inset: 0.6)
                    .stroke(Theme.star.opacity(0.24), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            Canvas { ctx, sz in
                let box = CGRect(origin: .zero, size: sz).insetBy(dx: sz.width * 0.23, dy: sz.height * 0.23)
                emblem(ctx, box, earned ? tone : Theme.paper3)
            }
            .opacity(earned ? 1 : 0.4)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if !earned {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.15))
                    .foregroundStyle(Theme.paper3)
                    .frame(width: size * 0.32, height: size * 0.32)
                    .background(Theme.night, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.star.opacity(0.22), lineWidth: 1))
            }
        }
        .accessibilityHidden(true)
    }
}

struct BadgeMedal: View {
    let badge: Badge
    var earned = true
    var size: CGFloat = 56

    var body: some View {
        MedalFace(outline: badge.outline, tone: badge.tone, earned: earned, size: size) { ctx, box, color in
            BadgeEmblem.draw(badge, in: box, ctx: ctx, color: color, unit: size / 56)
        }
    }
}

/// The medal for a finished constellation: its own figure, every star lit.
struct ConstellationMedal: View {
    let constellation: Constellation
    var size: CGFloat = 56

    var body: some View {
        MedalFace(outline: .circle, tone: Theme.accentInk, size: size) { ctx, box, color in
            SkyDrawing.draw(constellation, lit: { _ in true }, in: box.insetBy(dx: -size * 0.04, dy: -size * 0.04), ctx: ctx,
                            accent: color, ink: color, missing: color, starScale: size / 120)
        }
    }
}

enum BadgeEmblem {
    static func draw(_ badge: Badge, in r: CGRect, ctx: GraphicsContext, color: Color, unit u: CGFloat) {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        func dot(_ c: CGPoint, _ rad: CGFloat, _ o: Double = 1) {
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)), with: .color(color.opacity(o)))
        }
        func spark(_ c: CGPoint, _ s: CGFloat) {
            ctx.fill(SparkShape().path(in: CGRect(x: c.x - s / 2, y: c.y - s / 2, width: s, height: s)), with: .color(color))
        }
        let w = r.width
        let line = StrokeStyle(lineWidth: 1.6 * u, lineCap: .round)

        switch badge {
        case .firstLight:
            // The first sunrise: a half sun on the horizon, rays, its reflection on the water.
            let c = p(0.5, 0.66)
            var sun = Path()
            sun.addArc(center: c, radius: w * 0.24, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            sun.closeSubpath()
            ctx.fill(sun, with: .color(color))
            for i in 0..<7 {
                let a = (190 + Double(i) * 160 / 6) * .pi / 180
                var ray = Path()
                ray.move(to: CGPoint(x: c.x + cos(a) * w * 0.34, y: c.y + sin(a) * w * 0.34))
                ray.addLine(to: CGPoint(x: c.x + cos(a) * w * 0.47, y: c.y + sin(a) * w * 0.47))
                ctx.stroke(ray, with: .color(color), style: line)
            }
            for (y, half, o) in [(0.66, 0.5, 1.0), (0.8, 0.28, 0.7), (0.93, 0.14, 0.45)] {
                var h = Path()
                h.move(to: p(0.5 - half, y)); h.addLine(to: p(0.5 + half, y))
                ctx.stroke(h, with: .color(color.opacity(o)), style: line)
            }

        case .marathon90:
            // A dial run three quarters round, with 90 at its heart.
            let c = p(0.5, 0.5), rad = w * 0.46
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)),
                       with: .color(color.opacity(0.28)), lineWidth: 2.2 * u)
            var arc = Path()
            arc.addArc(center: c, radius: rad, startAngle: .degrees(-90), endAngle: .degrees(180), clockwise: false)
            ctx.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: 2.4 * u, lineCap: .round))
            dot(CGPoint(x: c.x - rad, y: c.y), 2.4 * u)
            ctx.draw(Text("90").font(.system(size: w * 0.42, weight: .semibold, design: .serif)).foregroundColor(color), at: c)

        case .streak7:
            // Seven days climbing into a star.
            let pts = (0..<7).map { i -> CGPoint in
                let t = CGFloat(i) / 6
                return p(0.04 + t * 0.84, 0.9 - (t * 0.55 + t * t * 0.25))
            }
            var trail = Path()
            trail.addLines(pts)
            ctx.stroke(trail, with: .color(color.opacity(0.45)), style: StrokeStyle(lineWidth: 1 * u, lineCap: .round, dash: [1.5 * u, 2.5 * u]))
            for (i, pt) in pts.dropLast().enumerated() { dot(pt, (1.5 + CGFloat(i) * 0.3) * u, 0.55 + Double(i) * 0.07) }
            spark(pts[6], w * 0.42)

        case .nightOwl:
            // A crescent moon and the late stars beside it.
            let big = Path(ellipseIn: CGRect(x: r.minX + w * 0.04, y: r.minY + w * 0.12, width: w * 0.72, height: w * 0.72))
            let bite = Path(ellipseIn: CGRect(x: r.minX + w * 0.28, y: r.minY + w * 0.0, width: w * 0.62, height: w * 0.62))
            ctx.fill(big.subtracting(bite), with: .color(color))
            spark(p(0.82, 0.62), w * 0.26)
            dot(p(0.66, 0.9), 1.3 * u, 0.8)
            dot(p(0.96, 0.32), 1.1 * u, 0.6)

        case .proxima:
            // Alpha Centauri A and B on their shared orbit; Proxima, the red dwarf, far out.
            let orbit = Path(ellipseIn: CGRect(x: r.minX + w * 0.02, y: r.minY + w * 0.44, width: w * 0.7, height: w * 0.34))
            ctx.stroke(orbit, with: .color(color.opacity(0.4)), lineWidth: 1 * u)
            dot(p(0.24, 0.62), w * 0.13)
            dot(p(0.52, 0.6), w * 0.09)
            var path = Path()
            path.move(to: p(0.6, 0.48))
            path.addQuadCurve(to: p(0.84, 0.16), control: p(0.82, 0.42))
            ctx.stroke(path, with: .color(color.opacity(0.55)), style: StrokeStyle(lineWidth: 1 * u, lineCap: .round, dash: [1.5 * u, 2.5 * u]))
            dot(p(0.88, 0.12), w * 0.14, 0.18)
            dot(p(0.88, 0.12), w * 0.06)

        case .pleiades:
            // The Seven Sisters as they sit in the sky.
            let sisters: [(CGFloat, CGFloat, CGFloat)] = [
                (0.5, 0.5, 1.0), (0.84, 0.54, 0.8), (0.88, 0.38, 0.6), (0.38, 0.72, 0.75),
                (0.12, 0.52, 0.75), (0.3, 0.3, 0.7), (0.4, 0.08, 0.6),
            ]
            for (x, y, s) in sisters {
                dot(p(x, y), w * 0.15 * s, 0.16)
                dot(p(x, y), w * 0.065 * s)
            }

        case .meteor:
            // Three meteors falling in the same direction, as in a shower.
            for (hx, hy, len, s) in [(0.24, 0.74, 0.62, 1.0), (0.6, 0.86, 0.4, 0.7), (0.56, 0.34, 0.36, 0.6)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                let head = p(hx, hy)
                let tail = CGPoint(x: head.x + len * w, y: head.y - len * w)
                let half = 2.2 * u * s
                var streak = Path()
                streak.move(to: tail)
                streak.addLine(to: CGPoint(x: head.x - half * 0.7, y: head.y - half * 0.7))
                streak.addLine(to: CGPoint(x: head.x + half * 0.7, y: head.y + half * 0.7))
                streak.closeSubpath()
                ctx.fill(streak, with: .linearGradient(Gradient(colors: [color.opacity(0), color]), startPoint: tail, endPoint: head))
                dot(head, half * 1.1)
            }
        }
    }
}
