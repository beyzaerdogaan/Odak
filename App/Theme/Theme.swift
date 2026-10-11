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
struct StarField: View {
    var seed: UInt64 = 1
    var count = 90
    /// Fraction of the height the stars occupy, from the top.
    var depth: CGFloat = 1
    var grid = true
    var theme: SkyTheme = .night

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Theme.night
            if !theme.horizon.isEmpty {
                LinearGradient(colors: [.clear] + theme.horizon, startPoint: .center, endPoint: .bottom)
                    .opacity(scheme == .light ? 0.35 : 1)
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
                for _ in 0..<count {
                    let x = CGFloat.random(in: 0...size.width, using: &rng)
                    let y = CGFloat.random(in: 0...bottom, using: &rng)
                    let fade = 1 - y / max(1, bottom) * 0.75
                    let r: CGFloat = [0.5, 0.6, 0.7, 0.8, 0.9, 1.1, 1.3].randomElement(using: &rng)!
                    let o = Double(CGFloat.random(in: 0.25...0.85, using: &rng) * fade)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(ink.opacity(o)))
                }
                for _ in 0..<3 {
                    let x = CGFloat.random(in: 20...max(21, size.width - 20), using: &rng)
                    let y = CGFloat.random(in: 0...max(1, bottom * 0.5), using: &rng)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)), with: .color(ink.opacity(0.08)))
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1.3, y: y - 1.3, width: 2.6, height: 2.6)), with: .color(ink.opacity(0.9)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
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
