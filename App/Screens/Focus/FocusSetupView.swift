import FamilyControls
import OdakCore
import SwiftUI

/// "Ne üzerinde odaklanıyorsun?": task, duration, what to block, and the start button.
struct FocusSetupView: View {
    @Environment(AppModel.self) private var model
    @State private var custom = false
    @State private var showPicker = false
    @State private var showBlockingInfo = false
    @State private var showShortcutsGuide = false
    @State private var showSounds = false
    /// The block-mode picker runs on local state so its Liquid Glass slide isn't interrupted by
    /// model writes; the choice is committed once it settles (and always before starting).
    @State private var blockMode: BlockMode = .selected
    @State private var blockModeCommit: Task<Void, Never>?
    @FocusState private var taskFocused: Bool

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header.fadesOnScroll()
                taskField($model.settings.task)
                durationSection
                blockingSection
                soundsSection
                togglesSection
                armedBoosters
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .defaultScrollAnchor(Demo.scrolled ? .bottom : nil)
        .collapsingTitle(String(localized: "Odak"))
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: String(localized: "Odaklanmaya başla")) {
                taskFocused = false
                blockModeCommit?.cancel()
                model.settings.blockMode = blockMode
                model.startSession()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
            .bottomFade()
        }
        .background(StarField(seed: 1, count: 90, depth: 0.7, grid: false, theme: model.progress.selectedTheme, falloff: true))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            custom = !FocusSettings.presets.contains(model.settings.minutes)
            blockMode = model.settings.blockMode
        }
        .onChange(of: blockMode) { _, mode in
            // "Tümü" never opens the app picker, so ask for the Screen Time permission here, before the session starts.
            if mode == .all, ScreenTimeController.isAvailable, !model.screenTime.isAuthorized {
                Task { await model.screenTime.ensureAuthorized() }
            }
            blockModeCommit?.cancel()
            blockModeCommit = Task {
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, model.settings.blockMode != mode else { return }
                model.settings.blockMode = mode
            }
        }
        .onDisappear {
            blockModeCommit?.cancel()
            if model.settings.blockMode != blockMode { model.settings.blockMode = blockMode }
        }
        .sheet(isPresented: $showPicker) { AppPickerSheet() }
        .sheet(isPresented: $showBlockingInfo) { BlockingInfoSheet() }
        .sheet(isPresented: $showShortcutsGuide) { FocusShortcutsGuide() }
        .sheet(isPresented: $showSounds) { SoundsSheet() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if model.streak > 0 {
                    HStack(spacing: 5) { Spark(size: 12); Text("\(model.streak) günlük seri") }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentInk)
                }
                Text(model.todayMinutes > 0 ? String(localized: "Bugün \(model.todayMinutes.minutesText) odaklandın") : String(localized: "Bugün henüz odaklanmadın")).meta()
            }
            Text("Ne üzerinde\nodaklanıyorsun?").font(.serif(36)).foregroundStyle(Theme.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func taskField(_ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Görev").small()
            TextField("Örneğin: Tez, bölüm 3", text: text)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.paper)
                .focused($taskFocused)
                .submitLabel(.done)
            Rectangle().fill(Theme.hair).frame(height: 1).padding(.top, 6)
        }
    }

    private var durationSection: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Odak süresi").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.paper2)
                Spacer()
                // With "Özel" picked, −/+ sit on both sides of the value itself, so the minutes show only once.
                if custom { stepButton("minus", label: String(localized: "5 dakika azalt"), by: -5) }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(model.settings.minutes)").font(.serif(44)).monospacedDigit().foregroundStyle(Theme.paper)
                        .contentTransition(.numericText())
                    Text("dk").font(.system(size: 18)).foregroundStyle(Theme.paper2)
                }
                if custom { stepButton("plus", label: String(localized: "5 dakika artır"), by: 5) }
            }
            Picker("Odak süresi", selection: Binding(
                get: { custom ? 0 : model.settings.minutes },
                set: { v in
                    withAnimation(.snappy) {
                        custom = v == 0
                        if v != 0 { model.settings.minutes = v }
                    }
                })) {
                ForEach(FocusSettings.presets, id: \.self) { Text("\($0)").tag($0) }
                Text("Özel").tag(0)
            }
            .pickerStyle(.segmented)
            HStack(spacing: 8) {
                Spark(size: 13)
                Text("Bu oturum sana 1 yıldız ve yaklaşık \(model.estimatedLight) Işık kazandırır")
            }
            .font(.system(size: 13)).foregroundStyle(Theme.paper2)
        }
    }

    private func stepButton(_ symbol: String, label: String, by step: Int) -> some View {
        let range = 5...180
        return Button {
            // Read the value at tap time, never one captured when the button was last drawn:
            // a quick tap could otherwise land on a stale action and step from an older value.
            let next = min(max(model.settings.minutes + step, range.lowerBound), range.upperBound)
            withAnimation(.snappy) { model.settings.minutes = next }
        } label: {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(!range.contains(model.settings.minutes + step))
        .accessibilityLabel(label)
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 14 }
        .transition(.scale.combined(with: .opacity))
    }

    private var blockingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Engellenecek uygulamalar").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                Button("Düzenle") { editApps() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accentInk)
                    .frame(minHeight: 44)
            }
            Picker("Engelleme modu", selection: $blockMode) {
                ForEach(BlockMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.top, -6)
            HStack(spacing: 6) {
                switch blockMode {
                case .selected: Chip(text: model.screenTime.selectionSummary, systemImage: "lock")
                case .all: Chip(text: String(localized: "Telefon ve izin verdiklerin dışında her şey kilitlenir"), systemImage: "lock")
                case .none: Chip(text: String(localized: "Hiçbir uygulama kilitlenmez"), systemImage: "lock.open")
                }
            }
            .background(Theme.plate, in: .capsule)
            if !ScreenTimeController.isAvailable {
                Button { showBlockingInfo = true } label: {
                    Label("Uygulama engelleme, Apple onay verdikten sonra açılacak", systemImage: "info.circle")
                        .font(.system(size: 12)).foregroundStyle(Theme.paper2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Sounds and the playlist can be picked ahead of time; they start together with the session.
    private var soundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ses ve müzik").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
            NowPlayingCard(onOpen: { showSounds = true })
        }
    }

    private var togglesSection: some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            toggleRow(String(localized: "Arama ve mesajları sustur"), isOn: $model.settings.silenceCalls)
                .onChange(of: model.settings.silenceCalls) { _, on in
                    // The one-time Shortcuts setup is offered when the toggle is first turned on.
                    if on && !model.settings.focusShortcutsReady { showShortcutsGuide = true }
                }
            Divider().overlay(Theme.hair)
            toggleRow(String(localized: "Favoriler arayabilsin"), isOn: $model.settings.allowFavorites)
            Divider().overlay(Theme.hair)
            toggleRow(String(localized: "Katı mod"), info: String(localized: "Süre bitmeden kilit açılmaz ve Işık 1,5 katına çıkar"), isOn: $model.settings.strict)
        }
    }

    private func toggleRow(_ title: String, info: String? = nil, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            InfoTitle(title: title, info: info)
        }
        .tint(Theme.accent)
        .frame(minHeight: 52)
    }

    @ViewBuilder private var armedBoosters: some View {
        let p = model.progress
        let armed = [p.armedShootingStar ? String(localized: "Kayan yıldız hazır, bu oturumda Işık iki katına çıkacak") : nil,
                     p.armedBrightTicket ? String(localized: "Parlak yıldız bileti hazır") : nil,
                     p.armedTwinStar ? String(localized: "İkiz yıldız hazır, 45 dakika ya da daha uzun bir oturumda iki yıldız yanacak") : nil,
                     p.armedComet ? String(localized: "Kuyrukluyıldız hazır, bu oturum yolculukta iki kat sayılacak") : nil,
                     p.telescopeTarget.flatMap { id in Catalog.constellation(containing: id)?.star(id).map { String(localized: "Teleskop \($0.name) yıldızına çevrildi") } }]
            .compactMap { $0 }
        if !armed.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(armed, id: \.self) { text in
                    HStack(spacing: 8) { Spark(size: 12); Text(text) }
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.accentInk)
                }
            }
            .plate(radius: 16, padding: 12)
        }
    }

    private func editApps() {
        guard ScreenTimeController.isAvailable else { showBlockingInfo = true; return }
        Task {
            if !model.screenTime.isAuthorized { await model.screenTime.requestAuthorization() }
            if model.screenTime.isAuthorized { showPicker = true } else { showBlockingInfo = true }
        }
    }
}

