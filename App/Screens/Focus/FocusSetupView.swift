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
    /// The block-mode picker runs on local state so its Liquid Glass slide isn't interrupted by
    /// model writes; the choice is committed once it settles (and always before starting).
    @State private var blockMode: BlockMode = .selected
    @State private var blockModeCommit: Task<Void, Never>?
    @FocusState private var taskFocused: Bool
    /// Content has started scrolling under the status bar: show the compact "Odak" bar over it.
    @State private var titleCollapsed = Demo.scrolled

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                taskField($model.settings.task)
                durationSection
                blockingSection
                togglesSection
                armedBoosters
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .defaultScrollAnchor(Demo.scrolled ? .bottom : nil)
        .onScrollGeometryChange(for: Bool.self) { g in
            g.contentOffset.y + g.contentInsets.top > 8
        } action: { _, collapsed in
            withAnimation(.easeOut(duration: 0.2)) { titleCollapsed = collapsed }
        }
        .overlay(alignment: .top) {
            compactTitleBar.opacity(titleCollapsed ? 1 : 0).allowsHitTesting(false).accessibilityHidden(!titleCollapsed)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Odaklanmaya başla") {
                taskFocused = false
                blockModeCommit?.cancel()
                model.settings.blockMode = blockMode
                model.startSession()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
            .bottomFade()
        }
        .background(StarField(seed: 1, count: 46, depth: 0.28, grid: false, theme: model.progress.selectedTheme))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            custom = !FocusSettings.presets.contains(model.settings.minutes)
            blockMode = model.settings.blockMode
        }
        .onChange(of: blockMode) { _, mode in
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
    }

    /// Like a navigation bar's inline title: content scrolling up fades out under it and never
    /// reaches the status bar.
    private var compactTitleBar: some View {
        Text("Odak")
            .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.paper)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background {
                LinearGradient(colors: [Theme.night, Theme.night.opacity(0.94), Theme.night.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .padding(.bottom, -28)
                    .ignoresSafeArea(edges: .top)
            }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if model.streak > 0 {
                    HStack(spacing: 5) { Spark(size: 12); Text("\(model.streak) günlük seri") }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentInk)
                }
                Text(model.todayMinutes > 0 ? "Bugün \(model.todayMinutes.minutesText) odaklandın" : "Bugün henüz odaklanmadın").meta()
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
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(model.settings.minutes)").font(.serif(44)).monospacedDigit().foregroundStyle(Theme.paper)
                        .contentTransition(.numericText())
                    Text("dk").font(.system(size: 18)).foregroundStyle(Theme.paper2)
                }
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
            if custom {
                Stepper(value: $model.settings.minutes, in: 5...180, step: 5) {
                    Text("\(model.settings.minutes) dakika").font(.system(size: 15)).foregroundStyle(Theme.paper)
                }
            }
            HStack(spacing: 8) {
                Spark(size: 13)
                Text("Bu oturum sana 1 yıldız ve yaklaşık \(model.estimatedLight) Işık kazandırır")
            }
            .font(.system(size: 13)).foregroundStyle(Theme.paper2)
        }
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
                case .all: Chip(text: "Telefon ve izin verdiklerin dışında her şey", systemImage: "lock")
                case .none: Chip(text: "Hiçbir uygulama kilitlenmez", systemImage: "lock.open")
                }
            }
            .background(Theme.plate, in: .capsule)
            if !ScreenTimeController.isAvailable {
                Button { showBlockingInfo = true } label: {
                    Label("Uygulama engelleme Apple onayından sonra açılacak", systemImage: "info.circle")
                        .font(.system(size: 12)).foregroundStyle(Theme.paper2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var togglesSection: some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            toggleRow("Arama ve mesajları sustur", isOn: $model.settings.silenceCalls)
                .onChange(of: model.settings.silenceCalls) { _, on in
                    // The one-time Shortcuts setup is offered when the toggle is first turned on.
                    if on && !model.settings.focusShortcutsReady { showShortcutsGuide = true }
                }
            Divider().overlay(Theme.hair)
            toggleRow("Favoriler arayabilsin", isOn: $model.settings.allowFavorites)
            Divider().overlay(Theme.hair)
            toggleRow("Katı mod", info: "Süre bitmeden kilit açılmaz, Işık ×1,5", isOn: $model.settings.strict)
        }
    }

    private func toggleRow(_ title: String, info: String? = nil, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.paper)
                if let info { InfoButton(text: info) }
            }
        }
        .tint(Theme.accent)
        .frame(minHeight: 52)
    }

    @ViewBuilder private var armedBoosters: some View {
        let p = model.progress
        let armed = [p.armedShootingStar ? "Kayan yıldız hazır: Işık ×2" : nil,
                     p.armedBrightTicket ? "Parlak yıldız bileti hazır" : nil,
                     p.telescopeTarget.flatMap { id in Catalog.constellation(containing: id)?.star(id).map { "Teleskop: \($0.name)" } }]
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

/// A small "i" next to a title that shows its explanation in a popover bubble.
private struct InfoButton: View {
    let text: String
    @State private var shown = Demo.info

    var body: some View {
        Button { shown = true } label: {
            Image(systemName: "info.circle").font(.system(size: 14)).foregroundStyle(Theme.paper3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bilgi")
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            Text(text)
                .font(.system(size: 14)).foregroundStyle(Theme.paper)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 260, alignment: .leading)
                .padding(14)
                .presentationCompactAdaptation(.popover)
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
                    FamilyActivityPicker(headerText: "“Tümü” modunda bile açık kalacak uygulamalar, örneğin Spotify.",
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
                         : "Diğer uygulamaları kilitlemek Apple'ın Ekran Süresi (Family Controls) iznini gerektiriyor. Apple bu izni onayladığında bu sürümde açılacak.")
                    Text("O zamana kadar Derin oturumu yine yönetir: odak sırasında başka bir uygulamaya geçersen “hiç telefona bakmadın” bonusu düşer. Telefonu kilitlemek sayılmaz.")
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

    private let steps = [
        ("moon", "Ayarlar > Odak'ta “+” ile yeni bir Odak oluştur ve adını “Derin” koy."),
        ("person.2", "İzin verilen kişilere Favoriler'i ekle, böylece acil durumda sana ulaşabilirler."),
        ("square.stack.3d.up", "Kestirmeler'de “Derin Başlat” adında bir kestirme oluştur: “Odağı Ayarla” eylemi, Derin, Açık."),
        ("square.stack.3d.down.right", "Bir tane daha: “Derin Bitir”, aynı eylem, Kapalı."),
        ("checkmark.circle", "Hepsi bu. Oturum başlarken ve biterken Derin bu kestirmeleri çalıştırır, Kestirmeler seni hemen geri getirir."),
    ]

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("iOS, uygulamaların aramaları ve mesajları kendi başına susturmasına izin vermiyor. Bunun yerine bir kez bir Odak modu ve iki kestirme kuruyoruz.")
                        .font(.system(size: 15)).foregroundStyle(Theme.paperBody)
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            IconDisc(systemImage: step.0, color: Theme.accentInk, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Adım \(i + 1)").small()
                                Text(step.1).font(.system(size: 15)).foregroundStyle(Theme.paper)
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        SecondaryButton(title: "Ayarlar") { UIApplication.shared.open(FocusModeShortcuts.focusSettingsURL) }
                        SecondaryButton(title: "Kestirmeler") { UIApplication.shared.open(URL(string: "shortcuts://")!) }
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
