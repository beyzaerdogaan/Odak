import Foundation
import MusicKit
import Observation

/// Apple Music inside Derin, through MusicKit: lists added from Apple Music play in the app itself,
/// next to the ambient sounds, without opening the Music app. Needs the user's permission and an
/// Apple Music subscription; without them the list opens in the Music app as before.
///
/// MusicKit also has to be turned on for the app's identifier on the developer site
/// (Identifiers → the app → App Services → MusicKit), or catalog requests fail.
@MainActor @Observable
final class AppleMusicPlayer {
    private(set) var isPlaying = false
    /// The list loaded into the player, by `MusicList.id`.
    private(set) var current: String?
    private(set) var library: [MusicList] = []
    private(set) var lastError: String?

    private var player: ApplicationMusicPlayer { .shared }

    var isAuthorized: Bool { MusicAuthorization.currentStatus == .authorized }

    /// Asks for Apple Music access the first time; true when the user can play catalog music.
    func prepare() async -> Bool {
        if MusicAuthorization.currentStatus == .notDetermined {
            _ = await MusicAuthorization.request()
        }
        guard isAuthorized else {
            lastError = "Apple Music'e erişim izni verilmedi. Ayarlar'dan açabilirsin."
            return false
        }
        guard let subscription = try? await MusicSubscription.current, subscription.canPlayCatalogContent else {
            lastError = "Derin'in içinde çalmak için Apple Music aboneliği gerekiyor."
            return false
        }
        lastError = nil
        return true
    }

    /// Plays the list inside Derin. False when it has to open in the Music app instead.
    func play(_ list: MusicList) async -> Bool {
        guard list.service == .appleMusic, await prepare() else { return false }
        do {
            if current != list.id {
                if list.isAlbum, let album = try await album(for: list) {
                    player.queue = [album]
                } else if let playlist = try await playlist(for: list) {
                    player.queue = [playlist]
                } else {
                    lastError = "Liste Apple Music'te bulunamadı."
                    return false
                }
                current = list.id
            }
            try await player.play()
            isPlaying = true
            return true
        } catch {
            lastError = "Apple Music listeyi çalamadı."
            current = nil
            return false
        }
    }

    func resume() async {
        guard current != nil else { return }
        try? await player.play()
        refresh()
    }

    func pause() {
        guard current != nil else { return }
        player.pause()
        isPlaying = false
    }

    /// Picks up changes made from the lock screen or Control Center.
    func refresh() {
        isPlaying = current != nil && player.state.playbackStatus == .playing
    }

    /// The user's own playlists, for picking one in "Liste ekle".
    func loadLibrary() async {
        guard await prepare() else { return }
        guard let response = try? await MusicLibraryRequest<Playlist>().response() else {
            lastError = "Apple Music kitaplığın okunamadı."
            return
        }
        let playlists = response.items.sorted { ($0.lastPlayedDate ?? .distantPast) > ($1.lastPlayedDate ?? .distantPast) }
        library = playlists.map { playlist in
            // Library artwork can come as a musicKit:// address that only MusicKit's own views load.
            let artwork = playlist.artwork?.url(width: 300, height: 300).flatMap { $0.scheme == "https" ? $0 : nil }
            return MusicList(service: .appleMusic,
                             link: playlist.url ?? URL(string: "https://music.apple.com/library/playlist/\(playlist.id.rawValue)")!,
                             name: playlist.name, artwork: artwork, appleMusicID: playlist.id.rawValue)
        }
    }

    // MARK: - Finding the list

    /// The catalog ID is the last part of the link: …/playlist/name/pl.123 or …/album/name/456.
    private func catalogID(_ list: MusicList) -> MusicItemID? {
        list.link.pathComponents.last.map { MusicItemID($0) }
    }

    private func playlist(for list: MusicList) async throws -> Playlist? {
        // Lists picked from the library are found there; shared links in the catalog.
        if let id = list.appleMusicID,
           let found = try await MusicLibraryRequest<Playlist>().response().items.first(where: { $0.id.rawValue == id }) {
            return found
        }
        guard let id = catalogID(list) else { return nil }
        return try await MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: id).response().items.first
    }

    private func album(for list: MusicList) async throws -> Album? {
        guard let id = catalogID(list) else { return nil }
        return try await MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: id).response().items.first
    }
}
