import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Fun filters

enum KidFilter: String, CaseIterable, Identifiable {
    case none, comic, mono, sepia, xray

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "Normal"
        case .comic: "Comic"
        case .mono: "Old Timey"
        case .sepia: "Golden"
        case .xray: "Silly"
        }
    }

    var icon: String {
        switch self {
        case .none: "camera.fill"
        case .comic: "paintpalette.fill"
        case .mono: "circle.lefthalf.filled"
        case .sepia: "sun.max.fill"
        case .xray: "sparkles"
        }
    }

    func apply(to image: CIImage) -> CIImage {
        switch self {
        case .none:
            return image
        case .comic:
            let filter = CIFilter.comicEffect()
            filter.inputImage = image
            return filter.outputImage ?? image
        case .mono:
            let filter = CIFilter.photoEffectNoir()
            filter.inputImage = image
            return filter.outputImage ?? image
        case .sepia:
            let filter = CIFilter.sepiaTone()
            filter.inputImage = image
            filter.intensity = 0.9
            return filter.outputImage ?? image
        case .xray:
            let filter = CIFilter.colorInvert()
            filter.inputImage = image
            return filter.outputImage ?? image
        }
    }
}

// MARK: - Photo storage (app-private folder, never the system photo library)

@MainActor
final class KidPhotoStore: ObservableObject {
    static let shared = KidPhotoStore()
    @Published var photos: [URL] = []

    nonisolated static var dir: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KidPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() { reload() }

    func reload() {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: Self.dir, includingPropertiesForKeys: nil
        )) ?? []
        photos = contents
            .filter { $0.pathExtension.lowercased() == "jpg" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func save(_ data: Data) {
        let name = String(format: "photo-%.0f.jpg", Date.now.timeIntervalSince1970 * 1000)
        let url = Self.dir.appendingPathComponent(name)
        try? data.write(to: url)
        reload()
        // Every photo also lands on the family photo wall for the grown-ups.
        if FamilyStore.shared.isConnected {
            Task { await FamilyStore.shared.uploadKidPhoto(fileURL: url) }
        }
    }

    func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        reload()
    }
}

// MARK: - Camera controller

@MainActor
final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published var noCamera = false
    @Published var filter: KidFilter = .none {
        didSet { filterForFrames = filter }
    }
    /// Live filtered preview frame (used when a filter is active).
    @Published var filteredFrame: CGImage?

    private let output = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var position: AVCaptureDevice.Position = .back
    nonisolated(unsafe) private var filterForFrames: KidFilter = .none
    nonisolated(unsafe) private let ciContext = CIContext()
    private let videoQueue = DispatchQueue(label: "camera.frames")

    func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            noCamera = true
            return
        }
        configure()
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    func stop() {
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
    }

    func flip() {
        position = position == .back ? .front : .back
        configure()
    }

    func capture() {
        guard !noCamera else { return }
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.inputs.forEach { session.removeInput($0) }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            noCamera = true
            return
        }
        if session.canAddInput(input) { session.addInput(input) }
        if !session.outputs.contains(where: { $0 === output }), session.canAddOutput(output) {
            session.addOutput(output)
        }
        if !session.outputs.contains(where: { $0 === videoOutput }), session.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            session.addOutput(videoOutput)
        }
        session.commitConfiguration()
        frontCamera = position == .front
        noCamera = false
    }

    nonisolated(unsafe) private var frontCamera = false

    // Live frames for the filtered preview.
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let currentFilter = filterForFrames
        guard currentFilter != .none,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            if currentFilter == .none {
                Task { @MainActor in self.filteredFrame = nil }
            }
            return
        }
        // Camera buffers arrive landscape; rotate to portrait (and mirror the
        // front camera so the preview behaves like a mirror).
        let upright = CIImage(cvPixelBuffer: pixelBuffer)
            .oriented(frontCamera ? .leftMirrored : .right)
        let image = currentFilter.apply(to: upright)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return }
        Task { @MainActor in self.filteredFrame = cgImage }
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in
            KidPhotoStore.shared.save(self.processCapture(data))
            Sfx.tap()
            Sfx.bump()
        }
    }

    /// Applies the active filter to the captured photo.
    private func processCapture(_ data: Data) -> Data {
        guard filter != .none,
              let ciImage = CIImage(data: data, options: [.applyOrientationProperty: true])
        else { return data }
        let filtered = filter.apply(to: ciImage)
        guard let cgImage = ciContext.createCGImage(filtered, from: filtered.extent) else { return data }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.85) ?? data
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}

// MARK: - Kid camera screen

