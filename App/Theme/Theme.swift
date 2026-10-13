import OdakCore
import SwiftUI
import UIKit

/// Design tokens from design/tools/derin_build.py. Dark is the night sky; light is a dawn star atlas
/// printed in navy ink. Every colour resolves per trait, so the app follows the system appearance.
enum Theme {
    static let night = dynamic(light: 0xE8EBF4, dark: 0x090D22)
    static let night2 = dynamic(light: 0xF6F7FB, dark: 0x0E1430)
    static let deep = dynamic(light: 0xCBD1E2, dark: 0x05081A)
    static let plate = dynamic(light: 0x1B2140, lightAlpha: 0.055, dark: 0xECE6D6, darkAlpha: 0.045)
    static let plate2 = dynamic(light: 0x1B2140, lightAlpha: 0.09, dark: 0xECE6D6, darkAlpha: 0.08)
    static let hair = dynamic(light: 0x1B2140, lightAlpha: 0.13, dark: 0xECE6D6, darkAlpha: 0.11)
    static let paper = dynamic(light: 0x1B2140, dark: 0xECE6D6)
    static let paper2 = dynamic(light: 0x4F5779, dark: 0xA7ADC6)
    static let paper3 = dynamic(light: 0x7D84A2, dark: 0x6E7597)
    static let paperBody = dynamic(light: 0x353C5E, dark: 0xCFCBC0)
    static let star = dynamic(light: 0x27305C, dark: 0xECE6D6)
    /// Accent as a fill (buttons, lit stars).
    static let accent = dynamic(light: 0xD3A24B, dark: 0xF2C46D)
    /// Accent as text, darker on light backgrounds for contrast.
    static let accentInk = dynamic(light: 0x8A6312, dark: 0xF2C46D)
    static let onAccent = Color(hex: 0x1C1404)
    static let core = dynamic(light: 0xFFFDF5, dark: 0xFFF8E6)
    static let nebula = dynamic(light: 0xA8487A, dark: 0xE6A6C7)
    static let ice = dynamic(light: 0x3557B8, dark: 0xA8C4FF)
    static let aurora = dynamic(light: 0x1C7D60, dark: 0x8FDCC0)
    static let meteor = dynamic(light: 0x5D47BE, dark: 0xC9B8FF)
    static let meteor2 = dynamic(light: 0x463A7A, dark: 0xD6CFF0)
    static let ember = dynamic(light: 0xB9582A, dark: 0xF0A070)
    static let alarm = dynamic(light: 0xB23A30, dark: 0xF2A49A)

    static func dynamic(light: UInt32, lightAlpha: Double = 1, dark: UInt32, darkAlpha: Double = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .light ? UIColor(hex: light, alpha: lightAlpha) : UIColor(hex: dark, alpha: darkAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) { self.init(uiColor: UIColor(hex: hex, alpha: opacity)) }
}

// MARK: - Type

extension Font {
    /// Newsreader in the design; the system serif (New York) is the native stand-in.
    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        let f = Font.system(size: size, weight: .regular, design: .serif)
        return italic ? f.italic() : f
    }
}

extension View {
    func meta() -> some View { font(.system(size: 13)).foregroundStyle(Theme.paper2) }
    func small() -> some View { font(.system(size: 12)).foregroundStyle(Theme.paper3) }
}

// MARK: - Sky backgrounds

extension SkyTheme {
    /// Glow along the bottom of the sky for themes bought in the shop.
    var horizon: [Color] {
        switch self {
        case .night: []
        case .aurora: [Color(hex: 0x1E5A5A, opacity: 0.55), Color(hex: 0x5FD3A8, opacity: 0.35)]
        case .twilight: [Color(hex: 0x6A3A3A, opacity: 0.5), Color(hex: 0xE59A6A, opacity: 0.35)]
        case .nebula: [Color(hex: 0x6A2F55, opacity: 0.45), Color(hex: 0xE6A6C7, opacity: 0.3)]
        case .redDwarf: [Color(hex: 0x5A1E1E, opacity: 0.5), Color(hex: 0xF07050, opacity: 0.3)]
        }
    }
}

