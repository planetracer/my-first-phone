import SwiftUI

struct DoodleView: View {
    @State private var strokes: [Stroke] = []
    @State private var current: Stroke?
    @State private var selectedColor: Color = Palette.red
    @State private var canvasSize: CGSize = .zero
    @State private var sentConfirmation = false

    private let palette: [Color] = [
        Palette.red, Palette.orange, Palette.yellow, Palette.green,
        Palette.blue, Palette.purple, Palette.pink, Palette.ink,
    ]

    struct Stroke {
        var color: Color
        var points: [CGPoint]
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 14) {
                TopBar(title: "Doodle")

                canvas
                    .padding(.horizontal, 20)

                paletteBar
                    .padding(.bottom, 16)
            }
        }
    }

    private var canvas: some View {
        Canvas { context, size in
            Task { @MainActor in
                if canvasSize != size { canvasSize = size }
            }
            let allStrokes = strokes + (current.map { [$0] } ?? [])
            for stroke in allStrokes {
                if stroke.points.count == 1, let point = stroke.points.first {
                    let dot = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                    context.fill(Path(ellipseIn: dot), with: .color(stroke.color))
                } else {
                    var path = Path()
                    path.addLines(stroke.points)
                    context.stroke(
                        path,
                        with: .color(stroke.color),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if current == nil {
                        current = Stroke(color: selectedColor, points: [])
                    }
                    current?.points.append(value.location)
                }
                .onEnded { _ in
                    if let stroke = current { strokes.append(stroke) }
                    current = nil
                    Sfx.bump(.light)
                }
        )
    }

    private var paletteBar: some View {
        VStack(spacing: 12) {
            // Colours on their own row so nothing overflows the screen.
            HStack(spacing: 10) {
                ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                    Button {
                        Sfx.tap()
                        Sfx.bump(.light)
                        selectedColor = color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle().stroke(Palette.card, lineWidth: selectedColor == color ? 4 : 0)
                            )
                            .shadow(color: .black.opacity(selectedColor == color ? 0.2 : 0.08), radius: 4, y: 2)
                            .scaleEffect(selectedColor == color ? 1.2 : 1)
                            .animation(.spring(response: 0.3), value: selectedColor == color)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }

            HStack(spacing: 14) {
                Button {
                    Sfx.bump()
                    withAnimation { strokes.removeAll() }
                } label: {
                    Label("Clear", systemImage: "trash.fill")
                        .font(.rounded(15, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .card(cornerRadius: 16)
                }
                .buttonStyle(BouncyButtonStyle())

                if FamilyStore.shared.isConnected {
                    Button {
                        sendToFamily()
                    } label: {
                        Label(sentConfirmation ? "Sent!" : "Send", systemImage: sentConfirmation ? "checkmark" : "paperplane.fill")
                            .font(.rounded(15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(sentConfirmation ? Palette.green : Palette.blue, in: Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .disabled(strokes.isEmpty || sentConfirmation)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    /// Renders the drawing to an image and sends it to the family chat.
    private func sendToFamily() {
        guard !strokes.isEmpty, canvasSize != .zero else { return }
        Sfx.bump()

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))
            for stroke in strokes {
                let path = UIBezierPath()
                path.lineWidth = 10
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                if stroke.points.count == 1, let point = stroke.points.first {
                    let dot = UIBezierPath(ovalIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
                    UIColor(stroke.color).setFill()
                    dot.fill()
                } else if let first = stroke.points.first {
                    path.move(to: first)
                    for point in stroke.points.dropFirst() { path.addLine(to: point) }
                    UIColor(stroke.color).setStroke()
                    path.stroke()
                }
            }
        }

        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("doodle-\(UUID().uuidString).jpg")
        try? data.write(to: url)

        Task {
            await FamilyStore.shared.sendPhoto(fileURL: url)
            sentConfirmation = true
            Speaker.shared.say("Drawing sent to your family!")
            try? await Task.sleep(for: .seconds(2))
            sentConfirmation = false
        }
    }
}