/// A row title with an optional small "i" that shows its explanation in a slim bubble just above.
/// A custom bubble rather than a popover: the system popover adds tall insets around one line of text.
/// The bubble starts at the title's leading edge and wraps to two lines, so it never leaves the screen.
private struct InfoTitle: View {
    let title: String
    let info: String?
    @State private var shown = Demo.info

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.paper)
            if let info {
                Button { withAnimation(.easeOut(duration: 0.15)) { shown.toggle() } } label: {
                    Image(systemName: "info.circle").font(.system(size: 14)).foregroundStyle(Theme.paper3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Bilgi")
                .accessibilityHint(info)
            }
        }
        .overlay(alignment: .topLeading) {
            if shown, let info {
                Text(info)
                    .font(.system(size: 12)).foregroundStyle(Theme.paper)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 220, alignment: .leading)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Theme.night2, in: .rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hair))
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                    .frame(width: 240, alignment: .leading)
                    .alignmentGuide(.top) { $0[.bottom] + 6 }
                    .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { shown = false } }
                    .transition(.opacity)
            }
        }
        .task(id: shown) {
            guard shown, !Demo.info else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.15)) { shown = false }
        }
    }
}

/// Apple's picker: the app only ever sees opaque tokens, never app names.
struct AppPickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var picking = 0

    var body: some View {
        @Bindable var screenTime = model.screenTime
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Liste", selection: $picking) {
                    Text("Engellenecekler").tag(0)
                    Text("Her zaman açık").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                if picking == 0 {
                    FamilyActivityPicker(selection: $screenTime.selection)
                } else {
                    FamilyActivityPicker(headerText: String(localized: "“Tümü” modunda bile açık kalmasını istediğin uygulamaları seç, örneğin Spotify'ı."),
                                         selection: $screenTime.exemptions)
                }
            }
            .navigationTitle("Uygulamalar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }
}

