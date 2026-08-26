import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Sheet shown from the home screen: PIN pad first, settings after.
struct ParentAccessView: View {
    @State private var unlocked = false

    var body: some View {
        if unlocked {
            ParentGateView()
        } else {
            CodePadView { unlocked = true }
        }
    }
}

struct CodePadView: View {
    let onSuccess: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var entered = ""
    @State private var shake = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    CloseButton { dismiss() }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)

                Text("Grown-ups only")
                    .font(.rounded(26))
                    .foregroundStyle(Palette.ink)

                Text("Enter the 4-digit code")
                    .font(.rounded(16, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)

                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < entered.count ? Palette.ink : Palette.field)
                            .frame(width: 16, height: 16)
                    }
                }
                .offset(x: shake ? -10 : 0)
                .animation(shake ? .spring(response: 0.1, dampingFraction: 0.2) : .default, value: shake)

                if model.parentCodeIsDefault {
                    Text("Starter code is 1234. Change it inside!")
                        .font(.rounded(13, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft.opacity(0.7))
                }

                Spacer()

                keypad
                    .padding(.bottom, 30)
            }
        }
    }

    private var keypad: some View {
        VStack(spacing: 14) {
            ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]], id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(width: 76, height: 76)
                        } else {
                            Button {
                                press(key)
                            } label: {
                                Text(key)
                                    .font(.rounded(28, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                    .frame(width: 76, height: 76)
                                    .card(cornerRadius: 26)
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private func press(_ key: String) {
        Sfx.tap()
        Sfx.bump(.light)
        if key == "⌫" {
            if !entered.isEmpty { entered.removeLast() }
            return
        }
        guard entered.count < 4 else { return }
        entered += key
        if entered.count == 4 {
            if entered == model.parentCode {
                Sfx.bump()
                onSuccess()
            } else {
                Sfx.bump(.heavy)
                shake = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.3))
                    shake = false
                    entered = ""
                }
            }
        }
    }
}

