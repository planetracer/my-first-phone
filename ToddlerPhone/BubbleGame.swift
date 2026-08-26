import SwiftUI

// MARK: - Bubbles (pure calm sensory play, no score and no timer)

/// One drifting bubble. Motion is worked out from the clock, so nothing here
/// is written every frame.
struct BubbleItem: Identifiable {
    let id = UUID()
    let birth: Double
    let x0: CGFloat
    let y0: CGFloat
    let radius: CGFloat
    let speed: CGFloat
    let wobble: CGFloat
    let wobbleRate: Double
    let phase: Double
    let tint: Color
    let isRainbow: Bool
    let animal: String?

    var symbol: String? {
        switch animal {
        case "dog": return "dog.fill"
        case "cat": return "cat.fill"
        case "bird": return "bird.fill"
        default: return nil
        }
    }
}

struct BubblePop: Identifiable {
    let id = UUID()
    let point: CGPoint
    let radius: CGFloat
    let tint: Color
}

struct BubbleView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var bubbles: [BubbleItem] = []
    @State private var pops: [BubblePop] = []
    @State private var combo = 0
    @State private var lastPop = Date.distantPast
    @State private var wandPoint: CGPoint = .zero
    @State private var isWanding = false
    @State private var underwater = false
    @State private var screen: CGSize = .zero
    @State private var start = Date.now
    @State private var loop: Task<Void, Never>?

    private static let maxBubbles = 22
    private static let maxPops = 6
    private static let animals = ["dog", "cat", "bird"]
    private static let tints: [Color] = [
        Palette.blue, Palette.teal, Palette.pink, Palette.purple, Palette.green,
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                sky
                underwaterScene.opacity(underwater ? 1 : 0)

                TimelineView(.animation) { timeline in
                    let now = timeline.date.timeIntervalSince(start)
                    ZStack {
                        ForEach(bubbles) { bubble in
                            let point = position(bubble, at: now)
                            BubbleArt(bubble: bubble)
                                .frame(width: bubble.radius * 2, height: bubble.radius * 2)
                                .padding(14)
                                .contentShape(Circle())
                                .position(point)
                                .onTapGesture { pop(bubble, at: point) }
                        }
                    }
                }

                ForEach(pops) { item in
                    BubblePopBurst(radius: item.radius, tint: item.tint)
                        .position(item.point)
                }

                wand

                VStack(spacing: 8) {
                    GameTopBar(title: "Bubbles") { close() }

                    Text("Tap the bubbles or drag the wand")
                        .font(.rounded(15, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)

                    if combo >= 2 {
                        comboChip
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer(minLength: 0)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: "bubbles")
            .onAppear {
                screen = geo.size
                if wandPoint == .zero {
                    wandPoint = CGPoint(x: geo.size.width / 2, y: geo.size.height - 110)
                }
                startLoop()
            }
            .onDisappear { loop?.cancel() }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Backgrounds

    private var sky: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.80, green: 0.90, blue: 0.98),
                    Color(red: 0.95, green: 0.96, blue: 0.92),
                ],
                startPoint: .top, endPoint: .bottom
            )

            Circle()
                .fill(Palette.yellow.opacity(0.28))
                .frame(width: 150, height: 150)
                .offset(x: 110, y: -240)

            cloud(width: 150).offset(x: -90, y: -160)
            cloud(width: 110).offset(x: 120, y: -40)
            cloud(width: 130).offset(x: -60, y: 120)
        }
        .ignoresSafeArea()
    }

    private var underwaterScene: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.92, blue: 0.93),
                    Color(red: 0.86, green: 0.94, blue: 0.90),
                ],
                startPoint: .top, endPoint: .bottom
            )

            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(width: 90, height: 520)
                    .rotationEffect(.degrees(18))
                    .offset(x: CGFloat(i) * 130 - 130, y: -120)
            }

            VStack {
                Spacer()
                ZStack(alignment: .bottom) {
                    Ellipse()
                        .fill(Color(red: 0.95, green: 0.92, blue: 0.82))
                        .frame(height: 130)
                        .offset(y: 40)

                    HStack(alignment: .bottom, spacing: 26) {
                        seaweed(height: 120, tint: Palette.green.opacity(0.35))
                        seaweed(height: 78, tint: Palette.teal.opacity(0.35))
                        seaweed(height: 104, tint: Palette.green.opacity(0.28))
                    }
                    .offset(y: -6)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func cloud(width: CGFloat) -> some View {
        ZStack {
            Capsule().fill(.white.opacity(0.7)).frame(width: width, height: width * 0.34)
            Circle().fill(.white.opacity(0.7)).frame(width: width * 0.5, height: width * 0.5)
                .offset(x: -width * 0.16, y: -width * 0.12)
            Circle().fill(.white.opacity(0.7)).frame(width: width * 0.38, height: width * 0.38)
                .offset(x: width * 0.2, y: -width * 0.1)
        }
    }

    private func seaweed(height: CGFloat, tint: Color) -> some View {
        VStack(spacing: -height * 0.12) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(tint)
                    .frame(width: 16, height: height / 2.2)
                    .rotationEffect(.degrees(i.isMultiple(of: 2) ? 9 : -9))
            }
        }
    }

    // MARK: Wand

    private var wand: some View {
        ZStack {
            Capsule()
                .fill(Palette.brown.opacity(0.85))
                .frame(width: 13, height: 78)
                .offset(y: 40)

            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Palette.pink.opacity(0.30), Palette.blue.opacity(0.30),
                            Palette.green.opacity(0.30), Palette.yellow.opacity(0.30),
                            Palette.pink.opacity(0.30),
                        ],
                        center: .center
                    )
                )
                .frame(width: 58, height: 58)
                .offset(y: -24)

            Circle()
                .strokeBorder(.white.opacity(0.95), lineWidth: 7)
                .frame(width: 62, height: 62)
                .offset(y: -24)
        }
        .frame(width: 96, height: 140)
        .contentShape(Rectangle())
        .scaleEffect(isWanding ? 1.08 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isWanding)
        .position(wandPoint)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("bubbles"))
                .onChanged { value in
                    if !isWanding {
                        isWanding = true
                        Sfx.bump(.light)
                    }
                    wandPoint = value.location
                }
                .onEnded { _ in isWanding = false }
        )
    }

    private var comboChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles").foregroundStyle(Palette.teal)
            Text("\(combo) in a row")
                .foregroundStyle(Palette.ink)
        }
        .font(.rounded(18))
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .card(cornerRadius: 16)
    }

    // MARK: Motion

    private func position(_ bubble: BubbleItem, at time: Double) -> CGPoint {
        let age = time - bubble.birth
        return CGPoint(
            x: bubble.x0 + bubble.wobble * CGFloat(sin(bubble.wobbleRate * age + bubble.phase)),
            y: bubble.y0 - CGFloat(age) * bubble.speed
        )
    }

    // MARK: Loop

    private func startLoop() {
        loop?.cancel()
        loop = Task { @MainActor in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.2))
                if Task.isCancelled { break }
                tick += 1
                let now = Date.now.timeIntervalSince(start)

                bubbles.removeAll { position($0, at: now).y < -($0.radius + 60) }

                if isWanding {
                    spawn(at: CGPoint(x: wandPoint.x + .random(in: -16...16), y: wandPoint.y - 24),
                          radius: .random(in: 14...34))
                } else if tick % 3 == 0 {
                    spawnFromBottom()
                }

                if combo > 0, Date.now.timeIntervalSince(lastPop) > 1.6 {
                    withAnimation(.easeOut(duration: 0.3)) { combo = 0 }
                }

                if tick % 95 == 0 {
                    withAnimation(.easeInOut(duration: 6)) { underwater.toggle() }
                }
            }
        }
    }

    private func spawnFromBottom() {
        guard screen.width > 0 else { return }
        spawn(
            at: CGPoint(x: .random(in: 34...(max(70, screen.width - 34))), y: screen.height + 50),
            radius: .random(in: 18...54)
        )
    }

    @discardableResult
    private func spawn(at point: CGPoint, radius: CGFloat, tiny: Bool = false) -> Bool {
        guard bubbles.count < Self.maxBubbles else { return false }
        let roll = Int.random(in: 0..<24)
        let rainbow = !tiny && roll == 0
        let animal = (!tiny && roll == 1) ? Self.animals.randomElement() : nil

        bubbles.append(
            BubbleItem(
                birth: Date.now.timeIntervalSince(start),
                x0: point.x,
                y0: point.y,
                radius: animal != nil ? max(radius, 42) : radius,
                speed: tiny ? .random(in: 60...110) : .random(in: 26...58),
                wobble: .random(in: 8...26),
                wobbleRate: .random(in: 0.7...1.6),
                phase: .random(in: 0...(2 * .pi)),
                tint: Self.tints.randomElement() ?? Palette.blue,
                isRainbow: rainbow,
                animal: animal
            )
        )
        return true
    }

    // MARK: Popping

    private func pop(_ bubble: BubbleItem, at point: CGPoint) {
        bubbles.removeAll { $0.id == bubble.id }
        Sfx.pop()
        Sfx.bump(.light)

        pops.append(BubblePop(point: point, radius: bubble.radius, tint: bubble.tint))
        if pops.count > Self.maxPops { pops.removeFirst() }
        let popID = pops.last?.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            pops.removeAll { $0.id == popID }
        }

        if bubble.isRainbow {
            for i in 0..<8 {
                let angle = Double(i) / 8 * 2 * .pi
                spawn(
                    at: CGPoint(
                        x: point.x + CGFloat(cos(angle)) * bubble.radius * 0.8,
                        y: point.y + CGFloat(sin(angle)) * bubble.radius * 0.8
                    ),
                    radius: .random(in: 12...20),
                    tiny: true
                )
            }
        }

        if let animal = bubble.animal {
            SoundFile.shared.play(animal)
        }

        let now = Date.now
        let quick = now.timeIntervalSince(lastPop) < 1.0
        lastPop = now
        withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
            combo = quick ? combo + 1 : 1
        }

        switch combo {
        case 5: Speaker.shared.cheer("Wow, so many bubbles!")
        case 10: Speaker.shared.cheer("You are a bubble popping star!")
        case 20: Speaker.shared.cheer("Amazing popping!")
        default: break
        }
    }

    private func close() {
        loop?.cancel()
        Speaker.shared.stop()
        dismiss()
    }
}

