import OdakCore
import SwiftUI

/// Background for the "Gökyüzü etkinliği" screen, drawn after the event itself. Meteor showers get
/// live meteors streaking away from the shower's radiant over a quiet star field; each shower has its
/// own pace, colour and radiant so Perseidler and Liridler do not look the same.
struct EventBackdrop: View {
    let shower: MeteorShower
    /// Outside the active window the sky only hints at what is coming: fewer, fainter meteors.
    var active = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let style = MeteorStyle(shower)
        ZStack {
            StarField(seed: 31, count: 110, grid: false)
            LinearGradient(colors: [style.tint.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            TimelineView(.animation(paused: reduceMotion)) { context in
                MeteorRain(style: style, active: active,
                           time: reduceMotion ? 3.2 : context.date.timeIntervalSinceReferenceDate)
            }
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
}

/// How one shower looks: meteors per screen, how fast they fall and where they come from.
struct MeteorStyle {
    /// Meteors that can be in the sky at once.
    var lanes: Int
    /// Seconds a meteor takes to cross its path.
    var speed: ClosedRange<Double>
    /// Seconds between two meteors in the same lane.
    var period: ClosedRange<Double>
    /// Where the meteors seem to come from, in unit coordinates of the screen (may lie off screen).
    var radiant: CGPoint
    var tint: Color

    init(_ shower: MeteorShower) {
        switch shower.id {
        case "perseids": // The richest summer shower: many bright, warm-tailed meteors.
            self.init(lanes: 9, speed: 0.7...1.1, period: 2.2...4.2, radiant: CGPoint(x: 0.85, y: -0.12), tint: Theme.ember)
        case "geminids": // Slow, bright and plentiful, often yellowish.
            self.init(lanes: 9, speed: 1.0...1.5, period: 2.4...4.4, radiant: CGPoint(x: 0.25, y: -0.15), tint: Theme.accent)
        case "leonids": // The fastest meteors, green-tinged trains.
            self.init(lanes: 6, speed: 0.45...0.75, period: 2.8...5.0, radiant: CGPoint(x: 0.7, y: -0.2), tint: Theme.aurora)
        case "orionids": // Fast, from Avcı rising in the east.
            self.init(lanes: 6, speed: 0.55...0.85, period: 3.0...5.2, radiant: CGPoint(x: 1.05, y: 0.05), tint: Theme.ice)
        case "quadrantids": // A short, sharp peak from the far north.
            self.init(lanes: 7, speed: 0.7...1.0, period: 2.6...4.6, radiant: CGPoint(x: 0.5, y: -0.25), tint: Theme.ice)
        case "lyrids": // A modest spring shower near Vega.
            self.init(lanes: 4, speed: 0.8...1.2, period: 3.4...6.0, radiant: CGPoint(x: 0.15, y: -0.1), tint: Theme.meteor)
        default:
            self.init(lanes: 6, speed: 0.7...1.1, period: 3.0...5.0, radiant: CGPoint(x: 0.8, y: -0.15), tint: Theme.meteor)
        }
    }

    init(lanes: Int, speed: ClosedRange<Double>, period: ClosedRange<Double>, radiant: CGPoint, tint: Color) {
        self.lanes = lanes; self.speed = speed; self.period = period; self.radiant = radiant; self.tint = tint
    }
}

/// The meteors for one instant. Each lane replays a meteor every `period` seconds; the meteor's path
/// is picked from a hash of (lane, cycle), so the sky never repeats but needs no stored state.
private struct MeteorRain: View {
    let style: MeteorStyle
    let active: Bool
    let time: TimeInterval

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { ctx, size in
            let light = scheme == .light
            let radiant = CGPoint(x: style.radiant.x * size.width, y: style.radiant.y * size.height)
            let (rx, ry) = (Double(radiant.x), Double(radiant.y))
            let reach = Double(hypot(size.width, size.height))
            let lanes = active ? style.lanes : max(2, style.lanes / 3)
            let head = light ? style.tint : Color(hex: 0xFFFBF0)

            for lane in 0..<lanes {
                var r = Hash(UInt64(lane) &* 0x9E37_79B9 &+ 17)
                let period = r.in(style.period)
                let t = time + r.in(0...period) // stagger lanes
                let cycle = floor(t / period)
                let local = t - cycle * period
                var m = Hash((UInt64(lane) &* 0x1000_0193) ^ (UInt64(bitPattern: Int64(cycle)) &* 0x2545_F491_4F6C_DD1D))
                let duration = m.in(style.speed)
                guard local < duration else { continue }
                let p = local / duration

                // Direction away from the radiant, spread over the lower half-plane it faces.
                let toCenter = Double(atan2(size.height / 2 - radiant.y, size.width / 2 - radiant.x))
                let angle = toCenter + m.in(-0.75...0.75)
                let dir = (x: cos(angle), y: sin(angle))
                // Meteors appear a little way from the radiant, never right on it.
                let start = m.in(0.15...0.75) * reach
                let length = m.in(0.18...0.34) * reach
                let tail = m.in(70...150)
                let brightness = m.in(0.55...1.0) * (active ? 1 : 0.6)

                let travelled = start + length * p
                let h = CGPoint(x: rx + dir.x * travelled, y: ry + dir.y * travelled)
                let trail = min(tail, length * p + 8)
                let t0 = CGPoint(x: h.x - dir.x * trail, y: h.y - dir.y * trail)
                // Flare in, burn, fade out.
                let alpha = brightness * min(1, p * 6) * (p > 0.7 ? (1 - p) / 0.3 : 1)

                var path = Path()
                path.move(to: t0)
                path.addLine(to: h)
                ctx.stroke(path, with: .linearGradient(
                    Gradient(colors: [style.tint.opacity(0), style.tint.opacity(alpha * 0.55), head.opacity(alpha)]),
                    startPoint: t0, endPoint: h), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                let g: CGFloat = 5
                ctx.fill(Path(ellipseIn: CGRect(x: h.x - g, y: h.y - g, width: g * 2, height: g * 2)),
                         with: .radialGradient(Gradient(colors: [head.opacity(alpha * 0.7), head.opacity(0)]),
                                               center: h, startRadius: 0, endRadius: g))
            }
        }
    }
}

/// SplitMix64: well-mixed numbers from small, sequential seeds.
private struct Hash {
    var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func `in`(_ range: ClosedRange<Double>) -> Double { range.lowerBound + unit() * (range.upperBound - range.lowerBound) }
}
