import OdakCore
import StoreKit
import SwiftUI

/// "Ödüller": self-promises, the Işık shop and Zenit.
struct RewardsView: View {
    @Environment(AppModel.self) private var model
    @State private var category: Category = .all
    @State private var showNewPromise = false
    @State private var showTelescope = false
    @State private var showZenit = false

    enum Category: String, CaseIterable, Identifiable {
        case all = "Tümü", boosters = "Güçlendirici", sounds = "Sesler", looks = "Görünüm", zenit = "Zenit"
        var id: String { rawValue }
    }

    var body: some View {
        let p = model.progress
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("Ödüller").font(.serif(36)).foregroundStyle(Theme.paper)
                    Spacer()
                    LightPill(amount: p.light)
                }
                .fadesOnScroll()
                promises(p)
                categoryBar
                if category == .all || category == .boosters { boosters(p) }
                if category == .all || category == .sounds { soundPacks(p) }
                if category == .all || category == .looks { looks(p) }
                if category == .all || category == .zenit { zenitCard }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .collapsingTitle("Ödüller")
        .background(StarField(seed: 6, count: 90, depth: 0.7, grid: false, theme: p.selectedTheme, falloff: true))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showNewPromise) { NewPromiseSheet(onNeedZenit: { showZenit = true }) }
        .sheet(isPresented: $showTelescope) { TelescopeSheet() }
        .sheet(isPresented: $showZenit) { ZenitSheet() }
    }

    private func promises(_ p: SkyProgress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Kendine sözler").font(.serif(24)).foregroundStyle(Theme.paper)
                Spacer()
                Button("+ Yeni söz") { showNewPromise = true }
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.accentInk).frame(minHeight: 44)
            }
            if p.promises.isEmpty {
                Text("Kendine bir ödül belirle, örneğin “10 saat odaklanınca yeni bir kitap alacağım” ya da “7 gün üst üste odaklanınca kahvaltıya çıkacağım”. Derin ilerlemeni takip eder ve hedefe ulaştığında seninle kutlar.")
                    .font(.system(size: 13)).foregroundStyle(Theme.paper2).padding(.vertical, 8)
            }
            ForEach(p.promises.sorted { ($0.celebratedAt == nil ? 0 : 1) < ($1.celebratedAt == nil ? 0 : 1) }) { promise in
                let value = p.promiseProgress(promise, now: .now)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(promise.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.paper)
                        if promise.celebratedAt != nil { Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.aurora) }
                        Spacer()
                        Text(p.promiseValueText(promise, now: .now)).font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.paper2)
                    }
                    ProgressBar(value: value, color: promise.goal.isConstellation ? Theme.ice : Theme.accent)
                    Text(promise.goalText).small()
                }
                .padding(.vertical, 14)
                .contextMenu {
                    Button("Sözü sil", systemImage: "trash", role: .destructive) {
                        model.progress.promises.removeAll { $0.id == promise.id }
                    }
                }
                Divider().overlay(Theme.hair)
            }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(Category.allCases) { c in
                        Button {
                            withAnimation(.snappy) { category = c }
                        } label: {
                            Text(c.rawValue)
                                .font(.system(size: 14, weight: category == c ? .semibold : .medium))
                                .foregroundStyle(category == c ? Theme.night : Theme.paper2)
                                .padding(.horizontal, 15).frame(height: 38)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(category == c ? .regular.tint(Theme.paper).interactive() : .regular.interactive(), in: .capsule)
                        .accessibilityAddTraits(category == c ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal, 22)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -22)
    }

    private func boosters(_ p: SkyProgress) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Güçlendiriciler").font(.serif(24)).foregroundStyle(Theme.paper).padding(.bottom, 4)
            ForEach(Booster.allCases) { b in
                HStack(spacing: 12) {
                    IconDisc(systemImage: icon(b), color: color(b), fill: color(b).opacity(0.12), size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                        Text(p.count(b) > 0 ? "\(b.detail) · Elinde \(p.count(b)) tane var" : b.detail).small()
                    }
                    Spacer(minLength: 4)
                    if p.count(b) > 0 && b != .cloud {
                        Button("Kullan") { use(b) }
                            .font(.system(size: 13, weight: .semibold))
                            .buttonStyle(.glass).controlSize(.small)
                    }
                    PriceButton(price: b.price) { model.buy(.booster(b)) }
                        .disabled(p.count(b) >= b.maxCount)
                }
                .frame(minHeight: 72)
                Divider().overlay(Theme.hair)
            }
        }
    }

    private func use(_ b: Booster) {
        if b == .telescope { showTelescope = true; return }
        model.toast = model.progress.use(b) ? "\(b.title) sonraki oturum için hazır" : "Bu zaten hazır"
    }

    private func icon(_ b: Booster) -> String {
        switch b {
        case .telescope: "scope"
        case .shootingStar: "sparkle"
        case .cloud: "cloud"
        case .brightTicket: "sun.max"
        }
    }

    private func color(_ b: Booster) -> Color {
        switch b {
        case .telescope, .shootingStar: Theme.accentInk
        case .cloud: Theme.ice
        case .brightTicket: Theme.ember
        }
    }

    private func soundPacks(_ p: SkyProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ses paketleri").font(.serif(24)).foregroundStyle(Theme.paper)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach([SoundID.library, .summerNight, .stream, .distantStorm, .winterNight]) { s in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(s.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                        if model.canUse(s) {
                            Text(model.isZenit && !p.ownedSounds.contains(s) ? "Zenit ile açık" : "Açıldı")
                                .font(.system(size: 12)).foregroundStyle(Theme.ice).frame(minHeight: 32)
                        } else if let price = ShopItem.sound(s).price {
                            PriceButton(price: price, compact: true) { model.buy(.sound(s)) }
                        } else {
                            Text("Avcı'yı tamamlayınca açılır").font(.system(size: 12)).foregroundStyle(Theme.paper3).frame(minHeight: 32)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(model.canUse(s) ? Theme.ice.opacity(0.09) : Theme.plate, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private func looks(_ p: SkyProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Görünüm").font(.serif(24)).foregroundStyle(Theme.paper)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], alignment: .leading, spacing: 18) {
                ForEach(SkyTheme.allCases) { theme in
                    if theme == .night || ShopItem.theme(theme).price != nil || p.ownedThemes.contains(theme) {
                        lookTile(preview: AnyView(MiniSky(theme: theme)), title: theme.title,
                                 owned: model.canUse(theme), selected: p.selectedTheme == theme,
                                 price: ShopItem.theme(theme).price,
                                 onBuy: { model.buy(.theme(theme)) }, onSelect: { model.selectTheme(theme) })
                    }
                }
                lookTile(preview: AnyView(Image(systemName: "clock").font(.system(size: 30, weight: .light)).foregroundStyle(Theme.paper2)),
                         title: "Analog sayaç", owned: p.ownedDials.contains(.analog) || model.isZenit,
                         selected: p.selectedDial == .analog, price: ShopItem.analogDial.price,
                         onBuy: { model.buy(.analogDial) },
                         onSelect: { model.progress.selectedDial = p.selectedDial == .analog ? .classic : .analog })
                if p.ownedDials.contains(.meteor) {
                    lookTile(preview: AnyView(Image(systemName: "sparkles").font(.system(size: 28)).foregroundStyle(Theme.meteor)),
                             title: "Meteor izi", owned: true, selected: p.selectedDial == .meteor, price: nil, onBuy: {},
                             onSelect: { model.progress.selectedDial = p.selectedDial == .meteor ? .classic : .meteor })
                }
                lookTile(preview: AnyView(Image("AppIconPreview").resizable().scaledToFit().frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))),
                         title: "Şafak uygulama ikonu", owned: p.ownsAppIcon || model.isZenit,
                         selected: UIApplication.shared.alternateIconName != nil, price: ShopItem.appIcon.price,
                         onBuy: { model.buy(.appIcon) },
                         onSelect: { model.setAlternateIcon(UIApplication.shared.alternateIconName == nil) })
            }
        }
    }

    private func lookTile(preview: AnyView, title: String, owned: Bool, selected: Bool, price: Int?,
                          onBuy: @escaping () -> Void, onSelect: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            preview
                .frame(maxWidth: .infinity).frame(height: 64)
                .background(Theme.plate, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    if selected { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.accent, lineWidth: 2) }
                }
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
            if owned {
                Button(selected ? "Kullanılıyor" : "Kullan", action: onSelect)
                    .font(.system(size: 13, weight: .semibold))
                    .buttonStyle(.glass).controlSize(.small)
            } else if let price {
                PriceButton(price: price, compact: true, action: onBuy)
            } else {
                Text("Keşfedince açılır").font(.system(size: 12)).foregroundStyle(Theme.paper3).frame(minHeight: 32)
            }
        }
    }

    private var zenitCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sun.horizon").font(.system(size: 22)).foregroundStyle(Theme.accentInk)
                    .frame(width: 46, height: 46).background(Theme.accent.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text("Zenit").font(.serif(28)).foregroundStyle(Theme.paper)
                    Text("Zenit, gökyüzünün en tepesi demek. Odaklanmak, yıldızlar ve Işık her zaman ücretsiz kalır.").font(.system(size: 12)).foregroundStyle(Theme.paper2)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(["Tüm ses paketleri ve gök temaları", "Ayrıntılı haftalık ve aylık istatistikler", "Sınırsız kendine söz"], id: \.self) { line in
                    HStack(spacing: 10) { Spark(size: 11); Text(line).font(.system(size: 14)).foregroundStyle(Theme.paper) }
                }
            }
            if model.isZenit {
                Label("Zenit aktif", systemImage: "checkmark.seal.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.aurora)
            } else {
                PrimaryButton(title: "Zenit'e geç") { showZenit = true }
            }
        }
        .padding(18)
        .background(LinearGradient(colors: [Theme.accent.opacity(0.16), Theme.accent.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.accent.opacity(0.32)))
    }
}

