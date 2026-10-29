import OdakCore
import SwiftUI

/// "Gökyüzün seninle kalsın": sign in or create an account with Apple or Google. Shown once on first
/// launch and from Ayarlar. Signing in for the first time creates the account; there is no separate
/// sign-up form.
struct SignInView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let account = model.account
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Kapat", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(Theme.paper2)
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer(minLength: 24)

            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.12)).frame(width: 92, height: 92)
                    Circle().strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1).frame(width: 92, height: 92)
                    Spark(size: 30)
                }
                .accessibilityHidden(true)
                Text("Gökyüzün seninle kalsın")
                    .font(.serif(32)).foregroundStyle(Theme.paper)
                    .multilineTextAlignment(.center)
                Text("Bir hesapla yıldızların, Işığın ve takımyıldızların saklanır. Telefonunu değiştirsen ya da uygulamayı silsen bile kaldığın yerden devam edersin.")
                    .font(.system(size: 15)).foregroundStyle(Theme.paper2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 32)

            VStack(spacing: 12) {
                Group {
                    ProviderButton(title: String(localized: "Apple ile devam et"), busy: account.busy == .apple, style: .apple(dark: scheme == .dark)) {
                        Task { await signIn { await account.signInWithApple() } }
                    }
                    ProviderButton(title: String(localized: "Google ile devam et"), busy: account.busy == .google, style: .google) {
                        Task { await signIn { await account.signInWithGoogle() } }
                    }
                }
                .disabled(account.busy != nil || (!AccountService.isAvailable && !Demo.isOn))
                if let error = account.errorText {
                    Text(error).font(.system(size: 13)).foregroundStyle(Theme.alarm)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                } else if !AccountService.isAvailable && !Demo.isOn {
                    Text("Hesaplar bu sürümde henüz açık değil.").small()
                }
                Button("Şimdilik geç") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.paper2)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)

            Text("İlk girişte hesabın oluşturulur. Bu telefondaki ilerlemen hesabına eklenir, hiçbir şey silinmez.")
                .small()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 20)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StarField(seed: 31, count: 90, depth: 0.75, grid: true, theme: model.progress.selectedTheme))
        .animation(.smooth, value: account.errorText)
        .onAppear { account.errorText = nil }
    }

    private func signIn(_ work: () async -> Void) async {
        await work()
        if model.account.account != nil { dismiss() }
    }
}

/// Full-width sign-in button in each provider's own colours, as their guidelines ask.
private struct ProviderButton: View {
    enum Style {
        case apple(dark: Bool), google
    }

    let title: String
    var busy: Bool
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if busy {
                    ProgressView().tint(foreground)
                } else {
                    logo
                }
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder private var logo: some View {
        switch style {
        case .apple: Image(systemName: "apple.logo").font(.system(size: 19, weight: .medium)).offset(y: -1)
        case .google: Image("GoogleLogo").resizable().frame(width: 20, height: 20)
        }
    }

    private var foreground: Color {
        switch style {
        case let .apple(dark): dark ? .black : .white
        case .google: Color(hex: 0x1F1F1F)
        }
    }

    private var background: Color {
        switch style {
        case let .apple(dark): dark ? .white : .black
        case .google: .white
        }
    }

    private var border: Color {
        switch style {
        case .apple: .clear
        case .google: Color(hex: 0x747775).opacity(0.35)
        }
    }
}
