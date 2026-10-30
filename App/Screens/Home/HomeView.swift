import OdakCore
import SwiftUI

/// "Evrenin": the entry screen. The user's own sky as a planisphere and the next step toward it.
struct HomeView: View {
    @Binding var tab: AppTab
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: String(localized: "Günaydın")
        case 12..<18: String(localized: "İyi günler")
        default: String(localized: "İyi akşamlar")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greeting).meta()
            Text("Evrenin").font(.serif(38)).lineLimit(1).fixedSize().foregroundStyle(Theme.paper)
        }
    }

    private var pills: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 6) {
                Text("\(model.progress.totalFocusedMinutes / 60) sa odak")
                    .font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.paper)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 12).frame(height: 32)
                    .glassEffect(.regular, in: .capsule)
                LightPill(amount: model.progress.light)
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 15, weight: .medium)).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.paper2)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Ayarlar")
            }
        }
    }

    var body: some View {
        let p = model.progress
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // When the title and the pills don't fit side by side (English "Your Universe"),
                // the pills move above the title instead of squeezing it.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom) {
                        header
                        Spacer()
                        pills
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Spacer(); pills }
                        header
                    }
                }
                .padding(.horizontal, 22)
                .fadesOnScroll()

                NavigationLink(value: Route.collection) {
                    Planisphere(progress: p)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Koleksiyon haritasını açar")

                StatStrip(items: [
                    ("\(p.starCount)", String(localized: "yıldız yaktın")),
                    ("\(p.completedConstellations.count)", String(localized: "takımyıldız tamamlandı")),
                    ("\(p.unlockedPlanets.count + p.deepSky.count)", String(localized: "gök cismi açıldı")),
                ])
                .padding(.horizontal, 22)

                NextStepCard(onStart: { tab = .focus })
                    .padding(.horizontal, 22)

                if let shower = MeteorShowers.active(on: .now) {
                    NavigationLink(value: Route.event) {
                        EventBanner(shower: shower, active: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .collapsingTitle(String(localized: "Evrenin"))
        .background(StarField(seed: 12, count: 90, depth: 0.7, grid: false, theme: p.selectedTheme, falloff: true))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}

private struct NextStepCard: View {
    @Environment(AppModel.self) private var model
    var onStart: () -> Void

    var body: some View {
        let p = model.progress
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Spark(size: 16, color: Theme.ember)
                    .frame(width: 40, height: 40)
                    .background(Theme.ember.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title(p)).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                    Text(detail(p)).font(.system(size: 12)).foregroundStyle(Theme.paper2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            PrimaryButton(title: String(localized: "Odaklanmaya başla"), action: onStart)
        }
        .plate(radius: 24)
    }

    private func title(_ p: SkyProgress) -> String {
        if p.records.isEmpty { return String(localized: "İlk yıldızını yakmaya hazır mısın?") }
        if p.journeyUnlocked, let stop = p.nextStop {
            let distance = max(0, stop.lightYears - p.lightYearsTravelled).formatted(.number.precision(.fractionLength(1)).locale(AppLanguage.locale))
            return String(localized: "\(stop.name) durağına \(distance) ışık yılı kaldı")
        }
        guard let c = p.nearestConstellation else { return String(localized: "Gökyüzün tamamlandı") }
        let left = c.stars.count - p.litCount(in: c)
        return left == 1 ? String(localized: "\(c.name) takımyıldızını bitirmene bir yıldız kaldı") : String(localized: "\(c.name) takımyıldızı için \(left) yıldız kaldı")
    }

    private func detail(_ p: SkyProgress) -> String {
        if p.records.isEmpty { return String(localized: "Tamamladığın her oturum gökyüzüne bir yıldız ekler. Vazgeçersen gökyüzüne sönmüş bir yıldız düşer ama odaklandığın dakikalar yine de sayılır.") }
        guard let c = p.nearestConstellation else { return String(localized: "Her odak saati seni bir ışık yılı ileri taşır.") }
        let remaining = c.stars.filter { !p.isLit($0.id) }
        if let bright = remaining.first(where: \.isBright), remaining.allSatisfy(\.isBright) {
            return String(localized: "\(bright.name) parlak bir yıldız, bu yüzden yalnızca en az 60 dakikalık bir oturumda ya da katı modda düşer.")
        }
        return String(localized: "Hangi yıldızın düşeceği oturum bitince belli olur.")
    }
}

struct EventBanner: View {
    let shower: MeteorShower
    var active: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 22)).foregroundStyle(Theme.meteor)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(shower.name) meteor yağmuru").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                Text(active && shower.isPeak(on: .now) ? "Bugün zirvede, oturumlarında kayan yıldız düşebilir."
                     : active ? "Şu an sürüyor, zirvesi \(shower.peakText())." : "Yaklaşıyor, zirvesi \(shower.peakText()).")
                    .font(.system(size: 12)).foregroundStyle(Theme.meteor2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.meteor)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Theme.meteor.opacity(0.22), Theme.meteor.opacity(0.08)], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.meteor.opacity(0.25)))
        .accessibilityElement(children: .combine)
    }
}