extension SelfPromise.Goal {
    var isConstellation: Bool { if case .constellation = self { true } else { false } }
}

struct PriceButton: View {
    let price: Int
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Spark(size: compact ? 10 : 11)
                Text("\(price)").monospacedDigit()
            }
            .font(.system(size: compact ? 13 : 14, weight: .semibold))
            .foregroundStyle(Theme.accentInk)
            .padding(.horizontal, compact ? 11 : 13)
            .frame(height: compact ? 32 : 36)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.accent.opacity(0.12)).interactive(), in: .capsule)
        .accessibilityLabel("\(price) Işık ile satın al")
    }
}

struct MiniSky: View {
    let theme: SkyTheme
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0B1026)] + theme.horizon.map { $0.opacity(1) }, startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                var rng = SeededGenerator(seed: UInt64(theme.rawValue.count + 11))
                for _ in 0..<22 {
                    let x = CGFloat.random(in: 4...max(5, size.width - 4), using: &rng), y = CGFloat.random(in: 4...max(5, size.height - 10), using: &rng)
                    let r = CGFloat.random(in: 0.6...1.2, using: &rng)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(Color(hex: 0xECE6D6, opacity: Double.random(in: 0.4...0.95, using: &rng))))
                }
            }
        }
    }
}

/// New "kendine söz": a title and one of three goal types.
struct NewPromiseSheet: View {
    var onNeedZenit: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var kind = 0
    @State private var hours = 10
    @State private var days = 7
    @State private var constellation = "cygnus"

