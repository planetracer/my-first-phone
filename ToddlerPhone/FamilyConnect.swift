import SwiftUI
import CloudKit
import AVFoundation
import UserNotifications

// MARK: - Family store (CloudKit-backed in-app chat between family phones)

struct FamilyMessage: Identifiable, Equatable {
    enum Kind: String {
        case text, voice, ring, photo
    }

    let id: String
    let sender: String
    let kind: Kind
    let text: String
    let audioURL: URL?
    let sentAt: Date
    /// Empty string = the whole family; otherwise a member's name (direct message).
    var to: String = ""
}

@MainActor
final class FamilyStore: ObservableObject {
    static let shared = FamilyStore()

    @Published var code: String? = UserDefaults.standard.string(forKey: "familyCode") {
        didSet { UserDefaults.standard.set(code, forKey: "familyCode") }
    }
    @Published var displayName: String = UserDefaults.standard.string(forKey: "familyName") ?? "" {
        didSet { UserDefaults.standard.set(displayName, forKey: "familyName") }
    }
    @Published var messages: [FamilyMessage] = []
    @Published var lastError: String?
    /// Other family members (from their status beacons) — the kid's "contacts".
    @Published var members: [DeviceStatus] = []
    /// Latest "read up to" timestamps of other family members, by name.
    @Published var readReceipts: [String: Date] = [:]
    private var seenRingID: String?
    private var lastReceiptPush = Date.distantPast

    var isConnected: Bool { code != nil }

    // CKContainer throws an ObjC exception when the app lacks the iCloud
    // entitlement — trapped via the shim so we degrade to an error message.
    private var cachedContainer: CKContainer?

    private var container: CKContainer {
        get throws {
            if let cachedContainer { return cachedContainer }
            let container = TPCatchException {
                CKContainer(identifier: "iCloud.com.family.ToddlerPhone")
            } as? CKContainer
            guard let container else { throw CloudUnavailable() }
            cachedContainer = container
            return container
        }
    }

    var database: CKDatabase {
        get throws { try container.publicCloudDatabase }
    }

    struct CloudUnavailable: Error {}

    /// Step-by-step connection diagnostic shown in settings and the dashboard.
    func connectionTest() async -> String {
        guard let code else {
            return "❌ No family code yet. Create or join a family first."
        }

        // 1. Does this build have iCloud at all?
        let db: CKDatabase
        let ckContainer: CKContainer
        do {
            ckContainer = try container
            db = try database
        } catch {
            return "❌ This build has no iCloud access. In Xcode: select the ToddlerPhone target → Signing & Capabilities → pick your Team (paid Apple Developer account), then reinstall on both phones."
        }

        // 2. Is the device signed into iCloud?
        let status = (try? await ckContainer.accountStatus()) ?? .couldNotDetermine
        switch status {
        case .available:
            break
        case .noAccount:
            return "❌ This device isn't signed into iCloud. Open Settings → sign in with an Apple ID, then try again."
        case .restricted:
            return "❌ iCloud is restricted on this device (Screen Time or profile settings)."
        default:
            return "❌ Couldn't reach iCloud. Check the internet connection and that iCloud is signed in, then try again."
        }

        // 3. Can we save?
        let ping = CKRecord(recordType: "FamilyPing")
        ping["code"] = code
        ping["sentAt"] = Date.now
        do {
            try await db.save(ping)
        } catch {
            return "❌ Saving to iCloud failed: \(error.localizedDescription)\nIf this mentions the container, open Xcode → Signing & Capabilities and confirm the iCloud container exists for your team."
        }

        // 4. Can we query? (This is where missing indexes show up.)
        do {
            let query = CKQuery(recordType: "FamilyPing", predicate: NSPredicate(format: "code == %@", code))
            _ = try await db.records(matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1)
        } catch {
            return "⚠️ Saving works but searching doesn't, which means CloudKit needs indexes. Go to icloud.developer.apple.com → your container → Development → Indexes, and for EACH record type (FamilyMessage, CallSignal, FamilyStatus, FamilyReceipt, FamilyPing) add a QUERYABLE index on the 'code' field. Then run this test again.\n(\(error.localizedDescription))"
        }

        return "✅ iCloud is working! Messages and calls can flow. Remember: the other phone must be online, and calls ring while its app is open or when the call notification is tapped. Run this same test on the other phone too."
    }

