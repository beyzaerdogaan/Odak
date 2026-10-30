import OdakCore
import SwiftUI

/// After a session: the new star and its Işık, then the constellation celebration if one was finished.
struct RewardFlowView: View {
    let summary: SessionSummary
    var onShowSky: () -> Void
    @Environment(AppModel.self) private var model
    @State private var showConstellation = Demo.screen == "constellation"

    var body: some View {
        ZStack {
            if showConstellation, let c = summary.completedConstellation {
                ConstellationCompleteView(constellation: c, sessions: model.progress.records.filter { r in
                    [r.starID, r.twinStarID].contains { $0.map { c.star($0) != nil } ?? false }
                }.count) {
                    close(showSky: true)
                }
                .transition(.opacity)
            } else {
                RewardView(summary: summary) {
                    if summary.completedConstellation != nil {
                        withAnimation(.smooth) { showConstellation = true }
                    } else {
                        close(showSky: false)
                    }
                } onSky: {
                    close(showSky: true)
                }
            }
        }
    }

    private func close(showSky: Bool) {
        model.summary = nil
        if showSky { onShowSky() }
    }
}

/// "Ödül anı"
struct RewardView: View {
    let summary: SessionSummary
    var onContinue: () -> Void
    var onSky: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let c = summary.constellation {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(c.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                            Text(c.latin).font(.serif(15, italic: true)).foregroundStyle(Theme.paper2)
                            Spacer()
                            Text("\(model.progress.litCount(in: c)) / \(c.stars.count)")
                                .font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.accentInk)
                        }
                        ConstellationFigure(constellation: c, progress: model.progress, highlight: summary.star?.id)
                            .frame(height: 190)
                        if let note = brightNote(c) {
                            Text(note).font(.system(size: 12)).foregroundStyle(Theme.paper2)
                                .padding(.top, 12) // keep clear of the star labels drawn at the figure's bottom edge
                        }
                    }
                }
                Divider().overlay(Theme.hair)
                ledger
                extras
                promise
            }
            .padding(.horizontal, 22)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                PrimaryButton(title: summary.completedConstellation != nil ? "Takımyıldızı gör" : "Devam", action: onContinue)
                SecondaryButton(title: "Gökyüzüme bak", action: onSky)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
            .bottomFade()
        }
        .background {
            ZStack {
                StarField(seed: 3, count: 70, depth: 0.5, theme: model.progress.selectedTheme)
                RadialGradient(colors: [Theme.accent.opacity(0.16), .clear], center: .init(x: 0.5, y: 0.2), startRadius: 0, endRadius: 220)
                    .ignoresSafeArea()
            }
        }
        .sensoryFeedback(.success, trigger: summary.record.id)
    }

    private var header: some View {
        VStack(spacing: 2) {
            if let star = summary.star, let c = summary.constellation {
                Text("Yeni bir yıldız yaktın").meta()
                Text(star.name).font(.serif(64, italic: true)).foregroundStyle(Theme.paper)
                    .minimumScaleFactor(0.5).lineLimit(1)
                Text("\(c.name) takımyıldızı")
                    .font(.system(size: 13)).foregroundStyle(Theme.paper)
            } else if summary.journeyStarted || model.progress.journeyUnlocked {
                Text("Yolculuk sürüyor").meta()
                Text("\(summary.record.focusedMinutes) dk").font(.serif(64, italic: true)).foregroundStyle(Theme.paper)
                Text("Bu oturum seni \(String(format: "%.1f", Double(summary.record.focusedMinutes * (summary.cometUsed ? 2 : 1)) / 60).replacingOccurrences(of: ".", with: ",")) ışık yılı ileri taşıdı")
                    .font(.system(size: 13)).foregroundStyle(Theme.paper)
            } else {
                Text("Bu oturumda yıldız düşmedi").meta()
                Text("\(summary.record.focusedMinutes) dk").font(.serif(64, italic: true)).foregroundStyle(Theme.paper)
                Text("Kalan yıldızların hepsi parlak, bu yüzden en az 60 dakikalık bir oturum ya da katı mod gerekiyor. Üst üste 4 oturumda yıldız düşmezse sıradaki oturumda yıldız garanti.")
                    .font(.system(size: 13)).foregroundStyle(Theme.paper).multilineTextAlignment(.center)
            }
            if let off = model.lastScreenOffMinutes, off > 0 {
                Text("\(off) dakika telefona bakmadın")
                    .font(.serif(15, italic: true)).foregroundStyle(Theme.paper2).padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var ledger: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kazandığın Işık").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.paper2)
            ForEach(summary.ledger.lines, id: \.self) { line in
                HStack(spacing: 8) {
                    Text(line.label)
                    DottedLeader()
                    Text("+\(line.amount)").monospacedDigit()
                }
                .font(.system(size: 14)).foregroundStyle(Theme.paper)
            }
            if summary.bonusLight > 0 {
                HStack(spacing: 8) {
                    Text("Takımyıldız ödülü")
                    DottedLeader()
                    Text("+\(summary.bonusLight)").monospacedDigit()
                }
                .font(.system(size: 14)).foregroundStyle(Theme.paper)
            }
            HStack {
                Text("Toplam").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                HStack(spacing: 6) {
                    Spark(size: 16)
                    Text("\(summary.ledger.total + summary.bonusLight)").font(.serif(34)).monospacedDigit()
                }
                .foregroundStyle(Theme.accentInk)
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder private var extras: some View {
        let items = extraItems
        if !items.isEmpty || !summary.newBadges.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.newBadges) { b in
                    HStack(spacing: 10) {
                        BadgeMedal(badge: b, size: 34)
                        Text("Rozet: \(b.title)").font(.system(size: 14, weight: .medium)).foregroundStyle(b.tone)
                    }
                }
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Label(item.1, systemImage: item.0).font(.system(size: 14, weight: .medium)).foregroundStyle(item.2)
                }
            }
            .plate(padding: 14)
        }
    }

    private var extraItems: [(String, String, Color)] {
        var items: [(String, String, Color)] = []
        if let twin = summary.twinStar, let c = Catalog.constellation(containing: twin.id) {
            items.append(("sparkles", "İkiz yıldız: \(c.name) takımyıldızında \(twin.name) da yandı", Theme.accentInk))
        }
        if summary.cometUsed { items.append(("moon.stars", "Kuyrukluyıldız bu oturumu yolculukta iki kat saydı", Theme.ice)) }
        for o in summary.newDeepSky { items.append(("sparkles", "\(o.name) keşfedildi ve \(o.light) Işık kazandın", Theme.nebula)) }
        for p in summary.newPlanets { items.append(("circle.fill", "\(p.name) açıldı", Theme.ice)) }
        for s in summary.reachedStops { items.append(("location.north.fill", "\(s.name) durağına vardın, ödülün: \(s.rewardText)", Theme.accentInk)) }
        if summary.journeyStarted { items.append(("airplane", "Işık yolculuğu başladı", Theme.accentInk)) }
        if summary.caughtShootingStar { items.append(("sparkle", "Kayan yıldız yakaladın, bu oturumun Işığı iki katına çıktı", Theme.meteor)) }
        return items
    }

    @ViewBuilder private var promise: some View {
        let p = model.progress
        if let kept = summary.promisesKept.first {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sözünü tuttun!").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.accentInk)
                Text(kept.title).font(.serif(22)).foregroundStyle(Theme.paper)
                Text("Kendine verdiğin ödülü almanın zamanı geldi.").small()
            }
            .plate()
        } else if let open = p.promises.first(where: { $0.celebratedAt == nil }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Söz: \(open.title)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                    Spacer()
                    Text(p.promiseValueText(open, now: .now)).font(.system(size: 12)).monospacedDigit().foregroundStyle(Theme.paper2)
                }
                ProgressBar(value: p.promiseProgress(open, now: .now))
            }
            .plate(padding: 14)
        }
    }

    private func brightNote(_ c: Constellation) -> String? {
        let left = c.stars.filter { !model.progress.isLit($0.id) }
        guard left.count == 1, let last = left.first, last.isBright else { return nil }
        return "Son yıldız \(last.name) parlak bir yıldız, bu yüzden yalnızca en az 60 dakikalık bir oturumda ya da katı modda düşer."
    }
}

