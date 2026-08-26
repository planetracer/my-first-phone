import SwiftUI
import AVFoundation

// MARK: - Music room (xylophone, drums, piano and bells)

/// The four toys in the music room.
enum MusicInstrument: String, CaseIterable, Identifiable {
    case xylophone, drums, piano, bells

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xylophone: return "Xylophone"
        case .drums: return "Drums"
        case .piano: return "Piano"
        case .bells: return "Bells"
        }
    }

    var symbol: String {
        switch self {
        case .xylophone: return "music.quarternote.3"
        case .drums: return "circle.grid.2x2.fill"
        case .piano: return "pianokeys"
        case .bells: return "bell.fill"
        }
    }

    var tint: Color {
        switch self {
        case .xylophone: return Palette.orange
        case .drums: return Palette.brown
        case .piano: return Palette.indigo
        case .bells: return Palette.teal
        }
    }

    /// Drums are the only instrument that cannot follow a melody.
    var isMelodic: Bool { self != .drums }
}

/// One tap captured by the little recorder.
struct MusicTap {
    let instrument: MusicInstrument
    let key: Int
    let offset: Double
}

/// A short melody written as steps of the C major scale (0 is C4, 7 is C5).
struct MusicSong: Identifiable {
    let id: Int
    let title: String
    let notes: [Int]
}

// MARK: - Tone synthesis

/// Generates every note in this file with AVAudioEngine. Buffers are built
/// once and cached, so a tap only ever schedules an existing buffer.
final class MusicEngine {
    static let shared = MusicEngine()

