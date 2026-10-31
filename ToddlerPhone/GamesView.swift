import SwiftUI

// MARK: - Games hub

struct GamesView: View {
    @State private var activeGame: Game?

    enum Game: String, Identifiable {
        case balloons, memory, shapes, ballRun, dressUp, cooking, music, puzzle, bubbles
        var id: String { rawValue }
    }

    /// One game tile: symbol, name, a short friendly line and a tint.
    struct Entry: Identifiable {
        let game: Game
        let icon: String
        let title: String
        let blurb: String
        let color: Color
        var id: String { game.rawValue }
    }

    /// A soft group of games under one heading.
    struct Shelf: Identifiable {
        let name: String
        let symbol: String
        let color: Color
        let entries: [Entry]
        var id: String { name }
    }

    private static let shelves: [Shelf] = [
        Shelf(name: "Play", symbol: "sparkles", color: Palette.orange, entries: [
            Entry(game: .balloons, icon: "balloon.fill", title: "Balloon Pop",
                  blurb: "Pop them as they float", color: Palette.red),
            Entry(game: .ballRun, icon: "circle.fill", title: "Ball Run",
                  blurb: "Roll the ball along", color: Palette.green),
            Entry(game: .cooking, icon: "frying.pan.fill", title: "Little Chef",
                  blurb: "Cook a tasty snack", color: Palette.orange),
        ]),
        Shelf(name: "Learn", symbol: "lightbulb.fill", color: Palette.blue, entries: [
            Entry(game: .shapes, icon: "star.fill", title: "Shape Find",
                  blurb: "Shapes, colors and counting", color: Palette.blue),
            Entry(game: .memory, icon: "square.grid.2x2.fill", title: "Memory",
                  blurb: "Find the matching pairs", color: Palette.purple),
            Entry(game: .puzzle, icon: "puzzlepiece.extension.fill", title: "Puzzle",
                  blurb: "Slide the pieces home", color: Palette.indigo),
        ]),
        Shelf(name: "Calm", symbol: "leaf.fill", color: Palette.teal, entries: [
            Entry(game: .bubbles, icon: "bubbles.and.sparkles.fill", title: "Bubbles",
                  blurb: "Drift and pop gently", color: Palette.blue),
            Entry(game: .music, icon: "pianokeys", title: "Music",
                  blurb: "Tap out a little tune", color: Palette.teal),
            Entry(game: .dressUp, icon: "tshirt.fill", title: "Dress Up",
                  blurb: "Pick a cosy outfit", color: Palette.pink),
        ]),
    ]

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 14) {
                TopBar(title: "Games")

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(Self.shelves) { shelf in
                            VStack(alignment: .leading, spacing: 12) {
                                header(shelf)
                                // Pairs sit in the grid, a leftover one becomes a
                                // wide tile so every shelf looks complete.
                                let paired = shelf.entries.count - shelf.entries.count % 2
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(shelf.entries.prefix(paired)) { entry in
                                        tile(entry)
                                    }
                                }
                                ForEach(shelf.entries.dropFirst(paired)) { entry in
                                    wideTile(entry)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        #if DEBUG
        .onAppear {
            // Lets `simctl launch ... -game dressUp` open a game for testing.
            if let raw = UserDefaults.standard.string(forKey: "game") {
                activeGame = Game(rawValue: raw)
            }
        }
        #endif
        .fullScreenCover(item: $activeGame) { game in
            switch game {
            case .balloons: BalloonPopView()
            case .memory: MemoryMatchView()
            case .shapes: ShapeFindView()
            case .ballRun: BallRunView()
            case .dressUp: DressUpView()
            case .cooking: CookingView()
            case .music: MusicView()
            case .puzzle: PuzzleView()
            case .bubbles: BubbleView()
            }
        }
    }

    private func header(_ shelf: Shelf) -> some View {
        HStack(spacing: 8) {
            Image(systemName: shelf.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(shelf.color)
            Text(shelf.name)
                .font(.rounded(19))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(shelf.color.opacity(0.13), in: Capsule())
        .padding(.leading, 2)
    }

    private func tile(_ entry: Entry) -> some View {
        Button {
            Sfx.tap()
            Sfx.bump(.light)
            activeGame = entry.game
        } label: {
            VStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [entry.color.opacity(0.30), entry.color.opacity(0.09)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                    Image(systemName: entry.icon)
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(entry.color)
                }

                Text(entry.title)
                    .font(.rounded(17, weight: .semibold))
                    .foregroundStyle(Palette.ink)

                Text(entry.blurb)
                    .font(.rounded(12, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 30, alignment: .top)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 172)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [entry.color.opacity(0.12), entry.color.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            )
            .card()
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private func wideTile(_ entry: Entry) -> some View {
        Button {
            Sfx.tap()
            Sfx.bump(.light)
            activeGame = entry.game
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [entry.color.opacity(0.30), entry.color.opacity(0.09)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                    Image(systemName: entry.icon)
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(entry.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.rounded(17, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(entry.blurb)
                        .font(.rounded(12, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 106)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [entry.color.opacity(0.12), entry.color.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            )
            .card()
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Balloon Pop (vector balloons, no emoji)

/// A slow drifting cloud made of soft white capsules.
struct DriftingCloud: View {
    var body: some View {
        ZStack {
            Capsule().fill(.white.opacity(0.85)).frame(width: 92, height: 40)
            Circle().fill(.white.opacity(0.85)).frame(width: 52).offset(x: -26, y: -8)
            Circle().fill(.white.opacity(0.9)).frame(width: 66).offset(x: 4, y: -14)
            Circle().fill(.white.opacity(0.8)).frame(width: 46).offset(x: 34, y: -6)
        }
        .frame(width: 140, height: 60)
    }
}

/// A friendly bonus cloud: a small cloud with sparkles, full of little balloons.
struct BonusCloud: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            DriftingCloud()
                .scaleEffect(0.68)
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.yellow)
                .offset(y: -6)
                .scaleEffect(glow ? 1.14 : 0.92)
        }
        .frame(width: 100, height: 52)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

/// The classic balloon outline: round over the top, drawn in to a little
/// neck at the bottom. An ellipse reads as an egg, not a balloon.
struct BalloonBody: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let cx = r.midX
        var path = Path()
        path.move(to: CGPoint(x: cx, y: r.maxY))
        path.addCurve(
            to: CGPoint(x: r.minX, y: r.minY + h * 0.40),
            control1: CGPoint(x: cx - w * 0.26, y: r.maxY - h * 0.13),
            control2: CGPoint(x: r.minX, y: r.minY + h * 0.78)
        )
        path.addCurve(
            to: CGPoint(x: cx, y: r.minY),
            control1: CGPoint(x: r.minX, y: r.minY + h * 0.13),
            control2: CGPoint(x: cx - w * 0.32, y: r.minY)
        )
        path.addCurve(
            to: CGPoint(x: r.maxX, y: r.minY + h * 0.40),
            control1: CGPoint(x: cx + w * 0.32, y: r.minY),
            control2: CGPoint(x: r.maxX, y: r.minY + h * 0.13)
        )
        path.addCurve(
            to: CGPoint(x: cx, y: r.maxY),
            control1: CGPoint(x: r.maxX, y: r.minY + h * 0.78),
            control2: CGPoint(x: cx + w * 0.26, y: r.maxY - h * 0.13)
        )
        path.closeSubpath()
        return path
    }
}

/// A string with a kink in it, the way a real one hangs.
struct BalloonString: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY))
        path.addCurve(
            to: CGPoint(x: r.midX + r.width * 0.2, y: r.maxY),
            control1: CGPoint(x: r.midX - r.width * 1.6, y: r.minY + r.height * 0.40),
            control2: CGPoint(x: r.midX + r.width * 1.8, y: r.minY + r.height * 0.74)
        )
        return path
    }
}

/// A balloon: a rounded body lit from the top left, a knot and a string.
struct BalloonShape: View {
    let color: Color
    var isRainbow: Bool = false
    var hasGlow: Bool = false

    private static let rainbow: [Color] = [
        Palette.red, Palette.orange, Palette.yellow, Palette.green,
        Palette.teal, Palette.blue, Palette.purple, Palette.pink, Palette.red,
    ]

    var body: some View {
        VStack(spacing: 0) {
            BalloonBody()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.55), color, color.opacity(0.92)],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 2,
                        endRadius: 62
                    )
                )
                .overlay {
                    if isRainbow {
                        BalloonBody()
                            .fill(AngularGradient(colors: Self.rainbow, center: .center))
                            .opacity(0.92)
                    }
                }
                .overlay {
                    if hasGlow {
                        BalloonBody()
                            .stroke(.white.opacity(0.85), lineWidth: 4)
                    }
                }
                .overlay(
                    // The shine, following the curve of the balloon.
                    Ellipse()
                        .fill(.white.opacity(0.45))
                        .frame(width: 13, height: 21)
                        .rotationEffect(.degrees(24))
                        .offset(x: -13, y: -15)
                )
                .overlay(
                    BalloonBody().stroke(.black.opacity(0.10), lineWidth: 1)
                )
                .frame(width: 60, height: 74)

            // Knot.
            Triangle()
                .fill(color)
                .rotationEffect(.degrees(180))
                .frame(width: 11, height: 8)
                .offset(y: -1)

            BalloonString()
                .stroke(
                    Palette.ink.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                )
                .frame(width: 10, height: 28)
        }
    }
}

