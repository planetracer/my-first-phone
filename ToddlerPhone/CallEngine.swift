import SwiftUI
import WebRTC
import AVFoundation
import CallKit

// MARK: - CallKit bridge (native incoming-call UI, lock-screen answer)

final class CallKitManager: NSObject, CXProviderDelegate {
    static let shared = CallKitManager()

    private let provider: CXProvider
    private let callController = CXCallController()
    private var currentUUID: UUID?

    var hasCall: Bool { currentUUID != nil }

    override init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = true
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func reportIncoming(from caller: String) {
        guard currentUUID == nil else { return }
        let uuid = UUID()
        currentUUID = uuid
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: caller)
        update.localizedCallerName = caller
        update.hasVideo = true
        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if error != nil { self?.currentUUID = nil }
        }
    }

    func requestAnswer() {
        guard let uuid = currentUUID else { return }
        callController.request(CXTransaction(action: CXAnswerCallAction(call: uuid))) { _ in }
    }

    func requestEnd() {
        guard let uuid = currentUUID else { return }
        callController.request(CXTransaction(action: CXEndCallAction(call: uuid))) { _ in }
    }

    func reportConnected() {
        guard let uuid = currentUUID else { return }
        provider.reportOutgoingCall(with: uuid, connectedAt: nil)
    }

    func reportEnded() {
        guard let uuid = currentUUID else { return }
        currentUUID = nil
        provider.reportCall(with: uuid, endedAt: nil, reason: .remoteEnded)
    }

    // MARK: CXProviderDelegate (callbacks arrive on the main queue)

    func providerDidReset(_ provider: CXProvider) {
        currentUUID = nil
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
        Task { @MainActor in CallEngine.shared.performAccept() }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        currentUUID = nil
        action.fulfill()
        Task { @MainActor in CallEngine.shared.performHangup() }
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = true
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = false
    }
}

// MARK: - Live family audio calls (peer-to-peer WebRTC, signaled over CloudKit)

@MainActor
final class CallEngine: NSObject, ObservableObject {
    static let shared = CallEngine()

    enum Phase: Equatable {
        case idle
        case outgoing
        case incoming(String)
        case connecting
        case active(Date)
        case ended(String)
    }

    @Published var phase: Phase = .idle
    @Published var peerName = "Family"
    @Published var isMuted = false {
        didSet { audioTrack?.isEnabled = !isMuted }
    }
    @Published var speakerOn = true {
        didSet { applySpeaker() }
    }
    @Published var videoOn = false
    @Published var localVideoTrack: RTCVideoTrack?
    @Published var remoteVideoTrack: RTCVideoTrack?

    private var factory: RTCPeerConnectionFactory?
    private var peer: RTCPeerConnection?
    private var audioTrack: RTCAudioTrack?
    private var videoSource: RTCVideoSource?
    private var capturer: RTCCameraVideoCapturer?
    private var cameraPosition: AVCaptureDevice.Position = .front
    private let frameGrabber = FrameGrabber()

    /// Keeps the newest remote video frame so it can be saved as a photo.
    final class FrameGrabber: NSObject, RTCVideoRenderer {
        nonisolated(unsafe) var latest: CVPixelBuffer?
        func setSize(_ size: CGSize) {}
        func renderFrame(_ frame: RTCVideoFrame?) {
            guard let buffer = (frame?.buffer as? RTCCVPixelBuffer)?.pixelBuffer else { return }
            latest = buffer
        }
    }