// MARK: - Art

/// Soft translucent bubble with a light rim, a highlight and a faint sheen.
private struct BubbleArt: View {
    let bubble: BubbleItem

    /// Plain shapes only, no blur, so twenty bubbles can drift at once.
    var body: some View {
        let size = bubble.radius * 2
        let sheen = bubble.isRainbow ? 0.40 : 0.18

        return ZStack {
            Circle()
                .fill(bubble.tint.opacity(bubble.isRainbow ? 0.16 : 0.10))

            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Palette.pink.opacity(sheen),
                            Palette.yellow.opacity(sheen * 0.9),
                            Palette.green.opacity(sheen * 0.9),
                            Palette.blue.opacity(sheen),
                            Palette.pink.opacity(sheen),
                        ],
                        center: .center
                    )
                )
                .mask(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.clear, .white],
                                center: .center,
                                startRadius: bubble.radius * 0.35,
                                endRadius: bubble.radius
                            )
                        )
                )

            Circle()
                .strokeBorder(.white.opacity(0.85), lineWidth: max(1.5, size * 0.045))

            Ellipse()
                .fill(.white.opacity(0.8))
                .frame(width: size * 0.24, height: size * 0.16)
                .rotationEffect(.degrees(-28))
                .offset(x: -size * 0.19, y: -size * 0.22)

            Circle()
                .fill(.white.opacity(0.5))
                .frame(width: size * 0.08, height: size * 0.08)
                .offset(x: size * 0.2, y: size * 0.18)

            if let symbol = bubble.symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Spray of droplets left behind by a pop.
private struct BubblePopBurst: View {
    let radius: CGFloat
    let tint: Color

    @State private var out = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.85), lineWidth: 3)
                .frame(width: radius * 2, height: radius * 2)
                .scaleEffect(out ? 1.5 : 0.9)
                .opacity(out ? 0 : 0.9)

            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 2 * .pi
                Circle()
                    .fill(tint.opacity(0.75))
                    .frame(width: max(4, radius * 0.18), height: max(4, radius * 0.18))
                    .offset(
                        x: CGFloat(cos(angle)) * radius * (out ? 1.9 : 0.4),
                        y: CGFloat(sin(angle)) * radius * (out ? 1.9 : 0.4)
                    )
                    .opacity(out ? 0 : 0.95)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { out = true }
        }
    }
}
