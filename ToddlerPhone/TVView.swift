import SwiftUI
import AVKit
import AVFoundation

// MARK: - Video library (parent-managed, stored in app Documents)

@MainActor
final class VideoLibrary: ObservableObject {
    static let shared = VideoLibrary()
    @Published var videos: [URL] = []

    nonisolated static var videosDir: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() { reload() }

    func reload() {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: Self.videosDir, includingPropertiesForKeys: nil
        )) ?? []
        videos = contents
            .filter { ["mov", "mp4", "m4v"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func removeAll() {
        for url in videos { try? FileManager.default.removeItem(at: url) }
        reload()
    }

    nonisolated static func thumbnail(for url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        guard let cgImage = try? await generator.image(at: time).image else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Videos a grown-up sent to the family

/// Keeps the family video list and the downloaded files. The kid phone only
/// ever taps play, so each file is copied into the caches directory the first
/// time it is opened and reused after that instead of coming down again.
@MainActor
final class FamilyVideoCache: ObservableObject {
    static let shared = FamilyVideoCache()

    @Published var videos: [FamilyStore.FamilyVideo] = []
    /// Videos being fetched right now, so their tile can show a spinner.
    @Published var downloading: Set<String> = []

    private static var cacheDir: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FamilyVideos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func cacheURL(for video: FamilyStore.FamilyVideo) -> URL {
        cacheDir.appendingPathComponent("\(video.id).\(video.fileExtension)")
    }

    func refresh() async {
        guard FamilyStore.shared.isConnected else {
            videos = []
            return
        }
        let fetched = await FamilyStore.shared.fetchFamilyVideos()
        // A query that couldn't reach iCloud also comes back empty, so an
        // offline kid phone keeps the list and files it already had.
        guard !fetched.isEmpty || FamilyStore.shared.lastError == nil else { return }
        videos = fetched
        pruneDeleted()
    }

    func cachedFile(for video: FamilyStore.FamilyVideo) -> URL? {
        let url = Self.cacheURL(for: video)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// The playable file: the cached copy when there is one, a download otherwise.
    func file(for video: FamilyStore.FamilyVideo) async -> URL? {
        if let cached = cachedFile(for: video) { return cached }
        downloading.insert(video.id)
        defer { downloading.remove(video.id) }

        guard let downloaded = await FamilyStore.shared.downloadFamilyVideo(id: video.id) else { return nil }
        let destination = Self.cacheURL(for: video)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: downloaded, to: destination)
            return destination
        } catch {
            // Playing straight from CloudKit's own copy still works; it just
            // won't survive to the next time TV is opened.
            return downloaded
        }
    }

    /// Drops files for videos a grown-up has taken down.
    private func pruneDeleted() {
        let keep = Set(videos.map(\.id))
        let files = (try? FileManager.default.contentsOfDirectory(
            at: Self.cacheDir, includingPropertiesForKeys: nil
        )) ?? []
        for file in files where !keep.contains(file.deletingPathExtension().lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

// MARK: - Streamed shows (public domain and open license, from the Internet Archive)

/// A category row in the library. Order here is the order on screen.
enum ShowCategory: String, CaseIterable, Identifiable {
    case modern = "Modern Cartoons"
    case fairyTales = "Fairy Tales"
    case classics = "Classics"

    var id: String { rawValue }
    var title: String { rawValue }

    var tint: Color {
        switch self {
        case .modern: Palette.green
        case .fairyTales: Palette.purple
        case .classics: Palette.orange
        }
    }
}

struct ClassicShow: Identifiable {
    let title: String
    let identifier: String
    let file: String
    let category: ShowCategory
    /// Cosmetic, approximate running time.
    let runtime: String
    var id: String { identifier }

    var streamURL: URL? {
        guard let encoded = file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "https://archive.org/download/\(identifier)/\(encoded)")
    }

    var thumbnailURL: URL? {
        URL(string: "https://archive.org/services/img/\(identifier)")
    }

    static let all: [ClassicShow] = [
        // Blender Foundation open movies (CC-BY), modern and colorful.
        ClassicShow(
            title: "Big Buck Bunny",
            identifier: "BigBuckBunny_124",
            file: "Content/big_buck_bunny_720p_surround.mp4",
            category: .modern,
            runtime: "10 min"
        ),
        ClassicShow(
            title: "Llama Drama",
            identifier: "Caminandes1LlamaDrama",
            file: "01_llama_drama_1080p.mp4",
            category: .modern,
            runtime: "2 min"
        ),
        ClassicShow(
            title: "Gran Dillama",
            identifier: "Caminandes2GranDillama",
            file: "02_gran_dillama_1080p.mp4",
            category: .modern,
            runtime: "2 min"
        ),
        ClassicShow(
            title: "Llamigos",
            identifier: "CaminandesLlamigos",
            file: "Caminandes_ Llamigos-1080p.mp4",
            category: .modern,
            runtime: "4 min"
        ),
        // ComiColor storybook cartoons (Ub Iwerks, 1934 to 1936).
        ClassicShow(
            title: "The Three Bears",
            identifier: "comi-color-cartoons-1935x-07-the-three-bears",
            file: "ComiColor Cartoons - 1935x07 - The Three Bears.mp4",
            category: .fairyTales,
            runtime: "8 min"
        ),
        ClassicShow(
            title: "Humpty Dumpty",
            identifier: "comi-color-cartoons-1935x-10-humpty-dumpty",
            file: "ComiColor Cartoons - 1935x10 - Humpty Dumpty.mp4",
            category: .fairyTales,
            runtime: "8 min"
        ),
        ClassicShow(
            title: "Tom Thumb",
            identifier: "comi-color-cartoons-1936x-02-tom-thumb",
            file: "ComiColor Cartoons - 1936x02 - Tom Thumb.mp4",
            category: .fairyTales,
            runtime: "8 min"
        ),
        ClassicShow(
            title: "Sinbad the Sailor",
            identifier: "comi-color-cartoons-1935x-06-sinbad-the-sailor",
            file: "ComiColor Cartoons - 1935x06 - Sinbad the Sailor.mp4",
            category: .fairyTales,
            runtime: "8 min"
        ),
        ClassicShow(
            title: "Simple Simon",
            identifier: "comi-color-cartoons-1935x-09-simple-simon",
            file: "ComiColor Cartoons - 1935x09 - Simple Simon.mp4",
            category: .fairyTales,
            runtime: "7 min"
        ),
        ClassicShow(
            title: "The Brave Tin Soldier",
            identifier: "comi-color-cartoons-1934x-02-the-brave-tin-soldier",
            file: "ComiColor Cartoons - 1934x02 - The Brave Tin Soldier.mp4",
            category: .fairyTales,
            runtime: "8 min"
        ),
        ClassicShow(
            title: "Little Boy Blue",
            identifier: "ytdown-you-tube-little-boy-blue-1936-full-hd-comi-color-c-media-4wr-0-v-02-cf-ou-003-360p",
            file: "YTDown_YouTube_Little-Boy-Blue-1936-Full-HD-ComiColor-C_Media_4wr0V02CfOU_003_360p.mp4",
            category: .fairyTales,
            runtime: "7 min"
        ),
        // Black and white favorites.
        ClassicShow(
            title: "Steamboat Willie",
            identifier: "steamboat-willie-mickey",
            file: "01 - Steamboat Willie.mp4",
            category: .classics,
            runtime: "8 min"
        ),
        ClassicShow(
            title: "Casper the Friendly Ghost",
            identifier: "TheFriendlyGhost",
            file: "TheFriendlyGhost_512kb.mp4",
            category: .classics,
            runtime: "8 min"
        ),
        ClassicShow(
            title: "Felix the Cat",
            identifier: "felix-the-cat-cartoons",
            file: "Felix The Cat Felix Gets Revenge.mp4",
            category: .classics,
            runtime: "7 min"
        ),
    ]

    static func shows(in category: ShowCategory) -> [ClassicShow] {
        all.filter { $0.category == category }
    }

    /// One show picked per app launch for the featured banner.
    static let featured: ClassicShow = all.randomElement() ?? all[0]
}

// MARK: - Poster cache (one download per show, decode off the main thread)

@MainActor
final class PosterCache: ObservableObject {
    static let shared = PosterCache()

    private var images: [String: UIImage] = [:]
    private var loads: [String: Task<UIImage?, Never>] = [:]

    /// Returns the poster, downloading it once and reusing it afterwards.
    func poster(for show: ClassicShow) async -> UIImage? {
        let key = show.identifier
        if let cached = images[key] { return cached }
        if let running = loads[key] { return await running.value }
        guard let url = show.thumbnailURL else { return nil }

        let load = Task<UIImage?, Never> { await Self.fetch(url) }
        loads[key] = load
        let image = await load.value
        loads[key] = nil
        if let image { images[key] = image }
        return image
    }

    nonisolated private static func fetch(_ url: URL) async -> UIImage? {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return await Task.detached(priority: .utility) {
            guard let image = UIImage(data: data) else { return nil }
            return image.preparingForDisplay() ?? image
        }.value
    }
}

// MARK: - TV screen

enum ChannelKind: String, CaseIterable, Identifiable {
    case fishTank, danceParty, starryNight
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fishTank: "Fish Tank"
        case .danceParty: "Dance Party"
        case .starryNight: "Starry Night"
        }
    }

    var symbol: String {
        switch self {
        case .fishTank: "fish.fill"
        case .danceParty: "music.note"
        case .starryNight: "moon.stars.fill"
        }
    }

    var color: Color {
        switch self {
        case .fishTank: Palette.teal
        case .danceParty: Palette.pink
        case .starryNight: Palette.indigo
        }
    }
}

struct TVView: View {
    @StateObject private var library = VideoLibrary.shared
    @StateObject private var familyVideos = FamilyVideoCache.shared
    @State private var selection: TVSelection?
    @AppStorage("classicsEnabled") private var classicsEnabled = true

    enum TVSelection: Identifiable {
        case channel(ChannelKind)
        case video(URL)

        var id: String {
            switch self {
            case .channel(let kind): "channel-\(kind.rawValue)"
            case .video(let url): "video-\(url.lastPathComponent)"
            }
        }
    }

    /// Width of one poster card. Cards are 16:9.
    private static let cardWidth: CGFloat = 208

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 8) {
                TopBar(title: "TV")

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if classicsEnabled {
                            FeaturedBanner(show: ClassicShow.featured) {
                                play(ClassicShow.featured)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                        }

                        channelsRow

                        if classicsEnabled {
                            ForEach(ShowCategory.allCases) { category in
                                showRow(category)
                            }
                        }

                        // Only there when a grown-up has actually sent
                        // something, so an empty family leaves no gap.
                        if !familyVideos.videos.isEmpty {
                            familyRow
                        }

                        myShowsRow
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear { library.reload() }
        .task { await familyVideos.refresh() }
        .fullScreenCover(item: $selection) { selection in
            switch selection {
            case .channel(let kind): ChannelPlayerView(kind: kind)
            case .video(let url): VideoPlayerScreen(url: url)
            }
        }
    }

    // MARK: Rows

    private var channelsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Channels")
            horizontalRow {
                ForEach(ChannelKind.allCases) { channel in
                    Button {
                        Sfx.tap()
                        selection = .channel(channel)
                    } label: {
                        ChannelCard(channel: channel, width: Self.cardWidth)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }
        }
    }

    private func showRow(_ category: ShowCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(category.title)
            horizontalRow {
                ForEach(ClassicShow.shows(in: category)) { show in
                    Button {
                        play(show)
                    } label: {
                        ShowPosterCard(show: show, width: Self.cardWidth)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }
        }
    }

    private var familyRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("From your family")
            horizontalRow {
                ForEach(familyVideos.videos) { video in
                    Button {
                        play(video)
                    } label: {
                        FamilyVideoTile(
                            video: video,
                            width: Self.cardWidth,
                            isLoading: familyVideos.downloading.contains(video.id)
                        )
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .disabled(familyVideos.downloading.contains(video.id))
                }
            }
        }
    }

    private var myShowsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("My Shows")
            if library.videos.isEmpty {
                Text("No shows yet! Ask a grown-up to add some from the grown-ups area on the home screen.")
                    .font(.rounded(15, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .card(cornerRadius: 24)
                    .padding(.horizontal, 20)
            } else {
                horizontalRow {
                    ForEach(library.videos, id: \.self) { url in
                        Button {
                            Sfx.tap()
                            selection = .video(url)
                        } label: {
                            VideoThumbnailTile(url: url, width: Self.cardWidth)
                        }
                        .buttonStyle(BouncyButtonStyle())
                    }
                }
            }
        }
    }

    /// Lazy horizontal strip with room at the edges for the card shadows.
    private func horizontalRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
    }

    private func play(_ show: ClassicShow) {
        Sfx.tap()
        if let url = show.streamURL {
            selection = .video(url)
        }
    }

    /// The first tap on a family video may have to fetch it, so the tile spins
    /// and the player opens once the file is here.
    private func play(_ video: FamilyStore.FamilyVideo) {
        Sfx.tap()
        Task {
            if let url = await familyVideos.file(for: video) {
                selection = .video(url)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.rounded(20))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 20)
    }
}

// MARK: - Library artwork

/// Poster artwork for a streamed show, with a soft placeholder while it loads.
struct PosterArtwork: View {
    let show: ClassicShow
    var symbolSize: CGFloat = 28
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Palette.field
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "film.fill")
                    .font(.system(size: symbolSize))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .animation(.easeIn(duration: 0.2), value: image == nil)
        .task(id: show.id) {
            image = await PosterCache.shared.poster(for: show)
        }
    }
}

