import OdakCore
import SwiftUI

enum AppTab: Hashable { case universe, focus, sky, rewards }

enum Route: Hashable {
    case collection, deepSky, event, journey, skyCalendar
    case constellation(String)
    /// A meteor shower or an eclipse, planet event or supermoon opened from the sky calendar.
    case meteor(String), astro(String)
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .universe
    @State private var universePath: [Route] = []

    var body: some View {
        if Demo.screen == "lockscreen" {
            LiveActivityPreview()
        } else {
            tabs
        }
    }

    private var tabs: some View {
        // The standard iOS 26 tab bar (Liquid Glass): the system keeps tab content and bottom
        // buttons clear of it. Pushed detail screens hide it (see `routes()`).
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
            case "calendar": universePath = [.event, .skyCalendar]
            case let s? where s.hasPrefix("astro-"): universePath = [.skyCalendar, .astro(String(s.dropFirst(6)))]
            default: break
            }
        }
    }
}

extension View {
    func routes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .collection: CollectionMapView()
            case .deepSky: DeepSkyView()
            case .event: MeteorEventView()
            case .journey: JourneyView()
            case .skyCalendar: SkyCalendarView()
            case let .constellation(id): ConstellationDetailView(id: id)
            case let .meteor(id): MeteorEventView(showerID: id)
            case let .astro(id): AstroEventView(id: id)
            }
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
