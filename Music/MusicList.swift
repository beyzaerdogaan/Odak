import Foundation

/// Music apps whose shared links Derin can keep. Their lists always play in the music app itself:
/// Spotify and YouTube Music don't let other apps stream, and Apple Music needs MusicKit for that.
enum MusicService: String, Codable, CaseIterable, Identifiable {
    case spotify, appleMusic, youtubeMusic
    var id: String { rawValue }

    var title: String {
        switch self {
        case .spotify: "Spotify"
        case .appleMusic: "Apple Music"
        case .youtubeMusic: "YouTube Music"
        }
    }

    /// Opens the app itself; the web address is the fallback when it isn't installed.
    var appURL: URL {
        switch self {
        case .spotify: URL(string: "spotify:")!
        case .appleMusic: URL(string: "music://")!
        case .youtubeMusic: URL(string: "youtubemusic://")!
        }
    }

    var webURL: URL {
        switch self {
        case .spotify: URL(string: "https://open.spotify.com")!
        case .appleMusic: URL(string: "https://music.apple.com")!
        case .youtubeMusic: URL(string: "https://music.youtube.com")!
        }
    }
}

/// A playlist or album the user brought in from a music app, by sharing it to Derin or pasting its link.
struct MusicList: Codable, Hashable, Identifiable {
    var service: MusicService
    /// The canonical web link; it opens the list in the music app when that is installed.
    var link: URL
    var name: String
    var isAlbum = false
    var artwork: URL?
    var id: String { link.absoluteString }

    var kindTitle: String { isAlbum ? "Albüm" : "Çalma listesi" }

    /// Spotify's own URI opens the app directly instead of going through the web link.
    var spotifyURI: URL? {
        guard service == .spotify else { return nil }
        let parts = link.pathComponents.filter { $0 != "/" }
        guard parts.count == 2 else { return nil }
        return URL(string: "spotify:\(parts[0]):\(parts[1])")
    }
}

