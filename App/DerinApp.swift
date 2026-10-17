import GoogleSignIn
import SwiftUI

@main
struct DerinApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .onOpenURL { _ = GIDSignIn.sharedInstance.handle($0) }
        }
        .onChange(of: phase) { _, new in
            switch new {
            case .background: model.didEnterBackground()
            case .active: model.didBecomeActive()
            default: break
            }
        }
    }
}
