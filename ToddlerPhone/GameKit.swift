import SwiftUI

// MARK: - Shared celebration system (used by every game)

/// A five pointed star drawn as a path, for confetti and decorations.
struct StarShape: Shape {
    var points: Int = 5
    var innerRatio: CGFloat = 0.44

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let step = CGFloat.pi / CGFloat(points)
        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = -CGFloat.pi / 2 + step * CGFloat(i)
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// A short burst of small shapes flying outward, falling and fading.
/// Draws itself once on appear and then disappears. Particle counts are
/// capped so several bursts can run at the same time.
struct ConfettiBurst: View {
    var count: Int = 28
    var spread: CGFloat = 150
    var duration: Double = 1.5
    var scale: CGFloat = 1

    @State private var particles: [Particle] = []
    @State private var start = Date.now
    @State private var finished = false

    static let colors: [Color] = [
        Palette.pink, Palette.blue, Palette.yellow, Palette.green,
        Palette.orange, Palette.purple, Palette.teal, Palette.red,
    ]

    struct Particle: Identifiable {
        let id = UUID()
        let angle: CGFloat
        let speed: CGFloat
        let spin: Double
        let size: CGFloat
        let kind: Int          // 0 circle, 1 capsule, 2 star
        let color: Color
    }

    var body: some View {
        ZStack {
            if !finished {
                TimelineView(.animation) { timeline in
                    let t = CGFloat(max(0, timeline.date.timeIntervalSince(start)))
                    ZStack {
                        ForEach(particles) { particle in
                            shape(particle)
                                .rotationEffect(.degrees(particle.spin * Double(t)))
                                .offset(
                                    x: cos(particle.angle) * particle.speed * t,
                                    y: sin(particle.angle) * particle.speed * t + 300 * t * t
                                )
                                .opacity(Double(fade(t)))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: begin)
    }

    @ViewBuilder
    private func shape(_ particle: Particle) -> some View {
        switch particle.kind {
        case 0:
            Circle()
                .fill(particle.color)
                .frame(width: particle.size, height: particle.size)
        case 1:
            Capsule()
                .fill(particle.color)
                .frame(width: particle.size * 0.55, height: particle.size * 1.7)
        default:
            StarShape()
                .fill(particle.color)
                .frame(width: particle.size * 1.5, height: particle.size * 1.5)
        }
    }

    private func fade(_ t: CGFloat) -> CGFloat {
        let d = CGFloat(duration)
        guard t > d * 0.55 else { return 1 }
        return max(0, 1 - (t - d * 0.55) / (d * 0.45))
    }

    private func begin() {
        guard particles.isEmpty else { return }
        let total = max(8, min(count, 36))
        particles = (0..<total).map { i in
            let base = CGFloat(i) / CGFloat(total) * .pi * 2
            return Particle(
                angle: base + .random(in: -0.22...0.22),
                speed: .random(in: spread * 0.45...spread) * scale,
                spin: .random(in: -260...260),
                size: .random(in: 6...11) * scale,
                kind: Int.random(in: 0...2),
                color: Self.colors.randomElement() ?? Palette.pink
            )
        }
        start = .now
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            finished = true
        }
    }
}

/// The one win moment used by every game: dimmed backdrop, confetti and a
/// white card with a big symbol, a title and one large button.
struct CelebrationOverlay: View {
    let title: String
    var subtitle: String? = nil
    var buttonLabel: String = "Play again"
    var symbol: String = "star.fill"
    var tint: Color = Palette.yellow
    let action: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.35 : 0)
                .ignoresSafeArea()

            ConfettiBurst(count: 34, spread: 210, duration: 1.9)
                .offset(y: -40)

            VStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 108, height: 108)
                    .background(tint.opacity(0.15), in: Circle())
                    .scaleEffect(shown ? 1 : 0.6)
                    .rotationEffect(.degrees(shown ? 0 : -25))

                Text(title)
                    .font(.rounded(30))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.rounded(17, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Sfx.tap()
                    Sfx.bump(.light)
                    action()
                } label: {
                    Text(buttonLabel)
                        .font(.rounded(20))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 38)
                        .padding(.vertical, 16)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.top, 4)
            }
            .padding(30)
            .card(cornerRadius: 34)
            .padding(34)
            .scaleEffect(shown ? 1 : 0.75)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { shown = true }
        }
    }
}

/// Rounded chip with a symbol and a number that bounces when the number grows.
struct StarChip: View {
    let count: Int
    var symbol: String = "star.fill"
    var color: Color = Palette.yellow
    var label: String? = nil

    @State private var bounce = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(label.map { "\($0) \(count)" } ?? "\(count)")
                .foregroundStyle(Palette.ink)
        }
        .font(.rounded(22))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .card(cornerRadius: 18)
        .scaleEffect(bounce ? 1.18 : 1)
        .onChange(of: count) { _ in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) { bounce = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.16))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { bounce = false }
            }
        }
    }
}

/// Shared game header: close button on the left, optional centered title and
/// an optional star chip on the right.
struct GameTopBar<Trailing: View>: View {
    private let title: String?
    private let stars: Int?
    private let starColor: Color
    private let onClose: () -> Void
    private let trailing: Trailing

    init(
        title: String? = nil,
        stars: Int? = nil,
        starColor: Color = Palette.yellow,
        onClose: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.stars = stars
        self.starColor = starColor
        self.onClose = onClose
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            if let title {
                Text(title)
                    .font(.rounded(26))
                    .foregroundStyle(Palette.ink)
            }
            HStack(spacing: 10) {
                CloseButton(action: onClose)
                Spacer(minLength: 0)
                trailing
                if let stars {
                    StarChip(count: stars, color: starColor)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

extension GameTopBar where Trailing == EmptyView {
    init(
        title: String? = nil,
        stars: Int? = nil,
        starColor: Color = Palette.yellow,
        onClose: @escaping () -> Void
    ) {
        self.init(title: title, stars: stars, starColor: starColor, onClose: onClose) {
            EmptyView()
        }
    }
}
