import Foundation
import Observation
import UIKit

/// Playlists and albums the user brought in from Spotify, Apple Music or YouTube Music, by sharing
/// them to Derin or pasting their link. They play in the music app itself; Derin only opens them.
@MainActor @Observable
final class MusicLibrary {
    private(set) var lists: [MusicList] = [] { didSet { save() } }

    @ObservationIgnored private let file: URL?

    init(folder: URL?) {
        file = folder?.appending(path: "music.json")
        if let file, let data = try? Data(contentsOf: file) {
            lists = (try? JSONDecoder().decode([MusicList].self, from: data)) ?? []
        }
        collectShared()
    }

    /// Takes in what the share extension received while the app was closed. Returns the newest one.
    @discardableResult
    func collectShared() -> MusicList? {
        let shared = MusicInbox.take()
        for list in shared { insert(list) }
        return shared.last
    }

    /// Adds the list behind a pasted link; nil when the text holds no playlist or album link.
    func add(link text: String) async -> MusicList? {
        guard let url = MusicLink.firstURL(in: text), let list = await MusicLink.resolve(url) else { return nil }
        insert(list)
        return list
    }

    func remove(_ list: MusicList) {
        lists.removeAll { $0.id == list.id }
    }

    func list(id: String) -> MusicList? { lists.first { $0.id == id } }

    /// Opens the list in its music app, or on the web when the app isn't installed.
    func open(_ list: MusicList) async {
        if let uri = list.spotifyURI, await UIApplication.shared.open(uri) { return }
        await UIApplication.shared.open(list.link)
    }

    /// Opens the music app so the user can share a list from it.
    func openApp(_ service: MusicService) async {
        if await UIApplication.shared.open(service.appURL) { return }
        await UIApplication.shared.open(service.webURL)
    }

    private func insert(_ list: MusicList) {
        lists.removeAll { $0.id == list.id }
        lists.insert(list, at: 0)
    }

    private func save() {
        guard let file else { return }
        if let data = try? JSONEncoder().encode(lists) {
            try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }
}
