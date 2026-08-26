import SwiftUI

// MARK: - Ball Run
//
// A gentle arcade roller for two to four year olds. Drag anywhere to steer the
// ball down a scrolling road, collect the stars the level asks for and roll
// around the obstacles. Three hearts, eight themed levels, four power ups and
// friendly characters worth bonus stars. Nothing here can be lost or failed:
// running out of hearts just offers another go.
//
// Motion is driven by one TimelineView(.animation). A single low rate timer
// handles spawning and collisions so state is never written every frame.

// MARK: Model

enum BallRunObstacle: CaseIterable, Equatable {
    case cone, rock, log, hay, mud, tumbleweed
}

enum BallRunPower: CaseIterable, Equatable {
    case magnet, shield, slow, burst

    var seconds: Double {
        switch self {
        case .magnet: return 7
        case .shield: return 8
        case .slow: return 6
        case .burst: return 0
        }
    }

    var symbol: String {
        switch self {
        case .magnet: return "bolt.horizontal.fill"
        case .shield: return "shield.fill"
        case .slow: return "tortoise.fill"
        case .burst: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .magnet: return Palette.red
        case .shield: return Palette.blue
        case .slow: return Palette.teal
        case .burst: return Palette.yellow
        }
    }
}

enum BallRunFriend: Equatable {
    case duckling, bouncy
}

enum BallRunItemKind: Equatable {
    case star
    case obstacle(BallRunObstacle)
    case power(BallRunPower)
    case friend(BallRunFriend)

    var isStar: Bool { self == .star }
}

enum BallRunScenery {
    case flower, bush, palm, shell, snowyPine, snowman
    case tree, mushroom, lamp, nightStar, cactus, desertRock
    case lollipop, candyCane, planet, rocket
}

/// Colors and scenery for one level.
struct BallRunTheme {
    let road: Color
    let center: Color
    let verge: Color
    let sky: Color
    let line: Color
    let accent: Color
    let scenery: [BallRunScenery]
}

/// One hand tuned level: a goal, a gentle speed and its own look.
struct BallRunLevel {
    let name: String
    let goal: Int
    let speed: CGFloat          // points per second, downward
    let gap: Double             // seconds between spawns
    let obstacles: [BallRunObstacle]
    let theme: BallRunTheme
}

enum BallRunLevels {
    static let all: [BallRunLevel] = [
        BallRunLevel(
            name: "Meadow", goal: 5, speed: 92, gap: 1.35,
            obstacles: [.cone, .rock],
            theme: BallRunTheme(
                road: Color(red: 0.74, green: 0.73, blue: 0.70),
                center: Color(red: 0.83, green: 0.82, blue: 0.79),
                verge: Color(red: 0.51, green: 0.74, blue: 0.54),
                sky: Color(red: 0.64, green: 0.84, blue: 0.94),
                line: Color.white.opacity(0.75),
                accent: Palette.green,
                scenery: [.flower, .bush]
            )
        ),
        BallRunLevel(
            name: "Beach", goal: 6, speed: 98, gap: 1.28,
            obstacles: [.rock, .log, .mud],
            theme: BallRunTheme(
                road: Color(red: 0.82, green: 0.77, blue: 0.68),
                center: Color(red: 0.90, green: 0.86, blue: 0.78),
                verge: Color(red: 0.95, green: 0.88, blue: 0.70),
                sky: Color(red: 0.60, green: 0.85, blue: 0.93),
                line: Color.white.opacity(0.8),
                accent: Palette.teal,
                scenery: [.palm, .shell]
            )
        ),
        BallRunLevel(
            name: "Snow", goal: 8, speed: 104, gap: 1.20,
            obstacles: [.rock, .log, .cone],
            theme: BallRunTheme(
                road: Color(red: 0.78, green: 0.84, blue: 0.90),
                center: Color(red: 0.87, green: 0.91, blue: 0.95),
                verge: Color(red: 0.94, green: 0.96, blue: 0.99),
                sky: Color(red: 0.76, green: 0.87, blue: 0.96),
                line: Color.white.opacity(0.9),
                accent: Palette.blue,
                scenery: [.snowyPine, .snowman]
            )
        ),
        BallRunLevel(
            name: "Forest", goal: 8, speed: 110, gap: 1.12,
            obstacles: [.log, .rock, .mud, .hay],
            theme: BallRunTheme(
                road: Color(red: 0.72, green: 0.69, blue: 0.63),
                center: Color(red: 0.81, green: 0.78, blue: 0.72),
                verge: Color(red: 0.40, green: 0.62, blue: 0.45),
                sky: Color(red: 0.73, green: 0.89, blue: 0.83),
                line: Color.white.opacity(0.7),
                accent: Palette.green,
                scenery: [.tree, .mushroom]
            )
        ),
        BallRunLevel(
            name: "Night", goal: 10, speed: 116, gap: 1.05,
            obstacles: [.cone, .rock, .log],
            theme: BallRunTheme(
                road: Color(red: 0.64, green: 0.65, blue: 0.79),
                center: Color(red: 0.73, green: 0.74, blue: 0.86),
                verge: Color(red: 0.49, green: 0.51, blue: 0.68),
                sky: Color(red: 0.57, green: 0.60, blue: 0.80),
                line: Color.white.opacity(0.8),
                accent: Palette.indigo,
                scenery: [.lamp, .nightStar]
            )
        ),
        BallRunLevel(
            name: "Desert", goal: 10, speed: 122, gap: 1.00,
            obstacles: [.rock, .tumbleweed, .cone],
            theme: BallRunTheme(
                road: Color(red: 0.85, green: 0.77, blue: 0.65),
                center: Color(red: 0.92, green: 0.85, blue: 0.74),
                verge: Color(red: 0.91, green: 0.79, blue: 0.58),
                sky: Color(red: 0.96, green: 0.84, blue: 0.68),
                line: Color.white.opacity(0.75),
                accent: Palette.orange,
                scenery: [.cactus, .desertRock]
            )
        ),
        BallRunLevel(
            name: "Candy", goal: 12, speed: 128, gap: 0.95,
            obstacles: [.hay, .log, .rock],
            theme: BallRunTheme(
                road: Color(red: 0.88, green: 0.80, blue: 0.88),
                center: Color(red: 0.94, green: 0.88, blue: 0.93),
                verge: Color(red: 0.98, green: 0.82, blue: 0.89),
                sky: Color(red: 0.97, green: 0.86, blue: 0.94),
                line: Color.white.opacity(0.85),
                accent: Palette.pink,
                scenery: [.lollipop, .candyCane]
            )
        ),
        BallRunLevel(
            name: "Space", goal: 12, speed: 134, gap: 0.90,
            obstacles: [.rock, .cone, .tumbleweed],
            theme: BallRunTheme(
                road: Color(red: 0.74, green: 0.73, blue: 0.88),
                center: Color(red: 0.82, green: 0.81, blue: 0.93),
                verge: Color(red: 0.64, green: 0.62, blue: 0.83),
                sky: Color(red: 0.70, green: 0.68, blue: 0.88),
                line: Color.white.opacity(0.8),
                accent: Palette.purple,
                scenery: [.planet, .rocket]
            )
        ),
    ]
}

