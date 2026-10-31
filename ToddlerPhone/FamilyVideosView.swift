import SwiftUI
import PhotosUI

// MARK: - Family videos (grown-up side)
//
// A grown-up picks a video from their own photo library, titles it and sends
// it to the family. It lands in the TV app on every kid phone under "From your
// family". Deleting one here takes it off all of them.

struct FamilyVideosView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var familyStore = FamilyStore.shared

    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedFile: URL?
    @State private var pickedThumbnail: UIImage?
    @State private var preparing = false
    @State private var title = ""
    @State private var uploading = false
    @State private var progress: Double = 0
    @State private var sentConfirmation = false
    @State private var videos: [FamilyStore.FamilyVideo] = []
    @State private var loading = true
    @State private var pendingDeletion: FamilyStore.FamilyVideo?
    @State private var deleting: String?

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                ScrollView {
                    VStack(spacing: 14) {
                        sendCard
                        sharedList
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .onChange(of: pickedItem) { _ in loadPickedVideo() }
        .alert(
            "Delete \"\(pendingDeletion?.title ?? "")\"?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let video = pendingDeletion { delete(video) }
                pendingDeletion = nil
            }
            Button("Keep", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("It disappears from the TV app on every phone in the family.")
        }
        .task { await reload() }
    }

    private var header: some View {
        HStack {
            CloseButton { dismiss() }
            Spacer()
            Text("Family Videos")
                .font(.rounded(24))
                .foregroundStyle(Palette.ink)
            Spacer()
            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: Sending a new one

    private var sendCard: some View {
        VStack(spacing: 14) {
            Text("Pick a video from your photos and it shows up in the TV app on your kid's phone.")
                .font(.rounded(14, weight: .medium))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)

            PhotosPicker(selection: $pickedItem, matching: .videos, photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    if preparing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Palette.purple)
                        Text("Getting the video…")
                    } else {
                        Image(systemName: "film.stack")
                        Text(pickedFile == nil ? "Choose a video" : "Choose a different one")
                    }
                }
                .font(.rounded(16, weight: .semibold))
                .foregroundStyle(Palette.purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Palette.purple.opacity(0.13), in: Capsule())
            }
            .disabled(preparing || uploading)

            if pickedFile != nil {
                pickedPreview

                TextField("Give it a title", text: $title)
                    .font(.rounded(17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Palette.field, in: RoundedRectangle(cornerRadius: 16))
                    .disabled(uploading)

                if uploading {
                    // Videos are big, so the bar shows the real upload fraction
                    // instead of letting the screen look stuck.
                    VStack(spacing: 6) {
                        ProgressView(value: progress)
                            .tint(Palette.purple)
                        Text("Sending… \(Int(progress * 100))%")
                            .font(.rounded(13, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }

                sendButton
            }

            if let error = familyStore.lastError {
                Text(error)
                    .font(.rounded(13, weight: .medium))
                    .foregroundStyle(Palette.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .card(cornerRadius: 26)
    }

    private var pickedPreview: some View {
        ZStack {
            Palette.field
            if let pickedThumbnail {
                Image(uiImage: pickedThumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "film.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var sendButton: some View {
        Button {
            upload()
        } label: {
            HStack(spacing: 8) {
                if uploading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("Sending…")
                } else {
                    Image(systemName: sentConfirmation ? "checkmark" : "paperplane.fill")
                    Text(sentConfirmation ? "Sent!" : "Send to the family")
                }
            }
            .font(.rounded(17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                sentConfirmation ? Palette.green : (uploading ? Palette.purple.opacity(0.75) : Palette.purple),
                in: Capsule()
            )
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(uploading || sentConfirmation)
    }

    // MARK: Already shared

    private var sharedList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shared with the family")
                .font(.rounded(19))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 4)

            if loading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Looking…")
                        .font(.rounded(14, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .card(cornerRadius: 22)
            } else if videos.isEmpty {
                Text("Nothing shared yet. The videos you send show up here so you can take them down again later.")
                    .font(.rounded(14, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .card(cornerRadius: 22)
            } else {
                ForEach(videos) { video in
                    videoRow(video)
                }
            }
        }
    }

    private func videoRow(_ video: FamilyStore.FamilyVideo) -> some View {
        HStack(spacing: 12) {
            SymbolAvatar(symbol: "play.rectangle.fill", color: Palette.purple, size: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.rounded(16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Text("\(video.sender) · \(video.sentAt.formatted(.relative(presentation: .named)))")
                    .font(.rounded(13, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
            }

            Spacer(minLength: 8)

            if deleting == video.id {
                ProgressView()
            } else {
                Button {
                    Sfx.tap()
                    pendingDeletion = video
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.red)
                        .frame(width: 42, height: 42)
                        .background(Palette.red.opacity(0.12), in: Circle())
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
        .padding(12)
        .card(cornerRadius: 22)
    }

    // MARK: Actions

    private func reload() async {
        videos = await familyStore.fetchFamilyVideos()
        loading = false
    }

    /// Copies the picked library video somewhere we can hand to CloudKit, and
    /// grabs a frame for the preview.
    private func loadPickedVideo() {
        guard let item = pickedItem else { return }
        preparing = true
        pickedFile = nil
        pickedThumbnail = nil
        sentConfirmation = false
        progress = 0
        Task {
            let picked = try? await item.loadTransferable(type: PickedFamilyVideo.self)
            pickedFile = picked?.url
            preparing = false
            if let url = picked?.url {
                if title.trimmingCharacters(in: .whitespaces).isEmpty {
                    title = Self.suggestedTitle
                }
                pickedThumbnail = await VideoLibrary.thumbnail(for: url)
            }
        }
    }

    private func upload() {
        guard let fileURL = pickedFile, !uploading, !sentConfirmation else { return }
        let name = title.trimmingCharacters(in: .whitespaces)
        Sfx.bump()
        uploading = true
        progress = 0

        Task {
            let sent = await familyStore.uploadFamilyVideo(
                fileURL: fileURL,
                title: name.isEmpty ? Self.suggestedTitle : name
            ) { fraction in
                progress = fraction
            }
            uploading = false
            guard sent else { return }

            sentConfirmation = true
            await reload()
            try? FileManager.default.removeItem(at: fileURL)
            try? await Task.sleep(for: .seconds(2))
            // Back to a clean slate so the next video starts from scratch.
            sentConfirmation = false
            pickedItem = nil
            pickedFile = nil
            pickedThumbnail = nil
            title = ""
            progress = 0
        }
    }

    private func delete(_ video: FamilyStore.FamilyVideo) {
        deleting = video.id
        Task {
            await familyStore.deleteFamilyVideo(id: video.id)
            await reload()
            deleting = nil
        }
    }

    /// A friendly default so a grown-up in a hurry can just hit send.
    private static var suggestedTitle: String {
        "Video from \(FamilyStore.shared.displayName.isEmpty ? "the family" : FamilyStore.shared.displayName)"
    }
}

/// Copies a picked photo-library video into a temporary file we can upload.
/// Separate from `ImportedVideo` so family videos never land in the kid
/// phone's own "My Shows" folder.
struct PickedFamilyVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("family-video-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedFamilyVideo(url: dest)
        }
    }
}
