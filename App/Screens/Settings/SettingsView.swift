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
    @State private var showSignIn = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                AccountSection(showSignIn: $showSignIn, confirmSignOut: $confirmSignOut, confirmDelete: $confirmDelete)

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

                Section("Hakkında") {
                    Link("Gizlilik politikası", destination: URL(string: "https://beyzaerdogaan.github.io/Odak/gizlilik/")!)
                    Link("Destek ve iletişim", destination: URL(string: "https://beyzaerdogaan.github.io/Odak/destek/")!)
                }

                Section {
                    Button("Bütün ilerlemeyi sıfırla", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Derin \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")). Takımyıldız bilgileri ve mesafeler yayından önce bir astronomi kaynağıyla doğrulanacak.\n\nOrtam sesi kayıtları Freesound'dan: yağmur jmbphilmes, orman kvgarlic, şömine 16FThumaF (CC0), dalga Luftrum (CC BY).")
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Bitti", systemImage: "checkmark") { dismiss() } } }
            .sheet(isPresented: $showGuide) { FocusShortcutsGuide() }
            .sheet(isPresented: $showZenit) { ZenitSheet() }
            .sheet(isPresented: $showSignIn) { SignInView() }
            .confirmationDialog("Çıkış yapılsın mı?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Çıkış yap", role: .destructive) { Task { await model.signOut() } }
            } message: {
                Text(model.hasUnsyncedChanges
                     ? "Son değişikliklerin henüz hesabına ulaşmadı. İnternete bağlanmadan çıkarsan bu telefondaki son ilerleme kaybolur."
                     : "İlerlemen hesabında saklı kalır ve bu telefondan kaldırılır. Tekrar giriş yapınca geri gelir.")
            }
            .confirmationDialog("Hesabın silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Hesabı kalıcı olarak sil", role: .destructive) { Task { await model.deleteAccount() } }
            } message: {
                Text("Hesabın ve içinde saklanan bütün yıldızlar, Işık ve sözler kalıcı olarak silinir. Önce kimliğini bir kez daha doğrulaman istenir.")
            }
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

/// "Hesap": who is signed in and how the sky's copy in the account is doing.
private struct AccountSection: View {
    @Environment(AppModel.self) private var model
    @Binding var showSignIn: Bool
    @Binding var confirmSignOut: Bool
    @Binding var confirmDelete: Bool

    var body: some View {
        Section {
            if let account = model.account.account {
                HStack(spacing: 12) {
                    Image(systemName: account.provider == .google ? "envelope.fill" : "apple.logo")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.paper2)
                        .frame(width: 36, height: 36)
                        .background(Theme.plate2, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name ?? "Hesabın").foregroundStyle(Theme.paper)
                        if let email = account.email { Text(email).small() }
                    }
                }
                LabeledContent("Yedekleme", value: syncText)
                if model.account.busy != nil {
                    HStack { Text("Hesabın doğrulanıyor"); Spacer(); ProgressView() }
                }
                Button("Çıkış yap") { confirmSignOut = true }
                Button("Hesabı sil", role: .destructive) { confirmDelete = true }
            } else {
                Button("Giriş yap veya hesap oluştur") { showSignIn = true }
            }
        } header: {
            Text("Hesap")
        } footer: {
            if let error = model.account.errorText, model.account.account != nil {
                Text(error).foregroundStyle(Theme.alarm)
            } else if model.account.account == nil {
                Text("Apple ya da Google hesabınla giriş yaparsan ilerlemen saklanır ve yeni telefonuna taşınır.")
            }
        }
    }

    private var syncText: String {
        let cloud = model.cloud
        if cloud.isSyncing { return "Eşitleniyor…" }
        if cloud.failed { return "Bağlantı bekleniyor" }
        guard let date = cloud.lastSynced else { return "Henüz eşitlenmedi" }
        if Date.now.timeIntervalSince(date) < 60 { return "Az önce" }
        return date.formatted(.relative(presentation: .named).locale(Locale(identifier: "tr_TR")))
    }
}