    /// C major scale, C4 up to C5.
    static let scale: [Double] = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25]
    /// The five black keys of that octave: C#, D#, F#, G#, A#.
    static let sharps: [Double] = [277.18, 311.13, 369.99, 415.30, 466.16]

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private let cacheLock = NSLock()
    private static let sampleRate: Double = 44100

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        for _ in 0..<8 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            players.append(node)
        }
        try? engine.start()
        for node in players { node.play() }
    }

    /// Number of playable keys for an instrument.
    static func keyCount(_ instrument: MusicInstrument) -> Int {
        switch instrument {
        case .xylophone, .bells: return 8
        case .piano: return 13          // 8 white then 5 black
        case .drums: return 4
        }
    }

    /// Builds and caches every buffer for one instrument, off the main thread
    /// so switching instruments never costs a frame.
    func prepare(_ instrument: MusicInstrument) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            for key in 0..<Self.keyCount(instrument) {
                _ = self.buffer(instrument, key)
            }
        }
    }

    func play(_ instrument: MusicInstrument, _ key: Int) {
        guard let sound = buffer(instrument, key) else { return }
        if !engine.isRunning {
            try? AVAudioSession.sharedInstance().setActive(true)
            try? engine.start()
            for node in players { node.play() }
        }
        let node = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        node.scheduleBuffer(sound, at: nil, options: [.interrupts], completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    // MARK: Buffer building

    /// The lock is never held while samples are being generated, so a tap can
    /// always read the cache straight away.
    private func buffer(_ instrument: MusicInstrument, _ key: Int) -> AVAudioPCMBuffer? {
        let name = "\(instrument.rawValue)-\(key)"
        cacheLock.lock()
        let cached = buffers[name]
        cacheLock.unlock()
        if let cached { return cached }

        guard let made = make(instrument, key) else { return nil }
        cacheLock.lock()
        buffers[name] = made
        cacheLock.unlock()
        return made
    }

    private func make(_ instrument: MusicInstrument, _ key: Int) -> AVAudioPCMBuffer? {
        switch instrument {
        case .drums:
            return pcm(from: drumSamples(key))
        case .xylophone:
            guard let f = frequency(instrument, key) else { return nil }
            return pcm(from: toneSamples(
                frequency: f, duration: 1.0, decay: 4.6, attack: 0.004,
                partials: [(1, 1), (2.76, 0.30), (5.40, 0.10)]
            ))
        case .piano:
            guard let f = frequency(instrument, key) else { return nil }
            return pcm(from: toneSamples(
                frequency: f, duration: 1.7, decay: 2.1, attack: 0.008,
                partials: [(1, 1), (2, 0.42), (3, 0.17), (4, 0.07)]
            ))
        case .bells:
            guard let f = frequency(instrument, key) else { return nil }
            return pcm(from: toneSamples(
                frequency: f * 2, duration: 2.4, decay: 1.5, attack: 0.012,
                partials: [(1, 1), (2, 0.45), (3.01, 0.26), (4.2, 0.10)]
            ))
        }
    }

    private func frequency(_ instrument: MusicInstrument, _ key: Int) -> Double? {
        switch instrument {
        case .drums:
            return nil
        case .piano:
            if key < 8 { return Self.scale[key] }
            let sharp = key - 8
            return sharp < Self.sharps.count ? Self.sharps[sharp] : nil
        case .xylophone, .bells:
            return key < Self.scale.count ? Self.scale[key] : nil
        }
    }

    /// Additive tone with a soft attack and an exponential decay.
    private func toneSamples(
        frequency: Double,
        duration: Double,
        decay: Double,
        attack: Double,
        partials: [(Double, Double)]
    ) -> [Float] {
        let rate = Self.sampleRate
        let count = Int(rate * duration)
        var samples = [Float](repeating: 0, count: count)
        let norm = max(partials.reduce(0.0) { $0 + $1.1 }, 0.0001)
        let tail = 0.08

        for i in 0..<count {
            let t = Double(i) / rate
            var value = 0.0
            for (ratio, amp) in partials {
                value += sin(2 * .pi * frequency * ratio * t) * amp
            }
            value /= norm
            let rise = attack <= 0 ? 1 : min(1, t / attack)
            let fall = min(1, max(0, (duration - t) / tail))
            samples[i] = Float(value * rise * exp(-t * decay) * fall * 0.5)
        }
        return samples
    }

    /// Kick, snare, tom and cymbal made from sine thumps and noise bursts.
    private func drumSamples(_ key: Int) -> [Float] {
        let rate = Self.sampleRate
        switch key {
        case 0:
            return sweep(from: 135, to: 45, duration: 0.55, decay: 8.5, rate: rate)
        case 1:
            let duration = 0.35
            let count = Int(rate * duration)
            var samples = [Float](repeating: 0, count: count)
            var seed: UInt64 = 8_675_309
            for i in 0..<count {
                let t = Double(i) / rate
                let noise = nextNoise(&seed)
                let body = sin(2 * .pi * 195 * t) * 0.5
                let env = exp(-t * 24)
                let fall = min(1, max(0, (duration - t) / 0.05))
                samples[i] = Float((noise * 0.75 + body) * env * fall * 0.45)
            }
            return samples
        case 2:
            return sweep(from: 240, to: 110, duration: 0.55, decay: 7.0, rate: rate)
        default:
            let duration = 1.1
            let count = Int(rate * duration)
            var samples = [Float](repeating: 0, count: count)
            var seed: UInt64 = 1_234_577
            var previous = 0.0
            for i in 0..<count {
                let t = Double(i) / rate
                let noise = nextNoise(&seed)
                let bright = noise - previous      // cheap high pass, gives a shimmer
                previous = noise
                let env = exp(-t * 4.2)
                let rise = min(1, t / 0.003)
                let fall = min(1, max(0, (duration - t) / 0.1))
                samples[i] = Float(bright * env * rise * fall * 0.3)
            }
            return samples
        }
    }

    private func sweep(from start: Double, to end: Double, duration: Double, decay: Double, rate: Double) -> [Float] {
        let count = Int(rate * duration)
        var samples = [Float](repeating: 0, count: count)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / rate
            let progress = t / duration
            let frequency = end + (start - end) * exp(-progress * 6)
            phase += 2 * .pi * frequency / rate
            let rise = min(1, t / 0.004)
            let fall = min(1, max(0, (duration - t) / 0.06))
            samples[i] = Float(sin(phase) * exp(-t * decay) * rise * fall * 0.7)
        }
        return samples
    }

    private func nextNoise(_ seed: inout UInt64) -> Double {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let value = Double((seed >> 33) & 0xFFFF) / 65535.0
        return value * 2 - 1
    }

    private func pcm(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)
              ) else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        for i in samples.indices { channel[i] = samples[i] }
        return buffer
    }
}

// MARK: - The room

