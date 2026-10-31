import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - Palette (warm paper background, white cards, muted accents)

enum Palette {
    static let background = Color(red: 0.972, green: 0.962, blue: 0.943)
    static let card = Color.white
    static let ink = Color(red: 0.22, green: 0.22, blue: 0.27)
    static let inkSoft = Color(red: 0.52, green: 0.52, blue: 0.57)
    static let field = Color(red: 0.93, green: 0.92, blue: 0.90)

    static let green = Color(red: 0.30, green: 0.62, blue: 0.44)
    static let blue = Color(red: 0.32, green: 0.51, blue: 0.84)
    static let pink = Color(red: 0.84, green: 0.44, blue: 0.57)
    static let red = Color(red: 0.86, green: 0.43, blue: 0.39)
    static let orange = Color(red: 0.91, green: 0.58, blue: 0.29)
    static let indigo = Color(red: 0.47, green: 0.47, blue: 0.81)
    static let purple = Color(red: 0.61, green: 0.46, blue: 0.77)
    static let teal = Color(red: 0.30, green: 0.61, blue: 0.62)
    static let brown = Color(red: 0.62, green: 0.48, blue: 0.36)
    static let yellow = Color(red: 0.89, green: 0.70, blue: 0.29)

    /// Cycle used to color family avatars.
    static let avatarColors: [Color] = [pink, blue, purple, teal, orange, green, indigo, red]

    /// Stable color for a member name.
    static func colorFor(_ name: String) -> Color {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return avatarColors[sum % avatarColors.count]
    }
}