/// One thing rolling down the road.
struct BallRunItem: Identifiable {
    let id = UUID()
    var xFrac: CGFloat          // fraction across the road, 0...1
    let kind: BallRunItemKind
    let bornWorld: Double       // world clock time it entered at the top
    let speed: CGFloat
    var yBoost: CGFloat = 0     // extra pull, used by the magnet
    let seed: CGFloat
}

/// A scenery piece on the verge, looping as the world scrolls.
struct BallRunDecor: Identifiable {
    let id = UUID()
    let leftSide: Bool
    let acrossFrac: CGFloat
    let ySeed: CGFloat
    let second: Bool            // which of the theme's two shapes
    let scale: CGFloat
}

struct BallRunEffect: Identifiable {
    let id = UUID()
    let point: CGPoint
    let kind: Int               // 0 sparkle, 1 dust, 2 splash, 3 shield pop
}

// MARK: - Entry point

struct BallRunView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("ballRunTopLevel") private var topLevel = 1
    @AppStorage("ballRunBestStars") private var bestStars = 0

    private enum Phase { case start, playing, levelDone, allDone, outOfHearts }

    @State private var phase: Phase = .start
    @State private var levelIndex = 0
    @State private var stars = 0
    @State private var runStars = 0
    @State private var hearts = 3

    @State private var items: [BallRunItem] = []
    @State private var decorations: [BallRunDecor] = []
    @State private var effects: [BallRunEffect] = []
    @State private var confetti: [BallRunEffect] = []
    @State private var nextConfettiAt = 5

    @State private var ballXFrac: CGFloat = 0.5
    @State private var tilt: CGFloat = 0
    @State private var trail: [CGPoint] = []
    @State private var ballOpacity: Double = 1
    @State private var shake: CGSize = .zero
    @State private var wobble = false

    @State private var activePower: BallRunPower?
    @State private var powerEndsAt = Date.distantPast
    @State private var ringProgress: CGFloat = 0
    @State private var safeUntil = Date.distantPast

    // Warped world clock: motion pauses on overlays and halves under the slow
    // power without any per frame state writes.
    @State private var worldBase: Double = 0
    @State private var worldAnchor = Date.now
    @State private var worldRate: Double = 0
    @State private var nextSpawnWorld: Double = 0

    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private let roadLeftFrac: CGFloat = 0.16
    private let roadRightFrac: CGFloat = 0.84
    private let ballYFrac: CGFloat = 0.80

    private var level: BallRunLevel { BallRunLevels.all[min(levelIndex, BallRunLevels.all.count - 1)] }
    private var theme: BallRunTheme { level.theme }

    var body: some View {
        ZStack {
            if phase == .start {
                BallRunStartScreen(
                    topLevel: topLevel,
                    bestStars: bestStars,
                    onPlay: { start(level: topLevel - 1) },
                    onPick: { start(level: $0) },
                    onClose: { dismiss() }
                )
                .transition(.opacity)
            } else {
                field
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phase == .start)
    }

    // MARK: Play field

    private var field: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let roadLeft = w * roadLeftFrac
            let roadRight = w * roadRightFrac
            let roadWidth = roadRight - roadLeft
            let ballY = h * ballYFrac
            let ballX = roadLeft + ballXFrac * roadWidth

            ZStack {
                background(w: w, h: h, roadLeft: roadLeft, roadRight: roadRight, roadWidth: roadWidth)

                TimelineView(.animation) { timeline in
                    let now = timeline.date
                    let world = worldTime(now)
                    ZStack {
                        scenery(world: world, w: w, h: h, roadLeft: roadLeft, roadRight: roadRight)
                        centerline(world: world, w: w, h: h)

                        ForEach(items) { item in
                            itemView(item, world: world)
                                .position(
                                    x: itemX(item, world: world, roadLeft: roadLeft, roadWidth: roadWidth),
                                    y: itemY(item, world: world)
                                )
                        }

                        motionTrail
                        ball.position(x: ballX, y: ballY)
                    }
                    .offset(shake)
                }
                .allowsHitTesting(false)

                ForEach(effects) { effect in
                    BallRunEffectView(kind: effect.kind).position(effect.point)
                }
                ForEach(confetti) { item in
                    ConfettiBurst(count: 22, spread: 165, duration: 1.5).position(item.point)
                }

                hud

                phaseOverlay
            }
            .contentShape(Rectangle())
            .gesture(steering(roadLeft: roadLeft, roadWidth: roadWidth))
            .onReceive(ticker) { _ in
                guard phase == .playing else { return }
                tick(roadLeft: roadLeft, roadWidth: roadWidth, ballX: ballX, ballY: ballY, h: h)
            }
        }
        .onAppear {
            if decorations.isEmpty { decorations = BallRunView.makeDecorations() }
        }
    }

    private func steering(roadLeft: CGFloat, roadWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard phase == .playing else { return }
                let target = min(max((value.location.x - roadLeft) / roadWidth, 0), 1)
                let delta = target - ballXFrac
                withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
                    ballXFrac = target
                    tilt = min(max(delta * 90, -18), 18)
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { tilt = 0 }
            }
    }

    // MARK: Background

    @ViewBuilder
    private func background(w: CGFloat, h: CGFloat, roadLeft: CGFloat, roadRight: CGFloat, roadWidth: CGFloat) -> some View {
        theme.road
            .ignoresSafeArea()

        Rectangle()
            .fill(theme.verge)
            .frame(width: roadLeft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea()

        Rectangle()
            .fill(theme.verge)
            .frame(width: w - roadRight)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .ignoresSafeArea()

        RoundedRectangle(cornerRadius: 4)
            .fill(theme.center)
            .frame(width: roadWidth)
            .position(x: (roadLeft + roadRight) / 2, y: h / 2)
            .ignoresSafeArea()

        LinearGradient(
            colors: [theme.sky, theme.sky.opacity(0)],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: max(h * 0.3, 1))
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func scenery(world: Double, w: CGFloat, h: CGFloat, roadLeft: CGFloat, roadRight: CGFloat) -> some View {
        let scroll = CGFloat(world) * level.speed * 0.85
        let span = h + 180
        return ForEach(decorations) { decor in
            let y = (decor.ySeed * span + scroll).truncatingRemainder(dividingBy: span) - 90
            let x = decor.leftSide
                ? decor.acrossFrac * roadLeft
                : roadRight + decor.acrossFrac * (w - roadRight)
            BallRunSceneryView(kind: theme.scenery[decor.second ? 1 : 0], accent: theme.accent)
                .scaleEffect(decor.scale)
                .position(x: x, y: y)
        }
    }

    private func centerline(world: Double, w: CGFloat, h: CGFloat) -> some View {
        let scroll = CGFloat(world) * level.speed
        return Path { path in
            path.move(to: CGPoint(x: w / 2, y: -40))
            path.addLine(to: CGPoint(x: w / 2, y: h + 40))
        }
        .stroke(
            theme.line,
            style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [26, 26], dashPhase: -scroll)
        )
    }

    // MARK: Ball

    private var ball: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Palette.green.opacity(0.8), Palette.green],
                        center: .topLeading, startRadius: 4, endRadius: 40
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(.white, lineWidth: 4))
                .shadow(color: Palette.green.opacity(0.35), radius: 6, y: 3)

            if activePower == .shield {
                Circle()
                    .stroke(Palette.blue.opacity(0.55), lineWidth: 4)
                    .background(Circle().fill(Palette.blue.opacity(0.14)))
                    .frame(width: 78, height: 78)
                    .overlay(
                        Circle()
                            .trim(from: 0.58, to: 0.78)
                            .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 78, height: 78)
                    )
            }
            if activePower == .magnet {
                Circle()
                    .stroke(Palette.red.opacity(0.28), style: StrokeStyle(lineWidth: 3, dash: [7, 7]))
                    .frame(width: 96, height: 96)
            }
        }
        .opacity(ballOpacity)
        .scaleEffect(x: 1 + abs(tilt) / 120, y: 1 - abs(tilt) / 160, anchor: .bottom)
        .rotationEffect(.degrees(tilt))
        .offset(x: wobble ? -7 : 0)
        .rotationEffect(.degrees(wobble ? 8 : 0))
    }

    @ViewBuilder
    private var motionTrail: some View {
        let strength = min(abs(tilt) / 14, 1)
        if strength > 0.35 {
            ForEach(Array(trail.enumerated()), id: \.offset) { index, point in
                let age = CGFloat(trail.count - index) / CGFloat(max(trail.count, 1))
                Circle()
                    .fill(Palette.green.opacity(0.22 * Double(1 - age) * Double(strength)))
                    .frame(width: 44 * (1 - age * 0.55), height: 44 * (1 - age * 0.55))
                    .position(point)
            }
        }
    }

    // MARK: Heads up display

    private var hud: some View {
        VStack(spacing: 8) {
            GameTopBar(stars: stars, onClose: { dismiss() }) {
                HStack(spacing: 8) {
                    if let power = activePower {
                        BallRunPowerRing(power: power, progress: ringProgress)
                    }
                    BallRunHearts(hearts: hearts)
                }
            }

            BallRunGoalBar(
                title: "Level \(levelIndex + 1) \(level.name)",
                stars: stars,
                goal: level.goal,
                tint: theme.accent
            )
            .padding(.horizontal, 34)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var phaseOverlay: some View {
        switch phase {
        case .levelDone:
            CelebrationOverlay(
                title: "Level \(levelIndex + 1) done!",
                subtitle: "You collected \(stars) stars",
                buttonLabel: "Next",
                symbol: "star.fill",
                tint: theme.accent
            ) {
                advance()
            }
        case .allDone:
            CelebrationOverlay(
                title: "You finished them all!",
                subtitle: "Every level is open now",
                buttonLabel: "Play again",
                symbol: "crown.fill",
                tint: Palette.yellow
            ) {
                start(level: 0)
            }
        case .outOfHearts:
            CelebrationOverlay(
                title: "Nice try!",
                subtitle: "Want to go again?",
                buttonLabel: "Play again",
                symbol: "heart.fill",
                tint: Palette.pink
            ) {
                start(level: levelIndex, keepRun: true)
            }
        default:
            EmptyView()
        }
    }

    // MARK: World clock

    private func worldTime(_ now: Date) -> Double {
        worldBase + now.timeIntervalSince(worldAnchor) * worldRate
    }

    private func setRate(_ rate: Double) {
        let now = Date.now
        worldBase = worldTime(now)
        worldAnchor = now
        worldRate = rate
    }

    // MARK: Geometry helpers

    private func itemY(_ item: BallRunItem, world: Double) -> CGFloat {
        -70 + item.speed * CGFloat(world - item.bornWorld) + item.yBoost
    }

    private func itemX(_ item: BallRunItem, world: Double, roadLeft: CGFloat, roadWidth: CGFloat) -> CGFloat {
        var frac = item.xFrac
        if case .friend(let friend) = item.kind {
            let amp: CGFloat = friend == .bouncy ? 0.17 : 0.07
            frac += sin(CGFloat(world) * 1.7 + item.seed * 6) * amp
        }
        return roadLeft + min(max(frac, 0.04), 0.96) * roadWidth
    }

    // MARK: Item art

    @ViewBuilder
    private func itemView(_ item: BallRunItem, world: Double) -> some View {
        switch item.kind {
        case .star:
            Image(systemName: "star.fill")
                .font(.system(size: 34))
                .foregroundStyle(Palette.yellow)
                .shadow(color: Palette.yellow.opacity(0.35), radius: 4)
        case .obstacle(let kind):
            BallRunObstacleView(kind: kind, spin: kind == .tumbleweed ? world * 90 : 0)
        case .power(let power):
            BallRunPowerToken(power: power)
                .scaleEffect(1 + 0.07 * sin(CGFloat(world) * 3 + item.seed * 4))
        case .friend(let friend):
            BallRunFriendView(friend: friend)
                .offset(y: friend == .bouncy ? -14 * abs(sin(CGFloat(world) * 3.4 + item.seed)) : 0)
        }
    }

    // MARK: Flow

    private func start(level index: Int, keepRun: Bool = false) {
        let clamped = min(max(index, 0), BallRunLevels.all.count - 1)
        levelIndex = clamped
        stars = 0
        hearts = 3
        nextConfettiAt = 5
        if !keepRun { runStars = 0 }
        items = []
        effects = []
        confetti = []
        trail = []
        ballXFrac = 0.5
        ballOpacity = 1
        clearPower()
        safeUntil = .distantPast
        if decorations.isEmpty { decorations = BallRunView.makeDecorations() }
        setRate(1)
        nextSpawnWorld = worldTime(.now) + 1.1
        topLevel = max(topLevel, clamped + 1)
        phase = .playing
    }

    private func advance() {
        if levelIndex + 1 < BallRunLevels.all.count {
            start(level: levelIndex + 1, keepRun: true)
        } else {
            start(level: 0)
        }
    }

    private func finishLevel() {
        runStars += stars
        bestStars = max(bestStars, runStars)
        topLevel = max(topLevel, min(levelIndex + 2, BallRunLevels.all.count))
        clearPower()
        setRate(0)
        Sfx.pop()
        Sfx.bump(.light)
        if levelIndex + 1 >= BallRunLevels.all.count {
            topLevel = BallRunLevels.all.count
            phase = .allDone
            Speaker.shared.cheer("You finished them all! Amazing rolling!")
        } else {
            phase = .levelDone
            let lines = [
                "Great rolling!",
                "You did it!",
                "Wow! Super steering!",
                "You are on a roll!",
                "Nice job! Keep going!",
            ]
            Speaker.shared.cheer(lines.randomElement() ?? "You did it!")
        }
    }

    private func outOfHearts() {
        runStars += stars
        bestStars = max(bestStars, runStars)
        clearPower()
        setRate(0)
        phase = .outOfHearts
    }

    // MARK: Powers

    private func clearPower() {
        activePower = nil
        powerEndsAt = .distantPast
        ringProgress = 0
        if worldRate == 0.5 { setRate(1) }
    }

    private func activate(_ power: BallRunPower, ballX: CGFloat, ballY: CGFloat, roadLeft: CGFloat, roadWidth: CGFloat, world: Double) {
        Sfx.received()
        Sfx.bump(.light)
        guard power != .burst else {
            ToneEngine.shared.playShake()
            collectAllStars(world: world, roadLeft: roadLeft, roadWidth: roadWidth, ballX: ballX, ballY: ballY)
            return
        }
        if worldRate == 0.5 && power != .slow { setRate(1) }
        activePower = power
        powerEndsAt = Date.now.addingTimeInterval(power.seconds)
        ringProgress = 1
        withAnimation(.linear(duration: power.seconds)) { ringProgress = 0 }
        if power == .slow { setRate(0.5) }
    }

    private func collectAllStars(world: Double, roadLeft: CGFloat, roadWidth: CGFloat, ballX: CGFloat, ballY: CGFloat) {
        var picked = 0
        var points: [CGPoint] = []
        items.removeAll { item in
            guard item.kind.isStar else { return false }
            let y = itemY(item, world: world)
            guard y > -60 else { return false }
            picked += 1
            if points.count < 8 {
                points.append(CGPoint(x: itemX(item, world: world, roadLeft: roadLeft, roadWidth: roadWidth), y: y))
            }
            return true
        }
        guard picked > 0 else { return }
        for point in points { addEffect(0, at: point) }
        award(picked, at: CGPoint(x: ballX, y: ballY - 40))
    }

    // MARK: Tick

    private func tick(roadLeft: CGFloat, roadWidth: CGFloat, ballX: CGFloat, ballY: CGFloat, h: CGFloat) {
        let now = Date.now
        let world = worldTime(now)

        if activePower != nil, now > powerEndsAt {
            clearPower()
        }

        spawnStep(world: world)

        if activePower == .magnet {
            pullStars(world: world, roadLeft: roadLeft, roadWidth: roadWidth, ballX: ballX, ballY: ballY)
        }

        var gained = 0
        var sparkPoints: [CGPoint] = []
        var bonkPoint: CGPoint?
        var bonkKind: BallRunObstacle?
        var pickedPower: BallRunPower?
        let invincible = now < safeUntil

        items.removeAll { item in
            let y = itemY(item, world: world)
            if y > h + 100 { return true }
            let x = itemX(item, world: world, roadLeft: roadLeft, roadWidth: roadWidth)
            guard hypot(x - ballX, y - ballY) < 44 else { return false }

            switch item.kind {
            case .star:
                gained += 1
                if sparkPoints.count < 6 { sparkPoints.append(CGPoint(x: x, y: y)) }
                return true
            case .friend(let friend):
                gained += friend == .bouncy ? 3 : 1
                if sparkPoints.count < 6 { sparkPoints.append(CGPoint(x: x, y: y)) }
                return true
            case .power(let power):
                pickedPower = power
                return true
            case .obstacle(let kind):
                if invincible { return false }
                if bonkPoint == nil {
                    bonkPoint = CGPoint(x: x, y: y)
                    bonkKind = kind
                }
                return true
            }
        }

        for point in sparkPoints { addEffect(0, at: point) }
        if gained > 0 {
            Sfx.pop()
            Sfx.bump(.light)
            award(gained, at: CGPoint(x: ballX, y: ballY - 40))
        }

        if let power = pickedPower {
            activate(power, ballX: ballX, ballY: ballY, roadLeft: roadLeft, roadWidth: roadWidth, world: world)
        }

        if let bonkPoint, let bonkKind {
            handleBonk(kind: bonkKind, at: bonkPoint, ballX: ballX, ballY: ballY)
        }

        if abs(tilt) > 5 {
            trail.append(CGPoint(x: ballX, y: ballY))
            if trail.count > 7 { trail.removeFirst(trail.count - 7) }
        } else if !trail.isEmpty {
            trail.removeFirst()
        }

        if stars >= level.goal && phase == .playing {
            finishLevel()
        }
    }

    private func award(_ count: Int, at point: CGPoint) {
        stars += count
        if stars >= nextConfettiAt {
            nextConfettiAt = ((stars / 5) + 1) * 5
            addConfetti(at: point)
        }
    }

    private func pullStars(world: Double, roadLeft: CGFloat, roadWidth: CGFloat, ballX: CGFloat, ballY: CGFloat) {
        for index in items.indices where items[index].kind.isStar {
            let x = itemX(items[index], world: world, roadLeft: roadLeft, roadWidth: roadWidth)
            let y = itemY(items[index], world: world)
            guard y > -60, hypot(x - ballX, y - ballY) < 240 else { continue }
            items[index].xFrac += ((ballX - x) / roadWidth) * 0.17
            if y < ballY { items[index].yBoost += min(8, (ballY - y) * 0.1) }
        }
    }

    private func handleBonk(kind: BallRunObstacle, at point: CGPoint, ballX: CGFloat, ballY: CGFloat) {
        if activePower == .shield {
            clearPower()
            Sfx.pop()
            Sfx.bump(.light)
            addEffect(3, at: CGPoint(x: ballX, y: ballY))
            return
        }

        Sfx.tap()
        Sfx.bump(.medium)
        if kind == .mud {
            ToneEngine.shared.playSplash()
            addEffect(2, at: CGPoint(x: ballX, y: ballY))
        } else {
            addEffect(1, at: CGPoint(x: point.x, y: point.y + 12))
        }

        hearts = max(0, hearts - 1)
        safeUntil = Date.now.addingTimeInterval(1.5)
        ballOpacity = 1
        withAnimation(.easeInOut(duration: 0.15).repeatCount(10, autoreverses: true)) {
            ballOpacity = 0.3
        }
        withAnimation(.spring(response: 0.12, dampingFraction: 0.25)) {
            wobble = true
            shake = CGSize(width: .random(in: -5...5), height: .random(in: -4...4))
        }
        let empty = hearts == 0
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.28))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                wobble = false
                shake = .zero
            }
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeOut(duration: 0.2)) { ballOpacity = 1 }
        }
        if empty {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                if phase == .playing { outOfHearts() }
            }
        }
    }

    // MARK: Spawning

    private func spawnStep(world: Double) {
        guard world >= nextSpawnWorld else { return }
        let speed = level.speed
        let roll = Int.random(in: 0..<100)
        var gap = level.gap

        if roll < 9 {
            let power = BallRunPower.allCases.randomElement() ?? .shield
            items.append(makeItem(.power(power), x: .random(in: 0.2...0.8), world: world, speed: speed))
            gap = level.gap * 1.3
        } else if roll < 27 {
            spawnStarRow(world: world, speed: speed)
            gap = level.gap * 1.9
        } else if roll < 39 {
            spawnFriends(world: world, speed: speed)
            gap = level.gap * 1.7
        } else if roll < 68 {
            items.append(makeItem(.star, x: .random(in: 0.1...0.9), world: world, speed: speed))
        } else {
            spawnObstacles(world: world, speed: speed)
        }

        nextSpawnWorld = world + gap
    }

    private func spawnStarRow(world: Double, speed: CGFloat) {
        let count = 6
        let arc = Bool.random()
        let flip: CGFloat = Bool.random() ? 1 : -1
        for i in 0..<count {
            let t = CGFloat(i) / CGFloat(count - 1)
            let frac: CGFloat = arc
                ? 0.5 + flip * sin(t * .pi) * 0.34
                : 0.5 + flip * (i.isMultiple(of: 2) ? 0.3 : -0.3)
            items.append(makeItem(.star, x: frac, world: world + Double(i) * 0.26, speed: speed))
        }
    }

    private func spawnFriends(world: Double, speed: CGFloat) {
        if Bool.random() {
            let base = CGFloat.random(in: 0.25...0.75)
            for i in 0..<3 {
                items.append(makeItem(
                    .friend(.duckling),
                    x: min(max(base + CGFloat(i) * 0.08, 0.08), 0.92),
                    world: world + Double(i) * 0.3,
                    speed: speed
                ))
            }
        } else {
            items.append(makeItem(.friend(.bouncy), x: .random(in: 0.3...0.7), world: world, speed: speed))
        }
    }

    private func spawnObstacles(world: Double, speed: CGFloat) {
        let kind = level.obstacles.randomElement() ?? .cone
        let x = CGFloat.random(in: 0.12...0.88)
        items.append(makeItem(.obstacle(kind), x: x, world: world, speed: speed))
        // From level five on there is sometimes a second one, always with a
        // wide open lane between them.
        if levelIndex >= 4, Bool.random() {
            let other = level.obstacles.randomElement() ?? .rock
            let far = x < 0.5 ? CGFloat.random(in: 0.72...0.9) : CGFloat.random(in: 0.1...0.28)
            items.append(makeItem(.obstacle(other), x: far, world: world + 0.35, speed: speed))
        }
    }

    private func makeItem(_ kind: BallRunItemKind, x: CGFloat, world: Double, speed: CGFloat) -> BallRunItem {
        BallRunItem(
            xFrac: min(max(x, 0.06), 0.94),
            kind: kind,
            bornWorld: world,
            speed: speed,
            seed: .random(in: 0...6.28)
        )
    }

    // MARK: Effects

    private func addEffect(_ kind: Int, at point: CGPoint) {
        guard effects.count < 12 else { return }
        let effect = BallRunEffect(point: point, kind: kind)
        effects.append(effect)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            effects.removeAll { $0.id == effect.id }
        }
    }

    private func addConfetti(at point: CGPoint) {
        guard confetti.count < 3 else { return }
        let item = BallRunEffect(point: point, kind: 0)
        confetti.append(item)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.7))
            confetti.removeAll { $0.id == item.id }
        }
    }

    private static func makeDecorations() -> [BallRunDecor] {
        (0..<16).map { i in
            BallRunDecor(
                leftSide: i.isMultiple(of: 2),
                acrossFrac: .random(in: 0.18...0.82),
                ySeed: CGFloat(i) / 16 + .random(in: -0.03...0.03),
                second: Bool.random(),
                scale: .random(in: 0.75...1.15)
            )
        }
    }
}