/// Big 16:9 hero card for the show of the day.
struct FeaturedBanner: View {
    let show: ClassicShow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                PosterArtwork(show: show, symbolSize: 48)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.1), .black.opacity(0.68)],
                    startPoint: .top, endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(show.category.title)
                            .font(.rounded(13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(show.title)
                            .font(.rounded(26))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.leading)
                        Text(show.runtime)
                            .font(.rounded(13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 62, height: 62)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

/// One 16:9 poster card in a category row.
struct ShowPosterCard: View {
    let show: ClassicShow
    var width: CGFloat = 208

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                PosterArtwork(show: show)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.35)],
                    startPoint: .center, endPoint: .bottom
                )

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }
            .frame(width: width, height: width * 9 / 16)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(show.title)
                    .font(.rounded(15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(show.runtime)
                    .font(.rounded(12, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .frame(width: width, alignment: .leading)
        }
    }
}

/// One of the built-in animated channels, styled like a poster card.
struct ChannelCard: View {
    let channel: ChannelKind
    var width: CGFloat = 208

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                channel.color.opacity(0.16)
                Image(systemName: channel.symbol)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(channel.color)
            }
            .frame(width: width, height: width * 9 / 16)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(channel.title)
                    .font(.rounded(15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("Always on")
                    .font(.rounded(12, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .frame(width: width, alignment: .leading)
        }
    }
}

/// A parent-added local video, with a frame grabbed from the file.
struct VideoThumbnailTile: View {
    let url: URL
    var width: CGFloat = 208
    @State private var image: UIImage?

    private var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Palette.field
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "film.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Palette.inkSoft)
                }
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }
            .frame(width: width, height: width * 9 / 16)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            Text(name)
                .font(.rounded(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: width, alignment: .leading)
        }
        .task(id: url) { image = await VideoLibrary.thumbnail(for: url) }
    }
}

