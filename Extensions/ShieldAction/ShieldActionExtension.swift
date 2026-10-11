import ManagedSettings

/// Counts attempts to open a blocked app; any attempt costs the "hiç telefona bakmadın" bonus.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        SharedStore.shieldAttempts += 1
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        SharedStore.shieldAttempts += 1
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        SharedStore.shieldAttempts += 1
        completionHandler(.close)
    }
}