// MARK: - Start screen

struct BallRunStartScreen: View {
    let topLevel: Int
    let bestStars: Int
    let onPlay: () -> Void
    let onPick: (Int) -> Void
    let onClose: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 74), spacing: 14)]

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    CloseButton(action: onClose)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                ScrollView {
                    VStack(spacing: 20) {
                        BallRunTitleArt()
                            .padding(.top, 4)

                        Text("Ball Run")
                            .font(.rounded(34))
                            .foregroundStyle(Palette.ink)

                        HStack(spacing: 12) {
                            StarChip(count: topLevel, symbol: "flag.fill", color: Palette.green, label: "Level")
                            StarChip(count: bestStars, color: Palette.yellow, label: "Best")
                        }

                        Button {
                            Sfx.tap()
                            Sfx.bump(.light)
                            onPlay()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                Text("Play")
                            }
                            .font(.rounded(26))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 52)
                            .padding(.vertical, 20)
                            .background(Palette.green, in: Capsule())
                        }
                        .buttonStyle(BouncyButtonStyle())

                        Text("Pick a level")
                            .font(.rounded(18, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(Array(BallRunLevels.all.enumerated()), id: \.offset) { index, level in
                                BallRunLevelTile(
                                    number: index + 1,
                                    name: level.name,
                                    tint: level.theme.accent,
                                    unlocked: index < topLevel
                                ) {
                                    onPick(index)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

/// A rolling ball on a small stretch of road, just for the start screen.
struct BallRunTitleArt: View {
    @State private var roll = false

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.80, green: 0.79, blue: 0.76))
                .frame(width: 210, height: 26)
                .offset(y: 30)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Palette.green.opacity(0.8), Palette.green],
                        center: .topLeading, startRadius: 4, endRadius: 40
                    )
                )
                .frame(width: 62, height: 62)
                .overlay(Circle().stroke(.white, lineWidth: 5))
                .rotationEffect(.degrees(roll ? 360 : 0))
                .offset(x: roll ? 58 : -58)
        }
        .frame(height: 96)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                roll = true
            }
        }
    }
}