    // 8 characters from a 31-symbol alphabet: ~850 trillion combinations,
    // so a family's channel can't be stumbled into by guessing.
    static func newCode() -> String {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<8).map { _ in alphabet.randomElement()! })
    }

    func refresh() async {
        guard let code else { return }
        do {
            let predicate = NSPredicate(format: "code == %@", code)
            let query = CKQuery(recordType: "FamilyMessage", predicate: predicate)
            let (results, _) = try await database.records(

                matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 200
            )
            var fetched: [FamilyMessage] = []
            for (recordID, result) in results {
                if case .success(let record) = result {
                    fetched.append(Self.message(from: record, id: recordID.recordName))
                }
            }
            messages = fetched.sorted { $0.sentAt < $1.sentAt }
            lastError = nil
        } catch {
            lastError = Self.friendly(error)
        }
    }

    func sendText(_ text: String, kind: FamilyMessage.Kind = .text, to recipient: String = "") async {
        await send { record in
            record["text"] = text
            record["kind"] = kind.rawValue
            record["to"] = recipient
        }
        if kind == .text { Sfx.sent() }
    }

    func sendVoice(fileURL: URL, to recipient: String = "") async {
        await send { record in
            record["kind"] = FamilyMessage.Kind.voice.rawValue
            record["text"] = "Voice message"
            record["audio"] = CKAsset(fileURL: fileURL)
            record["to"] = recipient
        }
        Sfx.sent()
    }

    func sendPhoto(fileURL: URL, to recipient: String = "") async {
        await send { record in
            record["kind"] = FamilyMessage.Kind.photo.rawValue
            record["text"] = "Drawing"
            record["audio"] = CKAsset(fileURL: fileURL)
            record["to"] = recipient
        }
        Sfx.sent()
    }

    func ringFamily(to recipient: String = "") async {
        await sendText("rang the family phone", kind: .ring, to: recipient)
        Sfx.ring()
    }

    /// Returns who is ringing us right now (recent ring from someone else), once.
    func incomingRing() -> String? {
        guard let last = messages.last(where: {
                  $0.kind == .ring && ($0.to.isEmpty || $0.to == displayName)
              }),
              last.sender != displayName,
              Date.now.timeIntervalSince(last.sentAt) < 45,
              last.id != seenRingID
        else { return nil }
        seenRingID = last.id
        return last.sender
    }

    // MARK: Family photo wall (kid camera photos + call snapshots)

    struct SharedPhoto: Identifiable {
        let id: String
        let sender: String
        let fileURL: URL?
        let sentAt: Date
    }

    func uploadKidPhoto(fileURL: URL) async {
        guard let code else { return }
        let record = CKRecord(recordType: "KidPhoto")
        record["code"] = code
        record["sender"] = displayName.isEmpty ? "Someone" : displayName
        record["photo"] = CKAsset(fileURL: fileURL)
        record["sentAt"] = Date.now
        try? await database.save(record)
    }

    func fetchKidPhotos() async -> [SharedPhoto] {
        guard let code else { return [] }
        do {
            let query = CKQuery(
                recordType: "KidPhoto",
                predicate: NSPredicate(format: "code == %@", code)
            )
            let (results, _) = try await database.records(
                matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 60
            )
            var photos: [SharedPhoto] = []
            for (recordID, result) in results {
                if case .success(let record) = result {
                    photos.append(SharedPhoto(
                        id: recordID.recordName,
                        sender: record["sender"] as? String ?? "Someone",
                        fileURL: (record["photo"] as? CKAsset)?.fileURL,
                        sentAt: record["sentAt"] as? Date ?? .distantPast
                    ))
                }
            }
            return photos.sorted { $0.sentAt > $1.sentAt }
        } catch {
            lastError = Self.friendly(error)
            return []
        }
    }

    // MARK: Read receipts

    /// Marks the chat as read by this device (throttled). Call while the chat is open.
    func publishReadReceipt() async {
        guard let code, Date.now.timeIntervalSince(lastReceiptPush) > 20 else { return }
        lastReceiptPush = .now
        do {
            let db = try database
            let recordID = CKRecord.ID(recordName: "receipt-\(code)-\(displayName)")
            let record: CKRecord
            if let existing = try? await db.record(for: recordID) {
                record = existing
            } else {
                record = CKRecord(recordType: "FamilyReceipt", recordID: recordID)
            }
            record["code"] = code
            record["name"] = displayName
            record["readAt"] = Date.now
            try await db.save(record)
        } catch {
            // Best-effort.
        }
    }

    func fetchReadReceipts() async {
        guard let code else { return }
        do {
            let query = CKQuery(
                recordType: "FamilyReceipt",
                predicate: NSPredicate(format: "code == %@", code)
            )
            let (results, _) = try await database.records(
                matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 10
            )
            var receipts: [String: Date] = [:]
            for (_, result) in results {
                if case .success(let record) = result,
                   let name = record["name"] as? String,
                   let readAt = record["readAt"] as? Date,
                   name != displayName {
                    receipts[name] = readAt
                }
            }
            readReceipts = receipts
        } catch {
            // Best-effort.
        }
    }

    /// True if any other family member has read up to this message.
    func isSeen(_ message: FamilyMessage) -> Bool {
        readReceipts.values.contains { $0 >= message.sentAt }
    }

    // MARK: Device status (kid phone battery/last-seen shown on the parent dashboard)

    struct DeviceStatus: Identifiable {
        let name: String
        let battery: Int
        let updatedAt: Date
        var id: String { name }
    }


    func publishStatus() async {
        guard let code else { return }
        do {
            let db = try database
            let recordID = CKRecord.ID(recordName: "status-\(code)-\(displayName)")
            let record: CKRecord
            if let existing = try? await db.record(for: recordID) {
                record = existing
            } else {
                record = CKRecord(recordType: "FamilyStatus", recordID: recordID)
            }
            UIDevice.current.isBatteryMonitoringEnabled = true
            let level = UIDevice.current.batteryLevel
            record["code"] = code
            record["name"] = displayName
            record["battery"] = level < 0 ? -1 : Int(level * 100)
            record["updatedAt"] = Date.now
            try await db.save(record)
        } catch {
            // Status is best-effort; never surface errors for it.
        }
    }

    func fetchStatuses() async -> [DeviceStatus] {
        guard let code else { return [] }
        do {
            let query = CKQuery(
                recordType: "FamilyStatus",
                predicate: NSPredicate(format: "code == %@", code)
            )
            let (results, _) = try await database.records(
                matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 10
            )
            var statuses: [DeviceStatus] = []
            for (_, result) in results {
                if case .success(let record) = result {
                    statuses.append(DeviceStatus(
                        name: record["name"] as? String ?? "Family phone",
                        battery: record["battery"] as? Int ?? -1,
                        updatedAt: record["updatedAt"] as? Date ?? .distantPast
                    ))
                }
            }
            let others = statuses.filter { $0.name != displayName }
            members = others.sorted { $0.name < $1.name }
            return members
        } catch {
            return []
        }
    }

    /// Registers CloudKit push subscriptions so messages and calls arrive
    /// as notifications even when the app is closed.
    func enableNotifications() async {
        guard let code else { return }
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }

        do {
            let db = try database

            let messageSub = CKQuerySubscription(
                recordType: "FamilyMessage",
                predicate: NSPredicate(format: "code == %@", code),
                subscriptionID: "family-messages",
                options: [.firesOnRecordCreation]
            )
            let messageInfo = CKSubscription.NotificationInfo()
            messageInfo.title = "My First Phone"
            messageInfo.alertBody = "New message from your family"
            messageInfo.soundName = "default"
            messageInfo.desiredKeys = ["sender"]
            messageInfo.shouldSendContentAvailable = true
            messageSub.notificationInfo = messageInfo

            let callSub = CKQuerySubscription(
                recordType: "CallSignal",
                predicate: NSPredicate(format: "code == %@ AND kind == %@", code, "offer"),
                subscriptionID: "family-calls",
                options: [.firesOnRecordCreation]
            )
            let callInfo = CKSubscription.NotificationInfo()
            callInfo.title = "My First Phone"
            callInfo.alertBody = "Your family is calling! Tap to answer."
            callInfo.soundName = "default"
            callInfo.desiredKeys = ["sender"]
            // Wakes the app in the background so CallKit can ring natively.
            callInfo.shouldSendContentAvailable = true
            callSub.notificationInfo = callInfo

            _ = try await db.save(messageSub)
            _ = try await db.save(callSub)
        } catch {
            // Subscription already exists or iCloud unavailable — both fine here.
        }
    }

    private func send(_ configure: (CKRecord) -> Void) async {
        guard let code else { return }
        let record = CKRecord(recordType: "FamilyMessage")
        record["code"] = code
        record["sender"] = displayName.isEmpty ? "Someone" : displayName
        record["sentAt"] = Date.now
        configure(record)
        do {
            try await database.save(record)
            lastError = nil
            await refresh()
        } catch {
            lastError = Self.friendly(error)
        }
    }

    private static func message(from record: CKRecord, id: String) -> FamilyMessage {
        FamilyMessage(
            id: id,
            sender: record["sender"] as? String ?? "Someone",
            kind: FamilyMessage.Kind(rawValue: record["kind"] as? String ?? "text") ?? .text,
            text: record["text"] as? String ?? "",
            audioURL: (record["audio"] as? CKAsset)?.fileURL,
            sentAt: record["sentAt"] as? Date ?? record.creationDate ?? .now,
            to: record["to"] as? String ?? ""
        )
    }

    private static func friendly(_ error: Error) -> String {
        if error is CloudUnavailable {
            return "iCloud isn't enabled for this build. In Xcode, pick your team under Signing, then reinstall. See the README."
        }
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return "Sign in to iCloud in Settings, then try again."
            case .networkUnavailable, .networkFailure:
                return "No internet connection."
            default: break
            }
        }
        return "Family Connect needs iCloud set up (see the README). \(error.localizedDescription)"
    }
}