struct MusicView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var instrument: MusicInstrument = .xylophone
    @State private var songMode = false
    @State private var songIndex = 0
    @State private var step = 0
    @State private var pressedKey: Int?
    @State private var keyTaps: [Int] = Array(repeating: 0, count: 16)
    @State private var pulse = false
    @State private var showWin = false
    @State private var isRecording = false
    @State private var isPlayingBack = false
    @State private var recorded: [MusicTap] = []
    @State private var recordStart = Date.now
    @State private var playbackTask: Task<Void, Never>?

    static let songs: [MusicSong] = [
        MusicSong(id: 0, title: "Twinkle Twinkle", notes: [0, 0, 4, 4, 5, 5, 4, 3, 3, 2, 2, 1, 1, 0]),
        MusicSong(id: 1, title: "Old MacDonald", notes: [0, 0, 0, 4, 5, 5, 4, 2, 2, 1, 1, 0]),
        MusicSong(id: 2, title: "Happy Birthday", notes: [4, 4, 5, 4, 7, 6, 4, 4, 5, 4, 1, 0]),
        MusicSong(id: 3, title: "Row Row Row Your Boat", notes: [0, 0, 0, 1, 2, 2, 1, 2, 3, 4]),
    ]

    static let barColors: [Color] = [
        Palette.red, Palette.orange, Palette.yellow, Palette.green,
        Palette.teal, Palette.blue, Palette.indigo, Palette.purple,
    ]

    private var song: MusicSong { Self.songs[min(songIndex, Self.songs.count - 1)] }

    /// The key that should glow next, when a song is running.
    private var target: Int? {
        guard songMode, instrument.isMelodic, step < song.notes.count, !showWin else { return nil }
        return song.notes[step]
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 12) {
                GameTopBar(title: "Music") { close() }

                instrumentPicker

                modeRow

                if songMode {
                    songPicker
                    progressDots
                }

                board

                recorderBar
            }
            .padding(.bottom, 16)

            if showWin {
                CelebrationOverlay(
                    title: "You played \(song.title)!",
                    subtitle: "That sounded lovely",
                    buttonLabel: "Play again",
                    symbol: "music.note",
                    tint: Palette.purple
                ) {
                    showWin = false
                    step = 0
                }
            }
        }
        .onAppear {
            MusicEngine.shared.prepare(instrument)
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: instrument) { _, new in
            MusicEngine.shared.prepare(new)
        }
        .onDisappear { playbackTask?.cancel() }
    }

    // MARK: Pickers

    private var instrumentPicker: some View {
        HStack(spacing: 10) {
            ForEach(MusicInstrument.allCases) { item in
                Button {
                    Sfx.tap()
                    Sfx.bump(.light)
                    instrument = item
                    if songMode && !item.isMelodic { songMode = false }
                    step = 0
                    showWin = false
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 20, weight: .semibold))
                        Text(item.title)
                            .font(.rounded(12, weight: .semibold))
                    }
                    .foregroundStyle(instrument == item ? .white : Palette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(instrument == item ? item.tint : Palette.card)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }

    private var modeRow: some View {
        HStack(spacing: 10) {
            modeChip(title: "Free play", on: !songMode) {
                songMode = false
                showWin = false
            }
            modeChip(title: "Songs", on: songMode) {
                if !instrument.isMelodic { instrument = .xylophone }
                songMode = true
                step = 0
                showWin = false
            }
        }
        .padding(.horizontal, 20)
    }

    private func modeChip(title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Sfx.tap()
            Sfx.bump(.light)
            action()
        } label: {
            Text(title)
                .font(.rounded(17, weight: .bold))
                .foregroundStyle(on ? .white : Palette.inkSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(on ? Palette.green : Palette.field, in: Capsule())
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private var songPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.songs) { item in
                    Button {
                        Sfx.tap()
                        Sfx.bump(.light)
                        songIndex = item.id
                        step = 0
                        showWin = false
                    } label: {
                        Text(item.title)
                            .font(.rounded(15, weight: .bold))
                            .foregroundStyle(songIndex == item.id ? .white : Palette.ink)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(
                                songIndex == item.id ? Palette.purple : Palette.card,
                                in: Capsule()
                            )
                            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 50)
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<song.notes.count, id: \.self) { i in
                Circle()
                    .fill(i < step ? Palette.green : Palette.field)
                    .frame(width: i == step ? 12 : 9, height: i == step ? 12 : 9)
                    .overlay(
                        Circle()
                            .stroke(Palette.green.opacity(i == step ? 0.7 : 0), lineWidth: 2)
                    )
            }
        }
        .frame(height: 16)
    }

    // MARK: Board

    private var board: some View {
        GeometryReader { geo in
            Group {
                switch instrument {
                case .xylophone: xylophone(geo.size)
                case .drums: drums(geo.size)
                case .piano: piano(geo.size)
                case .bells: bells(geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    private func xylophone(_ size: CGSize) -> some View {
        let spacing: CGFloat = 8
        let barHeight = max(26, (size.height - spacing * 7) / 8)
        return VStack(spacing: spacing) {
            ForEach(0..<8, id: \.self) { i in
                let color = Self.barColors[i]
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .overlay(
                        HStack {
                            Circle().fill(.white.opacity(0.55)).frame(width: 7, height: 7)
                            Spacer()
                            Circle().fill(.white.opacity(0.55)).frame(width: 7, height: 7)
                        }
                        .padding(.horizontal, 14)
                    )
                    .frame(width: size.width * (1 - CGFloat(i) * 0.05), height: barHeight)
                    .keyLook(pressed: pressedKey == i, target: target == i, pulse: pulse, color: color)
                    .overlay(alignment: .top) {
                        MusicNoteFloat(trigger: keyTaps[i], color: color)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { tapKey(i) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bells(_ size: CGSize) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<8, id: \.self) { i in
                let color = Self.barColors[i]
                ZStack {
                    Circle().fill(color.opacity(0.18))
                    Circle().stroke(color.opacity(0.5), lineWidth: 3)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(color)
                }
                .frame(height: min(96, (size.height - 20) / 2))
                .keyLook(pressed: pressedKey == i, target: target == i, pulse: pulse, color: color, corner: 60)
                .overlay(alignment: .top) {
                    MusicNoteFloat(trigger: keyTaps[i], color: color)
                }
                .contentShape(Circle())
                .onTapGesture { tapKey(i) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func piano(_ size: CGSize) -> some View {
        let whiteWidth = size.width / 8
        let blackWidth = whiteWidth * 0.58
        let height = min(size.height, 300)
        let blackAfter = [0, 1, 3, 4, 5]     // white keys followed by a black key

        return ZStack(alignment: .topLeading) {
            HStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { i in
                    let color = Self.barColors[i]
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Palette.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Palette.field, lineWidth: 2)
                        )
                        .overlay(alignment: .bottom) {
                            Circle()
                                .fill(color)
                                .frame(width: 16, height: 16)
                                .padding(.bottom, 14)
                        }
                        .keyLook(pressed: pressedKey == i, target: target == i, pulse: pulse, color: color)
                        .overlay(alignment: .top) {
                            MusicNoteFloat(trigger: keyTaps[i], color: color)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { tapKey(i) }
                }
            }
            .frame(height: height)

            ForEach(Array(blackAfter.enumerated()), id: \.offset) { slot, white in
                let key = 8 + slot
                RoundedRectangle(cornerRadius: 8)
                    .fill(Palette.ink)
                    .frame(width: blackWidth, height: height * 0.58)
                    .keyLook(pressed: pressedKey == key, target: false, pulse: pulse, color: Palette.indigo)
                    .offset(x: whiteWidth * CGFloat(white + 1) - blackWidth / 2)
                    .contentShape(Rectangle())
                    .onTapGesture { tapKey(key) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func drums(_ size: CGSize) -> some View {
        let names = ["Kick", "Snare", "Tom", "Cymbal"]
        let colors = [Palette.brown, Palette.red, Palette.orange, Palette.yellow]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
        let pad = min(150, max(96, (size.height - 60) / 2))

        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<4, id: \.self) { i in
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(colors[i].opacity(0.22))
                        Circle().stroke(colors[i], lineWidth: 5)
                        Circle().stroke(colors[i].opacity(0.4), lineWidth: 3).padding(14)
                        if i == 3 {
                            ForEach(0..<8, id: \.self) { ray in
                                Capsule()
                                    .fill(colors[i].opacity(0.35))
                                    .frame(width: 3, height: pad * 0.22)
                                    .offset(y: -pad * 0.18)
                                    .rotationEffect(.degrees(Double(ray) * 45))
                            }
                        } else if i == 1 {
                            VStack(spacing: 7) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Capsule()
                                        .fill(colors[i].opacity(0.4))
                                        .frame(width: pad * 0.42, height: 3)
                                }
                            }
                        } else {
                            Circle().fill(colors[i].opacity(0.3)).frame(width: pad * 0.3)
                        }
                    }
                    .frame(width: pad, height: pad)
                    .keyLook(pressed: pressedKey == i, target: false, pulse: pulse, color: colors[i], corner: 90)
                    .overlay(alignment: .top) {
                        MusicNoteFloat(trigger: keyTaps[i], color: colors[i])
                    }
                    .contentShape(Circle())
                    .onTapGesture { tapKey(i) }

                    Text(names[i])
                        .font(.rounded(14, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: Recorder

    private var recorderBar: some View {
        HStack(spacing: 12) {
            Button {
                Sfx.tap()
                Sfx.bump(.medium)
                toggleRecording()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isRecording ? "stop.fill" : "circle.fill")
                        .font(.system(size: 17, weight: .bold))
                    Text(isRecording ? "Stop" : "Record")
                        .font(.rounded(16, weight: .bold))
                        .fixedSize()
                }
                .foregroundStyle(isRecording ? .white : Palette.red)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(isRecording ? Palette.red : Palette.card, in: Capsule())
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            }
            .buttonStyle(BouncyButtonStyle())

            Button {
                Sfx.tap()
                Sfx.bump(.light)
                playBack()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .bold))
                    Text("Play")
                        .font(.rounded(16, weight: .bold))
                        .fixedSize()
                }
                .foregroundStyle(recorded.isEmpty ? Palette.inkSoft : Palette.green)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Palette.card, in: Capsule())
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                .opacity(recorded.isEmpty ? 0.55 : 1)
            }
            .buttonStyle(BouncyButtonStyle())

            Spacer(minLength: 0)

            // Eight dots, each standing for two taps, so the buttons keep
            // their full labels on narrow phones.
            HStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(recorded.count > i * 2 ? Palette.pink : Palette.field)
                        .frame(width: 7, height: 7)
                }
            }
            .layoutPriority(-1)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Actions

    private func tapKey(_ key: Int) {
        MusicEngine.shared.play(instrument, key)
        Sfx.bump(.light)
        if key < keyTaps.count { keyTaps[key] += 1 }
        flash(key)

        if isRecording, recorded.count < 16 {
            recorded.append(MusicTap(
                instrument: instrument,
                key: key,
                offset: Date.now.timeIntervalSince(recordStart)
            ))
            if recorded.count == 16 { isRecording = false }
        }

        if let target, target == key {
            step += 1
            if step >= song.notes.count {
                Speaker.shared.cheer("You played the whole song!")
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showWin = true }
            }
        }
    }

    private func flash(_ key: Int) {
        withAnimation(.easeOut(duration: 0.08)) { pressedKey = key }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            if pressedKey == key {
                withAnimation(.easeOut(duration: 0.16)) { pressedKey = nil }
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            isRecording = false
        } else {
            playbackTask?.cancel()
            isPlayingBack = false
            recorded = []
            recordStart = .now
            isRecording = true
        }
    }

    private func playBack() {
        guard !recorded.isEmpty, !isPlayingBack else { return }
        isRecording = false
        isPlayingBack = true
        let notes = recorded
        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            var last = 0.0
            for note in notes {
                let wait = max(0, note.offset - last)
                last = note.offset
                try? await Task.sleep(for: .seconds(wait))
                if Task.isCancelled { break }
                MusicEngine.shared.play(note.instrument, note.key)
                if note.instrument == instrument {
                    if note.key < keyTaps.count { keyTaps[note.key] += 1 }
                    flash(note.key)
                }
            }
            isPlayingBack = false
        }
    }

    private func close() {
        playbackTask?.cancel()
        Speaker.shared.stop()
        dismiss()
    }
}

// MARK: - Small pieces

/// Press, glow and gentle pulse shared by every kind of key.
private struct MusicKeyLook: ViewModifier {
    let pressed: Bool
    let target: Bool
    let pulse: Bool
    let color: Color
    let corner: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.94 : (target && pulse ? 1.04 : 1))
            .shadow(color: color.opacity(pressed ? 0.75 : (target ? 0.45 : 0)), radius: pressed ? 16 : 12)
            .overlay {
                if target {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Palette.ink.opacity(0.22), lineWidth: 4)
                        .opacity(pulse ? 0.9 : 0.35)
                }
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: pressed)
    }
}

private extension View {
    func keyLook(
        pressed: Bool,
        target: Bool,
        pulse: Bool,
        color: Color,
        corner: CGFloat = 12
    ) -> some View {
        modifier(MusicKeyLook(pressed: pressed, target: target, pulse: pulse, color: color, corner: corner))
    }
}

/// A little vector note that drifts up from a key and fades. At most three
/// live at once per key, so tapping fast stays cheap.
private struct MusicNoteFloat: View {
    let trigger: Int
    let color: Color

    @State private var items: [UUID] = []

    var body: some View {
        ZStack {
            ForEach(items, id: \.self) { _ in
                MusicRisingNote(color: color)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            guard items.count < 3 else { return }
            let id = UUID()
            items.append(id)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.95))
                items.removeAll { $0 == id }
            }
        }
    }
}

private struct MusicRisingNote: View {
    let color: Color
    @State private var up = false

    var body: some View {
        Image(systemName: "music.note")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(color)
            .offset(x: up ? 14 : 0, y: up ? -66 : -6)
            .opacity(up ? 0 : 0.95)
            .scaleEffect(up ? 1.3 : 0.6)
            .rotationEffect(.degrees(up ? 18 : -8))
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { up = true }
            }
    }
}