    /// Saves a snapshot of the other person's video to the photo wall.
    func snapshotRemoteVideo() -> Bool {
        guard let buffer = frameGrabber.latest else { return false }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
              let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.85)
        else { return false }
        KidPhotoStore.shared.save(data)
        return true
    }
    private var callID = ""
    private var callTarget = ""
    private var pendingOfferSDP: String?
    private var pollTask: Task<Void, Never>?
    private static var sslInitialized = false

    private var store: FamilyStore { FamilyStore.shared }

    // MARK: - Public actions

    func startCall(to member: String? = nil) {
        guard phase == .idle else { return }
        peerName = member ?? "Family"
        callTarget = member ?? ""
        callID = UUID().uuidString
        phase = .outgoing
        Sfx.ring()
        Task { await placeOffer() }
    }

    func acceptIncoming() {
        guard case .incoming = phase else { return }
        if CallKitManager.shared.hasCall {
            CallKitManager.shared.requestAnswer()
        } else {
            performAccept()
        }
    }

    func performAccept() {
        guard case .incoming = phase else { return }
        Task { await answerCall() }
    }

    func declineIncoming() {
        guard case .incoming = phase else { return }
        if CallKitManager.shared.hasCall {
            CallKitManager.shared.requestEnd()
        } else {
            let id = callID
            Task { await store.sendCallSignal(kind: "hangup", callID: id, sdp: "") }
            reset("")
        }
    }

    func hangUp() {
        if CallKitManager.shared.hasCall {
            CallKitManager.shared.requestEnd()
        } else {
            performHangup()
        }
    }

    func performHangup() {
        let id = callID
        Task { await store.sendCallSignal(kind: "hangup", callID: id, sdp: "") }
        reset(phase == .idle ? "" : "Call ended")
    }

    /// Polled from the app root while idle: rings on a fresh offer from family.
    func checkForIncoming() async {
        guard phase == .idle, store.isConnected else { return }
        let signals = await store.recentCallSignals(within: 45)
        let me = store.displayName
        guard let offer = signals.last(where: {
            $0.kind == "offer" && $0.sender != me && ($0.to.isEmpty || $0.to == me)
        }) else { return }
        let finished = signals.contains {
            $0.callID == offer.callID && ($0.kind == "hangup" || ($0.kind == "answer" && $0.sender == me))
        }
        guard !finished else { return }

        pendingOfferSDP = offer.sdp
        callID = offer.callID
        peerName = offer.sender
        phase = .incoming(offer.sender)
        CallKitManager.shared.reportIncoming(from: offer.sender)
        Sfx.ring()
        Sfx.bump(.heavy)
    }

    // MARK: - Call setup

    private func placeOffer() async {
        guard await requestRecordPermissionCompat() else {
            reset("Microphone permission needed")
            return
        }
        do {
            let peer = try setupPeer()
            let offer = try await createOffer(peer)
            try await setLocal(peer, offer)
            await waitForIceGathering(peer)
            let sdp = peer.localDescription?.sdp ?? offer.sdp
            await store.sendCallSignal(kind: "offer", callID: callID, sdp: sdp, to: callTarget)
            startSignalLoop()
        } catch {
            reset("Could not start the call")
        }
    }

    private func answerCall() async {
        guard let offerSDP = pendingOfferSDP else { return }
        guard await requestRecordPermissionCompat() else {
            reset("Microphone permission needed")
            return
        }
        phase = .connecting
        do {
            let peer = try setupPeer()
            try await setRemote(peer, RTCSessionDescription(type: .offer, sdp: offerSDP))
            let answer = try await createAnswer(peer)
            try await setLocal(peer, answer)
            await waitForIceGathering(peer)
            let sdp = peer.localDescription?.sdp ?? answer.sdp
            await store.sendCallSignal(kind: "answer", callID: callID, sdp: sdp)
            startSignalLoop()
        } catch {
            reset("Could not connect")
        }
    }

    private func setupPeer() throws -> RTCPeerConnection {
        if !Self.sslInitialized {
            RTCInitializeSSL()
            Self.sslInitialized = true
        }
        let factory = RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory()
        )
        self.factory = factory

        let config = RTCConfiguration()
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(
                urlStrings: ["turn:openrelay.metered.ca:80", "turn:openrelay.metered.ca:443"],
                username: "openrelayproject",
                credential: "openrelayproject"
            ),
        ]
        config.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let connection = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            throw CallError.setupFailed
        }

        let source = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        let track = factory.audioTrack(with: source, trackId: "audio0")
        connection.add(track, streamIds: ["family"])
        audioTrack = track

        // Video is negotiated up front but stays off until the user taps the camera.
        let vSource = factory.videoSource()
        let vTrack = factory.videoTrack(with: vSource, trackId: "video0")
        vTrack.isEnabled = false
        connection.add(vTrack, streamIds: ["family"])
        videoSource = vSource
        localVideoTrack = vTrack

        peer = connection
        return connection
    }

    // MARK: - Camera

    func toggleVideo() {
        if videoOn {
            stopVideo()
        } else {
            Task { await startVideo() }
        }
    }

    func flipCamera() {
        guard videoOn else { return }
        cameraPosition = cameraPosition == .front ? .back : .front
        capturer?.stopCapture()
        capturer = nil
        Task { await startVideo() }
    }

    private func startVideo() async {
        guard await AVCaptureDevice.requestAccess(for: .video),
              let videoSource, let localVideoTrack else { return }

        let capturer = RTCCameraVideoCapturer(delegate: videoSource)
        self.capturer = capturer

        let devices = RTCCameraVideoCapturer.captureDevices()
        guard let device = devices.first(where: { $0.position == cameraPosition }) ?? devices.first else { return }

        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        let format = formats.min(by: { widthDelta($0) < widthDelta($1) }) ?? formats.first
        guard let format else { return }
        let fps = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 30

        do {
            try await capturer.startCapture(with: device, format: format, fps: Int(min(fps, 30)))
        } catch {
            self.capturer = nil
            return
        }
        localVideoTrack.isEnabled = true
        videoOn = true
    }

    private func widthDelta(_ format: AVCaptureDevice.Format) -> Int32 {
        abs(CMVideoFormatDescriptionGetDimensions(format.formatDescription).width - 640)
    }

    private func stopVideo() {
        capturer?.stopCapture()
        capturer = nil
        localVideoTrack?.isEnabled = false
        videoOn = false
    }

    private enum CallError: Error {
        case setupFailed, sdpFailed
    }

    // MARK: - Signal polling (answer / hangup / timeout)

    private func startSignalLoop() {
        pollTask?.cancel()
        let started = Date.now
        pollTask = Task {
            while !Task.isCancelled {
                let signals = await store.recentCallSignals(within: 120)
                let me = store.displayName

                if signals.contains(where: { $0.callID == callID && $0.kind == "hangup" && $0.sender != me }) {
                    reset("Call ended")
                    return
                }

                if phase == .outgoing,
                   let answer = signals.last(where: { $0.callID == callID && $0.kind == "answer" && $0.sender != me }) {
                    phase = .connecting
                    peerName = answer.sender
                    if let peer {
                        try? await setRemote(peer, RTCSessionDescription(type: .answer, sdp: answer.sdp))
                    }
                }

                if phase == .outgoing, Date.now.timeIntervalSince(started) > 45 {
                    await store.sendCallSignal(kind: "hangup", callID: callID, sdp: "")
                    reset("No answer")
                    return
                }

                try? await Task.sleep(for: .seconds(0.8))
            }
        }
    }

    // MARK: - Audio routing

    private func applySpeaker() {
        let session = AVAudioSession.sharedInstance()
        try? session.overrideOutputAudioPort(speakerOn ? .speaker : .none)
    }

    fileprivate func callConnected() {
        if phase == .connecting || phase == .outgoing {
            phase = .active(Date.now)
            Sfx.bump()
            // Without a CallKit activation (in-app answered/outgoing calls),
            // enable WebRTC audio manually.
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
            try? session.setActive(true)
            RTCAudioSession.sharedInstance().isAudioEnabled = true
            CallKitManager.shared.reportConnected()
            applySpeaker()
        }
    }

    fileprivate func callDropped() {
        switch phase {
        case .connecting, .active:
            reset("Connection lost")
        default:
            break
        }
    }

    private func reset(_ message: String) {
        pollTask?.cancel()
        pollTask = nil
        stopVideo()
        peer?.close()
        peer = nil
        factory = nil
        audioTrack = nil
        videoSource = nil
        localVideoTrack = nil
        remoteVideoTrack = nil
        pendingOfferSDP = nil
        isMuted = false
        speakerOn = true
        CallKitManager.shared.reportEnded()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)

        if message.isEmpty {
            phase = .idle
        } else {
            phase = .ended(message)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if case .ended = phase { phase = .idle }
            }
        }
    }

    // MARK: - SDP helpers

    private func createOffer(_ connection: RTCPeerConnection) async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            let constraints = RTCMediaConstraints(
                mandatoryConstraints: ["OfferToReceiveAudio": "true"], optionalConstraints: nil
            )
            connection.offer(for: constraints) { sdp, error in
                if let sdp {
                    continuation.resume(returning: sdp)
                } else {
                    continuation.resume(throwing: error ?? CallError.sdpFailed)
                }
            }
        }
    }

    private func createAnswer(_ connection: RTCPeerConnection) async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            connection.answer(for: constraints) { sdp, error in
                if let sdp {
                    continuation.resume(returning: sdp)
                } else {
                    continuation.resume(throwing: error ?? CallError.sdpFailed)
                }
            }
        }
    }

    private func setLocal(_ connection: RTCPeerConnection, _ sdp: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.setLocalDescription(sdp) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func setRemote(_ connection: RTCPeerConnection, _ sdp: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.setRemoteDescription(sdp) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Non-trickle ICE: wait briefly until candidates are gathered so the
    /// SDP we upload contains them all (single offer/answer exchange).
    /// Capped short — host/STUN candidates arrive fast, and waiting for slow
    /// TURN allocations just delays connecting.
    private func waitForIceGathering(_ connection: RTCPeerConnection) async {
        for _ in 0..<10 {
            if connection.iceGatheringState == .complete { return }
            try? await Task.sleep(for: .seconds(0.25))
        }
    }
}

// MARK: - WebRTC delegate (connection state → UI phase)

extension CallEngine: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor in
            switch newState {
            case .connected, .completed:
                self.callConnected()
            case .failed, .closed:
                self.callDropped()
            default:
                break
            }
        }
    }

    nonisolated func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didAdd rtpReceiver: RTCRtpReceiver,
        streams mediaStreams: [RTCMediaStream]
    ) {
        if let track = rtpReceiver.track as? RTCVideoTrack {
            Task { @MainActor in
                self.remoteVideoTrack = track
                track.add(self.frameGrabber)
            }
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

// MARK: - Call screen (mute, speaker, hang up; accept/decline when incoming)

/// Renders a WebRTC video track.
struct VideoTrackView: UIViewRepresentable {
    let track: RTCVideoTrack

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView()
        view.videoContentMode = .scaleAspectFill
        track.add(view)
        return view
    }

    func updateUIView(_ view: RTCMTLVideoView, context: Context) {}
}

struct LiveCallView: View {
    @StateObject private var engine = CallEngine.shared
    @State private var snapped = false

    private var showsRemoteVideo: Bool {
        if case .active = engine.phase, engine.remoteVideoTrack != nil { return true }
        return false
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.green.opacity(0.97), Palette.teal.opacity(0.95)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if showsRemoteVideo, let remote = engine.remoteVideoTrack {
                VideoTrackView(track: remote)
                    .id(ObjectIdentifier(remote))
                    .ignoresSafeArea()
            }

            VStack(spacing: 20) {
                if showsRemoteVideo {
                    HStack {
                        Button {
                            Sfx.bump()
                            snapped = engine.snapshotRemoteVideo()
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(1.5))
                                snapped = false
                            }
                        } label: {
                            Image(systemName: snapped ? "checkmark" : "camera.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(.white.opacity(0.25), in: Circle())
                        }
                        .buttonStyle(BouncyButtonStyle())
                        .padding(.leading, 20)
                        Spacer()
                    }
                    .padding(.top, 20)
                }

                if engine.videoOn, let local = engine.localVideoTrack {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            VideoTrackView(track: local)
                                .id(ObjectIdentifier(local))
                                .frame(width: 110, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.6), lineWidth: 2))
                            Button {
                                Sfx.bump(.light)
                                engine.flipCamera()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(.white.opacity(0.25), in: Circle())
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                }

                Spacer()

                if !showsRemoteVideo {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.white)
                        .frame(width: 150, height: 150)
                        .background(.white.opacity(0.2), in: Circle())
                }

                Text(engine.peerName)
                    .font(.rounded(34))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)

                Text(statusText)
                    .font(.rounded(18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 4)

                Spacer()

                controls
                    .padding(.bottom, 50)
            }
        }
    }

    private var statusText: String {
        switch engine.phase {
        case .idle: ""
        case .outgoing: "Calling…"
        case .incoming: "wants to talk!"
        case .connecting: "Connecting…"
        case .active(let since): elapsed(since: since)
        case .ended(let message): message
        }
    }

    private func elapsed(since: Date) -> String {
        let seconds = Int(Date.now.timeIntervalSince(since))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    @ViewBuilder
    private var controls: some View {
        if case .incoming = engine.phase {
            HStack(spacing: 60) {
                roundButton(icon: "phone.down.fill", color: Palette.red, size: 84) {
                    engine.declineIncoming()
                }
                roundButton(icon: "phone.fill", color: Palette.green, size: 84, border: true) {
                    engine.acceptIncoming()
                }
            }
        } else if case .ended = engine.phase {
            EmptyView()
        } else {
            HStack(spacing: 20) {
                roundButton(
                    icon: engine.isMuted ? "mic.slash.fill" : "mic.fill",
                    color: engine.isMuted ? .white : .white.opacity(0.25),
                    iconColor: engine.isMuted ? Palette.ink : .white,
                    size: 62
                ) {
                    engine.isMuted.toggle()
                }

                roundButton(
                    icon: engine.videoOn ? "video.fill" : "video.slash.fill",
                    color: engine.videoOn ? .white : .white.opacity(0.25),
                    iconColor: engine.videoOn ? Palette.ink : .white,
                    size: 62
                ) {
                    engine.toggleVideo()
                }

                roundButton(icon: "phone.down.fill", color: Palette.red, size: 80) {
                    engine.hangUp()
                }

                roundButton(
                    icon: engine.speakerOn ? "speaker.wave.3.fill" : "speaker.slash.fill",
                    color: engine.speakerOn ? .white : .white.opacity(0.25),
                    iconColor: engine.speakerOn ? Palette.ink : .white,
                    size: 62
                ) {
                    engine.speakerOn.toggle()
                }
            }
        }
    }

    private func roundButton(
        icon: String, color: Color, iconColor: Color = .white,
        size: CGFloat, border: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button {
            Sfx.bump(.light)
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: size, height: size)
                .background(color, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: border ? 3 : 0))
        }
        .buttonStyle(BouncyButtonStyle())
    }
}
