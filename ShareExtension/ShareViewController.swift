import Observation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "Derin" in the share sheet of Spotify, Apple Music and YouTube Music: keeps the shared playlist
/// or album for the Ses ve müzik screen. The app picks it up the next time it opens.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        Task { await model.receive(providers) }
    }
}

@MainActor @Observable
final class ShareModel {
    enum State { case working, added(MusicList), unsupported }
    var state = State.working

    func receive(_ providers: [NSItemProvider]) async {
        var url: URL?
        for provider in providers where url == nil {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                      let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                url = MusicLink.firstURL(in: text)
            }
        }
        guard let url, let list = await MusicLink.resolve(url) else {
            state = .unsupported
            return
        }
        MusicInbox.add(list)
        state = .added(list)
    }
}

private struct ShareView: View {
    let model: ShareModel
    let done: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                switch model.state {
                case .working:
                    ProgressView().controlSize(.large).frame(height: 120)
                    Text("Liste okunuyor").foregroundStyle(.secondary)
                case .added(let list):
                    AsyncImage(url: list.artwork) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "music.note.list").font(.system(size: 36)).foregroundStyle(.secondary)
                    }
                    .frame(width: 120, height: 120)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(spacing: 4) {
                        Text("Derin'e eklendi").font(.headline)
                        Text(list.name).font(.subheadline).multilineTextAlignment(.center).lineLimit(2)
                        Text("\(list.service.title) · \(list.kindTitle)").font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("Derin'de Ses ve müzik bölümünde seni bekliyor.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                case .unsupported:
                    Image(systemName: "questionmark.circle").font(.system(size: 44)).foregroundStyle(.secondary).frame(height: 120)
                    Text("Bu bir liste bağlantısı değil").font(.headline)
                    Text("Spotify, Apple Music ya da YouTube Music'ten bir çalma listesi veya albüm paylaş.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                Button(action: done) {
                    Text("Tamam").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled({ if case .working = model.state { true } else { false } }())
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.background, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(12)
        }
        .tint(Color(red: 0.55, green: 0.85, blue: 0.82))
    }
}