extension View {
    /// White rounded card with a soft shadow.
    func card(cornerRadius: CGFloat = 24) -> some View {
        self
            .background(Palette.card, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

// MARK: - Sounds & speech (all generated on-device)

enum Sfx {
    static func tap() { ToneEngine.shared.play("tap") }
    static func sent() { ToneEngine.shared.play("sent") }
    static func received() { ToneEngine.shared.play("received") }
    static func pop() { ToneEngine.shared.play("pop") }
    static func ring() { ToneEngine.shared.play("ring") }

    static func dtmf(_ digit: Int) {
        ToneEngine.shared.play("dtmf\(digit)")
    }

    static func bump(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Microphone permission

/// Asks for microphone access. The AVAudioApplication record-permission API
/// is iOS 17+, so this wraps the iOS 16 callback API and keeps `await` at the
/// call sites.
func requestRecordPermissionCompat() async -> Bool {
    await withCheckedContinuation { continuation in
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            continuation.resume(returning: granted)
        }
    }
}

/// Synthesizes all sound effects with AVAudioEngine. Using a `.playback`
/// audio session means sounds work even with the silent switch on —
/// system-sound IDs (the previous approach) are always muted by the switch.
final class ToneEngine {
    static let shared = ToneEngine()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let ambientPlayer = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var ambientBuffers: [String: AVAudioPCMBuffer] = [:]
    private(set) var currentAmbient: String?
    private static let sampleRate = 44100.0

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        engine.attach(player)
        engine.attach(ambientPlayer)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.connect(ambientPlayer, to: engine.mainMixerNode, format: format)
        try? engine.start()

        buildBuffers()
        buildAmbientBuffers()
    }

    /// Toggles a looping sleep sound. Returns the sound now playing, if any.
    @discardableResult
    func toggleAmbient(_ name: String) -> String? {
        ambientPlayer.stop()
        if currentAmbient == name {
            currentAmbient = nil
            return nil
        }
        guard let buffer = ambientBuffers[name] else { return nil }
        if !engine.isRunning {
            try? AVAudioSession.sharedInstance().setActive(true)
            try? engine.start()
        }
        ambientPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        ambientPlayer.play()
        currentAmbient = name
        return name
    }

    func stopAmbient() {
        ambientPlayer.stop()
        currentAmbient = nil
    }

    /// Short frying-pan sizzle (crackly noise burst) for the cooking game.
    func playSizzle() {
        if buffers["sizzle"] == nil {
            let sr = Self.sampleRate
            let count = Int(sr * 1.2)
            var samples = [Float](repeating: 0, count: count)
            for i in 0..<count {
                let t = Double(i) / sr
                let crackle: Float = Float.random(in: 0...1) > 0.982 ? Float.random(in: -1...1) : 0
                let hiss = Float.random(in: -1...1) * 0.18
                let envelope = Float(min(1.0, t / 0.05) * exp(-1.6 * t / 1.2))
                samples[i] = (hiss + crackle * 0.9) * 0.4 * envelope
            }
            buffers["sizzle"] = buffer(from: samples)
        }
        play("sizzle")
    }

    /// Short watery splash for the washing stage: a softer crackle burst
    /// plus a few descending sine plops.
    func playSplash() {
        if buffers["splash"] == nil {
            let sr = Self.sampleRate
            let count = Int(sr * 0.5)
            var samples = [Float](repeating: 0, count: count)
            for i in 0..<count {
                let t = Double(i) / sr
                // Watery: lower crackle density than the sizzle.
                let crackle: Float = Float.random(in: 0...1) > 0.994 ? Float.random(in: -1...1) : 0
                let hiss = Float.random(in: -1...1) * 0.10
                let envelope = Float(min(1.0, t / 0.02) * exp(-5.0 * t / 0.5))
                samples[i] = (hiss + crackle * 0.7) * 0.45 * envelope
            }
            // A few descending sine plops.
            for (offset, freq) in [(0.0, 620.0), (0.09, 500.0), (0.18, 400.0)] {
                let start = Int(offset * sr)
                let plopLength = Int(sr * 0.12)
                for i in 0..<plopLength where start + i < count {
                    let t = Double(i) / sr
                    let env = exp(-24 * t / 0.12)
                    samples[start + i] += Float(0.28 * env * sin(2 * .pi * freq * t))
                }
            }
            buffers["splash"] = buffer(from: samples)
        }
        play("splash")
    }

    /// Short low thock plus a click for the cutting stage.
    func playChop() {
        if buffers["chop"] == nil {
            // Low sine thock (~120 Hz, 60 ms) plus a bright click.
            let thock = blip([120], duration: 0.06, volume: 0.32)
            let click = blip([2600], duration: 0.015, volume: 0.16)
            buffers["chop"] = buffer(from: thock + click)
        }
        play("chop")
    }

    /// Soft maraca-like double tick for the parsley shaker.
    func playShake() {
        if buffers["shake"] == nil {
            let sr = Self.sampleRate
            let count = Int(sr * 0.34)
            var samples = [Float](repeating: 0, count: count)
            // Two short filtered noise ticks, the second a touch softer.
            for (offset, strength) in [(0.0, 1.0), (0.15, 0.72)] {
                let start = Int(offset * sr)
                let tickLength = Int(sr * 0.11)
                var high: Float = 0
                var previous: Float = 0
                for i in 0..<tickLength where start + i < count {
                    let t = Double(i) / sr
                    let white = Float.random(in: -1...1)
                    // Simple high pass so the grains sound like little seeds.
                    high = 0.72 * (high + white - previous)
                    previous = white
                    let envelope = Float(exp(-26 * t / 0.11) * min(1.0, t / 0.004))
                    samples[start + i] += high * 0.22 * Float(strength) * envelope
                }
            }
            buffers["shake"] = buffer(from: samples)
        }
        play("shake")
    }

    private func buildAmbientBuffers() {
        let sr = Self.sampleRate

        // Soft brown noise — steady "shhh" like a fan.
        let noiseCount = Int(sr * 4)
        var last: Float = 0
        var noise = [Float](repeating: 0, count: noiseCount)
        for i in 0..<noiseCount {
            let white = Float.random(in: -1...1)
            last = (last + 0.02 * white) / 1.02
            noise[i] = last * 3.5 * 0.55
        }
        ambientBuffers["noise"] = buffer(from: noise)

        // Ocean waves — the same noise swelling in and out.
        let waveCount = Int(sr * 12)
        var lastW: Float = 0
        var waves = [Float](repeating: 0, count: waveCount)
        for i in 0..<waveCount {
            let white = Float.random(in: -1...1)
            lastW = (lastW + 0.02 * white) / 1.02
            let t = Double(i) / sr
            let swell = 0.25 + 0.75 * abs(sin(.pi * t / 6.0))
            waves[i] = lastW * 3.5 * 0.6 * Float(swell)
        }
        ambientBuffers["waves"] = buffer(from: waves)

        // Slow heartbeat — two soft low thumps, 50 bpm.
        let beatCount = Int(sr * 2.4)
        var beat = [Float](repeating: 0, count: beatCount)
        for (offset, strength) in [(0.0, 1.0), (0.32, 0.7)] {
            let start = Int(offset * sr)
            let thumpLength = Int(sr * 0.22)
            for i in 0..<thumpLength where start + i < beatCount {
                let t = Double(i) / sr
                let envelope = exp(-14 * t / 0.22)
                beat[start + i] += Float(0.5 * strength * envelope * sin(2 * .pi * 52 * t))
            }
        }
        ambientBuffers["heartbeat"] = buffer(from: beat)
    }

    func play(_ name: String) {
        guard let buffer = buffers[name] else { return }
        if !engine.isRunning {
            try? AVAudioSession.sharedInstance().setActive(true)
            try? engine.start()
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    private func buildBuffers() {
        buffers["tap"] = buffer(from: blip([1250], duration: 0.045))
        buffers["pop"] = buffer(from: blip([520, 780], duration: 0.09))
        buffers["sent"] = buffer(from: blip([740], duration: 0.09) + silence(0.02) + blip([1100], duration: 0.12))
        buffers["received"] = buffer(from: blip([1100], duration: 0.09) + silence(0.02) + blip([740], duration: 0.12))

        // US ringback: 440+480 Hz, two short bursts.
        let burst = sustained([440, 480], duration: 0.55, volume: 0.16)
        buffers["ring"] = buffer(from: burst + silence(0.25) + burst)

        // Real DTMF frequency pairs for the dial pad.
        let rows = [697.0, 770.0, 852.0, 941.0]
        let cols = [1209.0, 1336.0, 1477.0]
        let layout: [Int: (Double, Double)] = [
            1: (rows[0], cols[0]), 2: (rows[0], cols[1]), 3: (rows[0], cols[2]),
            4: (rows[1], cols[0]), 5: (rows[1], cols[1]), 6: (rows[1], cols[2]),
            7: (rows[2], cols[0]), 8: (rows[2], cols[1]), 9: (rows[2], cols[2]),
            0: (rows[3], cols[1]),
        ]
        for (digit, pair) in layout {
            buffers["dtmf\(digit)"] = buffer(from: sustained([pair.0, pair.1], duration: 0.14, volume: 0.2))
        }
    }

    /// Short percussive tone: fast attack, exponential decay.
    private func blip(_ frequencies: [Double], duration: Double, volume: Float = 0.24) -> [Float] {
        let count = Int(Self.sampleRate * duration)
        return (0..<count).map { i in
            let t = Double(i) / Self.sampleRate
            let attack = min(1.0, Double(i) / (Self.sampleRate * 0.004))
            let envelope = attack * exp(-6.0 * t / duration)
            let sample = frequencies.reduce(0.0) { $0 + sin(2 * .pi * $1 * t) } / Double(frequencies.count)
            return volume * Float(envelope * sample)
        }
    }

    /// Held tone with a soft fade in and out (DTMF, ringback).
    private func sustained(_ frequencies: [Double], duration: Double, volume: Float) -> [Float] {
        let count = Int(Self.sampleRate * duration)
        let fade = Self.sampleRate * 0.012
        return (0..<count).map { i in
            let t = Double(i) / Self.sampleRate
            let envelope = min(1.0, Double(i) / fade) * min(1.0, Double(count - i) / fade)
            let sample = frequencies.reduce(0.0) { $0 + sin(2 * .pi * $1 * t) } / Double(frequencies.count)
            return volume * Float(envelope * sample)
        }
    }

    private func silence(_ duration: Double) -> [Float] {
        Array(repeating: 0, count: Int(Self.sampleRate * duration))
    }

    private func buffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)
        ) else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        for i in samples.indices { channel[i] = samples[i] }
        return buffer
    }
}

/// Plays short bundled recordings (real animal sounds).
final class SoundFile {
    static let shared = SoundFile()
    private var players: [String: AVAudioPlayer] = [:]

    func play(_ name: String) {
        if players[name] == nil,
           let url = Bundle.main.url(forResource: name, withExtension: "m4a") {
            players[name] = try? AVAudioPlayer(contentsOf: url)
        }
        guard let player = players[name] else { return }
        player.currentTime = 0
        player.play()
    }
}

final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()

    /// The best-sounding installed English voice. Named premium voices first
    /// (they sound genuinely human), then any premium, then enhanced, then default.
    private lazy var bestVoice: AVSpeechSynthesisVoice? = {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        let favorites = ["Zoe", "Ava", "Evan", "Allison", "Samantha", "Nathan", "Joelle", "Noelle"]

        if #available(iOS 16.0, *) {
            let premium = english.filter { $0.quality == .premium }
            for name in favorites {
                if let voice = premium.first(where: { $0.name.contains(name) }) { return voice }
            }
            if let voice = premium.first { return voice }
        }
        let enhanced = english.filter { $0.quality == .enhanced }
        for name in favorites {
            if let voice = enhanced.first(where: { $0.name.contains(name) }) { return voice }
        }
        if let voice = enhanced.first { return voice }
        return AVSpeechSynthesisVoice(language: "en-US")
    }()