struct BallRunLevelTile: View {
    let number: Int
    let name: String
    let tint: Color
    let unlocked: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Sfx.tap()
            Sfx.bump(.light)
            action()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(unlocked ? tint : Palette.field)
                        .frame(width: 58, height: 58)
                    if unlocked {
                        Text("\(number)")
                            .font(.rounded(26))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                Text(unlocked ? name : "Soon")
                    .font(.rounded(13, weight: .semibold))
                    .foregroundStyle(unlocked ? Palette.ink : Palette.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .card(cornerRadius: 20)
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(!unlocked)
    }
}

// MARK: - Heads up pieces

struct BallRunHearts: View {
    let hearts: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(index < hearts ? Palette.red : Palette.field)
                    .scaleEffect(index < hearts ? 1 : 0.82)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: hearts)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .card(cornerRadius: 18)
    }
}

/// Round badge for the power that is running, with a ring that empties.
struct BallRunPowerRing: View {
    let power: BallRunPower
    let progress: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.card)
                .frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            Circle()
                .stroke(power.tint.opacity(0.18), lineWidth: 5)
                .frame(width: 42, height: 42)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(power.tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 42, height: 42)
                .rotationEffect(.degrees(-90))
            Image(systemName: power.symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(power.tint)
        }
    }
}

