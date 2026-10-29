import Foundation
import Observation
import StoreKit

/// Zenit, the optional subscription. Focus, blocking, stars and Işık stay free; Zenit adds every
/// sound and sky theme, detailed statistics and unlimited self-promises.
/// Product IDs must match the auto-renewable subscriptions created in App Store Connect.
@MainActor @Observable
final class SubscriptionStore {
    static let productIDs = ["derin.zenit.monthly", "derin.zenit.yearly"]
    /// Off until the subscription is set up in App Store Connect: every Zenit entry point is hidden
    /// and detailed statistics are open to everyone. Flip to true to bring Zenit back.
    static let isOffered = false

    private(set) var isSubscribed = false
    @ObservationIgnored private var updates: Task<Void, Never>?

    func start() {
        guard Self.isOffered, updates == nil else { return }
        updates = Task { [weak self] in
            await self?.refresh()
            for await result in Transaction.updates {
                if case let .verified(t) = result { await t.finish() }
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case let .verified(t) = result, Self.productIDs.contains(t.productID), t.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }
}
