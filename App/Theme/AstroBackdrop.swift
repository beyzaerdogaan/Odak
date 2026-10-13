import OdakCore
import SwiftUI

/// Background for an eclipse, planet event or supermoon page, the counterpart of `EventBackdrop` for
/// meteor showers. Each kind has its own slow scene over a quiet star field: the Moon sliding through
/// Earth's shadow, the Moon biting into the Sun, a planet at its brightest with its moons or rings,
/// two planets drawing together, a planet above the twilight horizon, a large rising Moon.
struct AstroBackdrop: View {
    let event: AstroEvent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            StarField(seed: 53, count: 110, grid: false)
            LinearGradient(colors: [AstroStyle.tint(event).opacity(0.2), .clear], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            TimelineView(.animation(paused: reduceMotion)) { context in
                AstroScene(event: event, time: reduceMotion ? 13 : context.date.timeIntervalSinceReferenceDate)
            }
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
}

/// Colours of the bodies and of each kind of event.
enum AstroStyle {
    static func color(_ body: String) -> Color {
        switch body {
        case "sun": Theme.accent
        case "moon": dynamic(light: 0xFFFBEE, dark: 0xF4EEDC)
        case "mercury": dynamic(light: 0x8C7F73, dark: 0xC9BCAE)
        case "venus": dynamic(light: 0xC9A04A, dark: 0xFFF1C9)
        case "mars": dynamic(light: 0xB84A2A, dark: 0xF08A60)
        case "jupiter": dynamic(light: 0xA9824F, dark: 0xEBD3AA)
        case "saturn": dynamic(light: 0xA88A3C, dark: 0xE6CB86)
        default: Theme.star
        }
    }

