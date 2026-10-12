import ActivityKit
import Foundation

/// Keeps the session's Live Activity (lock screen and Dynamic Island, see LiveActivity/) in step with the model.
/// Times are sent as dates, so the countdown runs on the lock screen without the app updating it.
@MainActor
enum LiveActivityController {
    private static var activities: [Activity<FocusActivityAttributes>] { Activity<FocusActivityAttributes>.activities }

    static func start(_ s: FocusSession, now: Date = .now) {
        guard !Demo.isOn, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let attributes = FocusActivityAttributes(task: s.task, plannedMinutes: s.plannedMinutes)
        _ = try? Activity.request(attributes: attributes, content: content(s, now: now), pushType: nil)
    }

    static func update(_ s: FocusSession, now: Date = .now) {
        let content = content(s, now: now)
        for activity in activities {
            Task { await activity.update(content) }
        }
    }

    static func end() {
        for activity in activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// On launch: bring back the activity for a session that survived a relaunch, or clear one left without a session.
    static func sync(_ s: FocusSession?) {
        guard let s else { return end() }
        if activities.isEmpty { start(s) } else { update(s) }
    }

    private static func content(_ s: FocusSession, now: Date) -> ActivityContent<FocusActivityAttributes.ContentState> {
        let breakEnd = s.breakStartedAt.map { $0.addingTimeInterval(FocusSession.breakLength) }
        let state = FocusActivityAttributes.ContentState(end: s.end, breakEnd: breakEnd, remainingAtBreak: s.remaining(at: now))
        // Going stale is what flips the lock screen to "break over" or "time's up" while the app is asleep.
        return ActivityContent(state: state, staleDate: breakEnd ?? s.end)
    }
}