struct KidCameraView: View {
    @StateObject private var camera = CameraController()
    @StateObject private var photoStore = KidPhotoStore.shared
    @State private var flash = false
    @State private var showGallery = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 14) {
                TopBar(title: "Camera")

                ZStack {
                    if camera.noCamera {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Palette.inkSoft)
                            Text("The camera needs a real iPhone!")
                                .font(.rounded(16, weight: .semibold))
                                .foregroundStyle(Palette.inkSoft)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.field)
                    } else if camera.filter != .none, let frame = camera.filteredFrame {
                        GeometryReader { geo in
                            Image(decorative: frame, scale: 1)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        }
                    } else {
                        CameraPreview(session: camera.session)
                    }

                    if flash {
                        Color.white
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                .padding(.horizontal, 20)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(KidFilter.allCases) { kidFilter in
                            Button {
                                Sfx.tap()
                                camera.filter = kidFilter
                            } label: {
                                Label(kidFilter.label, systemImage: kidFilter.icon)
                                    .font(.rounded(14, weight: .semibold))
                                    .foregroundStyle(camera.filter == kidFilter ? .white : Palette.ink)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        camera.filter == kidFilter
                                            ? AnyShapeStyle(Palette.teal)
                                            : AnyShapeStyle(Palette.card),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }

                HStack(spacing: 40) {
                    // Gallery (last photo as thumbnail)
                    Button {
                        Sfx.tap()
                        showGallery = true
                    } label: {
                        if let latest = photoStore.photos.first,
                           let image = UIImage(contentsOfFile: latest.path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Palette.inkSoft)
                                .frame(width: 56, height: 56)
                                .card(cornerRadius: 16)
                        }
                    }
                    .buttonStyle(BouncyButtonStyle())

                    // Big shutter
                    Button {
                        takePhoto()
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 82, height: 82)
                            .overlay(Circle().stroke(Palette.teal, lineWidth: 5))
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                    }
                    .buttonStyle(BouncyButtonStyle())

                    // Flip
                    Button {
                        Sfx.tap()
                        camera.flip()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 56, height: 56)
                            .card(cornerRadius: 16)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
                .padding(.bottom, 16)
            }
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .fullScreenCover(isPresented: $showGallery) {
            KidGalleryView()
        }
    }

    private func takePhoto() {
        camera.capture()
        flash = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.12))
            withAnimation(.easeOut(duration: 0.25)) { flash = false }
        }
    }
}

// MARK: - Family photo wall (parent side: every kid photo + call snapshots)

struct FamilyPhotoWallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [FamilyStore.SharedPhoto] = []
    @State private var loading = true

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    CloseButton { dismiss() }
                    Spacer()
                    Text("Photo Wall")
                        .font(.rounded(26))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Color.clear.frame(width: 52, height: 52)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                if loading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if photos.isEmpty {
                    Spacer()
                    Text("No photos yet. Every picture from the kid camera shows up here.")
                        .font(.rounded(16, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(photos) { photo in
                                if let url = photo.fileURL,
                                   let image = UIImage(contentsOfFile: url.path) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 170)
                                            .frame(maxWidth: .infinity)
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                        Text("\(photo.sender) · \(photo.sentAt.formatted(.relative(presentation: .named)))")
                                            .font(.rounded(11, weight: .semibold))
                                            .foregroundStyle(Palette.inkSoft)
                                            .padding(.horizontal, 4)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .task {
            photos = await FamilyStore.shared.fetchKidPhotos()
            loading = false
        }
    }
}

// MARK: - Gallery

struct KidGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var photoStore = KidPhotoStore.shared
    @StateObject private var familyStore = FamilyStore.shared
    @State private var selected: URL?
    @State private var sent = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    CloseButton { dismiss() }
                    Spacer()
                    Text("My Photos")
                        .font(.rounded(26))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Color.clear.frame(width: 52, height: 52)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                if photoStore.photos.isEmpty {
                    Spacer()
                    Text("No photos yet. Go take some!")
                        .font(.rounded(17, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                            spacing: 10
                        ) {
                            ForEach(photoStore.photos, id: \.self) { url in
                                Button {
                                    Sfx.tap()
                                    selected = url
                                } label: {
                                    if let image = UIImage(contentsOfFile: url.path) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 110)
                                            .frame(maxWidth: .infinity)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    }
                                }
                                .buttonStyle(BouncyButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }

            if let url = selected {
                photoDetail(url)
            }
        }
    }

    private func photoDetail(_ url: URL) -> some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Button {
                        Sfx.tap()
                        selected = nil
                        sent = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.white.opacity(0.2), in: Circle())
                    }
                    .buttonStyle(BouncyButtonStyle())
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                if let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .padding(.horizontal, 20)
                }

                Spacer()

                HStack(spacing: 24) {
                    if familyStore.isConnected {
                        Button {
                            Sfx.bump()
                            sent = true
                            Task {
                                await FamilyStore.shared.sendPhoto(fileURL: url)
                                Speaker.shared.say("Photo sent to your family!")
                            }
                        } label: {
                            Label(sent ? "Sent!" : "Send to family", systemImage: sent ? "checkmark" : "paperplane.fill")
                                .font(.rounded(17))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 14)
                                .background(sent ? Palette.green : Palette.blue, in: Capsule())
                        }
                        .buttonStyle(BouncyButtonStyle())
                        .disabled(sent)
                    }

                    Button {
                        Sfx.tap()
                        photoStore.delete(url)
                        selected = nil
                        sent = false
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Palette.red, in: Circle())
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
                .padding(.bottom, 40)
            }
        }
    }
}