struct BalloonPopView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var balloons: [Balloon] = []
    @State private var pops: [Pop] = []
    @State private var confetti: [Confetti] = []
    @State private var score = 0
    @State private var milestone = 0

    @State private var wave = 1
    @State private var poppedThisWave = 0
    @State private var waveEnds = Date.now.addingTimeInterval(BalloonPopView.waveSeconds)
    @State private var nextSpawn = Date.now
    @State private var bannerWave: Int?
    @State private var showFinale = false

    @State private var combo = 0
    @State private var lastPop = Date.distantPast
    @State private var comboText: String?

    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    static let waves = 6
    static let waveSeconds: Double = 40
    static let waveBalloons = 20
    private static let maxOnScreen = 22

    private static let colors: [Color] = [
        Palette.red, Palette.blue, Palette.yellow, Palette.green,
        Palette.purple, Palette.orange, Palette.pink, Palette.teal,
    ]

    private static let comboPraise = [
        "Wow! So many!", "You are so quick!", "Look at you go!", "Amazing popping!",
    ]

    /// Clouds: y position, drift speed, size and a starting offset so they
    /// are spread out from the first frame.
    private static let clouds: [(y: CGFloat, speed: CGFloat, scale: CGFloat, start: CGFloat)] = [
        (0.13, 10, 1.0, 0.05),
        (0.28, 16, 0.7, 0.48),
        (0.44, 6, 0.85, 0.78),
    ]

    enum Kind {
        case normal, rainbow, giant, tiny, cloud

        var stars: Int {
            switch self {
            case .normal: return 1
            case .rainbow: return 3
            case .giant: return 5
            case .tiny: return 2
            case .cloud: return 1
            }
        }

        var scale: CGFloat {
            switch self {
            case .normal: return 1
            case .rainbow: return 1.2
            case .giant: return 1.85
            case .tiny: return 0.55
            case .cloud: return 1
            }
        }

        var speedFactor: CGFloat {
            switch self {
            case .normal: return 1
            case .rainbow: return 0.95
            case .giant: return 0.55
            case .tiny: return 1.75
            case .cloud: return 0.7
            }
        }
    }

    struct Balloon: Identifiable {
        let id = UUID()
        let kind: Kind
        let xFrac: CGFloat
        let color: Color
        let born: Date
        let startY: CGFloat
        let speed: CGFloat
        let scale: CGFloat
        let sway: CGFloat
        let phase: Double
        var squashed = false
    }

    struct Pop: Identifiable {
        let id = UUID()
        let point: CGPoint
        let color: Color
        let big: Bool
    }

    struct Confetti: Identifiable {
        let id = UUID()
        let point: CGPoint
    }

    /// How fast and how often balloons arrive in a given wave.
    struct WavePlan {
        let interval: Double
        let speedLow: CGFloat
        let speedHigh: CGFloat

        static func forWave(_ wave: Int) -> WavePlan {
            let step = Double(min(max(wave, 1), BalloonPopView.waves) - 1)
            return WavePlan(
                interval: max(0.42, 1.0 - 0.1 * step),
                speedLow: CGFloat(58 + 10 * step),
                speedHigh: CGFloat(96 + 16 * step)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.80, green: 0.89, blue: 0.97), Color(red: 0.93, green: 0.95, blue: 0.98)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                TimelineView(.animation) { timeline in
                    let now = timeline.date
                    ZStack {
                        // Parallax clouds drifting across the sky
                        ForEach(Array(Self.clouds.enumerated()), id: \.offset) { _, cloud in
                            let span = geo.size.width + 260
                            let travelled = cloud.start * span
                                + CGFloat(now.timeIntervalSinceReferenceDate) * cloud.speed
                            let x = travelled.truncatingRemainder(dividingBy: span) - 130
                            DriftingCloud()
                                .scaleEffect(cloud.scale)
                                .position(x: x, y: geo.size.height * cloud.y)
                        }

                        ForEach(balloons) { balloon in
                            let elapsed = now.timeIntervalSince(balloon.born)
                            let position = point(for: balloon, elapsed: elapsed, in: geo.size)
                            flyer(balloon, elapsed: elapsed)
                                .position(position)
                                .onTapGesture { tap(balloon, at: position, in: geo.size) }
                        }

                        ForEach(pops) { pop in
                            PopBurst(color: pop.color, big: pop.big)
                                .position(pop.point)
                        }
                    }
                }

                ForEach(confetti) { item in
                    ConfettiBurst(count: 30, spread: 190, duration: 1.6)
                        .position(item.point)
                }

                VStack {
                    GameTopBar(stars: score, onClose: { dismiss() }) {
                        StarChip(count: wave, symbol: "flag.fill", color: Palette.blue, label: "Wave")
                    }

                    if let comboText {
                        Text(comboText)
                            .font(.rounded(22))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .card(cornerRadius: 20)
                            .padding(.top, 10)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()
                }

                if let bannerWave {
                    waveBanner(bannerWave)
                }

                if showFinale {
                    CelebrationOverlay(
                        title: "All six waves done!",
                        subtitle: "You collected \(score) stars",
                        buttonLabel: "Play again",
                        symbol: "balloon.2.fill",
                        tint: Palette.red
                    ) {
                        restart()
                    }
                }
            }
            .onReceive(ticker) { now in
                tick(now, in: geo.size)
            }
            .onDisappear { Speaker.shared.stop() }
        }
    }

    // MARK: Drawing

    private func point(for balloon: Balloon, elapsed: TimeInterval, in size: CGSize) -> CGPoint {
        let sway = balloon.sway * CGFloat(sin(elapsed * 1.1 + balloon.phase))
        return CGPoint(
            x: balloon.xFrac * size.width + sway,
            y: balloon.startY - balloon.speed * CGFloat(elapsed)
        )
    }

    @ViewBuilder
    private func flyer(_ balloon: Balloon, elapsed: TimeInterval) -> some View {
        let tilt = sin(elapsed * 1.1 + balloon.phase) * 5

        if balloon.kind == .cloud {
            BonusCloud()
                .rotationEffect(.degrees(tilt * 0.4))
                .contentShape(Rectangle())
        } else {
            BalloonShape(
                color: balloon.color,
                isRainbow: balloon.kind == .rainbow,
                hasGlow: balloon.kind == .giant
            )
            .scaleEffect(
                x: balloon.scale * (balloon.squashed ? 1.2 : 1),
                y: balloon.scale * (balloon.squashed ? 0.82 : 1)
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: balloon.squashed)
            .rotationEffect(.degrees(tilt))
            .contentShape(Rectangle())
        }
    }

    private func waveBanner(_ number: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "flag.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Palette.blue)
            Text("Wave \(number)")
                .font(.rounded(34))
                .foregroundStyle(Palette.ink)
            Text("Here they come")
                .font(.rounded(17, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(34)
        .card(cornerRadius: 30)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: Game loop

    private func tick(_ now: Date, in size: CGSize) {
        guard !showFinale else { return }

        // Only write back when something actually left the screen, so the
        // board is not invalidated on every tick.
        let flying = balloons.filter { balloon in
            balloon.startY - balloon.speed * CGFloat(now.timeIntervalSince(balloon.born)) >= -160
        }
        if flying.count != balloons.count { balloons = flying }

        if combo > 0, now.timeIntervalSince(lastPop) > 1.4 { combo = 0 }
        guard bannerWave == nil else { return }

        if now >= waveEnds || poppedThisWave >= Self.waveBalloons {
            finishWave()
            return
        }

        if now >= nextSpawn {
            spawn(now: now, in: size)
            nextSpawn = now.addingTimeInterval(WavePlan.forWave(wave).interval)
        }
    }

    private func spawn(now: Date, in size: CGSize) {
        guard balloons.count < Self.maxOnScreen else { return }
        let plan = WavePlan.forWave(wave)
        let kind = randomKind()
        balloons.append(Balloon(
            kind: kind,
            xFrac: .random(in: 0.14...0.86),
            color: kind == .rainbow ? Palette.purple : (Self.colors.randomElement() ?? Palette.red),
            born: now,
            startY: size.height + 90,
            speed: CGFloat.random(in: plan.speedLow...plan.speedHigh) * kind.speedFactor,
            scale: kind == .normal ? .random(in: 0.9...1.15) : kind.scale,
            sway: .random(in: 10...26),
            phase: .random(in: 0...6.28)
        ))
    }

    private func randomKind() -> Kind {
        let roll = Double.random(in: 0...1)
        if roll < 0.07 { return .cloud }
        if roll < 0.19 { return .rainbow }
        if wave >= 2, roll < 0.29 { return .giant }
        if wave >= 3, roll < 0.44 { return .tiny }
        return .normal
    }

    private func finishWave() {
        balloons.removeAll()

        if wave >= Self.waves {
            showFinale = true
            Speaker.shared.cheer("You finished all six waves! What a star!")
            return
        }

        wave += 1
        poppedThisWave = 0
        combo = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { bannerWave = wave }
        Speaker.shared.cheer("Wave \(wave)! Here they come!")

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.25)) { bannerWave = nil }
            waveEnds = Date.now.addingTimeInterval(Self.waveSeconds)
            nextSpawn = .now
        }
    }

    private func restart() {
        showFinale = false
        wave = 1
        score = 0
        poppedThisWave = 0
        milestone = 0
        combo = 0
        balloons = []
        pops = []
        confetti = []
        waveEnds = Date.now.addingTimeInterval(Self.waveSeconds)
        nextSpawn = .now
    }

    // MARK: Popping

    private func tap(_ balloon: Balloon, at point: CGPoint, in size: CGSize) {
        guard let index = balloons.firstIndex(where: { $0.id == balloon.id }) else { return }

        // The giant one is squashy: the first tap only squashes it.
        if balloon.kind == .giant, !balloons[index].squashed {
            balloons[index].squashed = true
            Sfx.tap()
            Sfx.bump(.light)
            Speaker.shared.say("One more tap!")
            return
        }

        balloons.remove(at: index)
        poppedThisWave += 1
        score += balloon.kind.stars
        Sfx.tap()
        Sfx.bump(balloon.kind == .giant ? .heavy : .medium)

        let burst = Pop(point: point, color: balloon.color, big: balloon.kind != .tiny)
        pops.append(burst)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            pops.removeAll { $0.id == burst.id }
        }

        switch balloon.kind {
        case .rainbow:
            Sfx.pop()
            addConfetti(at: point)
            Speaker.shared.cheer("A rainbow balloon! Three stars!")
        case .giant:
            Sfx.pop()
            addConfetti(at: point)
            Speaker.shared.cheer("The big one! Five stars!")
        case .cloud:
            Sfx.pop()
            addConfetti(at: point)
            Speaker.shared.cheer("A cloud full of balloons!")
            release(from: balloon, at: point)
        default:
            break
        }

        trackCombo()
        checkMilestone(in: size)
    }

    /// The bonus cloud opens and lets five little balloons float free.
    private func release(from cloud: Balloon, at point: CGPoint) {
        let now = Date.now
        for i in 0..<5 {
            let spread = CGFloat(i - 2) * 0.09
            balloons.append(Balloon(
                kind: .tiny,
                xFrac: min(0.9, max(0.1, cloud.xFrac + spread)),
                color: Self.colors.randomElement() ?? Palette.pink,
                born: now,
                startY: point.y,
                speed: .random(in: 90...140),
                scale: Kind.tiny.scale,
                sway: .random(in: 12...30),
                phase: .random(in: 0...6.28)
            ))
        }
    }

    private func trackCombo() {
        let now = Date.now
        combo = now.timeIntervalSince(lastPop) < 1.2 ? combo + 1 : 1
        lastPop = now

        guard combo == 3 || combo == 5 || combo == 8 else { return }
        let praise = Self.comboPraise.randomElement() ?? "Wow!"
        Speaker.shared.cheer(praise)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            comboText = "\(combo) in a row"
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.25)) { comboText = nil }
        }
    }

    private func checkMilestone(in size: CGSize) {
        guard score / 25 > milestone else { return }
        milestone = score / 25
        addConfetti(at: CGPoint(x: size.width / 2, y: 160))
        Speaker.shared.cheer("Woohoo! \(milestone * 25) stars! Amazing!")
    }

    private func addConfetti(at point: CGPoint) {
        let item = Confetti(point: point)
        confetti.append(item)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            confetti.removeAll { $0.id == item.id }
        }
    }
}