/// A video a grown-up sent to the family. Its frame can only be grabbed once
/// the file is cached, so until then it wears the film placeholder.
struct FamilyVideoTile: View {
    let video: FamilyStore.FamilyVideo
    var width: CGFloat = 208
    var isLoading = false
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Palette.purple.opacity(0.16)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "film.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Palette.purple)
                }

                if isLoading {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.4)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
            }
            .frame(width: width, height: width * 9 / 16)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(video.title)
                    .font(.rounded(15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("From \(video.sender)")
                    .font(.rounded(12, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .frame(width: width, alignment: .leading)
        }
        // Keyed on the download too, so the frame appears as soon as the file
        // has landed rather than waiting for the next visit to TV.
        .task(id: "\(video.id)-\(isLoading)") {
            guard let cached = FamilyVideoCache.shared.cachedFile(for: video) else { return }
            image = await VideoLibrary.thumbnail(for: cached)
        }
    }
}

// MARK: - Video player (play/pause, skip, scrubbing; loops at the end)

struct VideoPlayerScreen: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player = AVPlayer()
    @State private var isPlaying = true
    @State private var duration: Double = 0
    @State private var current: Double = 0
    @State private var isScrubbing = false
    @State private var timeObserver: Any?
    @State private var endObserver: (any NSObjectProtocol)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PlayerLayerView(player: player)
                .ignoresSafeArea()
                .onTapGesture { togglePlayback() }

            VStack {
                HStack {
                    Button {
                        Sfx.tap()
                        dismiss()
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

                controls
            }
        }
        .onAppear { start() }
        .onDisappear { stop() }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(timeString(current))
                    .frame(width: 52, alignment: .leading)
                Slider(
                    value: $current,
                    in: 0...max(duration, 1)
                ) { editing in
                    isScrubbing = editing
                    if !editing {
                        player.seek(
                            to: CMTime(seconds: current, preferredTimescale: 600),
                            toleranceBefore: .zero, toleranceAfter: .zero
                        )
                    }
                }
                .tint(.white)
                Text(timeString(duration))
                    .frame(width: 52, alignment: .trailing)
            }
            .font(.rounded(13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 44) {
                controlButton(icon: "gobackward.10", size: 30) { skip(-10) }
                controlButton(icon: isPlaying ? "pause.fill" : "play.fill", size: 40) {
                    togglePlayback()
                }
                controlButton(icon: "goforward.10", size: 30) { skip(10) }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 26))
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func controlButton(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            Sfx.bump(.light)
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private func start() {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { time in
            if !isScrubbing { current = time.seconds }
            if let itemDuration = player.currentItem?.duration.seconds,
               itemDuration.isFinite {
                duration = itemDuration
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }

    private func stop() {
        player.pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    private func skip(_ seconds: Double) {
        let target = max(0, min(duration, current + seconds))
        current = target
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero, toleranceAfter: .zero
        )
    }

    private func togglePlayback() {
        Sfx.bump(.light)
        withAnimation(.spring(response: 0.3)) {
            if isPlaying { player.pause() } else { player.play() }
            isPlaying.toggle()
        }
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        view.playerLayer.player = player
    }
}

// MARK: - Built-in animated channels (drawn with symbols and shapes)

struct ChannelPlayerView: View {
    let kind: ChannelKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GeometryReader { geo in
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    switch kind {
                    case .fishTank: FishTankScene(t: t, size: geo.size)
                    case .danceParty: DancePartyScene(t: t, size: geo.size)
                    case .starryNight: StarryNightScene(t: t, size: geo.size)
                    }
                }
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        Sfx.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.black.opacity(0.25), in: Circle())
                    }
                    .buttonStyle(BouncyButtonStyle())
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                Spacer()
            }
        }
    }
}

