import SwiftUI
import UIKit
import WidgetKit

/// The few design tokens the Live Activity needs (see App/Theme/Theme.swift). Always the night
/// palette: the lock screen follows the system appearance, but Derin has no light look.
enum ActivityInk {
    /// See-through, so the lock screen wallpaper shows behind the system's blur.
    static let background = color(0x090D22, 0.45)
    static let paper = color(0xECE6D6)
    static let paper2 = color(0xA7ADC6)
    static let track = color(0xECE6D6, 0.12)
    static let accent = color(0xF2C46D)
    static let accentInk = color(0xF2C46D)
    static let aurora = color(0x8FDCC0)
    static let ice = color(0xA8C4FF)
    static let islandAccent = color(0xF2C46D)
    static let islandIce = color(0xA8C4FF)

    static func color(_ hex: UInt32, _ alpha: Double = 1) -> Color { Color(uiColor: rgb(hex, alpha)) }
}

/// Same as UIColor(hex:) in the app's theme, which the extension does not compile.
private func rgb(_ hex: UInt32, _ alpha: Double = 1) -> UIColor {
    UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Derin's four-point star.
struct ActivitySpark: Shape {
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

/// Lock screen and notification banner: status, task, a live countdown and a progress line.
struct FocusLockScreenView: View {
    let attributes: FocusActivityAttributes
    let phase: FocusActivityPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.16))
                    ActivitySpark().fill(tint).frame(width: 20, height: 20)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(status).font(.system(size: 13, weight: .medium)).foregroundStyle(ActivityInk.paper2)
                    Text(attributes.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(ActivityInk.paper)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                clock
            }
            progress
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    @ViewBuilder private var clock: some View {
        switch phase {
        case let .focus(interval):
            Text(timerInterval: interval, countsDown: true)
                .font(.system(size: 34, weight: .regular, design: .serif)).monospacedDigit()
                .foregroundStyle(ActivityInk.paper)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120, alignment: .trailing)
        case let .onBreak(until, _):
            Text(timerInterval: Date.now...max(until, .now), countsDown: true)
                .font(.system(size: 34, weight: .regular, design: .serif)).monospacedDigit()
                .foregroundStyle(ActivityInk.ice)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120, alignment: .trailing)
        case .done:
            ActivitySpark().fill(ActivityInk.accent).frame(width: 30, height: 30)
        }
    }

    @ViewBuilder private var progress: some View {
        switch phase {
        case let .focus(interval):
            ProgressView(timerInterval: interval, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.linear)
                .tint(ActivityInk.accent)
        case let .onBreak(_, remaining):
            HStack {
                Text("Mola bitince sayaç kaldığı yerden devam eder").font(.system(size: 12)).foregroundStyle(ActivityInk.paper2)
                Spacer()
                Text("\(minutes(remaining)) dk kaldı").font(.system(size: 12, weight: .medium)).foregroundStyle(ActivityInk.paper2)
            }
        case .done:
            Text("Süren doldu. Hangi yıldızı yaktığını görmek için Derin'i aç.")
                .font(.system(size: 13)).foregroundStyle(ActivityInk.paper2)
        }
    }

    private var status: String {
        switch phase {
        case .focus: "Derin odak sürüyor"
        case .onBreak: "Moladasın"
        case .done: "Yıldızın hazır"
        }
    }

    private var tint: Color {
        switch phase {
        case .focus, .done: ActivityInk.accent
        case .onBreak: ActivityInk.ice
        }
    }
}

/// Countdown for the Dynamic Island, where the system font sizes and the island's black background apply.
struct FocusIslandClock: View {
    let phase: FocusActivityPhase
    var size: CGFloat = 15

    var body: some View {
        switch phase {
        case let .focus(interval):
            Text(timerInterval: interval, countsDown: true)
                .font(.system(size: size, weight: .semibold)).monospacedDigit()
                .foregroundStyle(ActivityInk.islandAccent)
        case let .onBreak(until, _):
            Text(timerInterval: Date.now...max(until, .now), countsDown: true)
                .font(.system(size: size, weight: .semibold)).monospacedDigit()
                .foregroundStyle(ActivityInk.islandIce)
        case .done:
            Text("Bitti").font(.system(size: size, weight: .semibold)).foregroundStyle(ActivityInk.islandAccent)
        }
    }
}

private func minutes(_ t: TimeInterval) -> Int { Int((t / 60).rounded(.up)) }
