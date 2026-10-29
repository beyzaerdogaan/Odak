import SwiftUI

/// Screenshot mode only (`-screen lockscreen`): the session's Live Activity drawn the way the lock screen and the
/// Dynamic Island show it, since the simulator can't photograph its own lock screen.
struct LiveActivityPreview: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let now = Date.now
        let attributes = FocusActivityAttributes(task: model.settings.task, plannedMinutes: 45)
        let focus = FocusActivityPhase.focus(now.addingTimeInterval(-(12 * 60 + 46))...now.addingTimeInterval(32 * 60 + 14))
        let onBreak = FocusActivityPhase.onBreak(until: now.addingTimeInterval(3 * 60 + 20), remaining: 32 * 60 + 14)

        VStack(spacing: 14) {
            // The compact Dynamic Island around the camera.
            HStack {
                ActivitySpark().fill(ActivityInk.islandAccent).frame(width: 16, height: 16)
                Spacer()
                FocusIslandClock(phase: focus).frame(width: 48, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .frame(width: 230, height: 37)
            .background(.black, in: .capsule)
            .environment(\.colorScheme, .dark)

            VStack(spacing: 0) {
                Text(now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 18, weight: .semibold))
                Text(now, format: .dateTime.hour().minute().locale(Locale(identifier: "tr_TR")))
                    .font(.system(size: 92, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Theme.paper)
            .padding(.top, 18)

            Spacer(minLength: 0)

            card { FocusLockScreenView(attributes: attributes, phase: focus) }
            card { FocusLockScreenView(attributes: attributes, phase: onBreak) }
            card { FocusLockScreenView(attributes: attributes, phase: .done) }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 40)
        .background(StarField(seed: 2, count: 120, grid: true, theme: model.progress.selectedTheme))
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background(ActivityInk.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