struct FishTankScene: View {
    let t: TimeInterval
    let size: CGSize

    private static let fishColors: [Color] = [
        Palette.orange, Palette.yellow, Palette.pink, Palette.purple, Palette.red, Palette.teal,
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.45, blue: 0.65), Color(red: 0.06, green: 0.25, blue: 0.45)],
                startPoint: .top, endPoint: .bottom
            )

            ForEach(0..<6, id: \.self) { i in
                let speed = 35.0 + Double(i) * 14
                let travel = size.width + 140
                let progress = (t * speed + Double(i) * 240).truncatingRemainder(dividingBy: travel)
                let goesRight = i.isMultiple(of: 2)
                let x = goesRight ? progress - 70 : size.width - progress + 70
                let y = size.height * (0.15 + 0.12 * CGFloat(i)) + sin(t * 1.4 + Double(i)) * 14

                Image(systemName: "fish.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Self.fishColors[i])
                    .scaleEffect(x: goesRight ? -1 : 1)
                    .position(x: x, y: y)
            }

            // Bubbles
            ForEach(0..<6, id: \.self) { i in
                let rise = (t * 40 + Double(i) * 150).truncatingRemainder(dividingBy: size.height + 80)
                Circle()
                    .stroke(.white.opacity(0.45), lineWidth: 2)
                    .frame(width: 10 + CGFloat(i % 3) * 6)
                    .position(
                        x: size.width * (0.12 + 0.15 * CGFloat(i)) + sin(t + Double(i) * 2) * 10,
                        y: size.height + 40 - rise
                    )
            }

            // Seaweed
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Palette.green.opacity(0.8))
                    .rotationEffect(.degrees(sin(t + Double(i)) * 10 - 20 + Double(i) * 12))
                    .position(x: size.width * (0.15 + 0.23 * CGFloat(i)), y: size.height - 46)
            }
        }
    }
}

