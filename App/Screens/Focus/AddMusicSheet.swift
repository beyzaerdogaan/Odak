import SwiftUI

/// "Liste ekle": bring a playlist or album in from Spotify, Apple Music or YouTube Music, either by
/// sharing it to Derin from the music app or by pasting its link here.
struct AddMusicSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var working = false
    @State private var failed = false
    @State private var loadingLibrary = false
    @State private var libraryShown = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    appleMusicLibrary

                    Divider().overlay(Theme.hair)

                    VStack(alignment: .leading, spacing: 12) {
                        step(1, "Aşağıdan müzik uygulamanı aç ve bir çalma listesi ya da albüm seç.")
                        step(2, "Paylaş'a dokun, uygulamalar arasından Derin'i seç. Derin görünmüyorsa Diğer'e dokun.")
                        step(3, "Derin'e döndüğünde liste burada olur.")
                    }
                    VStack(spacing: 8) {
                        ForEach(MusicService.allCases) { service in
                            Button {
                                model.handOff()
                                Task { await model.music.openApp(service) }
                            } label: {
                                HStack {
                                    Text(openTitle(service)).font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.system(size: 13))
                                }
                                .foregroundStyle(Theme.paper)
                                .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(.glass)
                        }
                    }

                    Divider().overlay(Theme.hair)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ya da bağlantıyı yapıştır").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                        Text("Paylaş menüsünde “Bağlantıyı kopyala”ya dokunup buraya dön.").small()
                        HStack(spacing: 8) {
                            TextField("open.spotify.com/playlist/…", text: $link)
                                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                                .submitLabel(.done).onSubmit { add(link) }
                                .padding(.horizontal, 12).frame(minHeight: 44)
                                .background(Theme.plate, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            PasteButton(payloadType: String.self) { strings in
                                Task { @MainActor in
                                    if let text = strings.first { link = text; add(text) }
                                }
                            }
                            .labelStyle(.iconOnly)
                            .buttonBorderShape(.roundedRectangle(radius: 12))
                        }
                        if working {
                            HStack(spacing: 8) { ProgressView(); Text("Liste okunuyor").small() }
                        } else if failed {
                            Text("Bu bir çalma listesi ya da albüm bağlantısı değil.").font(.system(size: 12)).foregroundStyle(Theme.alarm)
                        }
                        if !link.isEmpty && !working {
                            Button("Ekle") { add(link) }.buttonStyle(.glassProminent).frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(22)
            }
            .navigationTitle("Liste ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        // A list shared from the music app arrives when Derin becomes active again.
        .onChange(of: model.music.lists.first?.id) { _, id in
            if let id { choose(id) }
        }
    }

    /// The user's own Apple Music playlists, which then play inside Derin.
    private var appleMusicLibrary: some View {
        let player = model.appleMusic
        return VStack(alignment: .leading, spacing: 10) {
            Text("Apple Music kitaplığından seç").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
            Text("Seçtiğin liste uygulamadan çıkmadan Derin'in içinde çalar.").small()
            if !libraryShown {
                Button {
                    loadingLibrary = true
                    Task {
                        await player.loadLibrary()
                        loadingLibrary = false
                        libraryShown = player.lastError == nil
                    }
                } label: {
                    HStack(spacing: 8) {
                        if loadingLibrary { ProgressView() } else { Image(systemName: "music.note.list") }
                        Text("Listelerimi göster")
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.glass)
                .disabled(loadingLibrary)
            } else if player.library.isEmpty {
                Text("Apple Music kitaplığında çalma listesi yok.").small()
            } else {
                VStack(spacing: 0) {
                    ForEach(player.library) { list in
                        Button {
                            model.music.add(list)
                            choose(list.id)
                            if model.session != nil { Task { _ = await player.play(list) } }
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: list.artwork) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "music.note").foregroundStyle(Theme.paper2)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.plate)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                Text(list.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.paper).lineLimit(1)
                                Spacer()
                                Image(systemName: "plus.circle").foregroundStyle(Theme.aurora)
                            }
                            .frame(minHeight: 54)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Theme.hair)
                    }
                }
            }
            if let err = player.lastError { Text(err).font(.system(size: 12)).foregroundStyle(Theme.alarm) }
        }
    }

    private func openTitle(_ service: MusicService) -> String {
        switch service {
        case .spotify: "Spotify'ı aç"
        case .appleMusic: "Apple Music'i aç"
        case .youtubeMusic: "YouTube Music'i aç"
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.aurora)
                .frame(width: 24, height: 24).background(Theme.aurora.opacity(0.16), in: Circle())
            Text(text).font(.system(size: 14)).foregroundStyle(Theme.paper2).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func add(_ text: String) {
        guard !working, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        working = true
        failed = false
        Task {
            let list = await model.music.add(link: text)
            working = false
            if let list { choose(list.id) } else { failed = true }
        }
    }

    private func choose(_ id: String) {
        model.settings.spotifyPlaylist = id
        dismiss()
    }
}