/// Slim bar showing how close the level goal is.
struct BallRunGoalBar: View {
    let title: String
    let stars: Int
    let goal: Int
    let tint: Color

    var body: some View {
        let fraction = min(CGFloat(stars) / CGFloat(max(goal, 1)), 1)
        VStack(spacing: 4) {
            Text(title)
                .font(.rounded(17))
                .foregroundStyle(Palette.ink)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.75))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(geo.size.width * fraction, fraction > 0 ? 14 : 0))
                }
            }
            .frame(height: 14)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: stars)

            Text("\(min(stars, goal)) of \(goal) stars")
                .font(.rounded(13, weight: .semibold))
                .foregroundStyle(Palette.ink.opacity(0.75))
        }
    }
}

// MARK: - Obstacles

struct BallRunObstacleView: View {
    let kind: BallRunObstacle
    var spin: Double = 0

    var body: some View {
        switch kind {
        case .cone:
            ZStack {
                BallRunTriangle()
                    .fill(Palette.orange)
                    .frame(width: 42, height: 48)
                Rectangle()
                    .fill(.white)
                    .frame(width: 30, height: 7)
                    .offset(y: 4)
            }
            .frame(width: 48, height: 48)
        case .rock:
            ZStack {
                Circle().fill(Color(red: 0.55, green: 0.55, blue: 0.58)).frame(width: 26).offset(x: -10, y: 4)
                Circle().fill(Color(red: 0.63, green: 0.63, blue: 0.66)).frame(width: 32).offset(y: -2)
                Circle().fill(Color(red: 0.50, green: 0.50, blue: 0.53)).frame(width: 24).offset(x: 12, y: 5)
            }
            .frame(width: 50, height: 44)
        case .log:
            Capsule()
                .fill(Palette.brown)
                .frame(width: 60, height: 26)
                .overlay(
                    Ellipse()
                        .fill(Palette.brown.opacity(0.55))
                        .frame(width: 12, height: 20)
                        .offset(x: 22)
                )
                .overlay(
                    Capsule()
                        .fill(.white.opacity(0.16))
                        .frame(width: 34, height: 5)
                        .offset(y: -6)
                )
        case .hay:
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.88, green: 0.76, blue: 0.44))
                    .frame(width: 56, height: 40)
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(Color(red: 0.78, green: 0.64, blue: 0.34).opacity(0.8))
                        .frame(width: 46, height: 4)
                        .offset(y: CGFloat(i - 1) * 11)
                }
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.72, green: 0.58, blue: 0.30), lineWidth: 3)
                    .frame(width: 56, height: 40)
            }
        case .mud:
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.48, green: 0.36, blue: 0.26).opacity(0.75))
                    .frame(width: 86, height: 40)
                Ellipse()
                    .fill(Color(red: 0.38, green: 0.28, blue: 0.20).opacity(0.7))
                    .frame(width: 54, height: 22)
                    .offset(x: -8, y: -3)
                Circle()
                    .fill(Color(red: 0.44, green: 0.33, blue: 0.23))
                    .frame(width: 14)
                    .offset(x: 30, y: 8)
            }
        case .tumbleweed:
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(Color(red: 0.70, green: 0.58, blue: 0.34).opacity(0.85))
                        .frame(width: 46, height: 6)
                        .rotationEffect(.degrees(Double(i) / 5 * 180))
                }
                Circle()
                    .stroke(Color(red: 0.62, green: 0.50, blue: 0.28).opacity(0.7), lineWidth: 4)
                    .frame(width: 40, height: 40)
            }
            .frame(width: 50, height: 50)
            .rotationEffect(.degrees(spin))
        }
    }
}