// MARK: - Live-call signaling (offer/answer/hangup records for WebRTC)

struct CallSignal: Identifiable {
    let id: String
    let kind: String
    let callID: String
    let sdp: String
    let sender: String
    let sentAt: Date
    var to: String = ""
}

extension FamilyStore {
    func sendCallSignal(kind: String, callID: String, sdp: String, to recipient: String = "") async {
        guard let code else { return }
        let record = CKRecord(recordType: "CallSignal")
        record["code"] = code
        record["kind"] = kind
        record["callID"] = callID
        record["sdp"] = sdp
        record["to"] = recipient
        record["sender"] = displayName.isEmpty ? "Someone" : displayName
        record["sentAt"] = Date.now
        do {
            try await database.save(record)
            lastError = nil
        } catch {
            lastError = Self.friendly(error)
        }
    }

    func recentCallSignals(within seconds: TimeInterval) async -> [CallSignal] {
        guard let code else { return [] }
        do {
            let predicate = NSPredicate(
                format: "code == %@ AND sentAt > %@",
                code, Date.now.addingTimeInterval(-seconds) as NSDate
            )
            let query = CKQuery(recordType: "CallSignal", predicate: predicate)
            let (results, _) = try await database.records(
                matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 50
            )
            var signals: [CallSignal] = []
            for (recordID, result) in results {
                if case .success(let record) = result {
                    signals.append(CallSignal(
                        id: recordID.recordName,
                        kind: record["kind"] as? String ?? "",
                        callID: record["callID"] as? String ?? "",
                        sdp: record["sdp"] as? String ?? "",
                        sender: record["sender"] as? String ?? "Someone",
                        sentAt: record["sentAt"] as? Date ?? .distantPast,
                        to: record["to"] as? String ?? ""
                    ))
                }
            }
            return signals.sorted { $0.sentAt < $1.sentAt }
        } catch {
            lastError = Self.friendly(error)
            return []
        }
    }
}

