import SwiftUI

// MARK: - Jigsaw puzzle made from the real photos

/// One of the bundled pictures, with the recording that belongs to it.
struct PuzzlePicture: Identifiable {
    let id: String          // matches "photo-<id>.jpg" and "<id>.m4a"
    let title: String

    static let all: [PuzzlePicture] = [
        PuzzlePicture(id: "dog", title: "Dog"),
        PuzzlePicture(id: "cat", title: "Cat"),
        PuzzlePicture(id: "duck", title: "Duck"),
        PuzzlePicture(id: "cow", title: "Cow"),
        PuzzlePicture(id: "horse", title: "Horse"),
        PuzzlePicture(id: "sheep", title: "Sheep"),
        PuzzlePicture(id: "bird", title: "Bird"),
        PuzzlePicture(id: "car", title: "Car"),
        PuzzlePicture(id: "train", title: "Train"),
    ]

    var image: UIImage? {
        UIImage(named: "photo-\(id).jpg") ?? UIImage(named: "photo-\(id)")
    }
}

/// How many pieces the picture is cut into.
enum PuzzleLevel: Int, CaseIterable, Identifiable {
    case four = 4, six = 6, nine = 9

    var id: Int { rawValue }

    var cols: Int {
        switch self {
        case .four: return 2
        case .six: return 3
        case .nine: return 3
        }
    }

    var rows: Int {
        switch self {
        case .four: return 2
        case .six: return 2
        case .nine: return 3
        }
    }

    var count: Int { cols * rows }
    var title: String { "\(count) pieces" }

    var tint: Color {
        switch self {
        case .four: return Palette.green
        case .six: return Palette.blue
        case .nine: return Palette.purple
        }
    }
}

struct PuzzlePiece: Identifiable {
    let id: Int
    let row: Int
    let col: Int
    let trayIndex: Int
    var placed = false
}

/// Everything the layout needs, worked out once per geometry pass.
private struct PuzzleMetrics {
    let width: CGFloat
    let cols: Int
    let rows: Int
    let count: Int
    let pieceSize: CGFloat
    let boardOrigin: CGPoint
    let trayTop: CGFloat
    let perRow: Int
    let thumb: CGFloat

    var boardWidth: CGFloat { pieceSize * CGFloat(cols) }
    var boardHeight: CGFloat { pieceSize * CGFloat(rows) }
    var thumbScale: CGFloat { pieceSize > 0 ? thumb / pieceSize : 1 }

    var boardCenter: CGPoint {
        CGPoint(x: boardOrigin.x + boardWidth / 2, y: boardOrigin.y + boardHeight / 2)
    }

    func slotCenter(row: Int, col: Int) -> CGPoint {
        CGPoint(
            x: boardOrigin.x + (CGFloat(col) + 0.5) * pieceSize,
            y: boardOrigin.y + (CGFloat(row) + 0.5) * pieceSize
        )
    }

    func trayCenter(_ index: Int) -> CGPoint {
        let row = index / perRow
        let col = index % perRow
        let inRow = min(perRow, count - row * perRow)
        let rowWidth = CGFloat(inRow) * (thumb + 12) - 12
        let startX = (width - rowWidth) / 2 + thumb / 2
        return CGPoint(
            x: startX + CGFloat(col) * (thumb + 12),
            y: trayTop + 20 + thumb / 2 + CGFloat(row) * (thumb + 14)
        )
    }
}

// MARK: - The game

