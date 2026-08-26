import SwiftUI

struct SoundboardView: View {
    // Every sound is a real recording; pressing shows a real photo too.
    private let sounds: [(symbol: String, name: String, color: Color, file: String)] = [
        ("dog.fill", "Dog", Palette.orange, "dog"),
        ("cat.fill", "Cat", Palette.purple, "cat"),
        ("bird.fill", "Bird", Palette.blue, "bird"),
        ("cow.fill", "Cow", Palette.brown, "cow"),
        ("water.waves", "Duck", Palette.teal, "duck"),
        ("figure.equestrian.sports", "Horse", Palette.red, "horse"),
        ("cloud.fill", "Sheep", Palette.indigo, "sheep"),
        ("car.fill", "Car", Palette.green, "car"),
        ("tram.fill", "Train", Palette.pink, "train"),
    ]

    @State private var showing: (name: String, file: String)?
    @State private var ambient: String?

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 8) {
                TopBar(title: "Sounds")

                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                        spacing: 14
                    ) {
                        ForEach(sounds, id: \.name) { item in
                            Button {
                                Sfx.bump()
                                SoundFile.shared.play(item.file)
                                withAnimation(.spring(response: 0.35)) {
                                    showing = (item.name, item.file)
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    // Real photo thumbnail on every tile.
                                    if let thumb = UIImage(named: "photo-\(item.file).jpg") ?? UIImage(named: "photo-\(item.file)") {
                                        Image(uiImage: thumb)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 58, height: 58)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(item.color.opacity(0.5), lineWidth: 3))
                                    } else {
                                        Image(systemName: item.symbol)
                                            .font(.system(size: 30, weight: .semibold))
                                            .foregroundStyle(item.color)
                                            .frame(width: 58, height: 58)
                                    }
                                    Text(item.name)
                                        .font(.rounded(15, weight: .semibold))
                                        .foregroundStyle(Palette.ink)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 108)
                                .card(cornerRadius: 22)
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    Text("Sleepy sounds")
                        .font(.rounded(20))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    Text("Gentle sounds that keep playing. Tap again to stop.")
                        .font(.rounded(13, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                        spacing: 14
                    ) {
                        AmbientTile(id: "noise", symbol: "fan.fill", name: "Fan", color: Palette.teal, active: $ambient)
                        AmbientTile(id: "waves", symbol: "water.waves", name: "Waves", color: Palette.blue, active: $ambient)
                        AmbientTile(id: "heartbeat", symbol: "heart.fill", name: "Heartbeat", color: Palette.pink, active: $ambient)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                }
            }

            // Real photo pops up while the sound plays.
            if let showing,
               let photo = UIImage(named: "photo-\(showing.file).jpg") ?? UIImage(named: "photo-\(showing.file)") {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { self.showing = nil } }

                VStack(spacing: 14) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 320, maxHeight: 340)
                        .clipShape(RoundedRectangle(cornerRadius: 26))

                    Text(showing.name)
                        .font(.rounded(30))
                        .foregroundStyle(Palette.ink)

                    Button {
                        Sfx.tap()
                        SoundFile.shared.play(showing.file)
                    } label: {
                        Label("Hear it again", systemImage: "speaker.wave.2.fill")
                            .font(.rounded(16))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Palette.green, in: Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
                .padding(18)
                .card(cornerRadius: 32)
                .padding(.horizontal, 30)
                .transition(.scale.combined(with: .opacity))
                .onTapGesture { withAnimation { self.showing = nil } }
            }
        }
        .onDisappear { ToneEngine.shared.stopAmbient() }
    }
}

struct AmbientTile: View {
    let id: String
    let symbol: String
    let name: String
    let color: Color
    @Binding var active: String?

    private var isOn: Bool { active == id }

    var body: some View {
        Button {
            Sfx.bump(.light)
            active = ToneEngine.shared.toggleAmbient(id)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: isOn ? "stop.fill" : symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(isOn ? .white : color)
                Text(name)
                    .font(.rounded(15, weight: .semibold))
                    .foregroundStyle(isOn ? .white : Palette.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 108)
            .background(
                isOn ? AnyShapeStyle(color) : AnyShapeStyle(Palette.card),
                in: RoundedRectangle(cornerRadius: 22)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}