struct BlockingInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(ScreenTimeController.isAvailable
                         ? "Uygulamaları kilitlemek için Ekran Süresi izni gerekiyor. Ayarlar > Ekran Süresi'nden Derin'e izin verebilirsin."
                         : "Diğer uygulamaları kilitlemek Apple'ın Ekran Süresi (Family Controls) iznini gerektiriyor. Apple bu izni onayladığında bu özellik açılacak.")
                    Text("O zamana kadar da Derin oturumu takip eder. Odak sırasında başka bir uygulamaya geçersen “hiç telefona bakmadın” bonusunu kaybedersin, ama telefonu kilitlemek bunu bozmaz.")
                }
                .font(.system(size: 15))
                .foregroundStyle(Theme.paperBody)
                .padding(22)
            }
            .navigationTitle("Uygulama engelleme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam", systemImage: "checkmark") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

/// One-time setup for silencing calls and messages through an iOS Focus and two Shortcuts.
struct FocusShortcutsGuide: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private struct Step {
        let icon: String
        let text: String
        var button: (title: String, url: URL)?
    }

    private let steps = [
        Step(icon: "moon", text: String(localized: "Ayarlar > Odak bölümünde “+” düğmesine dokunarak yeni bir Odak oluştur ve adını “Derin” koy."),
             button: (String(localized: "Ayarlar'ı aç"), FocusModeShortcuts.focusSettingsURL)),
        Step(icon: "person.2", text: String(localized: "İzin verilen kişilere Favoriler'i ekle, böylece acil durumda sana ulaşabilirler.")),
        Step(icon: "square.stack.3d.up", text: String(localized: "Aşağıdaki düğmeye dokun ve açılan ekranda “Kestirmeyi Ekle”yi seç. Odak sorulursa Derin'i seç."),
             button: (String(localized: "Derin Başlat'ı ekle"), FocusModeShortcuts.startShareURL)),
        Step(icon: "square.stack.3d.down.right", text: String(localized: "Aynı şekilde ikinci kestirmeyi de ekle."),
             button: (String(localized: "Derin Bitir'i ekle"), FocusModeShortcuts.endShareURL)),
        Step(icon: "checkmark.circle", text: String(localized: "Hepsi bu kadar. Oturum başlarken ve biterken Derin bu kestirmeleri çalıştırır, Kestirmeler de seni hemen uygulamaya geri getirir.")),
    ]

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("iOS, uygulamaların aramaları ve mesajları kendi başına susturmasına izin vermiyor. Bu yüzden bir kereliğine bir Odak modu oluşturup iki hazır kestirmeyi eklemen gerekiyor.")
                        .font(.system(size: 15)).foregroundStyle(Theme.paperBody)
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            IconDisc(systemImage: step.icon, color: Theme.accentInk, size: 36)
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Adım \(i + 1)").small()
                                    Text(step.text).font(.system(size: 15)).foregroundStyle(Theme.paper)
                                }
                                if let button = step.button {
                                    SecondaryButton(title: button.title, color: Theme.accentInk) { UIApplication.shared.open(button.url) }
                                }
                            }
                        }
                    }
                    Toggle("Kurulumu tamamladım", isOn: $model.settings.focusShortcutsReady)
                        .font(.system(size: 15, weight: .semibold))
                        .tint(Theme.accent)
                }
                .padding(22)
            }
            .navigationTitle("Arama ve mesajları sustur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Bitti", systemImage: "checkmark") { dismiss() } } }
        }
    }
}
