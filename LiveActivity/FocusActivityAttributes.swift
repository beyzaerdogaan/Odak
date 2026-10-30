import ActivityKit
import Foundation

/// The running focus session as a Live Activity: lock screen and Dynamic Island.
/// Compiled into both the app (which starts, updates and ends it) and the DerinWidgets extension (which draws it).
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Planned end of the focus; pushed later by the length of a break.
        var end: Date
        /// Set while on the five-minute break: when it runs out.
        var breakEnd: Date?
        /// Focus time left when the break started; the countdown resumes from here.
        var remainingAtBreak: TimeInterval = 0
    }

    var task: String
    var plannedMinutes: Int

    var title: String { task.isEmpty ? String(localized: "Odak") : task }
}

/// What the activity shows at a given moment. The system re-renders once the content goes stale, which is how
/// a break that ran out while the app was asleep turns back into the focus countdown without the app.
enum FocusActivityPhase {
    case focus(ClosedRange<Date>)
    case onBreak(until: Date, remaining: TimeInterval)
    case done

    init(_ state: FocusActivityAttributes.ContentState, plannedMinutes: Int, isStale: Bool) {
        let planned = TimeInterval(plannedMinutes * 60)
        if let breakEnd = state.breakEnd {
            if isStale {
                let end = breakEnd.addingTimeInterval(state.remainingAtBreak)
                self = .focus(end.addingTimeInterval(-planned)...end)
            } else {
                self = .onBreak(until: breakEnd, remaining: state.remainingAtBreak)
            }
        } else if isStale {
            self = .done
        } else {
            self = .focus(state.end.addingTimeInterval(-planned)...state.end)
        }
    }
}
