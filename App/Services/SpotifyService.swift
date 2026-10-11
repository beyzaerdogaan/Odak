import CryptoKit
import Foundation
import Observation
import Security
import UIKit

struct SpotifyPlaylist: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let subtitle: String
    var uri: String { "spotify:playlist:\(id)" }
    var webURL: URL { URL(string: "https://open.spotify.com/playlist/\(id)")! }
}

/// Spotify through the Web API with OAuth PKCE (no SDK, no client secret).
///
/// With a client ID in Config/Odak.xcconfig the user can sign in, see their own playlists and start
/// playback on their active Spotify device. Without one, or before signing in, the suggested
/// playlists open in the Spotify app. Spotify is never blocked during a session.
@MainActor @Observable
final class SpotifyService {
    static let redirectURI = "derin://spotify-callback"
    static let scopes = "playlist-read-private user-read-playback-state user-modify-playback-state"

    static let suggested = [
        SpotifyPlaylist(id: "37i9dQZF1DWZeKCadgRdKQ", name: "Derin Odak", subtitle: "Önerilen, enstrümantal"),
        SpotifyPlaylist(id: "37i9dQZF1DWWQRwui0ExPn", name: "Lo-fi Çalışma", subtitle: "Önerilen"),
    ]

    private(set) var isConnected = false
    private(set) var playlists: [SpotifyPlaylist] = []
    private(set) var lastError: String?

    @ObservationIgnored private var verifier = ""
    @ObservationIgnored private var tokens: Tokens? {
        didSet { Keychain.save(tokens, account: "spotify"); isConnected = tokens != nil }
    }

    private struct Tokens: Codable {
        var access: String
        var refresh: String?
        var expires: Date
    }

    var clientID: String { Bundle.main.object(forInfoDictionaryKey: "DerinSpotifyClientID") as? String ?? "" }
    var isConfigured: Bool { !clientID.isEmpty }
    var isAppInstalled: Bool { UIApplication.shared.canOpenURL(URL(string: "spotify:")!) }

    init() {
        tokens = Keychain.load(Tokens.self, account: "spotify")
        isConnected = tokens != nil
    }

    /// The authorize URL for ASWebAuthenticationSession.
    func authorizeURL() -> URL? {
        guard isConfigured else { return nil }
        verifier = Self.randomVerifier()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        var c = URLComponents(string: "https://accounts.spotify.com/authorize")!
        c.queryItems = [
            .init(name: "client_id", value: clientID), .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: Self.redirectURI), .init(name: "scope", value: Self.scopes),
            .init(name: "code_challenge_method", value: "S256"), .init(name: "code_challenge", value: challenge),
        ]
        return c.url
    }

    func handleCallback(_ url: URL) async {
        guard let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
            lastError = "Spotify bağlantısı iptal edildi."
            return
        }
        await requestToken(["grant_type": "authorization_code", "code": code, "redirect_uri": Self.redirectURI,
                            "client_id": clientID, "code_verifier": verifier])
        await loadPlaylists()
    }

    func disconnect() {
        tokens = nil
        playlists = []
    }

    func loadPlaylists() async {
        struct Page: Decodable {
            struct Item: Decodable {
                struct Owner: Decodable { let display_name: String? }
                let id: String
                let name: String
                let owner: Owner?
            }
            let items: [Item]
        }
        guard let data = await get("https://api.spotify.com/v1/me/playlists?limit=20"),
              let page = try? JSONDecoder().decode(Page.self, from: data) else { return }
        playlists = page.items.map { SpotifyPlaylist(id: $0.id, name: $0.name, subtitle: "Senin çalma listen") }
    }

    /// Starts the playlist on the user's active Spotify device, or opens it in the Spotify app.
    func play(_ playlist: SpotifyPlaylist) async {
        if isConnected, let token = await validToken() {
            var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/play")!)
            req.httpMethod = "PUT"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(["context_uri": playlist.uri])
            if let result = try? await URLSession.shared.data(for: req), (result.1 as? HTTPURLResponse)?.statusCode == 204 {
                return
            }
        }
        // No active device (or not signed in): hand off to the Spotify app.
        let url = isAppInstalled ? URL(string: playlist.uri)! : playlist.webURL
        await UIApplication.shared.open(url)
    }

    func pause() async {
        guard isConnected, let token = await validToken() else { return }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/pause")!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - Networking

    private func get(_ url: String) async -> Data? {
        guard let token = await validToken() else { return nil }
        var req = URLRequest(url: URL(string: url)!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let result = try? await URLSession.shared.data(for: req),
              (result.1 as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return result.0
    }

    private func validToken() async -> String? {
        guard let t = tokens else { return nil }
        if t.expires > .now.addingTimeInterval(60) { return t.access }
        guard let refresh = t.refresh else { tokens = nil; return nil }
        await requestToken(["grant_type": "refresh_token", "refresh_token": refresh, "client_id": clientID])
        return tokens?.access
    }

    private func requestToken(_ form: [String: String]) async {
        struct Response: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double
        }
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var c = URLComponents()
        c.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = c.percentEncodedQuery?.data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let r = try JSONDecoder().decode(Response.self, from: data)
            tokens = Tokens(access: r.access_token, refresh: r.refresh_token ?? tokens?.refresh,
                            expires: .now.addingTimeInterval(r.expires_in))
            lastError = nil
        } catch {
            lastError = "Spotify'a bağlanılamadı."
        }
    }

    private static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 48)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URL
    }
}

extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Minimal Keychain storage for the Spotify tokens.
enum Keychain {
    static func save<T: Encodable>(_ value: T?, account: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        guard let value, let data = try? JSONEncoder().encode(value) else { return }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load<T: Decodable>(_ type: T.Type, account: String) -> T? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
