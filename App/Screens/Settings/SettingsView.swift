import AuthenticationServices
import OdakCore
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var showGuide = false
    @State private var showZenit = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Uygulama engelleme") {
                        Text(!ScreenTimeController.isAvailable ? "Apple onayı bekleniyor"
                             : model.screenTime.isAuthorized ? "Açık" : "İzin gerekli")
                    }
                    if ScreenTimeController.isAvailable && !model.screenTime.isAuthorized {
                        Button("Ekran Süresi izni ver") { Task { await model.screenTime.requestAuthorization() } }
                    }
                    Button("Arama ve mesajları susturma kurulumu") { showGuide = true }
                } header: {
                    Text("Odak")
                } footer: {
                    Text("Telefonu kilitlemek odak sayılır. Başka bir uygulamaya geçmek ise “hiç telefona bakmadın” bonusunu düşürür.")
                }

                Section("Spotify") {
                    if model.spotify.isConnected {
                        LabeledContent("Durum", value: "Bağlı")
                        Button("Bağlantıyı kes", role: .destructive) { model.spotify.disconnect() }
                    } else if model.spotify.isConfigured {
                        Button("Spotify hesabını bağla") { Task { await connectSpotify() } }
                    } else {
                        Text("Önerilen listeler Spotify uygulamasında açılır.").small()
                    }
                }

                Section("Zenit") {
                    if model.isZenit {
                        LabeledContent("Durum", value: "Aktif")
                    } else {
                        Button("Zenit'e geç") { showZenit = true }
                    }
                    Button("Satın alımları geri yükle") {
                        Task {
                            try? await AppStore.sync()
                            await model.store.refresh()
                        }
                    }
                }

                Section {
                    Button("Bütün ilerlemeyi sıfırla", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Derin \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")). Takımyıldız bilgileri ve mesafeler yayından önce bir astronomi kaynağıyla doğrulanacak.")
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Bitti", systemImage: "checkmark") { dismiss() } } }
            .sheet(isPresented: $showGuide) { FocusShortcutsGuide() }
            .sheet(isPresented: $showZenit) { ZenitSheet() }
            .confirmationDialog("Bütün yıldızlar, Işık ve sözler silinsin mi?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Sıfırla", role: .destructive) { model.resetAll() }
            }
        }
    }

    private func connectSpotify() async {
        guard let url = model.spotify.authorizeURL() else { return }
        if let callback = try? await webAuth.authenticate(using: url, callbackURLScheme: "derin", preferredBrowserSession: .ephemeral) {
            await model.spotify.handleCallback(callback)
        }
    }
}