// MARK: - Friendly characters

struct BallRunFriendView: View {
    let friend: BallRunFriend

    var body: some View {
        switch friend {
        case .duckling:
            ZStack {
                Ellipse()
                    .fill(Palette.yellow)
                    .frame(width: 38, height: 28)
                Circle()
                    .fill(Palette.yellow)
                    .frame(width: 22, height: 22)
                    .offset(x: 12, y: -14)
                BallRunTriangle()
                    .fill(Palette.orange)
                    .frame(width: 12, height: 9)
                    .rotationEffect(.degrees(90))
                    .offset(x: 25, y: -12)
                Circle()
                    .fill(Palette.ink)
                    .frame(width: 4, height: 4)
                    .offset(x: 15, y: -17)
                Ellipse()
                    .fill(.white.opacity(0.55))
                    .frame(width: 18, height: 12)
                    .offset(x: -4, y: 1)
            }
            .frame(width: 52, height: 48)
        case .bouncy:
            ZStack {
                Circle()
                    .fill(Palette.pink)
                    .frame(width: 44, height: 44)
                Capsule()
                    .fill(.white)
                    .frame(width: 44, height: 11)
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .fill(.white.opacity(0.55))
                    .frame(width: 10, height: 10)
                    .offset(x: -10, y: -12)
            }
        }
    }
}

// MARK: - Power tokens