// MARK: - Voice recording & playback

@MainActor
final class VoiceRecorder {
    static let shared = VoiceRecorder()
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    func start() async -> Bool {
        guard await requestRecordPermissionCompat() else { return false }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else { return false }
        self.recorder = recorder
        fileURL = url
        recorder.record()
        return true
    }

    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        defer { fileURL = nil }
        return fileURL
    }
}

@MainActor
final class AudioPlayback {
    static let shared = AudioPlayback()
    private var player: AVAudioPlayer?

    func play(_ url: URL) {
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}

// MARK: - Family chat screen (both modes; kid gets big sticker buttons)

struct FamilyChatView: View {
    let isKid: Bool
    /// nil = the whole-family chat; a member name = a one-on-one chat.
    var peer: String? = nil
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = FamilyStore.shared
    @State private var draft = ""
    @State private var isRecording = false
    @State private var ringingFrom: String?

    /// Filtered once per message change instead of on every keystroke, so
    /// typing never re-walks the whole conversation.
    @State private var visibleMessages: [FamilyMessage] = []

    private func rebuildVisibleMessages() {
        let me = store.displayName
        if let peer {
            visibleMessages = store.messages.filter {
                ($0.sender == me && $0.to == peer) || ($0.sender == peer && $0.to == me)
            }
        } else {
            visibleMessages = store.messages.filter { $0.to.isEmpty }
        }
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if let error = store.lastError {
                    Text(error)
                        .font(.rounded(13, weight: .medium))
                        .foregroundStyle(Palette.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                }

                messagesList

                if isKid { kidComposer } else { parentComposer }
            }

            if let ringingFrom {
                ringOverlay(from: ringingFrom)
            }
        }
        .onAppear { rebuildVisibleMessages() }
        .onChange(of: store.messages.count) { _ in rebuildVisibleMessages() }
        .task {
            var lastReceiptFetch = Date.distantPast
            while !Task.isCancelled {
                // Pause syncing while a message is being typed so the
                // keyboard stays perfectly smooth.
                if draft.isEmpty, !isRecording {
                    await store.refresh()
                    if Date.now.timeIntervalSince(lastReceiptFetch) > 30 {
                        lastReceiptFetch = .now
                        await store.publishReadReceipt()
                        await store.fetchReadReceipts()
                    }
                    if let caller = store.incomingRing() {
                        ringingFrom = caller
                        Sfx.ring()
                    }
                }
                try? await Task.sleep(for: .seconds(8))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CloseButton { dismiss() }
            if let peer {
                InitialsAvatar(name: peer, color: Palette.colorFor(peer), size: 52)
            } else {
                SymbolAvatar(symbol: "person.3.fill", color: Palette.green, size: 52)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(peer ?? "My Family")
                    .font(.rounded(22))
                    .foregroundStyle(Palette.ink)
                Text(peer == nil ? "Everyone in the family" : "Just you two")
                    .font(.rounded(13, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(visibleMessages) { message in
                        bubble(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: visibleMessages.count) { _ in
                if let last = visibleMessages.last {
                    withAnimation(.spring(response: 0.35)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            // iOS 16 has no bottom default scroll anchor: open on the newest
            // message by scrolling there once the first layout pass is done.
            .onAppear {
                if let last = visibleMessages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
                Task {
                    try? await Task.sleep(for: .seconds(0.15))
                    if let last = visibleMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: FamilyMessage) -> some View {
        let isMine = message.sender == store.displayName

        if message.kind == .ring {
            Label("\(message.sender) rang the family phone", systemImage: "bell.fill")
                .font(.rounded(13, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .padding(.vertical, 4)
        } else {
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if !isMine {
                    Text(message.sender)
                        .font(.rounded(12, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.horizontal, 8)
                }
                HStack {
                    if isMine { Spacer(minLength: 60) }
                    bubbleContent(message, isMine: isMine)
                    if !isMine { Spacer(minLength: 60) }
                }
                if isMine, message.id == lastSeenMineID {
                    Label("Seen", systemImage: "checkmark.circle.fill")
                        .font(.rounded(11, weight: .semibold))
                        .foregroundStyle(Palette.green)
                        .padding(.horizontal, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        }
    }

    /// The newest of my messages that someone else has read.
    private var lastSeenMineID: String? {
        visibleMessages.last {
            $0.sender == store.displayName && $0.kind != .ring && store.isSeen($0)
        }?.id
    }

    @ViewBuilder
    private func bubbleContent(_ message: FamilyMessage, isMine: Bool) -> some View {
        if message.kind == .photo {
            if let url = message.audioURL,
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 230, maxHeight: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isMine ? Palette.green : Palette.field, lineWidth: 3)
                    )
            } else {
                Label("Drawing", systemImage: "photo")
                    .font(.rounded(16, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(14)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
            }
        } else if message.kind == .voice {
            Button {
                Sfx.tap()
                if let url = message.audioURL {
                    AudioPlayback.shared.play(url)
                }
            } label: {
                Label("Play voice message", systemImage: "play.circle.fill")
                    .font(.rounded(17, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        isMine ? AnyShapeStyle(Palette.green) : AnyShapeStyle(Palette.card),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                    .foregroundStyle(isMine ? .white : Palette.ink)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
            .buttonStyle(BouncyButtonStyle())
        } else {
            Text(message.text)
                .font(.rounded(20, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    isMine ? AnyShapeStyle(Palette.green) : AnyShapeStyle(Palette.card),
                    in: RoundedRectangle(cornerRadius: 20)
                )
                .foregroundStyle(isMine ? .white : Palette.ink)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }

    private var typeRow: some View {
        HStack(spacing: 10) {
            TextField("Type a message", text: $draft)
                .font(.rounded(16, weight: .medium))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.card, in: Capsule())
                .onSubmit { sendDraft() }

            Button {
                sendDraft()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? Palette.inkSoft.opacity(0.4) : Palette.green)
            }
            .buttonStyle(BouncyButtonStyle())
        }
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        draft = ""
        Task { await store.sendText(text, to: peer ?? "") }
    }

    private var kidComposer: some View {
        VStack(spacing: 10) {
            typeRow

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach(Sticker.all) { sticker in
                    Button {
                        Sfx.bump(.light)
                        Task { await store.sendText(sticker.text, to: peer ?? "") }
                    } label: {
                        Image(systemName: sticker.symbol)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(sticker.color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }

            HStack(spacing: 12) {
                ForEach(Sticker.phrases.prefix(2), id: \.self) { phrase in
                    Button {
                        Sfx.bump(.light)
                        Task { await store.sendText(phrase, to: peer ?? "") }
                    } label: {
                        Text(phrase)
                            .font(.rounded(15, weight: .semibold))
                            .foregroundStyle(Palette.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Palette.green.opacity(0.13), in: Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle())
                }

                recordButton(size: 56)

                Button {
                    Sfx.bump(.heavy)
                    Task { await store.ringFamily(to: peer ?? "") }
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Palette.orange, in: Circle())
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Palette.field.opacity(0.6))
    }

    private var parentComposer: some View {
        HStack(spacing: 10) {
            typeRow
            recordButton(size: 46)
        }
        .padding(.horizontal, 14)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Palette.field.opacity(0.6))
    }

    /// Tap once to record, tap again to send.
    private func recordButton(size: CGFloat) -> some View {
        Button {
            if isRecording {
                isRecording = false
                Sfx.bump(.light)
                if let url = VoiceRecorder.shared.stop() {
                    Task { await store.sendVoice(fileURL: url, to: peer ?? "") }
                }
            } else {
                Task {
                    if await VoiceRecorder.shared.start() {
                        isRecording = true
                        Sfx.bump()
                    }
                }
            }
        } label: {
            Image(systemName: isRecording ? "arrow.up.circle.fill" : "mic.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(isRecording ? Palette.red : Palette.blue, in: Circle())
                .scaleEffect(isRecording ? 1.2 : 1)
                .animation(
                    isRecording
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .spring(response: 0.3),
                    value: isRecording
                )
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private func ringOverlay(from caller: String) -> some View {
        ZStack {
            Palette.green.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
                Text("\(caller) is calling!")
                    .font(.rounded(32))
                    .foregroundStyle(.white)
                Text("Tap the microphone to talk back!")
                    .font(.rounded(16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
                Button {
                    Sfx.tap()
                    ringingFrom = nil
                } label: {
                    Text("OK!")
                        .font(.rounded(22))
                        .foregroundStyle(Palette.green)
                        .frame(width: 160, height: 60)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.bottom, 50)
            }
        }
        .onAppear { Sfx.ring() }
    }
}
