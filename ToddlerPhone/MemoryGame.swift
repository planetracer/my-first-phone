import SwiftUI

// MARK: - Memory Match (flip cards, find the pairs)

struct MemoryMatchView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var stage = Stage.setup
    @State private var level = Level.easy
    @State private var deckKind = DeckKind.symbols
    @State private var cards: [MemoryCard] = []
    @State private var flipped: [Int] = []          // indexes currently face up and unmatched
    @State private var busy = false
    @State private var pairs = 0
    @State private var flips = 0
    @State private var startedAt = Date.now
    @State private var showWin = false
    @State private var freshBest = false

    // Kept warm and personal: these are only ever compared to the child's own play.
    @AppStorage("memoryBestFlipsEasy") private var bestFlipsEasy = 0
    @AppStorage("memoryBestFlipsMedium") private var bestFlipsMedium = 0
    @AppStorage("memoryBestFlipsHard") private var bestFlipsHard = 0
    @AppStorage("memoryBestTimeEasy") private var bestTimeEasy = 0
    @AppStorage("memoryBestTimeMedium") private var bestTimeMedium = 0
    @AppStorage("memoryBestTimeHard") private var bestTimeHard = 0

    enum Stage {
        case setup, playing
    }

    enum Level: String, CaseIterable, Identifiable {
        case easy, medium, hard
        var id: String { rawValue }

        var title: String {
            switch self {
            case .easy: return "Easy"
            case .medium: return "Medium"
            case .hard: return "Hard"
            }
        }

        var pairs: Int {
            switch self {
            case .easy: return 3
            case .medium: return 6
            case .hard: return 8
            }
        }

        var columns: Int {
            switch self {
            case .easy: return 3
            case .medium, .hard: return 4
            }
        }

        var cardHeight: CGFloat {
            switch self {
            case .easy: return 112
            case .medium: return 94
            case .hard: return 84
            }
        }

        var blurb: String {
            switch self {
            case .easy: return "3 pairs"
            case .medium: return "6 pairs"
            case .hard: return "8 pairs"
            }
        }

        var color: Color {
            switch self {
            case .easy: return Palette.green
            case .medium: return Palette.blue
            case .hard: return Palette.purple
            }
        }
    }

    enum DeckKind: String, CaseIterable, Identifiable {
        case symbols, animals
        var id: String { rawValue }

        var title: String {
            switch self {
            case .symbols: return "Shapes"
            case .animals: return "Photos"
            }
        }

        var blurb: String {
            switch self {
            case .symbols: return "Colored pictures"
            case .animals: return "Real animals with sounds"
            }
        }

        var symbol: String {
            switch self {
            case .symbols: return "square.grid.2x2.fill"
            case .animals: return "photo.fill"
            }
        }

        var color: Color {
            switch self {
            case .symbols: return Palette.orange
            case .animals: return Palette.teal
            }
        }
    }

    /// One face of a pair: either a colored symbol or a bundled photo with a
    /// real recorded sound.
    struct CardFace {
        let symbol: String
        let photo: String?
        let sound: String?
        let color: Color
        let name: String
    }

    static let symbolFaces: [CardFace] = [
        CardFace(symbol: "heart.fill", photo: nil, sound: nil, color: Palette.pink, name: "heart"),
        CardFace(symbol: "star.fill", photo: nil, sound: nil, color: Palette.yellow, name: "star"),
        CardFace(symbol: "car.fill", photo: nil, sound: nil, color: Palette.red, name: "car"),
        CardFace(symbol: "leaf.fill", photo: nil, sound: nil, color: Palette.green, name: "leaf"),
        CardFace(symbol: "moon.fill", photo: nil, sound: nil, color: Palette.indigo, name: "moon"),
        CardFace(symbol: "sun.max.fill", photo: nil, sound: nil, color: Palette.orange, name: "sun"),
        CardFace(symbol: "cloud.fill", photo: nil, sound: nil, color: Palette.blue, name: "cloud"),
        CardFace(symbol: "flame.fill", photo: nil, sound: nil, color: Palette.purple, name: "flame"),
    ]

    static let animalFaces: [CardFace] = [
        CardFace(symbol: "dog.fill", photo: "photo-dog.jpg", sound: "dog", color: Palette.orange, name: "dog"),
        CardFace(symbol: "cat.fill", photo: "photo-cat.jpg", sound: "cat", color: Palette.pink, name: "cat"),
        CardFace(symbol: "bird.fill", photo: "photo-bird.jpg", sound: "bird", color: Palette.teal, name: "bird"),
        CardFace(symbol: "pawprint.fill", photo: "photo-cow.jpg", sound: "cow", color: Palette.brown, name: "cow"),
        CardFace(symbol: "bird.fill", photo: "photo-duck.jpg", sound: "duck", color: Palette.yellow, name: "duck"),
        CardFace(symbol: "hare.fill", photo: "photo-horse.jpg", sound: "horse", color: Palette.red, name: "horse"),
        CardFace(symbol: "pawprint.fill", photo: "photo-sheep.jpg", sound: "sheep", color: Palette.green, name: "sheep"),
        CardFace(symbol: "car.fill", photo: "photo-car.jpg", sound: "car", color: Palette.blue, name: "car"),
        CardFace(symbol: "tram.fill", photo: "photo-train.jpg", sound: "train", color: Palette.purple, name: "train"),
    ]

    static let matchCheers = [
        "Nice one!",
        "You found a pair!",
        "Great looking!",
        "That is a match!",
        "Clever you!",
        "Wonderful!",
    ]

    struct MemoryCard: Identifiable {
        let id = UUID()
        let face: Int
        var faceUp = false
        var matched = false
    }

    private var faces: [CardFace] {
        deckKind == .animals ? Self.animalFaces : Self.symbolFaces
    }

    private var allMatched: Bool { !cards.isEmpty && cards.allSatisfy { $0.matched } }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            if stage == .setup {
                setupScreen
            } else {
                boardScreen
            }

            if showWin {
                CelebrationOverlay(
                    title: "You found them all!",
                    subtitle: winSubtitle,
                    buttonLabel: "Play again",
                    symbol: "trophy.fill",
                    tint: Palette.purple
                ) {
                    showWin = false
                    startGame()
                }
            }
        }
        .onDisappear { Speaker.shared.stop() }
    }

    // MARK: Setup screen

    private var setupScreen: some View {
        VStack(spacing: 18) {
            GameTopBar(onClose: { dismiss() })

            Text("Memory")
                .font(.rounded(30))
                .foregroundStyle(Palette.ink)

            Text("Pick a board and some cards")
                .font(.rounded(15, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)

            ScrollView {
                VStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        pickerHeading("How many pairs", symbol: "square.grid.3x2.fill", color: Palette.blue)
                        HStack(spacing: 12) {
                            ForEach(Level.allCases) { option in
                                levelButton(option)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        pickerHeading("Which cards", symbol: "photo.on.rectangle", color: Palette.teal)
                        HStack(spacing: 12) {
                            ForEach(DeckKind.allCases) { option in
                                deckButton(option)
                            }
                        }
                    }

                    if let line = bestLine(for: level) {
                        Text(line)
                            .font(.rounded(14, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                    }

                    Button {
                        Sfx.tap()
                        Sfx.bump(.light)
                        startGame()
                    } label: {
                        Text("Start playing")
                            .font(.rounded(22))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 66)
                            .background(Palette.purple, in: Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func pickerHeading(_ text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.rounded(18))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(color.opacity(0.13), in: Capsule())
    }

    private func levelButton(_ option: Level) -> some View {
        let picked = level == option
        return Button {
            Sfx.tap()
            Sfx.bump(.light)
            level = option
        } label: {
            VStack(spacing: 6) {
                Text(option.title)
                    .font(.rounded(19))
                    .foregroundStyle(Palette.ink)
                Text(option.blurb)
                    .font(.rounded(13, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(option.color.opacity(picked ? 0.18 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(picked ? option.color : .clear, lineWidth: 3)
            )
            .card(cornerRadius: 22)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private func deckButton(_ option: DeckKind) -> some View {
        let picked = deckKind == option
        return Button {
            Sfx.tap()
            Sfx.bump(.light)
            deckKind = option
        } label: {
            VStack(spacing: 8) {
                Image(systemName: option.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(option.color)
                    .frame(width: 58, height: 58)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [option.color.opacity(0.30), option.color.opacity(0.09)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    )
                Text(option.title)
                    .font(.rounded(18))
                    .foregroundStyle(Palette.ink)
                Text(option.blurb)
                    .font(.rounded(12, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 30, alignment: .top)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 168)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(option.color.opacity(picked ? 0.16 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(picked ? option.color : .clear, lineWidth: 3)
            )
            .card()
        }
        .buttonStyle(BouncyButtonStyle())
    }

    // MARK: Board

    private var boardScreen: some View {
        VStack(spacing: 14) {
            GameTopBar(stars: pairs, onClose: { dismiss() }) {
                StarChip(count: flips, symbol: "hand.tap.fill", color: Palette.blue)
            }

            Text("Find the matching pairs!")
                .font(.rounded(16, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)

            Spacer(minLength: 0)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: level.columns),
                spacing: 14
            ) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    CardView(card: card, face: faces[card.face], height: level.cardHeight) {
                        flip(index)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            if let line = bestLine(for: level) {
                Text(line)
                    .font(.rounded(13, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button {
                Sfx.tap()
                Sfx.bump(.light)
                Speaker.shared.stop()
                stage = .setup
            } label: {
                Text("Change the cards")
                    .font(.rounded(16))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .card(cornerRadius: 18)
            }
            .buttonStyle(BouncyButtonStyle())
            .padding(.bottom, 26)
        }
    }

    // MARK: Personal bests, phrased warmly

    private var bestFlips: Int {
        switch level {
        case .easy: return bestFlipsEasy
        case .medium: return bestFlipsMedium
        case .hard: return bestFlipsHard
        }
    }

    private var bestTime: Int {
        switch level {
        case .easy: return bestTimeEasy
        case .medium: return bestTimeMedium
        case .hard: return bestTimeHard
        }
    }

    private func bestLine(for level: Level) -> String? {
        guard bestFlips > 0 else { return nil }
        let seconds = bestTime
        if seconds > 0 {
            return "Last best on \(level.title.lowercased()): \(bestFlips) flips in \(seconds) seconds. Any way you play is lovely."
        }
        return "Last best on \(level.title.lowercased()): \(bestFlips) flips. Any way you play is lovely."
    }

    private var winSubtitle: String {
        let seconds = Int(Date.now.timeIntervalSince(startedAt).rounded())
        if freshBest {
            return "\(flips) flips in \(seconds) seconds. That is your quickest yet"
        }
        return "\(flips) flips in \(seconds) seconds. Lovely finding"
    }

    private func recordFinish() {
        let seconds = max(1, Int(Date.now.timeIntervalSince(startedAt).rounded()))
        let better = bestFlips == 0 || flips < bestFlips || (flips == bestFlips && seconds < bestTime)
        freshBest = better
        guard better else { return }
        switch level {
        case .easy:
            bestFlipsEasy = flips
            bestTimeEasy = seconds
        case .medium:
            bestFlipsMedium = flips
            bestTimeMedium = seconds
        case .hard:
            bestFlipsHard = flips
            bestTimeHard = seconds
        }
    }

    // MARK: Play

    private func startGame() {
        var deck: [MemoryCard] = []
        let picks = Array(faces.indices.shuffled().prefix(level.pairs))
        for face in picks {
            deck.append(MemoryCard(face: face))
            deck.append(MemoryCard(face: face))
        }
        withAnimation(.spring(response: 0.4)) {
            cards = deck.shuffled()
        }
        flipped = []
        busy = false
        pairs = 0
        flips = 0
        freshBest = false
        startedAt = .now
        stage = .playing
    }

    private func flip(_ index: Int) {
        guard !busy, !cards[index].faceUp, !cards[index].matched else { return }
        Sfx.tap()
        Sfx.bump(.light)
        flips += 1
        withAnimation(.easeInOut(duration: 0.3)) { cards[index].faceUp = true }
        flipped.append(index)

        guard flipped.count == 2 else { return }
        let a = flipped[0]
        let b = flipped[1]

        if cards[a].face == cards[b].face {
            cards[a].matched = true
            cards[b].matched = true
            pairs += 1
            flipped = []
            Sfx.pop()
            Sfx.bump()
            celebrateMatch(face: faces[cards[a].face])
        } else {
            busy = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.easeInOut(duration: 0.3)) {
                    cards[a].faceUp = false
                    cards[b].faceUp = false
                }
                flipped = []
                busy = false
            }
        }
    }

    private func celebrateMatch(face: CardFace) {
        let finished = allMatched
        if finished { recordFinish() }

        if let sound = face.sound {
            SoundFile.shared.play(sound)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.0))
                if finished {
                    Speaker.shared.cheer("You found them all! You are a memory star!")
                } else {
                    Speaker.shared.cheer("Two \(face.name)s! \(Self.matchCheers.randomElement() ?? "Nice one!")")
                }
            }
        } else if finished {
            Speaker.shared.cheer("You found them all! You are a memory star!")
        } else {
            Speaker.shared.cheer(Self.matchCheers.randomElement() ?? "Nice one!")
        }

        guard finished else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            showWin = true
        }
    }
}

/// Slanted bars used for the patterned card backs.
struct DiagonalStripes: Shape {
    var spacing: CGFloat = 16
    var thickness: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = -rect.height
        while x < rect.width {
            var bar = Path()
            bar.move(to: CGPoint(x: x, y: rect.maxY))
            bar.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            bar.addLine(to: CGPoint(x: x + rect.height + thickness, y: rect.minY))
            bar.addLine(to: CGPoint(x: x + thickness, y: rect.maxY))
            bar.closeSubpath()
            path.addPath(bar)
            x += spacing
        }
        return path
    }
}

private struct CardView: View {
    let card: MemoryMatchView.MemoryCard
    let face: MemoryMatchView.CardFace
    let height: CGFloat
    let action: () -> Void

    @State private var burst = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if card.faceUp || card.matched {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Palette.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(card.matched ? face.color : .clear, lineWidth: 3)
                        )
                        .shadow(color: card.matched ? face.color.opacity(0.5) : .black.opacity(0.06),
                                radius: card.matched ? 10 : 6, y: 3)
                    faceArt
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Palette.field)
                        .overlay(
                            DiagonalStripes()
                                .fill(.white.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        )
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft.opacity(0.45))
                }
            }
            .frame(height: height)
            .rotation3DEffect(
                .degrees(card.faceUp || card.matched ? 0 : 180),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.easeInOut(duration: 0.3), value: card.faceUp)
            .overlay {
                if burst {
                    ConfettiBurst(count: 14, spread: 105, duration: 1.2, scale: 0.75)
                }
            }
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(card.matched)
        .onChange(of: card.matched) { matched in
            guard matched else { return }
            burst = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.3))
                burst = false
            }
        }
    }

    @ViewBuilder
    private var faceArt: some View {
        if let photo = face.photo, let image = UIImage(named: photo) ?? UIImage(named: face.name) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: height - 12)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(6)
        } else {
            Image(systemName: face.symbol)
                .font(.system(size: height > 100 ? 40 : 34, weight: .semibold))
                .foregroundStyle(face.color)
        }
    }
}
