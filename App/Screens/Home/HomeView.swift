import OdakCore
import SwiftUI

/// "Evrenin": the entry screen. The user's own sky as a planisphere and the next step toward it.
struct HomeView: View {
    @Binding var tab: AppTab
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Günaydın"
        case 12..<18: "İyi günler"
        default: "İyi akşamlar"
        }
    }

    var body: some View {
        let p = model.progress
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting).meta()
                        Text("Evrenin").font(.serif(38)).foregroundStyle(Theme.paper)
                    }
                    Spacer()
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 6) {
                            Text("\(p.totalFocusedMinutes / 60) sa odak")
                                .font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.paper)
                                .lineLimit(1).fixedSize()
                                .padding(.horizontal, 12).frame(height: 32)
                                .glassEffect(.regular, in: .capsule)
                            LightPill(amount: p.light)
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
                .padding(.horizontal, 22)
                .fadesOnScroll()

                NavigationLink(value: Route.collection) {
                    Planisphere(progress: p)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Koleksiyon haritasını açar")

                StatStrip(items: [
                    ("\(p.starCount)", "yıldız yaktın"),
                    ("\(p.completedConstellations.count)", "takımyıldız bitti"),
                    ("\(p.unlockedPlanets.count + p.deepSky.count)", "gök cismi açıldı"),
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
        .collapsingTitle("Evrenin")
        .background(StarField(seed: 12, count: 40, depth: 0.25, grid: false, theme: p.selectedTheme))
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
            PrimaryButton(title: "Odaklanmaya başla", action: onStart)
        }
        .plate(radius: 24)
    }

    private func title(_ p: SkyProgress) -> String {
        if p.records.isEmpty { return "İlk yıldızını yakmaya hazır mısın?" }
        if p.journeyUnlocked, let stop = p.nextStop {
            return "\(stop.name) durağına \(String(format: "%.1f", max(0, stop.lightYears - p.lightYearsTravelled)).replacingOccurrences(of: ".", with: ",")) ışık yılı kaldı"
        }
        guard let c = p.nearestConstellation else { return "Gökyüzün tamamlandı" }
        let left = c.stars.count - p.litCount(in: c)
        return left == 1 ? "\(c.name) takımyıldızını bitirmene bir yıldız kaldı" : "\(c.name) takımyıldızı için \(left) yıldız kaldı"
    }

    private func detail(_ p: SkyProgress) -> String {
        if p.records.isEmpty { return "Her tamamlanan oturum gökyüzüne bir yıldız ekler. Vazgeçersen yıldız söner ama dakikaların sayılır." }
        guard let c = p.nearestConstellation else { return "Her odak saati seni bir ışık yılı ileri taşır." }
        let remaining = c.stars.filter { !p.isLit($0.id) }
        if let bright = remaining.first(where: \.isBright), remaining.allSatisfy(\.isBright) {
            return "\(bright.name) parlak bir yıldız: yalnızca 60+ dk ya da katı mod oturumunda düşer."
        }
        return "Hangi yıldızın düşeceği oturum bitince belli olur."
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
                Text(active ? "Etkinlik sürüyor, zirve \(shower.peakText)" : "Sıradaki etkinlik, zirve \(shower.peakText)")
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
