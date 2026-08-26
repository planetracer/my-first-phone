import SwiftUI
import AVFoundation

// MARK: - Kid flashlight (real torch plus a glowing colored screen)

struct FlashlightView: View {
    @State private var isOn = false
    @State private var glowColor: Color = .white
    @State private var savedBrightness: CGFloat = UIScreen.main.brightness

    private let glows: [(name: String, color: Color)] = [
        ("White", .white),
        ("Sunny", Color(red: 1.0, green: 0.93, blue: 0.75)),
        ("Red", Color(red: 1.0, green: 0.55, blue: 0.5)),
        ("Green", Color(red: 0.6, green: 0.95, blue: 0.65)),
        ("Blue", Color(red: 0.6, green: 0.8, blue: 1.0)),
        ("Pink", Color(red: 1.0, green: 0.7, blue: 0.85)),
    ]

    var body: some View {
        ZStack {
            (isOn ? glowColor : Palette.background)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: isOn)
                .animation(.easeInOut(duration: 0.3), value: glowColor)

            VStack(spacing: 20) {
                TopBar(title: "Light")

                Spacer()

                // The big switch
                Button {
                    toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isOn ? .white : Palette.card)
                            .frame(width: 170, height: 170)
                            .shadow(color: isOn ? glowColor.opacity(0.9) : .black.opacity(0.08),
                                    radius: isOn ? 50 : 12, y: 6)
                        Image(systemName: isOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 60, weight: .semibold))
                            .foregroundStyle(isOn ? Palette.yellow : Palette.inkSoft)
                    }
                }
                .buttonStyle(BouncyButtonStyle())

                Text(isOn ? "So bright!" : "Tap to turn on!")
                    .font(.rounded(20))
                    .foregroundStyle(isOn ? Palette.ink.opacity(0.7) : Palette.inkSoft)

                Spacer()

                // Glow colors
                HStack(spacing: 12) {
                    ForEach(glows, id: \.name) { glow in
                        Button {
                            Sfx.tap()
                            Sfx.bump(.light)
                            glowColor = glow.color
                            if !isOn { toggle() }
                        } label: {
                            Circle()
                                .fill(glow.color)
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(
                                    glowColor == glow.color && isOn ? Palette.ink : Palette.field,
                                    lineWidth: 3
                                ))
                                .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                        }
                        .buttonStyle(BouncyButtonStyle())
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onDisappear {
            setTorch(false)
            UIScreen.main.brightness = savedBrightness
        }
    }

    private func toggle() {
        Sfx.tap()
        Sfx.bump()
        isOn.toggle()
        setTorch(isOn)
        if isOn {
            savedBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1
        } else {
            UIScreen.main.brightness = savedBrightness
        }
    }

    /// Turns on the real flashlight LED when the phone has one.
    private func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}
