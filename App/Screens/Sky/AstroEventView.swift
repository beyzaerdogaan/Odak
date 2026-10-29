import OdakCore
import SwiftUI

/// An eclipse, planet event or supermoon from the sky calendar: when it happens, what to expect,
/// how to watch it and a reminder, over its own animated sky.
struct AstroEventView: View {
    let id: String

    @State private var reminded = false

    var body: some View {
        let cal = Calendar.current
        let event = MeteorShowers.astroEvent(id: id).map { SkyEvent(astro: $0, calendar: cal) }
        ScrollView {
            if let event, let astro = event.astro {
                let tint = AstroStyle.tint(astro)
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Self.kindName(astro.kind)).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                        Text(astro.title).font(.serif(42)).foregroundStyle(Theme.paper)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(event.whenText(calendar: cal)).font(.system(size: 13)).foregroundStyle(Theme.paper2)
                    }
                    .padding(.top, 24)
                    .padding(.trailing, 90)

                    Text(astro.detail).font(.system(size: 14)).foregroundStyle(Theme.paperBody)
                        .fixedSize(horizontal: false, vertical: true)
                        .plate(radius: 22, fill: tint.opacity(0.08))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gerçekte de izle").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                        Text(astro.tip).font(.system(size: 14)).foregroundStyle(Theme.paperBody)
                            .fixedSize(horizontal: false, vertical: true)
                        if astro.kind != .solarEclipse, !astro.bodies.contains("moon") {
                            Text(event.moon >= 50 ? "O gece Ay %\(event.moon) dolu; parlak gezegenler yine de rahatça görünür."
                                                  : "O gece Ay yalnızca %\(event.moon) dolu.")
                                .font(.system(size: 13)).foregroundStyle(Theme.paper2)
                        }
                        if let at = event.reminderDate(calendar: cal), at > .now {
                            Button {
                                Task { await Notifications.remind(event, at: at); reminded = true }
                            } label: {
                                Label(reminded ? "Hatırlatma kuruldu" : "Hatırlat", systemImage: reminded ? "checkmark" : "bell")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .buttonStyle(.glass)
                            .tint(tint)
                            .disabled(reminded)
                        }
                    }
                }
                .padding(22)
            }
        }
        .pinnedHeader(fade: .clear) { BackHeader(title: "Gökyüzü etkinliği", subtitle: nil) }
        .background {
            if let astro = event?.astro { AstroBackdrop(event: astro) } else { StarField(seed: 53, count: 110, grid: false) }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    static func kindName(_ kind: AstroEvent.Kind?) -> String {
        switch kind {
        case .lunarEclipse?: "Ay tutulması"
        case .solarEclipse?: "Güneş tutulması"
        case .opposition?: "Karşı konum"
        case .conjunction?: "Kavuşum"
        case .elongation?: "En büyük uzanım"
        case .supermoon?: "Süper Ay"
        case nil: "Gökyüzü etkinliği"
        }
    }
}
