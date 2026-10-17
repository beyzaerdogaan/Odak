import OdakCore
import SwiftUI

/// "Odak sürüyor": the countdown dial, what is locked, the Işık so far and the sound card.
struct ActiveSessionView: View {
    @Environment(AppModel.self) private var model
    @State private var showSounds = Demo.screen == "sounds"
    @State private var giveUpProgress: CGFloat = 0
    @State private var holding = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let s = model.session {
                content(s, now: context.date)
                    .onChange(of: context.date) { _, now in model.tick(now: now) }
            }
        }
        .background(StarField(seed: 2, count: 120, grid: true, theme: model.progress.selectedTheme))
        .sheet(isPresented: $showSounds) { SoundsSheet() }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(false)
    }

    private func content(_ s: FocusSession, now: Date) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                HStack(spacing: 7) {
                    Circle().fill(s.isOnBreak ? Theme.ice : Theme.aurora).frame(width: 6, height: 6)
                        .shadow(color: s.isOnBreak ? Theme.ice : Theme.aurora, radius: 4)
                    Text(s.isOnBreak ? "Moladasın" : "Derin odak sürüyor").meta()
                }
                Text(s.task.isEmpty ? "Odak" : s.task).font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.paper)
                    .lineLimit(1)
            }
            .padding(.top, 12)

            ZStack {
                FocusDial(minutes: s.plannedMinutes, progress: s.progress(at: now), style: model.progress.selectedDial)
                VStack(spacing: 6) {
                    Text(clock(s.isOnBreak ? s.breakRemaining(at: now) : s.remaining(at: now)))
                        .font(.serif(68)).monospacedDigit().foregroundStyle(Theme.paper)
                        .contentTransition(.numericText(countsDown: true))
                    Text(s.isOnBreak ? "Mola bitince sayaç kaldığı yerden devam eder" : "Hangi yıldızı yaktığını\noturum bitince göreceksin")
                        .font(.serif(15, italic: true)).foregroundStyle(Theme.paper2).multilineTextAlignment(.center)
                        .frame(maxWidth: 190)
                }
            }
            .frame(width: 284, height: 284)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Kalan süre \(Int(s.remaining(at: now) / 60)) dakika"))

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Chip(text: lockText(s), systemImage: s.blockMode == .none || !model.screenTime.isAuthorized ? "lock.open" : "lock")
                        .glassEffect(.regular, in: .capsule)
                    if s.silenceCalls && model.settings.focusShortcutsReady {
                        Chip(text: "Bildirimler susturuldu", systemImage: "moon").glassEffect(.regular, in: .capsule)
                    }
                }
            }

            VStack(spacing: 2) {
                Text("+\(model.liveLight(at: now))").font(.serif(26)).monospacedDigit().foregroundStyle(Theme.accentInk)
                    .contentTransition(.numericText())
                Text("Işık birikti").small()
            }

            NowPlayingCard(onOpen: { showSounds = true })

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                if s.isOnBreak {
                    SecondaryButton(title: "Molayı bitir", detail: "· \(clock(s.breakRemaining(at: now)))") { model.endBreak() }
                } else {
                    SecondaryButton(title: "5 dk mola ver", detail: s.breakUsed ? "· hakkın kullanıldı" : "· 1 hakkın var") { model.startBreak() }
                        .disabled(s.breakUsed)
                }
                if s.strict {
                    Text("Katı moddasın, süre bitene kadar kilit açılmaz.")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.paper2)
                        .frame(maxWidth: .infinity, minHeight: 50)
                } else {
                    holdToGiveUp
                }
                Text("Vazgeçersen yıldız söner ama odaklandığın dakikalar yine de sayılır.").small()
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }

    private var holdToGiveUp: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                Capsule().fill(Theme.alarm.opacity(0.18)).frame(width: geo.size.width * giveUpProgress)
            }
            Text("Vazgeçmek için basılı tut")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.alarm)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 50)
        .clipShape(.capsule)
        .overlay(Capsule().strokeBorder(Theme.alarm.opacity(0.28)))
        .contentShape(.capsule)
        .onLongPressGesture(minimumDuration: 1.5, maximumDistance: 40) {
            model.abandon()
        } onPressingChanged: { pressing in
            withAnimation(pressing ? .linear(duration: 1.5) : .easeOut(duration: 0.25)) { giveUpProgress = pressing ? 1 : 0 }
        }
        .sensoryFeedback(.warning, trigger: giveUpProgress == 1)
        .accessibilityElement()
        .accessibilityLabel("Vazgeç")
        .accessibilityHint("Oturumu bitirir ve yıldız söner")
        .accessibilityAction { model.abandon() }
    }

    private func lockText(_ s: FocusSession) -> String {
        guard s.blockMode != .none, model.screenTime.isAuthorized else { return "Uygulama engeli kapalı" }
        if s.blockMode == .all { return "Uygulamalar kilitli" }
        let n = model.screenTime.blockedCount
        return n > 0 ? "\(n) uygulama ve kategori kilitli" : "Kilitlenecek uygulama seçilmedi"
    }

    private func clock(_ t: TimeInterval) -> String {
        let total = max(0, Int(t.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// The tick ring from the design: one tick per minute, lit ticks in the accent, and a flare at the head.
struct FocusDial: View {
    let minutes: Int
    let progress: Double
    var style: DialStyle = .classic

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let r = size / 2 - 22
            ZStack {
                Canvas { ctx, _ in
                    let ticks = max(12, min(minutes, 120))
                    for i in 0..<ticks {
                        let a = CGFloat(Double(i) / Double(ticks) * 2 * .pi - .pi / 2)
                        let major = i % 5 == 0
                        let lit = Double(i) / Double(ticks) <= progress
                        let r1 = r + 9, r2 = r + (major ? 17 : 13)
                        var p = Path()
                        p.move(to: CGPoint(x: c.x + r1 * cos(a), y: c.y + r1 * sin(a)))
                        p.addLine(to: CGPoint(x: c.x + r2 * cos(a), y: c.y + r2 * sin(a)))
                        let color = lit ? (style == .meteor ? Theme.meteor : Theme.accent) : Theme.star
                        let o = lit ? (major ? 0.9 : 0.55) : (major ? 0.35 : 0.16)
                        ctx.stroke(p, with: .color(color.opacity(o)), style: StrokeStyle(lineWidth: major ? 1.6 : 1, lineCap: .round))
                    }
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                               with: .color(Theme.star.opacity(0.08)), lineWidth: 2)
                    var arc = Path()
                    arc.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false)
                    ctx.stroke(arc, with: .color(style == .meteor ? Theme.meteor : Theme.accent), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    if style == .analog {
                        for h in 0..<12 {
                            let a = CGFloat(Double(h) / 12 * 2 * .pi)
                            ctx.fill(Path(ellipseIn: CGRect(x: c.x + (r - 14) * cos(a) - 1.5, y: c.y + (r - 14) * sin(a) - 1.5, width: 3, height: 3)),
                                     with: .color(Theme.star.opacity(0.5)))
                        }
                    }
                }
                let head = CGFloat(progress * 2 * .pi - .pi / 2)
                Flare(radius: 4.2, color: style == .meteor ? Theme.meteor : Theme.accent)
                    .position(x: c.x + r * cos(head), y: c.y + r * sin(head))
            }
        }
        .accessibilityHidden(true)
    }
}

