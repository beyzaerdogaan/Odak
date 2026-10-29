import ActivityKit
import SwiftUI
import WidgetKit

@main
struct DerinWidgets: WidgetBundle {
    var body: some Widget {
        FocusLiveActivity()
    }
}

/// The running focus on the lock screen and in the Dynamic Island.
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            FocusLockScreenView(attributes: context.attributes, phase: phase(context))
                .activityBackgroundTint(ActivityInk.background)
                .activitySystemActionForegroundColor(ActivityInk.paper)
        } dynamicIsland: { context in
            let phase = phase(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivitySpark().fill(tint(phase)).frame(width: 22, height: 22)
                        .padding(.leading, 6).padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FocusIslandClock(phase: phase, size: 26)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110, alignment: .trailing)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(label(phase)).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Text(context.attributes.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if case let .focus(interval) = phase {
                        ProgressView(timerInterval: interval, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                            .progressViewStyle(.linear)
                            .tint(ActivityInk.islandAccent)
                            .padding(.horizontal, 8).padding(.top, 4)
                    }
                }
            } compactLeading: {
                ActivitySpark().fill(tint(phase)).frame(width: 16, height: 16)
            } compactTrailing: {
                FocusIslandClock(phase: phase)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 48, alignment: .trailing)
            } minimal: {
                ActivitySpark().fill(tint(phase)).frame(width: 16, height: 16)
            }
            .keylineTint(tint(phase))
        }
    }

    private func phase(_ context: ActivityViewContext<FocusActivityAttributes>) -> FocusActivityPhase {
        FocusActivityPhase(context.state, plannedMinutes: context.attributes.plannedMinutes, isStale: context.isStale)
    }

    private func tint(_ phase: FocusActivityPhase) -> Color {
        if case .onBreak = phase { return ActivityInk.islandIce }
        return ActivityInk.islandAccent
    }

    private func label(_ phase: FocusActivityPhase) -> String {
        switch phase {
        case .focus: String(localized: "Derin odak")
        case .onBreak: String(localized: "Mola")
        case .done: String(localized: "Yıldızın hazır")
        }
    }
}