struct ParentGateView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var library = VideoLibrary.shared
    @State private var didReset = false
    @State private var testResult: String?
    @State private var testing = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false
    @State private var importing = false
    @State private var newCode = ""
    @State private var codeSaved = false
    @AppStorage("classicsEnabled") private var classicsEnabled = true
    @State private var guidedAccessOn = UIAccessibility.isGuidedAccessEnabled
    @State private var familyStore = FamilyStore.shared
    @State private var joinCode = ""

    private var roleBinding: Binding<PhoneRole> {
        Binding(
            get: { model.role ?? .kid },
            set: { model.role = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("This phone") {
                    Picker("Mode", selection: roleBinding) {
                        Text("Kid's phone").tag(PhoneRole.kid)
                        Text("Grown-up's phone").tag(PhoneRole.parent)
                    }
                    .pickerStyle(.segmented)
                    Text("Kid mode is the safe toddler phone. Grown-up mode is your family dashboard.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Lock status") {
                    if guidedAccessOn {
                        Label("Locked. Your child can't leave this app", systemImage: "lock.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not locked. Your child can leave this app", systemImage: "lock.open.fill")
                            .foregroundStyle(.orange)
                        Text("iOS only allows locking a device into an app via Guided Access:\n1. Settings → Accessibility → Guided Access → on, set a passcode.\n2. In this app, triple-click the side button, tap Start.\n3. Triple-click + passcode to exit.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Family Connect") {
                    Text("Install this app on both phones and join the same family code. Your kid can then text you, send voice messages and ring you inside the app. No phone number needed. Both devices need iCloud sign-in (see the README for the one-time Xcode setup).")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    TextField("Name shown in chat (e.g. Mom, Leo)", text: Binding(
                        get: { familyStore.displayName },
                        set: { familyStore.displayName = $0 }
                    ))

                    if let code = familyStore.code {
                        HStack {
                            Text("Family code")
                            Spacer()
                            Text(code)
                                .font(.system(.title3, design: .monospaced).bold())
                        }
                        Text("Enter this code on the other phone to connect.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Leave family", role: .destructive) {
                            familyStore.code = nil
                            familyStore.messages = []
                        }
                    } else {
                        Button("Create a new family code") {
                            familyStore.code = FamilyStore.newCode()
                        }
                        HStack {
                            TextField("Or enter a code to join", text: $joinCode)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                            Button("Join") {
                                let code = joinCode.trimmingCharacters(in: .whitespaces).uppercased()
                                guard (6...8).contains(code.count) else { return }
                                familyStore.code = code
                                joinCode = ""
                            }
                            .disabled(!(6...8).contains(joinCode.trimmingCharacters(in: .whitespaces).count))
                        }
                    }

                    Button(testing ? "Testing…" : "Test the connection") {
                        testing = true
                        testResult = nil
                        Task {
                            testResult = await familyStore.connectionTest()
                            testing = false
                        }
                    }
                    .disabled(testing)

                    if let testResult {
                        Text(testResult)
                            .font(.callout)
                            .textSelection(.enabled)
                    }

                    if let error = familyStore.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Quiet hours") {
                    Toggle("Lock the kid phone at bedtime", isOn: Binding(
                        get: { model.quietEnabled },
                        set: { model.quietEnabled = $0; model.quietOverrideUntil = nil }
                    ))
                    if model.quietEnabled {
                        DatePicker(
                            "Starts",
                            selection: minutesBinding(get: { model.quietStart }, set: { model.quietStart = $0 }),
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            "Ends",
                            selection: minutesBinding(get: { model.quietEnd }, set: { model.quietEnd = $0 }),
                            displayedComponents: .hourAndMinute
                        )
                        Text("During quiet hours the kid phone shows a bedtime screen instead of the apps. You can unlock for the night with the grown-ups code.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Grown-ups code") {
                    Text("This code protects this settings area inside the app.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("New 4-digit code", text: $newCode)
                            .keyboardType(.numberPad)
                            .onChange(of: newCode) {
                                newCode = String(newCode.filter(\.isNumber).prefix(4))
                                codeSaved = false
                            }
                        Button(codeSaved ? "Saved ✓" : "Save") {
                            model.parentCode = newCode
                            newCode = ""
                            codeSaved = true
                        }
                        .disabled(newCode.count != 4)
                    }
                }

                Section("TV: Classic Cartoons") {
                    Toggle("Show Classic Cartoons", isOn: $classicsEnabled)
                    Text("A hand-picked set of public-domain cartoons streamed from the Internet Archive. Turn it off if you want TV fully offline.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("TV: add your child's shows") {
                    Text("Videos you add show up in the TV app under \"My Shows\" and stay on this device. Streaming-app episodes are copy-protected, so use home videos or downloaded video files.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    PhotosPicker(selection: $pickedItems, matching: .videos) {
                        Label(importing ? "Adding…" : "Add from Photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .disabled(importing)

                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Add from Files", systemImage: "folder")
                    }
                    .disabled(importing)

                    if !library.videos.isEmpty {
                        Text("\(library.videos.count) video\(library.videos.count == 1 ? "" : "s") in My Shows")
                            .foregroundStyle(.secondary)
                        Button("Remove all videos", role: .destructive) {
                            library.removeAll()
                        }
                    }
                }

                Section("Narration voice") {
                    HStack {
                        Text("Current voice")
                        Spacer()
                        Text(Speaker.shared.currentVoiceName)
                            .foregroundStyle(.secondary)
                    }
                    if Speaker.shared.isUsingBasicVoice {
                        Text("The built-in voice sounds robotic. For a much more human voice: open Settings, then Accessibility, then Spoken Content, then Voices, then English, and download a voice marked Premium (Zoe or Ava sound best). The app switches to it automatically.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("You have a high quality voice installed. Nice.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Privacy & safety") {
                    Label("No accounts, no sign-ups. The app never asks for your child's email, birthday or any personal details.", systemImage: "person.crop.circle.badge.xmark")
                    Label("No public anything. Your family is reachable only by its private code. There is no search, no directory and no strangers.", systemImage: "eye.slash.fill")
                    Label("Messages, voice notes and photos travel through your own iCloud, encrypted in transit and at rest on Apple's servers. Live calls stream directly between your phones.", systemImage: "lock.icloud.fill")
                    Label("No analytics, no ads, no tracking of any kind. Nothing is ever sold or shared.", systemImage: "chart.bar.xaxis")
                }

                Section("About this app") {
                    Label("All calls and messages stay inside this app, between family phones only. There is no connection to the real phone, SMS, or FaceTime.", systemImage: "phone.badge.checkmark")
                    Label("Internet is used only for Family Connect (iCloud) and streaming cartoons (optional). No ads, no purchases, no data collection.", systemImage: "wifi.slash")
                }

                Section {
                    Button(didReset ? "Conversations reset ✓" : "Reset conversations") {
                        model.resetChats()
                        didReset = true
                    }
                    .disabled(didReset)
                }
            }
            .navigationTitle("Grown-ups")
            .onChange(of: model.role) {
                if model.role == .parent { dismiss() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: pickedItems) {
                importFromPhotos()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.guidedAccessStatusDidChangeNotification)) { _ in
                guidedAccessOn = UIAccessibility.isGuidedAccessEnabled
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: true
            ) { result in
                importFromFiles(result)
            }
        }
    }

    /// Bridges minutes-from-midnight storage to DatePicker's Date.
    private func minutesBinding(get: @escaping () -> Int, set: @escaping (Int) -> Void) -> Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(get() * 60))
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                set((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
            }
        )
    }

    private func importFromPhotos() {
        guard !pickedItems.isEmpty else { return }
        let items = pickedItems
        pickedItems = []
        importing = true
        Task {
            for item in items {
                _ = try? await item.loadTransferable(type: ImportedVideo.self)
            }
            library.reload()
            importing = false
        }
    }

    private func importFromFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            let dest = VideoLibrary.videosDir.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: url, to: dest)
        }
        library.reload()
    }
}

/// Copies a picked photo-library video into the app's Videos folder.
struct ImportedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = VideoLibrary.videosDir.appendingPathComponent(UUID().uuidString + "." + ext)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return ImportedVideo(url: dest)
        }
    }
}
