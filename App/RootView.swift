import OdakCore
import SwiftUI

enum AppTab: Hashable { case universe, focus, sky, rewards }

enum Route: Hashable {
    case collection, deepSky, event, journey
    case constellation(String)
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .universe
    @State private var universePath: [Route] = []
    @State private var skyPath: [Route] = []
    @State private var rewardsPath: [Route] = []

    var body: some View {
        if Demo.screen == "lockscreen" {
            LiveActivityPreview()
        } else {
            tabs
        }
    }

    private var tabs: some View {
        // The system tab bar's height is fixed by iOS, so it is hidden and replaced by a slimmer
        // Liquid Glass bar (CompactTabBar). Pushed detail screens hide it, as they hid the system one.
        TabView(selection: $tab) {
            Tab("Evren", systemImage: "circle.circle", value: .universe) {
                NavigationStack(path: $universePath) { HomeView(tab: $tab).routes().hidesSystemTabBar() }
            }
            Tab("Odak", systemImage: "timer", value: .focus) {
                NavigationStack { FocusSetupView().hidesSystemTabBar() }
            }
            Tab("Gökyüzü", systemImage: "moon.stars", value: .sky) {
                NavigationStack(path: $skyPath) { SkyView().routes().hidesSystemTabBar() }
            }
            Tab("Ödüller", systemImage: "gift", value: .rewards) {
                NavigationStack(path: $rewardsPath) { RewardsView().routes().hidesSystemTabBar() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsTabBar {
                CompactTabBar(selection: $tab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.3), value: showsTabBar)
        .fullScreenCover(isPresented: Binding(
            get: { model.session != nil || model.summary != nil },
            set: { if !$0 { model.summary = nil } }
        )) {
            FocusFlowView(onShowSky: { tab = .sky })
                .environment(model)
                .tint(Theme.accent)
        }
        .overlay(alignment: .top) { ToastView() }
        .task {
            model.applyDemoScreen()
            switch Demo.screen {
            case "focus": tab = .focus
            case "sky", "badges": tab = .sky
            case "rewards": tab = .rewards
            case "map": universePath = [.collection]
            case "deepsky": universePath = [.deepSky]
            case "event": universePath = [.event]
            case "journey": universePath = [.journey]
            default: break
            }
        }
    }

    /// Detail screens own the bottom edge (Derin gök's "Temayı uygula" sat under the tab bar).
    private var showsTabBar: Bool {
        switch tab {
        case .universe: universePath.isEmpty
        case .focus: true
        case .sky: skyPath.isEmpty
        case .rewards: rewardsPath.isEmpty
        }
    }
}

/// A slimmer floating Liquid Glass tab bar (52 pt instead of the system's ~62 pt), same tabs, icons and labels.
struct CompactTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var pill

    private let items: [(AppTab, String, String)] = [
        (.universe, "Evren", "circle.circle"),
        (.focus, "Odak", "timer"),
        (.sky, "Gökyüzü", "moon.stars"),
        (.rewards, "Ödüller", "gift"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { value, title, icon in
                let selected = selection == value
                Button {
                    withAnimation(.snappy(duration: 0.3)) { selection = value }
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .frame(height: 22)
                        Text(title)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selected ? Theme.accentInk : Theme.paper)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        if selected {
                            Capsule()
                                .fill(Theme.plate2)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(4)
        .frame(height: 52)
        .glassEffect(.regular.interactive(), in: .capsule)
        .frame(maxWidth: 360)
        .padding(.horizontal, 28)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

extension View {
    /// Hides the system tab bar for a tab's root; CompactTabBar is drawn instead.
    func hidesSystemTabBar() -> some View {
        toolbar(.hidden, for: .tabBar)
    }

    func routes() -> some View {
        navigationDestination(for: Route.self) { route in
            Group {
                switch route {
                case .collection: CollectionMapView()
                case .deepSky: DeepSkyView()
                case .event: MeteorEventView()
                case .journey: JourneyView()
                case let .constellation(id): ConstellationDetailView(id: id)
                }
            }
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

/// The running session, then its reward, in one full-screen flow.
struct FocusFlowView: View {
    @Environment(AppModel.self) private var model
    var onShowSky: () -> Void

    var body: some View {
        Group {
            if model.session != nil {
                ActiveSessionView()
                    .transition(.opacity)
            } else if let summary = model.summary {
                RewardFlowView(summary: summary, onShowSky: onShowSky)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.6), value: model.session == nil)
    }
}

struct ToastView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let text = model.toast {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .glassEffect(.regular, in: .capsule)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: text) {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { model.toast = nil }
                }
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}
