import Foundation
import Security

/// Lists the share extension received, waiting for the app to pick them up.
///
/// The app and the extension share a Keychain access group rather than an App Group: an App Group
/// has to be registered by hand on the developer site, while any app of the team may share a
/// Keychain group named "<team>.<anything>". The extension writes, the app reads and empties it
/// whenever it becomes active.
enum MusicInbox {
    private static let service = "derin.music"
    private static let account = "inbox"

    static func add(_ list: MusicList) {
        var lists = load().filter { $0.id != list.id }
        lists.append(list)
        save(lists)
    }

    static func take() -> [MusicList] {
        let lists = load()
        if !lists.isEmpty { save([]) }
        return lists
    }

    // MARK: - Keychain

    /// "<team>.<bundle prefix>.derin.shared"; nil when the build carries no Keychain entitlement
    /// (simulator builds without signing), and then items stay in the app's own group.
    private static let group: String? = {
        guard let base = Bundle.main.object(forInfoDictionaryKey: "DerinSharedKeychainGroup") as? String, !base.isEmpty,
              let team = teamPrefix() else { return nil }
        return team + "." + base
    }()

    private static func query() -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service, kSecAttrAccount as String: account]
        if let group { q[kSecAttrAccessGroup as String] = group }
        return q
    }

    private static func load() -> [MusicList] {
        var q = query()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return [] }
        return (try? JSONDecoder().decode([MusicList].self, from: data)) ?? []
    }

    private static func save(_ lists: [MusicList]) {
        SecItemDelete(query() as CFDictionary)
        guard !lists.isEmpty, let data = try? JSONEncoder().encode(lists) else { return }
        var add = query()
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    /// The team ID, read off the default access group of an item this bundle owns.
    private static func teamPrefix() -> String? {
        let probe: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: "probe"]
        var read = probe
        read[kSecReturnAttributes as String] = true
        var out: CFTypeRef?
        var status = SecItemCopyMatching(read as CFDictionary, &out)
        if status == errSecItemNotFound {
            var add = read
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(add as CFDictionary, &out)
        }
        guard status == errSecSuccess, let attributes = out as? [String: Any],
              let accessGroup = attributes[kSecAttrAccessGroup as String] as? String,
              let team = accessGroup.split(separator: ".").first else { return nil }
        return String(team)
    }
}