/// Expanding ring plus a few tiny fragments, shown when a balloon pops.
struct PopBurst: View {
    let color: Color
    var big: Bool = false

    @State private var expanded = false
    @State private var scattered = false
    @State private var fragments: [Fragment] = []

    struct Fragment: Identifiable {
        let id = UUID()
        let angle: CGFloat
        let distance: CGFloat
        let size: CGFloat
        let spin: Double
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: big ? 7 : 5)
                .frame(width: big ? 58 : 44, height: big ? 58 : 44)
                .scaleEffect(expanded ? 1.7 : 0.5)
                .opacity(expanded ? 0 : 1)

            ForEach(fragments) { fragment in
                Capsule()
                    .fill(color)
                    .frame(width: fragment.size * 0.6, height: fragment.size)
                    .rotationEffect(.degrees(scattered ? fragment.spin : 0))
                    .offset(
                        x: scattered ? cos(fragment.angle) * fragment.distance : 0,
                        y: scattered ? sin(fragment.angle) * fragment.distance + 46 : 0
                    )
                    .opacity(scattered ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            fragments = (0..<6).map { i in
                Fragment(
                    angle: CGFloat(i) / 6 * .pi * 2 + .random(in: -0.3...0.3),
                    distance: .random(in: 26...52),
                    size: .random(in: 8...14),
                    spin: .random(in: -200...200)
                )
            }
            withAnimation(.easeOut(duration: 0.35)) { expanded = true }
            withAnimation(.easeIn(duration: 0.65)) { scattered = true }
        }
    }
}