    /// True when only the robotic compact voice is installed.
    var isUsingBasicVoice: Bool {
        guard let voice = bestVoice else { return true }
        if #available(iOS 16.0, *), voice.quality == .premium { return false }
        return voice.quality != .enhanced
    }

    var currentVoiceName: String {
        bestVoice?.name ?? "Default"
    }

    // Natural pitch, unhurried pace. Pushing pitch up is what sounds robotic.
    func say(_ text: String, pitch: Float = 1.02) {
        speak(text, pitch: pitch, rate: 0.5)
    }

    /// Excited celebration delivery, a touch brighter and quicker.
    func cheer(_ text: String) {
        speak(text, pitch: 1.12, rate: 0.53)
    }

    private func speak(_ text: String, pitch: Float, rate: Float) {
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = 1.0
        utterance.voice = bestVoice
        synth.speak(utterance)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }
}

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension Font {
    static func rounded(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Avatars

/// Colored circle with an SF Symbol — used for pretend friends.
struct SymbolAvatar: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 62

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: Circle())
    }
}

/// Colored circle with initials — used for real family contacts.
struct InitialsAvatar: View {
    let name: String
    let color: Color
    var size: CGFloat = 62

    private var initials: String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.rounded(size * 0.36, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
    }
}

// MARK: - Shared chrome

/// Top bar with a Home button, used inside every "app".
struct TopBar: View {
    @EnvironmentObject private var model: AppModel
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Button {
                Sfx.tap()
                Sfx.bump(.light)
                model.screen = .home
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 52, height: 52)
                    .card(cornerRadius: 18)
            }
            .buttonStyle(BouncyButtonStyle())

            Text(title)
                .font(.rounded(28))
                .foregroundStyle(Palette.ink)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

/// Round close button for full-screen covers.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Sfx.tap()
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 52, height: 52)
                .card(cornerRadius: 18)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}