struct BallRunPowerToken: View {
    let power: BallRunPower

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: 54, height: 54)
                .shadow(color: power.tint.opacity(0.35), radius: 6, y: 2)
            Circle()
                .stroke(power.tint.opacity(0.5), lineWidth: 3)
                .frame(width: 54, height: 54)
            art
        }
        .frame(width: 58, height: 58)
    }

    @ViewBuilder
    private var art: some View {
        switch power {
        case .magnet:
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Palette.red, style: StrokeStyle(lineWidth: 10))
                    .frame(width: 28, height: 28)
                Capsule()
                    .fill(Color(red: 0.62, green: 0.63, blue: 0.66))
                    .frame(width: 10, height: 12)
                    .offset(x: -14, y: -6)
                Capsule()
                    .fill(Color(red: 0.62, green: 0.63, blue: 0.66))
                    .frame(width: 10, height: 12)
                    .offset(x: 14, y: -6)
            }
            .frame(width: 40, height: 34)
        case .shield:
            ZStack {
                Circle()
                    .fill(Palette.blue.opacity(0.22))
                    .frame(width: 32, height: 32)
                Circle()
                    .stroke(Palette.blue, lineWidth: 3.5)
                    .frame(width: 32, height: 32)
                Circle()
                    .trim(from: 0.58, to: 0.8)
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 32, height: 32)
            }
        case .slow:
            ZStack {
                Ellipse()
                    .fill(Palette.teal.opacity(0.55))
                    .frame(width: 34, height: 13)
                    .offset(x: -3, y: 9)
                Circle()
                    .fill(Palette.teal.opacity(0.25))
                    .frame(width: 26, height: 26)
                    .offset(x: 2, y: -1)
                Circle()
                    .stroke(Palette.teal, lineWidth: 3)
                    .frame(width: 26, height: 26)
                    .offset(x: 2, y: -1)
                Circle()
                    .stroke(Palette.teal, lineWidth: 3)
                    .frame(width: 13, height: 13)
                    .offset(x: 2, y: -1)
                Capsule()
                    .fill(Palette.teal)
                    .frame(width: 5, height: 11)
                    .offset(x: -17, y: 2)
            }
            .frame(width: 42, height: 34)
        case .burst:
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Capsule()
                        .fill(Palette.yellow.opacity(0.55))
                        .frame(width: 4, height: 10)
                        .offset(y: -18)
                        .rotationEffect(.degrees(Double(i) / 8 * 360))
                }
                StarShape()
                    .fill(Palette.yellow)
                    .frame(width: 26, height: 26)
            }
            .frame(width: 44, height: 44)
        }
    }
}

// MARK: - Scenery

struct BallRunSceneryView: View {
    let kind: BallRunScenery
    let accent: Color

    var body: some View {
        switch kind {
        case .flower: flower
        case .bush: bush
        case .palm: palm
        case .shell: shell
        case .snowyPine: snowyPine
        case .snowman: snowman
        case .tree: tree
        case .mushroom: mushroom
        case .lamp: lamp
        case .nightStar: nightStar
        case .cactus: cactus
        case .desertRock: desertRock
        case .lollipop: lollipop
        case .candyCane: candyCane
        case .planet: planet
        case .rocket: rocket
        }
    }

    private var flower: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.34, green: 0.52, blue: 0.34))
                .frame(width: 3, height: 16)
                .offset(y: 11)
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(Palette.pink.opacity(0.9))
                    .frame(width: 9, height: 9)
                    .offset(y: -8)
                    .rotationEffect(.degrees(Double(i) / 5 * 360))
            }
            Circle().fill(Palette.yellow).frame(width: 7, height: 7)
        }
        .frame(width: 28, height: 34)
    }

    private var bush: some View {
        ZStack {
            Circle().fill(Color(red: 0.30, green: 0.50, blue: 0.34).opacity(0.75)).frame(width: 24).offset(x: -10, y: 4)
            Circle().fill(Color(red: 0.34, green: 0.56, blue: 0.37).opacity(0.85)).frame(width: 30).offset(y: -2)
            Circle().fill(Color(red: 0.30, green: 0.50, blue: 0.34).opacity(0.75)).frame(width: 22).offset(x: 11, y: 5)
        }
        .frame(width: 46, height: 34)
    }

    private var palm: some View {
        ZStack {
            Capsule()
                .fill(Palette.brown)
                .frame(width: 7, height: 30)
                .offset(y: 12)
            ForEach(0..<5, id: \.self) { i in
                Ellipse()
                    .fill(Color(red: 0.32, green: 0.60, blue: 0.42))
                    .frame(width: 26, height: 11)
                    .offset(x: 12)
                    .rotationEffect(.degrees(Double(i) / 5 * 360 - 90))
            }
            .offset(y: -8)
        }
        .frame(width: 52, height: 56)
    }

    private var shell: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(Palette.pink.opacity(0.75))
                    .frame(width: 7, height: 24)
                    .offset(y: -6)
                    .rotationEffect(.degrees(Double(i - 2) * 17 + 8))
            }
            Circle()
                .fill(Palette.pink.opacity(0.9))
                .frame(width: 12, height: 12)
                .offset(y: 7)
        }
        .frame(width: 38, height: 34)
    }

    private var snowyPine: some View {
        ZStack {
            Capsule().fill(Palette.brown).frame(width: 6, height: 12).offset(y: 20)
            BallRunTriangle().fill(Color(red: 0.26, green: 0.48, blue: 0.40)).frame(width: 34, height: 26).offset(y: 6)
            BallRunTriangle().fill(Color(red: 0.30, green: 0.54, blue: 0.44)).frame(width: 26, height: 22).offset(y: -8)
            BallRunTriangle().fill(.white.opacity(0.85)).frame(width: 12, height: 10).offset(y: -14)
        }
        .frame(width: 40, height: 54)
    }

    private var snowman: some View {
        ZStack {
            Circle().fill(.white).frame(width: 26).offset(y: 10)
            Circle().fill(.white).frame(width: 18).offset(y: -6)
            Circle().fill(Palette.ink).frame(width: 3).offset(x: -4, y: -8)
            Circle().fill(Palette.ink).frame(width: 3).offset(x: 3, y: -8)
            BallRunTriangle()
                .fill(Palette.orange)
                .frame(width: 9, height: 7)
                .rotationEffect(.degrees(90))
                .offset(x: 6, y: -4)
        }
        .frame(width: 34, height: 46)
    }

    private var tree: some View {
        ZStack {
            Capsule().fill(Palette.brown).frame(width: 8, height: 18).offset(y: 20)
            Circle().fill(Color(red: 0.24, green: 0.48, blue: 0.32)).frame(width: 26).offset(x: -9, y: 2)
            Circle().fill(Color(red: 0.28, green: 0.54, blue: 0.36)).frame(width: 32).offset(y: -8)
            Circle().fill(Color(red: 0.24, green: 0.48, blue: 0.32)).frame(width: 24).offset(x: 10, y: 2)
        }
        .frame(width: 50, height: 56)
    }

    private var mushroom: some View {
        ZStack {
            Capsule().fill(Color(red: 0.94, green: 0.91, blue: 0.85)).frame(width: 10, height: 16).offset(y: 10)
            Circle()
                .fill(Palette.red)
                .frame(width: 30, height: 30)
                .offset(y: -4)
                .mask {
                    Rectangle().frame(width: 34, height: 17).offset(y: -12)
                }
            Circle().fill(.white.opacity(0.9)).frame(width: 6).offset(x: -6, y: -12)
            Circle().fill(.white.opacity(0.9)).frame(width: 5).offset(x: 5, y: -9)
        }
        .frame(width: 34, height: 34)
    }

    private var lamp: some View {
        ZStack {
            Capsule().fill(Color(red: 0.42, green: 0.44, blue: 0.58)).frame(width: 5, height: 34).offset(y: 12)
            Circle().fill(Palette.yellow.opacity(0.35)).frame(width: 34).offset(y: -12)
            Circle().fill(Palette.yellow).frame(width: 16).offset(y: -12)
        }
        .frame(width: 38, height: 56)
    }

    private var nightStar: some View {
        ZStack {
            StarShape().fill(Palette.yellow.opacity(0.9)).frame(width: 22, height: 22)
            StarShape().fill(.white.opacity(0.5)).frame(width: 10, height: 10)
        }
        .frame(width: 30, height: 30)
    }

    private var cactus: some View {
        ZStack {
            Capsule().fill(Color(red: 0.34, green: 0.58, blue: 0.42)).frame(width: 15, height: 44)
            Capsule().fill(Color(red: 0.34, green: 0.58, blue: 0.42)).frame(width: 10, height: 20).offset(x: -12, y: -4)
            Capsule().fill(Color(red: 0.34, green: 0.58, blue: 0.42)).frame(width: 9, height: 9).offset(x: -12, y: -13)
            Capsule().fill(Color(red: 0.34, green: 0.58, blue: 0.42)).frame(width: 10, height: 16).offset(x: 12, y: 2)
            Capsule().fill(Color(red: 0.34, green: 0.58, blue: 0.42)).frame(width: 9, height: 9).offset(x: 12, y: -5)
        }
        .frame(width: 42, height: 52)
    }

    private var desertRock: some View {
        ZStack {
            Ellipse().fill(Color(red: 0.76, green: 0.62, blue: 0.46)).frame(width: 40, height: 22).offset(y: 8)
            Ellipse().fill(Color(red: 0.82, green: 0.68, blue: 0.50)).frame(width: 28, height: 18).offset(y: -3)
            Ellipse().fill(Color(red: 0.88, green: 0.74, blue: 0.56)).frame(width: 16, height: 11).offset(y: -12)
        }
        .frame(width: 44, height: 40)
    }

    private var lollipop: some View {
        ZStack {
            Capsule().fill(.white).frame(width: 5, height: 22).offset(y: 15)
            Circle().fill(Palette.pink).frame(width: 26)
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 15, height: 15)
            Circle().stroke(Palette.pink.opacity(0.6), lineWidth: 3).frame(width: 26)
        }
        .frame(width: 34, height: 48)
    }

    private var candyCane: some View {
        ZStack {
            Capsule().fill(.white).frame(width: 10, height: 34).offset(y: 8)
            Circle()
                .trim(from: 0.5, to: 1)
                .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 20, height: 20)
                .offset(x: 5, y: -9)
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Palette.red.opacity(0.85))
                    .frame(width: 10, height: 5)
                    .offset(y: CGFloat(i) * 11 - 2)
            }
        }
        .frame(width: 34, height: 50)
    }

    private var planet: some View {
        ZStack {
            Ellipse()
                .stroke(Palette.yellow.opacity(0.8), lineWidth: 4)
                .frame(width: 46, height: 16)
                .rotationEffect(.degrees(-18))
            Circle().fill(Palette.purple.opacity(0.85)).frame(width: 26)
            Circle().fill(.white.opacity(0.3)).frame(width: 8).offset(x: -5, y: -6)
        }
        .frame(width: 50, height: 40)
    }

    private var rocket: some View {
        ZStack {
            Capsule().fill(.white).frame(width: 18, height: 38)
            BallRunTriangle().fill(Palette.red).frame(width: 18, height: 14).offset(y: -22)
            Circle().fill(Palette.blue.opacity(0.7)).frame(width: 10).offset(y: -6)
            BallRunTriangle()
                .fill(Palette.red.opacity(0.9))
                .frame(width: 10, height: 12)
                .rotationEffect(.degrees(180))
                .offset(x: -12, y: 15)
            BallRunTriangle()
                .fill(Palette.red.opacity(0.9))
                .frame(width: 10, height: 12)
                .rotationEffect(.degrees(180))
                .offset(x: 12, y: 15)
        }
        .frame(width: 42, height: 58)
    }
}

