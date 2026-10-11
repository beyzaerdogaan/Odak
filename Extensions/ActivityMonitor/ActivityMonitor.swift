import DeviceActivity
import ManagedSettings

/// Lifts the shields when a focus session's time is up, even if the app was closed.
final class ActivityMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue == SharedStore.activityName else { return }
        ManagedSettingsStore(named: ManagedSettingsStore.Name(SharedStore.storeName)).clearAllSettings()
        SharedStore.sessionEnd = nil
    }
}