struct DottedLeader: View {
    var body: some View {
        Line().stroke(Theme.star.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
            .frame(height: 1)
            .offset(y: 4)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}

/// "Takımyıldız tamamlandı"
struct ConstellationCompleteView: View {
    let constellation: Constellation
    let sessions: Int
    var onDone: () -> Void
    @Environment(AppModel.self) private var model
    @State private var showFinder = false

    var body: some View {
        let c = constellation
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 0) {
                    HStack(spacing: 6) { Spark(size: 12); Text("Takımyıldız tamamlandı") }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentInk)
                    Text(c.name).font(.serif(64)).foregroundStyle(Theme.paper)
                    HStack(spacing: 4) {
                        Text(c.latin).font(.serif(16, italic: true)).foregroundStyle(Theme.paper)
                        Text(", \(c.stars.count) yıldız, \(sessions) oturumda").meta()
                    }
                }
                .frame(maxWidth: .infinity)
                ConstellationFigure(constellation: c, progress: model.progress, showLabels: false)
                    .frame(height: 200)
                ConstellationFacts(constellation: c)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tamamlama ödülleri").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.paper2)
                    HStack {
                        prize(icon: AnyView(Spark(size: 18)), value: "+\(LightRules.constellationReward)", label: "Işık", color: Theme.accentInk)
                        if let s = c.unlocksSound {
                            prize(icon: AnyView(Image(systemName: "snowflake").foregroundStyle(Theme.ice)), value: s.title, label: "Ses paketi", color: Theme.ice)
                        }
                        prize(icon: AnyView(ConstellationMedal(constellation: c, size: 44)), value: c.name, label: "Rozet", color: Theme.accentInk)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                PrimaryButton(title: "Gerçek gökyüzünde bul", systemImage: "safari") { showFinder = true }
                if let next = model.progress.openConstellations.last.flatMap(Catalog.constellation(_:)) {
                    SecondaryButton(title: "Sıradaki takımyıldız:", detail: next.name, action: onDone)
                } else {
                    SecondaryButton(title: "Gökyüzüme bak", action: onDone)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
            .bottomFade()
        }
        .background(StarField(seed: 4, count: 130, grid: true, theme: model.progress.selectedTheme))
        .sheet(isPresented: $showFinder) {
            FindInSkySheet(constellation: c)
        }
    }

    private func prize(icon: AnyView, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            icon.frame(width: 44, height: 44).background(Theme.plate, in: Circle())
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).small()
        }
        .frame(maxWidth: .infinity)
    }
}

struct ConstellationFacts: View {
    let constellation: Constellation
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bunları biliyor muydun?").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
            ForEach(constellation.facts, id: \.self) { fact in
                Text(fact).font(.system(size: 13.5)).foregroundStyle(Theme.paperBody).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.accent.opacity(0.5)).frame(width: 1) }
    }
}

/// First version of "Gerçek gökyüzünde bul": where and when to look from Turkey. An AR sky finder
/// (ARKit + CoreLocation + CoreMotion) can replace this later.
struct FindInSkySheet: View {
    let constellation: Constellation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Label(constellation.whereToLook, systemImage: "location.north.line")
                    .font(.system(size: 16)).foregroundStyle(Theme.paper)
                Text("Şehir ışıklarından uzaklaş, gözlerinin karanlığa alışması için 10–15 dakika bekle ve ekranın parlaklığını kıs.")
                    .font(.system(size: 14)).foregroundStyle(Theme.paperBody)
                Spacer()
            }
            .padding(22)
            .navigationTitle(constellation.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam", systemImage: "checkmark") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