struct PuzzleView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("puzzlesFinished") private var puzzlesFinished = 0

    @State private var pictureIndex = 0
    @State private var level: PuzzleLevel = .four
    @State private var pieces: [PuzzlePiece] = []
    @State private var dragging: Int?
    @State private var dragPoint: CGPoint = .zero
    @State private var showWin = false
    @State private var celebrate = false

    private static let snapDistance: CGFloat = 44

    private var picture: PuzzlePicture { PuzzlePicture.all[pictureIndex] }
    private var solved: Bool { !pieces.isEmpty && pieces.allSatisfy { $0.placed } }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 10) {
                GameTopBar(title: "Puzzle", stars: puzzlesFinished) { dismiss() }

                gallery
                levelPicker

                GeometryReader { geo in
                    let metrics = metrics(for: geo.size)
                    ZStack(alignment: .topLeading) {
                        boardBackdrop(metrics)
                        trayBackdrop(metrics, height: geo.size.height)

                        ForEach(pieces) { piece in
                            pieceView(piece, metrics: metrics)
                        }

                        if celebrate {
                            finishedPicture(metrics)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .coordinateSpace(name: "puzzle")
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 14)

            if celebrate {
                ConfettiBurst(count: 34, spread: 220, duration: 1.8)
                    .allowsHitTesting(false)
            }

            if showWin {
                CelebrationOverlay(
                    title: "You finished the \(picture.title)!",
                    subtitle: "Every piece is in the right place",
                    buttonLabel: "Next picture",
                    symbol: "photo.fill",
                    tint: Palette.green
                ) {
                    showWin = false
                    celebrate = false
                    pictureIndex = (pictureIndex + 1) % PuzzlePicture.all.count
                    newPuzzle()
                }
            }
        }
        .onAppear { if pieces.isEmpty { newPuzzle() } }
    }

    // MARK: Pickers

    private var gallery: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(PuzzlePicture.all.enumerated()), id: \.element.id) { index, item in
                    Button {
                        Sfx.tap()
                        Sfx.bump(.light)
                        pictureIndex = index
                        newPuzzle()
                    } label: {
                        Group {
                            if let image = item.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Palette.field
                            }
                        }
                        .frame(width: 62, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    pictureIndex == index ? Palette.green : .white,
                                    lineWidth: pictureIndex == index ? 4 : 2
                                )
                        )
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .frame(height: 74)
    }

    private var levelPicker: some View {
        HStack(spacing: 10) {
            ForEach(PuzzleLevel.allCases) { option in
                Button {
                    Sfx.tap()
                    Sfx.bump(.light)
                    level = option
                    newPuzzle()
                } label: {
                    Text(option.title)
                        .font(.rounded(17, weight: .bold))
                        .foregroundStyle(level == option ? .white : Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(level == option ? option.tint : Palette.card, in: Capsule())
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Board

    private func boardBackdrop(_ metrics: PuzzleMetrics) -> some View {
        ZStack {
            if let image = picture.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: metrics.boardWidth, height: metrics.boardHeight)
                    .clipped()
                    .opacity(0.16)
            }

            ForEach(0..<metrics.rows, id: \.self) { row in
                ForEach(0..<metrics.cols, id: \.self) { col in
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Palette.inkSoft.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                        .frame(width: metrics.pieceSize - 4, height: metrics.pieceSize - 4)
                        .position(
                            x: (CGFloat(col) + 0.5) * metrics.pieceSize,
                            y: (CGFloat(row) + 0.5) * metrics.pieceSize
                        )
                }
            }
        }
        .frame(width: metrics.boardWidth, height: metrics.boardHeight)
        .background(Palette.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
        .position(metrics.boardCenter)
        .allowsHitTesting(false)
    }

    private func trayBackdrop(_ metrics: PuzzleMetrics, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Palette.card.opacity(0.75))
            .frame(width: metrics.width, height: max(0, height - metrics.trayTop))
            .position(x: metrics.width / 2, y: metrics.trayTop + max(0, height - metrics.trayTop) / 2)
            .allowsHitTesting(false)
    }

    private func finishedPicture(_ metrics: PuzzleMetrics) -> some View {
        Group {
            if let image = picture.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: metrics.boardWidth, height: metrics.boardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white, lineWidth: 5)
                    )
                    .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
                    .position(metrics.boardCenter)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: Pieces

    private func pieceView(_ piece: PuzzlePiece, metrics: PuzzleMetrics) -> some View {
        let isDragging = dragging == piece.id
        let center: CGPoint = {
            if isDragging { return dragPoint }
            if piece.placed { return metrics.slotCenter(row: piece.row, col: piece.col) }
            return metrics.trayCenter(piece.trayIndex)
        }()
        let scale: CGFloat = piece.placed || isDragging ? 1 : metrics.thumbScale

        return pieceArt(piece, size: metrics.pieceSize)
            .scaleEffect(scale)
            .shadow(
                color: .black.opacity(piece.placed ? 0.06 : (isDragging ? 0.25 : 0.12)),
                radius: isDragging ? 14 : 6,
                y: isDragging ? 8 : 3
            )
            .position(center)
            .zIndex(isDragging ? 10 : (piece.placed ? 1 : 2))
            .allowsHitTesting(!piece.placed)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("puzzle"))
                    .onChanged { value in
                        guard !piece.placed else { return }
                        if dragging != piece.id {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                dragging = piece.id
                            }
                            Sfx.bump(.light)
                        }
                        dragPoint = value.location
                    }
                    .onEnded { value in
                        guard !piece.placed else { return }
                        drop(piece, at: value.location, metrics: metrics)
                    }
            )
    }

    private func pieceArt(_ piece: PuzzlePiece, size: CGFloat) -> some View {
        let boardWidth = size * CGFloat(level.cols)
        let boardHeight = size * CGFloat(level.rows)

        return Color.clear
            .frame(width: size, height: size)
            .overlay(alignment: .topLeading) {
                Group {
                    if let image = picture.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: boardWidth, height: boardHeight)
                            .clipped()
                    } else {
                        Palette.field.frame(width: boardWidth, height: boardHeight)
                    }
                }
                .offset(x: -CGFloat(piece.col) * size, y: -CGFloat(piece.row) * size)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(piece.placed ? 0.35 : 0.95), lineWidth: piece.placed ? 1 : 3)
            )
    }

    // MARK: Actions

    private func drop(_ piece: PuzzlePiece, at point: CGPoint, metrics: PuzzleMetrics) {
        let slot = metrics.slotCenter(row: piece.row, col: piece.col)
        let distance = hypot(point.x - slot.x, point.y - slot.y)

        if distance <= Self.snapDistance {
            Sfx.pop()
            Sfx.bump(.medium)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) {
                if let index = pieces.firstIndex(where: { $0.id == piece.id }) {
                    pieces[index].placed = true
                }
                dragging = nil
            }
            if pieces.allSatisfy({ $0.placed }) { finish() }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                dragging = nil
            }
        }
    }

    private func finish() {
        puzzlesFinished += 1
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.easeOut(duration: 0.35)) { celebrate = true }
            SoundFile.shared.play(picture.id)
            try? await Task.sleep(for: .seconds(1.1))
            Speaker.shared.cheer("You did it! A whole \(picture.title).")
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showWin = true }
        }
    }

    private func newPuzzle() {
        dragging = nil
        showWin = false
        celebrate = false
        let order = Array(0..<level.count).shuffled()
        pieces = (0..<level.count).map { index in
            PuzzlePiece(
                id: index,
                row: index / level.cols,
                col: index % level.cols,
                trayIndex: order[index]
            )
        }
    }

    // MARK: Layout

    private func metrics(for size: CGSize) -> PuzzleMetrics {
        let count = level.count
        let perRow = count <= 4 ? count : (count <= 6 ? 3 : 5)
        let thumb = min(66, max(40, (size.width - 20) / CGFloat(perRow) - 14))
        let trayRows = Int(ceil(Double(count) / Double(perRow)))
        let trayHeight = CGFloat(trayRows) * (thumb + 14) + 26
        let boardArea = max(120, size.height - trayHeight - 10)
        let pieceSize = max(
            40,
            min((size.width - 16) / CGFloat(level.cols), (boardArea - 16) / CGFloat(level.rows))
        )
        let boardWidth = pieceSize * CGFloat(level.cols)
        let boardHeight = pieceSize * CGFloat(level.rows)

        return PuzzleMetrics(
            width: size.width,
            cols: level.cols,
            rows: level.rows,
            count: count,
            pieceSize: pieceSize,
            boardOrigin: CGPoint(
                x: (size.width - boardWidth) / 2,
                y: max(0, (boardArea - boardHeight) / 2)
            ),
            trayTop: size.height - trayHeight,
            perRow: perRow,
            thumb: thumb
        )
    }
}