struct DancePartyScene: View {
    let t: TimeInterval
    let size: CGSize

    private static let colors: [Color] = [
        Palette.pink, Palette.blue, Palette.yellow, Palette.purple, Palette.teal, Palette.orange,
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.2, blue: 0.5), Color(red: 0.55, green: 0.25, blue: 0.5)],
                startPoint: .top, endPoint: .bottom
            )
            .hueRotation(.degrees(t * 18))

            // Pulsing spotlight circles
            ForEach(0..<3, id: \.self) { i in
                let beat = t * 2 + Double(i)
                Circle()
                    .fill(Self.colors[i].opacity(0.18))
                    .frame(width: 220 + CGFloat(sin(beat)) * 40)
                    .position(
                        x: size.width * (0.2 + 0.3 * CGFloat(i)),
                        y: size.height * (0.3 + 0.15 * CGFloat(i % 2))
                    )
            }

            // Bouncing music notes
            ForEach(0..<6, id: \.self) { i in
                let beat = t * 3.2 + Double(i) * 0.7
                let col = i % 3
                let row = i / 3
                Image(systemName: i.isMultiple(of: 2) ? "music.note" : "music.quarternote.3")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Self.colors[i])
                    .rotationEffect(.degrees(sin(beat * 0.9) * 14))
                    .position(
                        x: size.width * (0.25 + 0.25 * CGFloat(col)),
                        y: size.height * (0.45 + 0.24 * CGFloat(row)) - abs(sin(beat)) * 46
                    )
            }
        }
    }
}