/// What is playing during the session; opens the Ses ve müzik sheet.
struct NowPlayingCard: View {
    @Environment(AppModel.self) private var model
    var onOpen: () -> Void

    var body: some View {
        let sounds = model.sounds
        let playlist = model.settings.spotifyPlaylist.flatMap { id -> (name: String, service: String)? in
            if let list = model.music.list(id: id) { return (list.name, list.service.title) }
            return (SpotifyService.suggested + model.spotify.playlists).first { $0.id == id }.map { ($0.name, "Spotify") }
        }
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 18)).foregroundStyle(Theme.aurora)
                .frame(width: 44, height: 44)
                .background(LinearGradient(colors: [Color(hex: 0x1E4A52), Color(hex: 0x13233A)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist?.name ?? (sounds.active.isEmpty ? "Ses ve müzik" : sounds.active.map(\.title).joined(separator: " ve ")))
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper).lineLimit(1)
                    Text(subtitle(playlist: playlist)).small().lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button {
                if sounds.isPlaying { sounds.stop() } else { sounds.play() }
            } label: {
                Image(systemName: sounds.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 16)).frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(sounds.active.isEmpty)
            .accessibilityLabel(sounds.isPlaying ? "Duraklat" : "Çal")
        }
        .padding(8)
        .background(Theme.plate, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func subtitle(playlist: (name: String, service: String)?) -> String {
        let ambient = model.sounds.active.map { "%\(Int((model.sounds.volumes[$0] ?? 0) * 100)) \($0.title.lowercased()) sesi" }
        if let playlist { return ([playlist.service] + ambient).joined(separator: " ve ") }
        return ambient.isEmpty ? "Ortam sesi ya da müzik seç" : ambient.joined(separator: ", ")
    }
}