/// Seeded star field with the faint celestial grid of the design. Drawn once with Canvas.
/// Reads like a real night sky: darker at the zenith with airglow near the horizon, many faint stars
/// and few bright ones in slightly different colours, and, when it fills the screen, a Milky Way band.
struct StarField: View {
    var seed: UInt64 = 1
    var count = 90
    /// Fraction of the height the stars occupy, from the top.
    var depth: CGFloat = 1
    var grid = true
    var theme: SkyTheme = .night
    /// Instead of stopping at `depth`, the stars thin out and dim gradually towards it, like a real sky
    /// fading into the horizon haze. Used behind the content screens (Evren, Odak, Ödüller).
    var falloff = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let light = scheme == .light
        ZStack {
            Theme.night
            // Zenith to horizon: deeper overhead, a faint airglow (dark) or dawn warmth (light) below.
            LinearGradient(stops: skyStops(light: light), startPoint: .top, endPoint: .bottom)
            if !theme.horizon.isEmpty {
                LinearGradient(colors: [.clear] + theme.horizon, startPoint: .center, endPoint: .bottom)
                    .opacity(light ? 0.35 : 1)
            }
            Canvas { ctx, size in
                var rng = SeededGenerator(seed: seed)
                let ink = Theme.star
                if grid {
                    let c = CGPoint(x: size.width / 2, y: size.height * 1.36)
                    for r in stride(from: CGFloat(520), through: 1000, by: 120) {
                        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                                   with: .color(ink.opacity(0.045)), lineWidth: 1)
                    }
                }
                let bottom = size.height * depth
                // Star colours by temperature; on the light atlas they stay in navy ink.
                let tints: [Color] = light ? [ink, ink, ink, Theme.ice]
                    : [ink, Color(hex: 0xF4F6FF), Color(hex: 0xCADBFF), Color(hex: 0xFFE4BE), Color(hex: 0xFFD2A8)]
                func star(at p: CGPoint, mag u: CGFloat, fade: CGFloat) {
                    // Most stars are faint pinpricks; brightness falls off steeply.
                    let r = 0.35 + pow(u, 3) * 1.15
                    let o = Double((0.18 + u * 0.7) * fade)
                    let tint = tints.randomElement(using: &rng)!
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(o)))
                }

                if falloff {
                    fadingSky(ctx: ctx, size: size, light: light, tints: tints, rng: &rng)
                    return
                }

                if depth >= 0.6 {
                    milkyWay(ctx: ctx, size: size, light: light) { p, u in
                        star(at: p, mag: u * 0.55, fade: 1 - p.y / size.height * 0.35)
                    }
                }

                for _ in 0..<count {
                    let x = CGFloat.random(in: 0...size.width, using: &rng)
                    let y = CGFloat.random(in: 0...bottom, using: &rng)
                    // Fewer, dimmer stars towards the horizon, as the air thickens.
                    let fade = 1 - y / max(1, bottom) * (depth >= 0.6 ? 0.45 : 0.75)
                    star(at: CGPoint(x: x, y: y), mag: CGFloat.random(in: 0...1, using: &rng), fade: fade)
                }
                // A handful of bright stars with a soft halo.
                for _ in 0..<(depth >= 0.6 ? 6 : 3) {
                    let x = CGFloat.random(in: 20...max(21, size.width - 20), using: &rng)
                    let y = CGFloat.random(in: 0...max(1, bottom * (depth >= 0.6 ? 0.8 : 0.5)), using: &rng)
                    let tint = tints.randomElement(using: &rng)!
                    let halo = CGFloat.random(in: 5...9, using: &rng)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - halo, y: y - halo, width: halo * 2, height: halo * 2)),
                             with: .radialGradient(Gradient(colors: [tint.opacity(light ? 0.14 : 0.22), tint.opacity(0)]),
                                                   center: CGPoint(x: x, y: y), startRadius: 0, endRadius: halo))
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1.3, y: y - 1.3, width: 2.6, height: 2.6)), with: .color(tint.opacity(0.95)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func skyStops(light: Bool) -> [Gradient.Stop] {
        light
            ? [.init(color: Color(hex: 0xD3DAEC), location: 0), .init(color: .clear, location: 0.45),
               .init(color: Color(hex: 0xF4EEEA), location: 1)]
            : [.init(color: Color(hex: 0x03050F), location: 0), .init(color: .clear, location: 0.5),
               .init(color: Color(hex: 0x1A2350, opacity: 0.8), location: 1)]
    }

    /// Stars that come down from the top of the screen and fade out gradually: density and brightness
    /// both fall off with height, most stars are faint (a steep magnitude distribution) with a fine
    /// dust of barely visible ones, and a few bright stars carry a soft halo and faint diffraction spikes.
    private func fadingSky(ctx: GraphicsContext, size: CGSize, light: Bool, tints: [Color], rng: inout SeededGenerator) {
        let bottom = size.height * depth
        func dot(_ p: CGPoint, r: CGFloat, _ color: Color) {
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(color))
        }
        // Height sample biased towards the top, with a long, thin tail down to `bottom`.
        func height(_ bias: Double) -> CGFloat {
            bottom * CGFloat(pow(Double.random(in: 0...1, using: &rng), bias))
        }
        func fade(_ y: CGFloat) -> CGFloat { pow(max(0, 1 - y / max(1, bottom)), 1.4) }

        // Unresolved background stars: tiny, dim, numerous.
        for _ in 0..<(count * 2) {
            let p = CGPoint(x: CGFloat.random(in: 0...size.width, using: &rng), y: height(1.3))
            let o = Double(CGFloat.random(in: 0.08...0.26, using: &rng) * fade(p.y)) * (light ? 0.8 : 1)
            dot(p, r: CGFloat.random(in: 0.25...0.45, using: &rng), tints.randomElement(using: &rng)!.opacity(o))
        }
        // Resolved stars with a steep magnitude distribution.
        for _ in 0..<count {
            let p = CGPoint(x: CGFloat.random(in: 0...size.width, using: &rng), y: height(1.6))
            let u = CGFloat(pow(Double.random(in: 0...1, using: &rng), 2.2))
            let f = 0.25 + 0.75 * fade(p.y)
            let tint = tints.randomElement(using: &rng)!
            let r = 0.4 + u * 1.1
            if u > 0.55 && !light {
                // Slight bloom around the brighter ones.
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 3, y: p.y - r * 3, width: r * 6, height: r * 6)),
                         with: .radialGradient(Gradient(colors: [tint.opacity(0.12 * f), tint.opacity(0)]),
                                               center: p, startRadius: 0, endRadius: r * 3))
            }
            dot(p, r: r, tint.opacity(Double((0.22 + u * 0.7) * f * fade(p.y * 0.6))))
        }
        // A few bright stars high up, with halo and faint four-way diffraction spikes.
        for _ in 0..<4 {
            let p = CGPoint(x: CGFloat.random(in: 24...max(25, size.width - 24), using: &rng),
                            y: CGFloat.random(in: 10...max(11, bottom * 0.45), using: &rng))
            let tint = tints.randomElement(using: &rng)!
            let f = Double(0.4 + 0.6 * fade(p.y))
            let halo = CGFloat.random(in: 7...11, using: &rng)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo, width: halo * 2, height: halo * 2)),
                     with: .radialGradient(Gradient(colors: [tint.opacity((light ? 0.14 : 0.24) * f), tint.opacity(0)]),
                                           center: p, startRadius: 0, endRadius: halo))
            let spike = halo * 1.3
            for (dx, dy) in [(spike, CGFloat(0)), (0, spike)] {
                var line = Path()
                line.move(to: CGPoint(x: p.x - dx, y: p.y - dy))
                line.addLine(to: CGPoint(x: p.x + dx, y: p.y + dy))
                ctx.stroke(line, with: .linearGradient(
                    Gradient(colors: [tint.opacity(0), tint.opacity((light ? 0.2 : 0.35) * f), tint.opacity(0)]),
                    startPoint: line.boundingRect.origin,
                    endPoint: CGPoint(x: line.boundingRect.maxX, y: line.boundingRect.maxY)), lineWidth: 0.6)
            }
            dot(p, r: 1.3, tint.opacity(0.95 * f))
        }
    }

    /// A diagonal band of diffuse light split by a dark dust lane, dusted with faint stars.
    private func milkyWay(ctx: GraphicsContext, size: CGSize, light: Bool, star: (CGPoint, CGFloat) -> Void) {
        var rng = SeededGenerator(seed: seed &+ 202)
        let center = CGPoint(x: size.width * 0.55, y: size.height * 0.42)
        let angle = -0.95 + Double(CGFloat.random(in: -0.12...0.12, using: &rng))
        let dir = CGPoint(x: cos(angle), y: sin(angle)), normal = CGPoint(x: -dir.y, y: dir.x)
        let length = hypot(size.width, size.height)
        let glow: Color = light ? .white : Color(hex: 0xB9C3EE)

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 26))
            layer.translateBy(x: center.x, y: center.y)
            layer.rotate(by: .radians(angle))
            var g = SeededGenerator(seed: seed &+ 101)
            for _ in 0..<9 {
                let x = CGFloat.random(in: -length * 0.5...length * 0.4, using: &g)
                let w = CGFloat.random(in: 140...260, using: &g), h = CGFloat.random(in: 60...120, using: &g)
                let dy = CGFloat.random(in: -18...18, using: &g)
                layer.fill(Path(ellipseIn: CGRect(x: x, y: dy - h / 2, width: w, height: h)),
                           with: .color(glow.opacity(light ? 0.28 : 0.07)))
            }
            // Dust lane slightly off the band's spine.
            for _ in 0..<5 {
                let x = CGFloat.random(in: -length * 0.4...length * 0.3, using: &g)
                let w = CGFloat.random(in: 120...220, using: &g)
                layer.fill(Path(ellipseIn: CGRect(x: x, y: 4, width: w, height: 22)),
                           with: .color(Theme.night.opacity(light ? 0.5 : 0.55)))
            }
        }

        // Faint stars crowd along the band (offsets roughly Gaussian across it).
        for _ in 0..<160 {
            let t = CGFloat.random(in: -length * 0.55...length * 0.55, using: &rng)
            let n = (CGFloat.random(in: -1...1, using: &rng) + CGFloat.random(in: -1...1, using: &rng)
                     + CGFloat.random(in: -1...1, using: &rng)) * 32
            let p = CGPoint(x: center.x + dir.x * t + normal.x * n, y: center.y + dir.y * t + normal.y * n)
            guard p.x >= 0, p.x <= size.width, p.y >= 0, p.y <= size.height else { continue }
            star(p, CGFloat.random(in: 0...1, using: &rng))
        }
    }
}