    var body: some View {
        NavigationStack {
            Form {
                Section("Ödülün") {
                    TextField("Örneğin: Yeni bir kitap al", text: $title)
                }
                Section("Hedef") {
                    Picker("Tür", selection: $kind) {
                        Text("Odak saati").tag(0)
                        Text("Seri").tag(1)
                        Text("Takımyıldız").tag(2)
                    }
                    .pickerStyle(.segmented)
                    switch kind {
                    case 0: Stepper("\(hours) saat odak", value: $hours, in: 1...200)
                    case 1: Stepper("\(days) günlük seri", value: $days, in: 2...365)
                    default:
                        Picker("Takımyıldız", selection: $constellation) {
                            ForEach(Catalog.constellations.filter { !model.progress.isComplete($0.id) }) { Text($0.name).tag($0.id) }
                        }
                    }
                }
                if !model.isZenit {
                    Section {
                        Text("Ücretsiz sürümde aynı anda \(SkyProgress.freePromiseLimit) söz tutabilirsin. Zenit ile istediğin kadar söz verebilirsin.").small()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Yeni söz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", systemImage: "checkmark") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let goal: SelfPromise.Goal = switch kind {
        case 0: .focusHours(hours)
        case 1: .streakDays(days)
        default: .constellation(constellation)
        }
        if model.addPromise(title: title.trimmingCharacters(in: .whitespaces), goal: goal) {
            dismiss()
        } else {
            dismiss()
            onNeedZenit()
        }
    }
}

/// Teleskop: choose which star the next session lights.
struct TelescopeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.progress.openConstellations.compactMap(Catalog.constellation(_:))) { c in
                    Section(c.name) {
                        ForEach(c.stars.filter { !model.progress.isLit($0.id) }) { s in
                            Button {
                                if model.progress.use(.telescope, target: s.id) {
                                    model.toast = "Sonraki yıldızın \(s.name) olacak"
                                }
                                dismiss()
                            } label: {
                                HStack {
                                    Text(s.name).foregroundStyle(Theme.paper)
                                    if s.isBright { Text("parlak").small() }
                                    Spacer()
                                    Image(systemName: "scope").foregroundStyle(Theme.accentInk)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Teleskop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç", systemImage: "xmark") { dismiss() } } }
        }
    }
}

/// Zenit paywall. StoreKit's own subscription view handles prices, trial, purchase and restore.
struct ZenitSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: SubscriptionStore.productIDs) {
            VStack(spacing: 12) {
                Image(systemName: "sun.horizon").font(.system(size: 36)).foregroundStyle(Theme.accentInk)
                Text("Zenit").font(.serif(40)).foregroundStyle(Theme.paper)
                Text("Zenit, gökyüzünün en tepesi demek. Odaklanmak, yıldızlar ve Işık her zaman ücretsiz kalır. Zenit ise bütün sesleri ve gök temalarını, ayrıntılı istatistikleri ve sınırsız kendine sözü açar.")
                    .font(.system(size: 14)).foregroundStyle(Theme.paper2).multilineTextAlignment(.center)
            }
            .padding()
            .containerBackground(for: .subscriptionStoreFullHeight) {
                StarField(seed: 21, count: 80, grid: false, theme: .night)
            }
        }
        .storeButton(.visible, for: .restorePurchases)
        .tint(Theme.accent)
        .onInAppPurchaseCompletion { _, _ in
            await model.store.refresh()
            if model.isZenit { dismiss() }
        }
    }
}