// MARK: - Effects

struct BallRunEffectView: View {
    let kind: Int

    var body: some View {
        switch kind {
        case 0: BallRunSparkle()
        case 2: BallRunSplash()
        case 3: BallRunShieldPop()
        default: BallRunDust()
        }
    }
}

/// A star that swells and fades with four tiny sparks when it is collected.
struct BallRunSparkle: View {
    @State private var out = false

    var body: some View {
        ZStack {
            Image(systemName: "star.fill")
                .font(.system(size: 34))
                .foregroundStyle(Palette.yellow)
                .scaleEffect(out ? 1.9 : 1)
                .opacity(out ? 0 : 1)

            ForEach(0..<4, id: \.self) { i in
                let angle = Double(i) / 4 * .pi * 2 + .pi / 4
                Circle()
                    .fill(Palette.yellow)
                    .frame(width: 7, height: 7)
                    .offset(x: out ? cos(angle) * 34 : 0, y: out ? sin(angle) * 34 : 0)
                    .opacity(out ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { out = true } }
    }
}

/// Three small dust puffs for a friendly bonk.
struct BallRunDust: View {
    @State private var out = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let dx: CGFloat = [-26, 0, 26][i]
                Circle()
                    .fill(Color(red: 0.78, green: 0.75, blue: 0.70).opacity(0.85))
                    .frame(width: 16, height: 16)
                    .scaleEffect(out ? 1.8 : 0.4)
                    .offset(x: out ? dx : 0, y: out ? -14 : 0)
                    .opacity(out ? 0 : 0.9)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.45)) { out = true } }
    }
}

/// Droplets kicked up by rolling through the mud.
struct BallRunSplash: View {
    @State private var out = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) / 6 * .pi * 2
                Ellipse()
                    .fill(Color(red: 0.48, green: 0.36, blue: 0.26).opacity(0.65))
                    .frame(width: 8, height: 11)
                    .offset(x: out ? cos(angle) * 42 : 0, y: out ? sin(angle) * 30 + 10 : 0)
                    .opacity(out ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.55)) { out = true } }
    }
}

/// The bubble popping when a shield takes a hit.
struct BallRunShieldPop: View {
    @State private var out = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.blue.opacity(0.65), lineWidth: 5)
                .frame(width: 76, height: 76)
                .scaleEffect(out ? 1.6 : 0.7)
                .opacity(out ? 0 : 1)
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) / 6 * .pi * 2
                Circle()
                    .fill(Palette.blue.opacity(0.5))
                    .frame(width: 9, height: 9)
                    .offset(x: out ? cos(angle) * 54 : 0, y: out ? sin(angle) * 54 : 0)
                    .opacity(out ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { out = true } }
    }
}

// MARK: - Shapes

/// Simple upward triangle used by cones, trees and beaks.
struct BallRunTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
