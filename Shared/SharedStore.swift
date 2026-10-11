import Foundation

/// State shared between the app and its Screen Time extensions through the App Group.
/// Without the Screen Time build the group is not provisioned and this falls back to the app's own defaults.
enum SharedStore {
    static let storeName = "derin"
    static let activityName = "derin.session"

    static var groupID: String { Bundle.main.object(forInfoDictionaryKey: "DerinAppGroup") as? String ?? "" }
    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }

    /// Times the user tried to open a blocked app during the current session.
    static var shieldAttempts: Int {
        get { defaults.integer(forKey: "shieldAttempts") }
        set { defaults.set(newValue, forKey: "shieldAttempts") }
    }

    static var sessionEnd: Date? {
        get { defaults.object(forKey: "sessionEnd") as? Date }
        set { defaults.set(newValue, forKey: "sessionEnd") }
    }

    static var selectionData: Data? {
        get { defaults.data(forKey: "selection") }
        set { defaults.set(newValue, forKey: "selection") }
    }

    static var exemptionData: Data? {
        get { defaults.data(forKey: "exemptions") }
        set { defaults.set(newValue, forKey: "exemptions") }
    }
}
