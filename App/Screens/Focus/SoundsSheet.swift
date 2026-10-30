import AuthenticationServices
import OdakCore
import SwiftUI

/// "Ses ve müzik": mix up to two ambient sounds and pick a playlist from Spotify, Apple Music or YouTube Music.
struct SoundsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var showZenit = false
    @State private var showAddMusic = false

    private let icons: [SoundID: String] = [
        .rain: "cloud.rain", .forest: "tree", .waves: "water.waves", .fire: "flame",
        .brownNoise: "waveform", .winterNight: "snowflake", .library: "books.vertical",
        .summerNight: "moon.stars", .stream: "drop", .distantStorm: "cloud.bolt.rain",
    ]

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ambient
                    Divider().overlay(Theme.hair)
                    music
                    Toggle(isOn: $model.settings.stopMusicAtEnd) {
                        Text("Bitince müziği durdur").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.paper)
                    }
                    .tint(Theme.accent)
                    .plate(padding: 14)
                }
                .padding(22)
            }
            .navigationTitle("Ses ve müzik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showZenit) { ZenitSheet() }
        .sheet(isPresented: $showAddMusic) { AddMusicSheet() }
        .onDisappear { model.settings.ambient = model.sounds.saved }
    }

    private var ambient: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ortam sesleri").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                Text("2 sese kadar karıştır").small()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 8) {
                ForEach(SoundID.allCases) { sound in tile(sound) }
            }
            ForEach(model.sounds.active) { sound in
                HStack(spacing: 14) {
                    Text(sound.title).font(.system(size: 13)).foregroundStyle(Theme.paper2).frame(minWidth: 64, alignment: .leading)
                    Slider(value: Binding(get: { model.sounds.volumes[sound] ?? 0 }, set: { model.sounds.setVolume($0, for: sound) }), in: 0...1)
                        .tint(Theme.aurora)
                    Text("%\(Int((model.sounds.volumes[sound] ?? 0) * 100))").font(.system(size: 13)).monospacedDigit()
                        .foregroundStyle(Theme.paper2).frame(minWidth: 36, alignment: .trailing)
                }
            }
            if !model.sounds.active.isEmpty {
                Button {
                    if model.sounds.isPlaying { model.sounds.stop() } else { model.sounds.play() }
                } label: {
                    Label(model.sounds.isPlaying ? "Sesi duraklat" : "Sesi çal", systemImage: model.sounds.isPlaying ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
        }
    }

    @ViewBuilder private func tile(_ sound: SoundID) -> some View {
        let on = model.sounds.volumes[sound] != nil
        let usable = model.canUse(sound)
        Button {
            if usable {
                model.sounds.toggle(sound)
                if model.session != nil || model.sounds.isPlaying { model.sounds.play() }
            } else if SubscriptionStore.isOffered {
                showZenit = sound != .winterNight
            }
        } label: {
            VStack(spacing: 7) {
                Image(systemName: usable ? icons[sound] ?? "speaker.wave.2" : "lock")
                    .font(.system(size: usable ? 22 : 18))
                    .foregroundStyle(on ? Theme.aurora : usable ? Theme.paper2 : Theme.paper3)
                    .frame(width: 56, height: 56)
                    .background(on ? Theme.aurora.opacity(0.16) : usable ? Theme.plate : .clear, in: Circle())
                    .overlay {
                        if on { Circle().strokeBorder(Theme.aurora, lineWidth: 1.5) }
                        if !usable { Circle().strokeBorder(Theme.star.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 3])) }
                    }
                Text(sound.title).font(.system(size: 12)).multilineTextAlignment(.center)
                    .foregroundStyle(usable ? Theme.paper : Theme.paper3)
                if !usable {
                    Text(sound == .winterNight ? "Avcı ile açılır" : "Mağazada").font(.system(size: 10)).foregroundStyle(Theme.paper3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .top)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var music: some View {
        let service = model.spotify
        let suggested = SpotifyService.suggested + service.playlists
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Müzik").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                    HStack(spacing: 6) {
                        Circle().fill(service.isConnected ? Theme.aurora : Theme.paper3).frame(width: 6, height: 6)
                        Text(service.isConnected ? "Spotify hesabın bağlı, odak boyunca engellenmez"
                             : "Apple Music Derin'de çalar, diğerleri kendi uygulamasında açılır")
                    }
                    .font(.system(size: 12)).foregroundStyle(service.isConnected ? Theme.aurora : Theme.paper2)
                }
                Spacer()
                Button("Liste ekle", systemImage: "plus") { showAddMusic = true }
                    .buttonStyle(.glass).controlSize(.small)
            }
            if model.session == nil {
                Text("Seçtiğin liste odaklanmaya başladığında çalmaya başlar.").small()
            }
            if let err = service.lastError ?? model.appleMusic.lastError {
                Text(err).font(.system(size: 12)).foregroundStyle(Theme.alarm)
            }
            VStack(spacing: 0) {
                ForEach(model.music.lists) { list in
                    row(id: list.id, name: list.name, subtitle: subtitle(for: list), artwork: list.artwork)
                    .contextMenu {
                        Button("Listeden kaldır", systemImage: "trash", role: .destructive) {
                            if model.settings.spotifyPlaylist == list.id { model.settings.spotifyPlaylist = nil }
                            model.music.remove(list)
                        }
                    }
                }
                ForEach(suggested) { list in
                    row(id: list.id, name: list.name, subtitle: String(localized: "Spotify · \(list.subtitle)"), artwork: nil)
                }
            }
            if service.isConnected {
                Button("Spotify bağlantısını kes") { service.disconnect() }.font(.system(size: 13)).foregroundStyle(Theme.paper2)
            } else if service.isConfigured {
                Button("Spotify hesabını bağla") { Task { await connect() } }.font(.system(size: 13)).foregroundStyle(Theme.paper2)
            }
        }
    }

    private func row(id: String, name: String, subtitle: String, artwork: URL?) -> some View {
        let selected = model.settings.spotifyPlaylist == id
        let inSession = model.session != nil
        return VStack(spacing: 0) {
            Button {
                model.settings.spotifyPlaylist = selected ? nil : id
                // Only one list plays at a time; an Apple Music list stops when another is picked.
                // Before a session the pick is only remembered, and it starts with the session.
                model.appleMusic.pause()
                if !selected, inSession { Task { await model.play(listID: id) } }
            } label: {
                HStack(spacing: 12) {
                    AsyncImage(url: artwork) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        LinearGradient(colors: gradient(for: id), startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                            .foregroundStyle(selected ? Theme.aurora : Theme.paper)
                        Text(subtitle).small().lineLimit(1)
                    }
                    Spacer()
                    if selected { Image(systemName: inSession ? "play.fill" : "checkmark").foregroundStyle(Theme.aurora) }
                }
                .frame(minHeight: 62)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Divider().overlay(Theme.hair)
        }
    }

    private func subtitle(for list: MusicList) -> String {
        list.service == .appleMusic ? String(localized: "Apple Music · Derin'de çalar") : String(localized: "\(list.service.title) · \(list.kindTitle)")
    }

    private func gradient(for id: String) -> [Color] {
        let palettes: [[UInt32]] = [[0x2A6A6A, 0x13233A], [0x5A3E7A, 0x221A3A], [0x7A5A2A, 0x2A1E10], [0x2A4A7A, 0x10182A]]
        let p = palettes[id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palettes.count]
        return p.map { Color(hex: $0) }
    }

    private func connect() async {
        guard let url = model.spotify.authorizeURL() else { return }
        model.handOff()
        do {
            let callback = try await webAuth.authenticate(using: url, callbackURLScheme: "derin", preferredBrowserSession: .ephemeral)
            await model.spotify.handleCallback(callback)
        } catch {
            // Cancelled by the user.
        }
    }
}