    static func tint(_ e: AstroEvent) -> Color {
        switch e.kind {
        case .lunarEclipse?: (e.magnitude ?? 0) >= 1 ? Theme.ember : Theme.meteor
        case .solarEclipse?: Theme.accent
        case .supermoon?: Theme.ice
        default: e.bodies.first.map(color) ?? Theme.meteor
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color { Theme.dynamic(light: light, dark: dark) }
}

private struct AstroScene: View {
    let event: AstroEvent
    let time: TimeInterval

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { ctx, size in
            let light = scheme == .light
            switch event.kind {
            case .lunarEclipse?: lunarEclipse(&ctx, size, light)
            case .solarEclipse?: solarEclipse(&ctx, size, light)
            case .opposition?: opposition(&ctx, size, light)
            case .conjunction?: conjunction(&ctx, size, light)
            case .elongation?: elongation(&ctx, size, light)
            case .supermoon?: supermoon(&ctx, size, light)
            case nil: break
            }
        }
    }

    /// Where the scene's main body sits: lower right, below the page's text so it never sits behind it.
    private func focus(_ size: CGSize) -> CGPoint { CGPoint(x: size.width * 0.66, y: size.height * 0.7) }

    /// 0...1 through a loop of `period` seconds.
    private func loop(_ period: Double) -> Double { (time / period).truncatingRemainder(dividingBy: 1) }

    // MARK: Lunar eclipse

    /// The Moon stays put while Earth's shadow drifts across it. The shadow's track is set so its
    /// deepest point matches the real umbral magnitude: a hint of shade for a penumbral eclipse,
    /// a dark bite for a partial one, copper red for a total one.
    private func lunarEclipse(_ ctx: inout GraphicsContext, _ size: CGSize, _ light: Bool) {
        let c = focus(size)
        let r = size.width * 0.16
        let umbra = r * 2.7, penumbra = umbra + r * 2
        let m = event.magnitude ?? 0.5
        // Closest approach of the shadow's centre to the Moon's: m = (umbra + r - d) / 2r.
        let d = max(0, umbra + r - 2 * r * m)
        // Ease through the middle so the deepest part of the eclipse lingers on screen.
        let q = loop(26) * 2 - 1
        let x = (q < 0 ? -1 : 1) * pow(abs(q), 2.2) * (penumbra + r) * 1.2
        let center = CGPoint(x: c.x + x, y: c.y + d)
        let total = m >= 1

        let moonDisc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        let covered = max(0, min(1, (umbra + r - hypot(x, d)) / (2 * r)))
        glow(&ctx, at: c, radius: r * 2.6, color: AstroStyle.color("moon"), alpha: (light ? 0.25 : 0.32) * (1 - covered * 0.8))
        // The Moon and Earth's shadow are drawn into one layer so the shadow multiplies the Moon's
        // own surface: maria and craters stay visible through the copper of the umbra, as in photos.
        ctx.drawLayer { layer in
            drawMoon(&layer, center: c, radius: r, light: light)
            layer.clip(to: moonDisc)
            layer.blendMode = .multiply
            let k = umbra / penumbra
            let core = total ? Color(hex: 0x4A160A) : Color(hex: 0x24100A)
            let rim = total ? Color(hex: 0xB4542C) : Color(hex: 0x6A3422)
            layer.fill(Path(ellipseIn: CGRect(x: center.x - penumbra, y: center.y - penumbra, width: 2 * penumbra, height: 2 * penumbra)),
                       with: .radialGradient(Gradient(stops: [
                           .init(color: core, location: 0),
                           .init(color: rim, location: k * 0.93),
                           .init(color: Color(white: 0.5), location: k * 1.02),
                           .init(color: Color(white: 0.8), location: k + (1 - k) * 0.45),
                           .init(color: .white, location: 1),
                       ]), center: center, startRadius: 0, endRadius: penumbra))
        }
        if total, covered > 0.95 {
            glow(&ctx, at: c, radius: r * 2.2, color: Color(hex: 0xC4502A), alpha: 0.25 * (covered - 0.95) / 0.05)
        }
    }

    // MARK: Solar eclipse

    /// The Moon passes in front of the Sun as seen from Turkey: at its deepest it covers the share of
    /// the Sun's diameter the calendar gives, and the sky dims with it.
    private func solarEclipse(_ ctx: inout GraphicsContext, _ size: CGSize, _ light: Bool) {
        let c = focus(size)
        let rs = size.width * 0.14, rm = rs * 1.03
        let m = event.magnitude ?? 0.6
        let d = max(0, rs + rm - 2 * rs * m)
        let p = loop(28)
        let along = (p * 2 - 1) * (rs + rm) * 1.6
        // The Moon travels from lower right to upper left, offset from the Sun's centre by `d`.
        let dir = CGVector(dx: -0.86, dy: -0.5), normal = CGVector(dx: 0.5, dy: -0.86)
        let moon = CGPoint(x: c.x + dir.dx * along + normal.dx * d, y: c.y + dir.dy * along + normal.dy * d)
        let covered = max(0, min(1, (rs + rm - hypot(along, d)) / (2 * rs)))

        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(covered * (light ? 0.12 : 0.3))))
        glow(&ctx, at: c, radius: rs * 3.4, color: Theme.accent, alpha: (light ? 0.35 : 0.45) * (1 - covered * 0.5))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - rs, y: c.y - rs, width: 2 * rs, height: 2 * rs)),
                 with: .radialGradient(Gradient(colors: [Theme.core, Theme.accent]), center: c, startRadius: 0, endRadius: rs * 1.05))
        ctx.drawLayer { layer in
            layer.clip(to: Path(ellipseIn: CGRect(x: c.x - rs * 1.02, y: c.y - rs * 1.02, width: rs * 2.04, height: rs * 2.04)))
            layer.fill(Path(ellipseIn: CGRect(x: moon.x - rm, y: moon.y - rm, width: 2 * rm, height: 2 * rm)),
                       with: .color(light ? Color(hex: 0x3A4064) : Color(hex: 0x070A1A)))
        }
    }

    // MARK: Opposition

    /// The planet at its brightest, breathing a soft glow: Jupiter with its four large moons in a
    /// line, Saturn with its rings, Mars red with a white polar cap.
    private func opposition(_ ctx: inout GraphicsContext, _ size: CGSize, _ light: Bool) {
        let body = event.bodies.first ?? "jupiter"
        let color = AstroStyle.color(body)
        let bob = sin(time / 5) * 4
        let c = CGPoint(x: focus(size).x, y: focus(size).y + bob)
        let r = size.width * (body == "mars" ? 0.08 : 0.1)
        let breathe = 0.85 + 0.15 * sin(time / 2.3)
        glow(&ctx, at: c, radius: r * 4, color: color, alpha: (light ? 0.3 : 0.4) * breathe)

        let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        if body == "saturn" { ring(&ctx, c, r, color, front: false) }
        ctx.fill(disc, with: .radialGradient(Gradient(colors: [color, color.opacity(0.8)]),
                                             center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.3), startRadius: 0, endRadius: r * 1.4))
        ctx.drawLayer { layer in
            layer.clip(to: disc)
            switch body {
            case "jupiter":
                for (i, y) in [-0.55, -0.2, 0.15, 0.45].enumerated() {
                    let band = CGRect(x: c.x - r, y: c.y + r * y, width: 2 * r, height: r * (i.isMultiple(of: 2) ? 0.16 : 0.1))
                    layer.fill(Path(band), with: .color(Color(hex: 0x8A5A32, opacity: 0.35)))
                }
                layer.fill(Path(ellipseIn: CGRect(x: c.x + r * 0.2, y: c.y + r * 0.2, width: r * 0.3, height: r * 0.16)),
                           with: .color(Color(hex: 0xB0502C, opacity: 0.5)))
            case "mars":
                layer.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.45, y: c.y - r * 1.1, width: r * 0.9, height: r * 0.4)), with: .color(.white.opacity(0.85)))
                layer.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.6, y: c.y - r * 0.05, width: r * 0.9, height: r * 0.35)),
                           with: .color(Color(hex: 0x5A2412, opacity: 0.35)))
            default:
                for y in [-0.35, 0.1] {
                    layer.fill(Path(CGRect(x: c.x - r, y: c.y + r * y, width: 2 * r, height: r * 0.12)), with: .color(Color(hex: 0x8A6A2A, opacity: 0.25)))
                }
            }
            // Night side terminator: the planet is nearly full at opposition, so only a thin shade.
            layer.fill(disc, with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.25)]),
                                                   center: CGPoint(x: c.x - r * 0.2, y: c.y - r * 0.2), startRadius: r * 0.7, endRadius: r * 1.2))
        }
        if body == "saturn" { ring(&ctx, c, r, color, front: true) }
        if body == "jupiter" {
            // Io, Europa, Ganymede and Callisto shuttle along a line, at their real relative periods.
            let moons: [(reach: Double, period: Double)] = [(1.9, 1.77), (2.6, 3.55), (3.5, 7.15), (5.0, 16.7)]
            for (i, moon) in moons.enumerated() {
                let x = c.x + CGFloat(cos(time / moon.period * 0.9 + Double(i) * 1.7) * moon.reach) * r
                let dot = CGRect(x: x - 2, y: c.y - 2, width: 4, height: 4)
                ctx.fill(Path(ellipseIn: dot), with: .color(Theme.star.opacity(0.85)))
            }
        }
    }

    private func ring(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ color: Color, front: Bool) {
        let ring = CGRect(x: c.x - r * 2.2, y: c.y - r * 0.55, width: r * 4.4, height: r * 1.1)
        var layer = ctx
        // The back half of the ring passes behind the planet, the front half in front of it.
        layer.clip(to: Path(CGRect(x: c.x - r * 3, y: front ? c.y : c.y - r * 2, width: r * 6, height: r * 2)))
        layer.stroke(Path(ellipseIn: ring), with: .color(color.opacity(0.85)), lineWidth: r * 0.16)
        layer.stroke(Path(ellipseIn: ring.insetBy(dx: r * 0.32, dy: r * 0.09)), with: .color(color.opacity(0.5)), lineWidth: r * 0.08)
    }

    // MARK: Conjunction

    /// Two planets drift together until they almost touch, then part, above the morning or evening
    /// horizon. The brighter one gets diffraction spikes.
    private func conjunction(_ ctx: inout GraphicsContext, _ size: CGSize, _ light: Bool) {
        horizon(&ctx, size, light, sky: event.sky)
        let a = event.bodies.first ?? "venus", b = event.bodies.dropFirst().first ?? "jupiter"
        let mid = CGPoint(x: size.width * 0.62, y: size.height * 0.7)
        let p = loop(22)
        let gap = 18 + 110 * abs(cos(p * .pi)) // closest in the middle of the loop
        let angle = -0.45
        let off = CGVector(dx: cos(angle) * gap / 2, dy: sin(angle) * gap / 2)
        let first = CGPoint(x: mid.x - off.dx, y: mid.y - off.dy + 6), second = CGPoint(x: mid.x + off.dx, y: mid.y + off.dy - 6)
        for (body, at) in [(a, first), (b, second)] {
            let bright = body == "venus" || body == "jupiter"
            let s: CGFloat = bright ? 7 : 5
            let twinkle = 0.85 + 0.15 * sin(time * 3 + (body == a ? 0 : 1.3))
            glow(&ctx, at: at, radius: s * 6, color: AstroStyle.color(body), alpha: 0.45 * twinkle)
            if body == "venus" { spikes(&ctx, at, length: s * 5, color: AstroStyle.color(body), alpha: 0.5 * twinkle) }
            ctx.fill(Path(ellipseIn: CGRect(x: at.x - s / 2, y: at.y - s / 2, width: s, height: s)), with: .color(AstroStyle.color(body)))
        }
    }

    // MARK: Elongation

    /// A planet hangs above the twilight horizon at its farthest from the Sun; a dotted arc runs down
    /// to where the Sun glows below the horizon.
    private func elongation(_ ctx: inout GraphicsContext, _ size: CGSize, _ light: Bool) {
        horizon(&ctx, size, light, sky: event.sky)
        let body = event.bodies.first ?? "venus"
        let ground = size.height * 0.9
        let morning = event.sky == .morning
        let sun = CGPoint(x: size.width * (morning ? 0.82 : 0.18), y: ground + 30)
        let planet = CGPoint(x: size.width * (morning ? 0.56 : 0.44), y: size.height * (body == "venus" ? 0.64 : 0.74))
        let breathe = 0.8 + 0.2 * sin(time / 3)
        glow(&ctx, at: sun, radius: size.width * 0.5, color: morning ? Theme.accent : Theme.ember, alpha: 0.35 * breathe)

        var arc = Path()
        let ctrl = CGPoint(x: (sun.x + planet.x) / 2 + (morning ? 40 : -40), y: planet.y)
        arc.move(to: sun)
        arc.addQuadCurve(to: planet, control: ctrl)
        ctx.stroke(arc, with: .color(Theme.paper3.opacity(0.45)), style: StrokeStyle(lineWidth: 1, dash: [2, 6]))

        let s: CGFloat = body == "venus" ? 8 : 5
        let twinkle = 0.8 + 0.2 * sin(time * 2.6)
        glow(&ctx, at: planet, radius: s * 7, color: AstroStyle.color(body), alpha: 0.5 * twinkle)
        if body == "venus" { spikes(&ctx, planet, length: s * 5, color: AstroStyle.color(body), alpha: 0.45 * twinkle) }
        ctx.fill(Path(ellipseIn: CGRect(x: planet.x - s / 2, y: planet.y - s / 2, width: s, height: s)), with: .color(AstroStyle.color(body)))
    }

    // MARK: Supermoon

    /// A large full Moon with a wide halo; a faint ring breathes out to the size of an ordinary full
    /// Moon so the difference shows.
    private func supermoon(_ ctx: inout GraphicsContext, _ size: CGSize, _ light: Bool) {
        let c = CGPoint(x: size.width * 0.6, y: size.height * 0.7 + CGFloat(sin(time / 6)) * 3)
        let r = size.width * 0.21
        glow(&ctx, at: c, radius: r * 3, color: AstroStyle.color("moon"), alpha: light ? 0.3 : 0.38)
        drawMoon(&ctx, center: c, radius: r, light: light)
        // An apogee full Moon is about 14 % smaller across.
        let p = 0.5 + 0.5 * sin(time / 2.8)
        let ordinary = r * 0.86
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - ordinary, y: c.y - ordinary, width: 2 * ordinary, height: 2 * ordinary)),
                   with: .color(Theme.ice.opacity(0.25 + 0.35 * p)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
    }

    // MARK: Pieces

    /// The near side of the full Moon, from NASA's LRO maps (`Moon` in the asset catalog), with a
    /// faint cool limb so it sits in the sky rather than on it.
    private func drawMoon(_ ctx: inout GraphicsContext, center c: CGPoint, radius r: CGFloat, light: Bool) {
        let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
        ctx.draw(Image("Moon"), in: rect)
        if light { ctx.stroke(Path(ellipseIn: rect), with: .color(Theme.star.opacity(0.3)), lineWidth: 1) }
    }

    private func glow(_ ctx: inout GraphicsContext, at c: CGPoint, radius: CGFloat, color: Color, alpha: Double) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: 2 * radius, height: 2 * radius)),
                 with: .radialGradient(Gradient(colors: [color.opacity(alpha), color.opacity(0)]), center: c, startRadius: 0, endRadius: radius))
    }

    private func spikes(_ ctx: inout GraphicsContext, _ c: CGPoint, length: CGFloat, color: Color, alpha: Double) {
        for (dx, dy) in [(1.0, 0.0), (0.0, 1.0)] {
            var p = Path()
            p.move(to: CGPoint(x: c.x - dx * length, y: c.y - dy * length))
            p.addLine(to: CGPoint(x: c.x + dx * length, y: c.y + dy * length))
            ctx.stroke(p, with: .linearGradient(Gradient(colors: [color.opacity(0), color.opacity(alpha), color.opacity(0)]),
                                                startPoint: CGPoint(x: c.x - dx * length, y: c.y - dy * length),
                                                endPoint: CGPoint(x: c.x + dx * length, y: c.y + dy * length)), lineWidth: 1)
        }
    }

    /// Dawn or dusk light rising from the bottom edge of the screen.
    private func horizon(_ ctx: inout GraphicsContext, _ size: CGSize, _ light: Bool, sky: AstroEvent.Sky) {
        let colors: [Color] = switch sky {
        case .morning: [Color(hex: 0xE9A27A, opacity: light ? 0.35 : 0.3), Color(hex: 0x6A5AA0, opacity: 0.12), .clear]
        case .evening: [Color(hex: 0xF0905A, opacity: light ? 0.4 : 0.35), Color(hex: 0x8A3A6A, opacity: 0.14), .clear]
        default: [Theme.ice.opacity(0.1), .clear]
        }
        let top = size.height * 0.55
        ctx.fill(Path(CGRect(x: 0, y: top, width: size.width, height: size.height - top)),
                 with: .linearGradient(Gradient(colors: colors.reversed()), startPoint: CGPoint(x: 0, y: top),
                                       endPoint: CGPoint(x: 0, y: size.height)))
    }
}