/// The four-point star used for stars and Işık everywhere.
struct SparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + x / 24 * w, y: rect.minY + y / 24 * h) }
        var path = Path()
        path.move(to: p(12, 0))
        path.addCurve(to: p(24, 12), control1: p(12.9, 7.4), control2: p(15.6, 11))
        path.addCurve(to: p(12, 24), control1: p(15.6, 13), control2: p(12.9, 16.6))
        path.addCurve(to: p(0, 12), control1: p(11.1, 16.6), control2: p(8.4, 13))
        path.addCurve(to: p(12, 0), control1: p(8.4, 11), control2: p(11.1, 7.4))
        path.closeSubpath()
        return path
    }
}

struct Spark: View {
    var size: CGFloat = 14
    var color: Color = Theme.accent
    var body: some View {
        SparkShape().fill(color).frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// A lit star drawn like a photographed one: halo, diffraction spikes and a hot core.
struct Flare: View {
    var radius: CGFloat = 4
    var color: Color = Theme.accent
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.10)).frame(width: radius * 6.4, height: radius * 6.4)
            Circle().fill(color.opacity(0.18)).frame(width: radius * 3.6, height: radius * 3.6)
            SparkShape().fill(color).frame(width: radius * 8.4, height: radius * 8.4)
            Circle().fill(Theme.core).frame(width: radius * 1.1, height: radius * 1.1)
        }
        .accessibilityHidden(true)
    }
}