struct StarryNightScene: View {
    let t: TimeInterval
    let size: CGSize

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.18), Color(red: 0.10, green: 0.09, blue: 0.32)],
                startPoint: .top, endPoint: .bottom
            )

            ForEach(0..<24, id: \.self) { i in
                let fx = abs(sin(Double(i) * 127.3))
                let fy = abs(sin(Double(i) * 311.7))
                Image(systemName: "star.fill")
                    .font(.system(size: 7 + CGFloat(i % 4) * 4))
                    .foregroundStyle(.white)
                    .opacity(0.25 + 0.7 * abs(sin(t * 1.2 + Double(i))))
                    .position(x: size.width * fx, y: size.height * (0.05 + 0.6 * fy))
            }

            // Shooting star
            let shootPhase = t.truncatingRemainder(dividingBy: 6)
            if shootPhase < 1.2 {
                Image(systemName: "sparkle")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .position(
                        x: size.width * (0.1 + shootPhase * 0.7),
                        y: size.height * (0.15 + shootPhase * 0.2)
                    )
                    .opacity(1 - shootPhase / 1.2)
            }

            Image(systemName: "moon.fill")
                .font(.system(size: 70))
                .foregroundStyle(Palette.yellow.opacity(0.9))
                .position(x: size.width * 0.8, y: size.height * 0.14)

            // Treeline
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: "tree.fill")
                    .font(.system(size: 64 + CGFloat(i % 2) * 22))
                    .foregroundStyle(Color(red: 0.05, green: 0.15, blue: 0.12))
                    .position(x: size.width * (0.1 + 0.2 * CGFloat(i)), y: size.height * 0.92)
            }
        }
    }
}