enum MusicLink {
    /// The first link in shared or pasted text, e.g. "Listen to Deep Focus https://open.spotify.com/…".
    static func firstURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("spotify:"), let url = URL(string: trimmed) { return url }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))?.url
    }

    /// Recognizes a playlist or album link and returns it without tracking parameters.
    /// The name is a placeholder until `resolve` fetches the real one.
    static func parse(_ url: URL) -> MusicList? {
        let host = url.host()?.lowercased() ?? ""
        let parts = url.pathComponents.filter { $0 != "/" }

        if url.scheme == "spotify" {
            // spotify:playlist:ID
            let p = url.absoluteString.split(separator: ":")
            guard p.count == 3, ["playlist", "album"].contains(p[1]) else { return nil }
            return spotify(kind: String(p[1]), id: String(p[2]))
        }
        if host == "open.spotify.com" {
            // /playlist/ID, also /intl-tr/playlist/ID
            guard let i = parts.firstIndex(where: { $0 == "playlist" || $0 == "album" }), i + 1 < parts.count else { return nil }
            return spotify(kind: parts[i], id: parts[i + 1])
        }
        if host == "music.apple.com" || host == "itunes.apple.com" {
            // /tr/playlist/name/pl.ID or /tr/album/name/123
            guard let i = parts.firstIndex(where: { $0 == "playlist" || $0 == "album" }), i + 1 < parts.count,
                  var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            c.host = "music.apple.com"
            c.query = nil
            c.fragment = nil
            guard let link = c.url else { return nil }
            let slug = parts.count > i + 2 ? parts[i + 1] : ""
            let name = slug.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
            return MusicList(service: .appleMusic, link: link, name: name.isEmpty ? "Apple Music listesi" : name,
                             isAlbum: parts[i] == "album")
        }
        if host == "music.youtube.com" || host.hasSuffix("youtube.com") {
            guard parts.first == "playlist",
                  let list = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "list" })?.value,
                  !list.isEmpty else { return nil }
            var c = URLComponents(string: "https://music.youtube.com/playlist")!
            c.queryItems = [URLQueryItem(name: "list", value: list)]
            // YouTube Music albums are playlists whose IDs start with OLAK5uy_.
            return MusicList(service: .youtubeMusic, link: c.url!, name: "YouTube Music listesi", isAlbum: list.hasPrefix("OLAK5uy_"))
        }
        return nil
    }

    private static func spotify(kind: String, id: String) -> MusicList? {
        guard !id.isEmpty, id.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return MusicList(service: .spotify, link: URL(string: "https://open.spotify.com/\(kind)/\(id)")!,
                         name: "Spotify listesi", isAlbum: kind == "album")
    }

    /// Short share links (spotify.link, spoti.fi) only redirect to the real address.
    static func isShortLink(_ url: URL) -> Bool {
        ["spotify.link", "spoti.fi", "spotify.app.link"].contains(url.host()?.lowercased() ?? "")
    }

    /// Parses the link, following short links, and fills in the list's name and cover from the
    /// services' public pages. No account or sign-in is involved.
    static func resolve(_ url: URL) async -> MusicList? {
        var target = url
        if isShortLink(url) {
            guard let (data, response) = try? await session.data(from: url) else { return nil }
            if let final = response.url, parse(final) != nil {
                target = final
            } else if let html = String(data: data, encoding: .utf8),
                      let found = html.firstMatch(of: #/https://open\.spotify\.com/(playlist|album)/[A-Za-z0-9]+/#),
                      let link = URL(string: String(found.output.0)) {
                target = link
            }
        }
        guard var list = parse(target) else { return nil }
        switch list.service {
        case .spotify:
            if let meta = await oEmbed("https://open.spotify.com/oembed", list.link) { list.apply(meta) }
        case .youtubeMusic:
            // YouTube's oEmbed knows playlists by their youtube.com address.
            var c = URLComponents(string: "https://www.youtube.com/playlist")!
            c.queryItems = URLComponents(url: list.link, resolvingAgainstBaseURL: false)?.queryItems
            if let meta = await oEmbed("https://www.youtube.com/oembed", c.url!) { list.apply(meta) }
        case .appleMusic:
            if let meta = await openGraph(list.link) { list.apply(meta) }
        }
        return list
    }

    fileprivate struct Meta: Decodable {
        var title: String?
        var thumbnail_url: String?
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"]
        return URLSession(configuration: config)
    }()

    private static func oEmbed(_ endpoint: String, _ link: URL) async -> Meta? {
        var c = URLComponents(string: endpoint)!
        c.queryItems = [URLQueryItem(name: "url", value: link.absoluteString), URLQueryItem(name: "format", value: "json")]
        guard let (data, _) = try? await session.data(from: c.url!) else { return nil }
        return try? JSONDecoder().decode(Meta.self, from: data)
    }

    /// Apple Music has no oEmbed; its pages carry og:title ("Pure Focus on Apple Music") and og:image.
    private static func openGraph(_ link: URL) async -> Meta? {
        guard let (data, _) = try? await session.data(from: link), let html = String(data: data, encoding: .utf8) else { return nil }
        func tag(_ property: String) -> String? {
            guard let range = html.range(of: "property=\"og:\(property)\" content=\"") else { return nil }
            let rest = html[range.upperBound...]
            guard let end = rest.firstIndex(of: "\"") else { return nil }
            return String(rest[..<end])
                .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&#x27;", with: "'")
        }
        var title = tag("title")
        for suffix in [" on Apple Music", " - Apple Music", " – Apple Music", " Apple Music'te"] {
            if let t = title, t.hasSuffix(suffix) { title = String(t.dropLast(suffix.count)) }
        }
        if let t = title, t.hasPrefix("Apple Music'te ") { title = String(t.dropFirst("Apple Music'te ".count)) }
        return Meta(title: title?.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\u{200E}"))),
                    thumbnail_url: tag("image"))
    }
}

private extension MusicList {
    mutating func apply(_ meta: MusicLink.Meta) {
        if let t = meta.title, !t.isEmpty { name = t }
        if let a = meta.thumbnail_url { artwork = URL(string: a) }
    }
}
