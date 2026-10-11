import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen a blocked app shows during a focus session.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private var config: ShieldConfiguration {
        let paper = UIColor(red: 0.925, green: 0.902, blue: 0.839, alpha: 1)
        let accent = UIColor(red: 0.949, green: 0.769, blue: 0.427, alpha: 1)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.035, green: 0.051, blue: 0.133, alpha: 0.92),
            icon: UIImage(systemName: "sparkle")?.withTintColor(accent, renderingMode: .alwaysOriginal),
            title: .init(text: "Derin odak sürüyor", color: paper),
            subtitle: .init(text: "Bu uygulama oturum bitene kadar kilitli. Yıldızın seni bekliyor.",
                            color: paper.withAlphaComponent(0.7)),
            primaryButtonLabel: .init(text: "Odağa dön", color: UIColor(red: 0.11, green: 0.08, blue: 0.016, alpha: 1)),
            primaryButtonBackgroundColor: accent)
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration { config }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { config }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { config }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { config }
}
