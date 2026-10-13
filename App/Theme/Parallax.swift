import CoreMotion
import Observation
import SwiftUI

/// Tilt of the phone, as an offset in -1...1 on each axis, measured from the way it is being held: the
/// neutral pose follows the hand slowly, so the sky drifts back to centre once the phone stays still.
@MainActor @Observable
final class DeviceTilt {
    /// One motion manager for the whole app, as Core Motion asks.
    static let shared = DeviceTilt()

    private(set) var offset: CGSize = .zero

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var neutral: CMAcceleration?
    @ObservationIgnored private var users = 0

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let g = motion?.gravity else { return }
            MainActor.assumeIsolated { self?.update(g) }
        }
    }

    func stop() {
        users = max(0, users - 1)
        guard users == 0 else { return }
        manager.stopDeviceMotionUpdates()
        neutral = nil
        offset = .zero
    }

    private func update(_ g: CMAcceleration) {
        var n = neutral ?? g
        // The neutral pose catches up with the hand over a few seconds.
        n.x += (g.x - n.x) * 0.006
        n.y += (g.y - n.y) * 0.006
        neutral = n
        // About 25 degrees of tilt moves the sky all the way; the reading is smoothed against jitter.
        let target = CGSize(width: clamp((g.x - n.x) / 0.42), height: clamp((g.y - n.y) / 0.42))
        offset = CGSize(width: offset.width + (target.width - offset.width) * 0.15,
                        height: offset.height + (target.height - offset.height) * 0.15)
    }

    private func clamp(_ v: Double) -> CGFloat { CGFloat(min(1, max(-1, v))) }
}

/// Shifts the content a little against the phone's tilt, so it reads as lying deeper than the screen.
/// Off with Reduce Motion, and still where there is no motion sensor (Simulator).
private struct TiltParallax: ViewModifier {
    var distance: CGFloat
    private var tilt: DeviceTilt { .shared }
    @State private var running = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let on = !reduceMotion && distance > 0
        content
            // Slightly oversized so the edges never come into view while it shifts.
            .scaleEffect(on ? 1 + distance * 2.4 / 400 : 1)
            .offset(x: on ? -tilt.offset.width * distance : 0, y: on ? tilt.offset.height * distance : 0)
            .onAppear { run(on) }
            .onDisappear { run(false) }
            .onChange(of: on) { _, now in run(now) }
    }

    private func run(_ on: Bool) {
        guard on != running else { return }
        running = on
        on ? tilt.start() : tilt.stop()
    }
}

extension View {
    func tiltParallax(_ distance: CGFloat) -> some View {
        modifier(TiltParallax(distance: distance))
    }
}
