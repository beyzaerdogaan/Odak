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

    var body: some View {
        TabView(selection: $tab) {
            Tab("Evren", systemImage: "circle.circle", value: .universe) {
                NavigationStack(path: $universePath) { HomeView(tab: $tab).routes() }
            }
            Tab("Odak", systemImage: "timer", value: .focus) {
                NavigationStack { FocusSetupView() }
            }
            Tab("Gökyüzü", systemImage: "moon.stars", value: .sky) {
                NavigationStack { SkyView().routes() }
            }
            Tab("Ödüller", systemImage: "gift", value: .rewards) {
                NavigationStack { RewardsView().routes() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
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
            case "sky": tab = .sky
            case "rewards": tab = .rewards
            case "map": universePath = [.collection]
            case "deepsky": universePath = [.deepSky]
            case "event": universePath = [.event]
            case "journey": universePath = [.journey]
            default: break
            }
        }
    }
}

extension View {
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
            // Detail screens own the bottom edge (Derin gök's "Temayı uygula" sat under the tab bar).
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
