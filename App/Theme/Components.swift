import SwiftUI

// Liquid Glass is reserved for controls that float above the sky (buttons, pills, chips);
// content cards stay as quiet "plates" so the glass has something to refract.

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var tint: Color = Theme.accent
    var foreground: Color = Theme.onAccent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title).font(.system(size: 16, weight: .semibold))
            } icon: {
                if let systemImage { Image(systemName: systemImage) }
            }
            .labelStyle(.titleAndIcon)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(tint)
        .controlSize(.extraLarge)
    }
}

struct SecondaryButton: View {
    let title: String
    var detail: String?
    var color: Color = Theme.paper
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).fontWeight(.medium)
                if let detail { Text(detail).foregroundStyle(Theme.paper3) }
            }
            .font(.system(size: 15))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }
}

struct Plate: ViewModifier {
    var radius: CGFloat = 20
    var padding: CGFloat = 16
    var fill: Color = Theme.plate
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func plate(radius: CGFloat = 20, padding: CGFloat = 16, fill: Color = Theme.plate) -> some View {
        modifier(Plate(radius: radius, padding: padding, fill: fill))
    }
}

struct Chip: View {
    let text: String
    var systemImage: String?
    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.paper2) }
            Text(text)
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.paper)
        .padding(.horizontal, 12)
        .frame(height: 32)
    }
}

struct ProgressBar: View {
    var value: Double
    var color: Color = Theme.accent
    var height: CGFloat = 4
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.plate2)
                Capsule().fill(color).frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue(Text("%\(Int((value * 100).rounded()))"))
    }
}

/// Işık balance, floating in the header as a tinted glass pill.
struct LightPill: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 6) {
            Spark(size: 12)
            Text(amount.formatted(.number.locale(Locale(identifier: "tr_TR"))))
                .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                .foregroundStyle(Theme.accentInk)
                .lineLimit(1)
        }
        .fixedSize()
        .padding(.horizontal, 12)
        .frame(height: 32)
        .glassEffect(.regular.tint(Theme.accent.opacity(0.18)), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(amount) Işık"))
    }
}

/// Fades scrolled content out under bottom-pinned buttons so text never shows through beside them.
struct BottomFade: ViewModifier {
    func body(content: Content) -> some View {
        content.background(alignment: .bottom) {
            LinearGradient(colors: [Theme.night.opacity(0), Theme.night.opacity(0.92), Theme.night],
                           startPoint: .top, endPoint: .bottom)
                .padding(.top, -28)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    func bottomFade() -> some View { modifier(BottomFade()) }
}

/// Three numbers separated by hairlines (Evrenin and Gökyüzüm).
struct StatStrip: View {
    let items: [(value: String, label: String)]
    var size: CGFloat = 26
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                if i > 0 { Rectangle().fill(Theme.hair).frame(width: 1, height: 36) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.value).font(.serif(size)).monospacedDigit().foregroundStyle(Theme.paper).lineLimit(1)
                    Text(item.label).small()
                }
                .accessibilityElement(children: .combine)
                if i < items.count - 1 { Spacer(minLength: 0) }
            }
        }
    }
}

struct IconDisc: View {
    let systemImage: String
    var color: Color = Theme.paper2
    var fill: Color = Theme.plate
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Header with a glass back button, as on the collection screens.
struct BackHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Geri")
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle { Text(subtitle).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentInk) }
                Text(title).font(.serif(28)).foregroundStyle(Theme.paper).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension BackHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

extension View {
    /// Keeps a `BackHeader` pinned above a scroll view; content scrolls under it with the system edge effect.
    func pinnedHeader<Header: View>(fade: Color = Theme.night, @ViewBuilder _ header: () -> Header) -> some View {
        safeAreaBar(edge: .top, spacing: 0) {
            header().padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 4)
                .background {
                    // Like BottomFade: scrolled text fades out before it reaches the title.
                    LinearGradient(colors: [fade, fade.opacity(0.92), fade.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                        .padding(.bottom, -28)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                }
        }
        .defaultScrollAnchor(Demo.scrolled ? .bottom : nil)
    }
}

extension Int {
    /// "1 sa 10 dk", "45 dk"
    var minutesText: String {
        let h = self / 60, m = self % 60
        if h == 0 { return "\(m) dk" }
        return m == 0 ? "\(h) sa" : "\(h) sa \(m) dk"
    }
}