// MARK: - Shape Find (shapes, colors and counting)

struct ShapeFindView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode?
    @State private var round = Round.placeholder
    @State private var stars = 0
    @State private var roundNumber = 1
    @State private var celebrating = false
    @State private var burstID: UUID?
    @State private var tapped: Set<UUID> = []
    @State private var wiggleID: UUID?
    @State private var wiggleOffset: CGFloat = 0
    @State private var showMilestone = false
    @State private var milestone = 0

    enum Mode: String, Identifiable, CaseIterable {
        case shapes, colors, counting
        var id: String { rawValue }

        var title: String {
            switch self {
            case .shapes: return "Shapes"
            case .colors: return "Colors"
            case .counting: return "Counting"
            }
        }

        var blurb: String {
            switch self {
            case .shapes: return "Find the shape that matches"
            case .colors: return "Find the color we ask for"
            case .counting: return "Tap and count out loud"
            }
        }

        var symbol: String {
            switch self {
            case .shapes: return "square.on.circle"
            case .colors: return "paintpalette.fill"
            case .counting: return "list.number"
            }
        }

        var color: Color {
            switch self {
            case .shapes: return Palette.blue
            case .colors: return Palette.pink
            case .counting: return Palette.green
            }
        }
    }

    struct Option: Identifiable {
        let id = UUID()
        let symbol: String
        let color: Color
        let isTarget: Bool
    }

    struct Round {
        let prompt: String
        let options: [Option]
        let needed: Int
        let tint: Color
        let previewSymbol: String?

        static let placeholder = Round(
            prompt: "Ready", options: [], needed: 1, tint: Palette.blue, previewSymbol: nil
        )
    }

    static let figures: [(symbol: String, name: String)] = [
        ("circle.fill", "circle"),
        ("square.fill", "square"),
        ("star.fill", "star"),
        ("heart.fill", "heart"),
        ("triangle.fill", "triangle"),
        ("moon.fill", "moon"),
        ("hexagon.fill", "hexagon"),
        ("diamond.fill", "diamond"),
    ]

    static let paints: [(name: String, color: Color)] = [
        ("red", Palette.red),
        ("blue", Palette.blue),
        ("yellow", Palette.yellow),
        ("green", Palette.green),
        ("orange", Palette.orange),
        ("purple", Palette.purple),
        ("pink", Palette.pink),
        ("teal", Palette.teal),
    ]

    /// Plural names for the counting prompts.
    static let counters: [(symbol: String, one: String, many: String, color: Color)] = [
        ("star.fill", "star", "stars", Palette.yellow),
        ("heart.fill", "heart", "hearts", Palette.pink),
        ("circle.fill", "ball", "balls", Palette.blue),
        ("leaf.fill", "leaf", "leaves", Palette.green),
        ("car.fill", "car", "cars", Palette.red),
    ]

    /// The board grows as stars are earned: three, then four, then six.
    private var optionCount: Int {
        if stars >= 12 { return 6 }
        if stars >= 5 { return 4 }
        return 3
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            if mode == nil {
                startScreen
            } else {
                playScreen
            }

            if showMilestone {
                CelebrationOverlay(
                    title: "\(milestone * 10) stars!",
                    subtitle: "You are such a good looker",
                    buttonLabel: "Keep playing",
                    symbol: "star.fill",
                    tint: Palette.yellow
                ) {
                    showMilestone = false
                    nextRound()
                }
            }
        }
        .onDisappear { Speaker.shared.stop() }
    }

    // MARK: Start screen

    private var startScreen: some View {
        VStack(spacing: 18) {
            GameTopBar(onClose: { dismiss() })

            Text("What shall we play?")
                .font(.rounded(26))
                .foregroundStyle(Palette.ink)
                .padding(.top, 6)

            Spacer(minLength: 0)

            VStack(spacing: 16) {
                ForEach(Mode.allCases) { option in
                    Button {
                        Sfx.tap()
                        Sfx.bump(.light)
                        start(option)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(option.color)
                                .frame(width: 66, height: 66)
                                .background(
                                    Circle().fill(
                                        LinearGradient(
                                            colors: [option.color.opacity(0.30), option.color.opacity(0.09)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.title)
                                    .font(.rounded(22))
                                    .foregroundStyle(Palette.ink)
                                Text(option.blurb)
                                    .font(.rounded(14, weight: .medium))
                                    .foregroundStyle(Palette.inkSoft)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 106)
                        .frame(maxWidth: .infinity)
                        .card(cornerRadius: 28)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }
            .padding(.horizontal, 26)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 40)
    }

    // MARK: Play screen

    private var playScreen: some View {
        VStack(spacing: 16) {
            GameTopBar(stars: stars, onClose: { dismiss() }) {
                StarChip(count: roundNumber, symbol: "flag.fill", color: Palette.blue)
            }

            Spacer(minLength: 0)

            Text(round.prompt)
                .font(.rounded(24))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            preview

            Text(celebrating ? "Yay!" : " ")
                .font(.rounded(24))
                .foregroundStyle(round.tint)
                .frame(height: 30)

            Spacer(minLength: 0)

            optionsBoard
                .padding(.horizontal, 26)
                .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let mode {
            switch mode {
            case .shapes:
            Image(systemName: round.previewSymbol ?? "star.fill")
                .font(.system(size: 76, weight: .semibold))
                .foregroundStyle(round.tint)
                .frame(width: 164, height: 164)
                .card(cornerRadius: 36)
                .scaleEffect(celebrating ? 1.1 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: celebrating)

        case .colors:
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    LinearGradient(
                        colors: [round.tint.opacity(0.8), round.tint],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 164, height: 120)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                .scaleEffect(celebrating ? 1.1 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: celebrating)

        case .counting:
            HStack(spacing: 12) {
                ForEach(0..<max(round.needed, 1), id: \.self) { index in
                    Circle()
                        .fill(index < tapped.count ? round.tint : Palette.field)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle().stroke(round.tint.opacity(0.4), lineWidth: 2)
                        )
                        .scaleEffect(index < tapped.count ? 1.12 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: tapped.count)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 20)
            .card(cornerRadius: 28)
            }
        }
    }

    @ViewBuilder
    private var optionsBoard: some View {
        if round.options.count == 3 {
            HStack(spacing: 14) {
                ForEach(round.options) { option in
                    optionButton(option, height: 100)
                }
            }
        } else {
            let columnCount = round.options.count >= 6 ? 3 : 2
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: columnCount),
                spacing: 14
            ) {
                ForEach(round.options) { option in
                    optionButton(option, height: columnCount == 3 ? 84 : 96)
                }
            }
        }
    }

    private func optionButton(_ option: Option, height: CGFloat) -> some View {
        let isDone = tapped.contains(option.id)
        return Button {
            choose(option)
        } label: {
            Image(systemName: option.symbol)
                .font(.system(size: height > 90 ? 42 : 36, weight: .semibold))
                .foregroundStyle(option.color)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(option.color.opacity(isDone ? 0.16 : 0.0))
                )
                .card(cornerRadius: 26)
                .overlay {
                    if burstID == option.id {
                        ConfettiBurst(count: 22, spread: 150, duration: 1.4, scale: 0.85)
                    }
                }
                .scaleEffect(isDone ? 0.94 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDone)
        }
        .buttonStyle(BouncyButtonStyle())
        .offset(x: wiggleID == option.id ? wiggleOffset : 0)
        .disabled(celebrating || isDone)
    }

    // MARK: Rounds

    private func start(_ chosen: Mode) {
        mode = chosen
        stars = 0
        roundNumber = 1
        milestone = 0
        round = makeRound(for: chosen, count: 3)
        tapped = []
        announce()
    }

    private func nextRound() {
        guard let mode else { return }
        celebrating = false
        burstID = nil
        tapped = []
        roundNumber += 1
        round = makeRound(for: mode, count: optionCount)
        announce()
    }

    private func announce() {
        Speaker.shared.say(round.prompt)
    }

    private func makeRound(for mode: Mode, count: Int) -> Round {
        switch mode {
        case .shapes:
            let picks = Array(Self.figures.indices.shuffled().prefix(count))
            guard let targetIndex = picks.first else { return .placeholder }
            let target = Self.figures[targetIndex]
            let paint = Self.paints[targetIndex % Self.paints.count]
            let options = picks.shuffled().map { index -> Option in
                Option(
                    symbol: Self.figures[index].symbol,
                    color: Self.paints[index % Self.paints.count].color,
                    isTarget: index == targetIndex
                )
            }
            return Round(
                prompt: "Find the \(paint.name) \(target.name)",
                options: options,
                needed: 1,
                tint: paint.color,
                previewSymbol: target.symbol
            )

        case .colors:
            let paints = Self.paints.shuffled()
            guard let target = paints.first else { return .placeholder }
            let others = Array(paints.dropFirst().prefix(count - 1))
            let figures = Self.figures.shuffled().prefix(count).map(\.symbol)
            var options: [Option] = []
            for (index, symbol) in figures.enumerated() {
                if index == 0 {
                    options.append(Option(symbol: symbol, color: target.color, isTarget: true))
                } else {
                    let paint = others[(index - 1) % max(others.count, 1)]
                    options.append(Option(symbol: symbol, color: paint.color, isTarget: false))
                }
            }
            return Round(
                prompt: "Find the \(target.name) one",
                options: options.shuffled(),
                needed: 1,
                tint: target.color,
                previewSymbol: nil
            )

        case .counting:
            let counter = Self.counters.randomElement() ?? Self.counters[0]
            let needed = max(1, min(count - 1, Int.random(in: (count >= 6 ? 3 : 1)...(count >= 6 ? 5 : count - 1))))
            let options = (0..<count).map { _ in
                Option(symbol: counter.symbol, color: counter.color, isTarget: true)
            }
            let word = needed == 1 ? counter.one : counter.many
            return Round(
                prompt: "Tap \(needed) \(word)",
                options: options,
                needed: needed,
                tint: counter.color,
                previewSymbol: counter.symbol
            )
        }
    }

    // MARK: Choosing

    private func choose(_ option: Option) {
        guard !celebrating else { return }

        if mode == .counting {
            tapped.insert(option.id)
            Sfx.tap()
            Sfx.bump(.light)
            if tapped.count >= round.needed {
                succeed(option)
            } else {
                Speaker.shared.say("\(tapped.count)")
            }
            return
        }

        if option.isTarget {
            succeed(option)
        } else {
            Sfx.bump(.light)
            Speaker.shared.say("Almost! Try again!")
            wiggle(option.id)
        }
    }

    private func succeed(_ option: Option) {
        stars += 1
        celebrating = true
        burstID = option.id
        Sfx.bump(.heavy)
        Sfx.received()
        Speaker.shared.cheer(cheerText())

        let reachedMilestone = stars / 10 > milestone
        if reachedMilestone { milestone = stars / 10 }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            if reachedMilestone {
                celebrating = false
                burstID = nil
                showMilestone = true
            } else {
                nextRound()
            }
        }
    }

    private func cheerText() -> String {
        if mode == .counting { return "You counted \(round.needed)! Wonderful!" }
        if mode == .colors { return "Yes! You found it! Great looking!" }
        return "Yay! You found it! Great job!"
    }

    /// A soft side to side nudge on the option that was tapped. No red, no
    /// harsh sound, just a hint to look again.
    private func wiggle(_ id: UUID) {
        guard wiggleID == nil else { return }
        wiggleID = id
        Task { @MainActor in
            for offset in [CGFloat(9), -9, 6, -6, 0] {
                withAnimation(.easeInOut(duration: 0.07)) { wiggleOffset = offset }
                try? await Task.sleep(for: .seconds(0.07))
            }
            wiggleID = nil
        }
    }
}
