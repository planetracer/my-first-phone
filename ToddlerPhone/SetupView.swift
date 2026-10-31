import SwiftUI

// MARK: - First-launch onboarding wizard

struct SetupView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step: Step = .welcome
    @State private var role: PhoneRole = .kid
    @State private var name = ""
    @State private var createdCode: String?
    @State private var joinCode = ""
    @State private var pin = ""
    @State private var familyChoiceMade = false

    enum Step: Int, CaseIterable {
        case welcome, role, name, family, pin, done
    }

    private var visibleSteps: [Step] {
        role == .kid ? Step.allCases : Step.allCases.filter { $0 != .pin }
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 20)

                Spacer()

                Group {
                    switch step {
                    case .welcome: welcome
                    case .role: rolePick
                    case .name: namePick
                    case .family: familySetup
                    case .pin: pinSetup
                    case .done: done
                    }
                }
                .transition(.opacity)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .animation(.spring(response: 0.35), value: step)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(visibleSteps, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Palette.green : Palette.field)
                    .frame(width: s == step ? 26 : 10, height: 10)
            }
        }
    }

    // Step 1 — welcome
    private var welcome: some View {
        VStack(spacing: 18) {
            Image(systemName: "phone.badge.waveform.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Palette.green)
                .frame(width: 110, height: 110)
                .background(Palette.green.opacity(0.13), in: Circle())

            Text("My First Phone")
                .font(.rounded(34))
                .foregroundStyle(Palette.ink)

            Text("A safe little phone with family calling, storybooks, games and TV. Set it up on your phone and your kid's phone, then connect them into one family.")
                .font(.rounded(16, weight: .medium))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)

            bigButton("Get started", color: Palette.green) {
                step = .role
            }
            .padding(.top, 8)
        }
    }

    // Step 2 — whose phone
    private var rolePick: some View {
        VStack(spacing: 16) {
            title("Whose phone is this?")

            choiceCard(
                icon: "figure.child", color: Palette.green,
                heading: "My kid's phone",
                detail: "The safe toddler phone. Everything stays behind a grown-ups code."
            ) {
                role = .kid
                step = .name
            }

            choiceCard(
                icon: "person.fill", color: Palette.blue,
                heading: "My phone (parent)",
                detail: "The family dashboard for calls, voice notes and messages from your kid."
            ) {
                role = .parent
                step = .name
            }
        }
    }

    // Step 3 — name
    private var namePick: some View {
        VStack(spacing: 16) {
            title(role == .kid ? "What's your kid's name?" : "What should the family call you?")

            Text(role == .kid
                 ? "Shown in the family chat when they send messages."
                 : "For example: Mom, Dad, Grandma.")
                .font(.rounded(15, weight: .medium))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)

            TextField(role == .kid ? "Kid's name" : "Your name", text: $name)
                .font(.rounded(22, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))

            bigButton("Continue", color: Palette.green, enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                step = .family
            }
        }
    }

    // Step 4 — family account
    private var familySetup: some View {
        VStack(spacing: 16) {
            title("Family account")

            Text(role == .kid
                 ? "If you already created a family code on YOUR phone, enter it here so this kid phone joins it. Otherwise create the family here and enter the code on your phone."
                 : "Create your family code here first. Then, when you set up your kid's phone, enter this same code there to link them.")
                .font(.rounded(15, weight: .medium))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)

            if let code = createdCode {
                VStack(spacing: 8) {
                    Text("Your family code")
                        .font(.rounded(14, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                    Text(code)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.ink)
                        .kerning(6)
                    Text("Write it down, then enter it on the other phone.")
                        .font(.rounded(13, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .card(cornerRadius: 24)

                bigButton("Continue", color: Palette.green) { advanceFromFamily() }
            } else {
                bigButton("Create a new family", color: Palette.green) {
                    createdCode = FamilyStore.newCode()
                    familyChoiceMade = true
                }

                HStack(spacing: 10) {
                    TextField("Have a code? Enter it", text: $joinCode)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Palette.ink)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 14)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
                    Button {
                        Sfx.tap()
                        familyChoiceMade = true
                        advanceFromFamily()
                    } label: {
                        Text("Join")
                            .font(.rounded(17))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 15)
                            .background(joinCodeValid ? Palette.blue : Palette.inkSoft.opacity(0.4), in: Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .disabled(!joinCodeValid)
                }

                Button("Skip for now — just pretend play") {
                    Sfx.tap()
                    advanceFromFamily()
                }
                .font(.rounded(14, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, 4)
            }
        }
    }

    private var joinCodeValid: Bool {
        (6...8).contains(joinCode.trimmingCharacters(in: .whitespaces).count)
    }

    private func advanceFromFamily() {
        step = role == .kid ? .pin : .done
    }

    // Step 5 (kid only) — grown-ups code
    private var pinSetup: some View {
        VStack(spacing: 16) {
            title("Set a grown-ups code")

            Text("This 4-digit code protects settings and mode switching from little fingers. Don't use one your kid has seen you type!")
                .font(.rounded(15, weight: .medium))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)

            TextField("4 digits", text: $pin)
                .keyboardType(.numberPad)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
                .onChange(of: pin) { _ in
                    pin = String(pin.filter(\.isNumber).prefix(4))
                }

            bigButton("Continue", color: Palette.green, enabled: pin.count == 4) {
                step = .done
            }
        }
    }

    // Step 6 — summary
    private var done: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Palette.green)

            title("All set!")

            VStack(alignment: .leading, spacing: 10) {
                summaryRow("iphone", role == .kid ? "Kid's phone — \(name)" : "Parent phone — \(name)")
                if let code = familyCodeToApply {
                    summaryRow("person.3.fill", "Family code: \(code)")
                } else {
                    summaryRow("person.3", "No family yet — connect later in the grown-ups area")
                }
                if role == .kid {
                    summaryRow("lock.fill", "Grown-ups code set")
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(cornerRadius: 24)

            bigButton(role == .kid ? "Start playing!" : "Open my dashboard", color: Palette.green) {
                finish()
            }
        }
    }

    private var familyCodeToApply: String? {
        if let createdCode { return createdCode }
        let joined = joinCode.trimmingCharacters(in: .whitespaces).uppercased()
        return joined.count == 6 ? joined : nil
    }

    private func finish() {
        let store = FamilyStore.shared
        store.displayName = name.trimmingCharacters(in: .whitespaces)
        if let code = familyCodeToApply {
            store.code = code
            Task { await store.enableNotifications() }
        }
        if role == .kid, pin.count == 4 { model.parentCode = pin }
        Sfx.bump()
        withAnimation(.spring(response: 0.4)) { model.role = role }
    }

    // MARK: helpers

    private func summaryRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.green)
                .frame(width: 26)
            Text(text)
                .font(.rounded(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.rounded(28))
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
    }

    private func bigButton(_ label: String, color: Color, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            Sfx.tap()
            Sfx.bump(.light)
            action()
        } label: {
            Text(label)
                .font(.rounded(19))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(enabled ? color : Palette.inkSoft.opacity(0.4), in: Capsule())
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(!enabled)
    }

    private func choiceCard(icon: String, color: Color, heading: String, detail: String, action: @escaping () -> Void) -> some View {
        Button {
            Sfx.tap()
            Sfx.bump(.light)
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 68, height: 68)
                    .background(color.opacity(0.13), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(heading)
                        .font(.rounded(20, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(detail)
                        .font(.rounded(14, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(18)
            .card(cornerRadius: 26)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Grown-up mode: family dashboard

struct ParentHomeView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var familyStore = FamilyStore.shared
    @State private var showSettings = false
    @State private var showFamilyChat = false
    @State private var showPhotoWall = false
    @State private var kidStatuses: [FamilyStore.DeviceStatus] = []
    @State private var testResult: String?
    @State private var testing = false
    @State private var quickSent: String?

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Grown-up mode")
                            .font(.rounded(15, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)
                        Text("Family")
                            .font(.rounded(32))
                            .foregroundStyle(Palette.ink)
                    }
                    Spacer()
                    Button {
                        Sfx.tap()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 52, height: 52)
                            .card(cornerRadius: 18)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(kidStatuses) { status in
                            HStack(spacing: 12) {
                                InitialsAvatar(name: status.name, color: Palette.teal, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(status.name)'s phone")
                                        .font(.rounded(16, weight: .semibold))
                                        .foregroundStyle(Palette.ink)
                                    HStack(spacing: 4) {
                                        if status.battery >= 0 {
                                            Image(systemName: batteryIcon(status.battery))
                                                .foregroundStyle(status.battery <= 20 ? Palette.red : Palette.green)
                                            Text("\(status.battery)%")
                                        }
                                        Text("· active")
                                        Text(status.updatedAt, style: .relative)
                                        Text("ago")
                                    }
                                    .font(.rounded(13, weight: .medium))
                                    .foregroundStyle(Palette.inkSoft)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .card(cornerRadius: 22)
                        }

                        if familyStore.isConnected {
                            Button {
                                Sfx.tap()
                                showFamilyChat = true
                            } label: {
                                HStack(spacing: 12) {
                                    SymbolAvatar(symbol: "person.3.fill", color: Palette.green, size: 52)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Family Chat")
                                            .font(.rounded(18, weight: .semibold))
                                            .foregroundStyle(Palette.ink)
                                        Text("Messages and voice notes from your kid")
                                            .font(.rounded(13, weight: .medium))
                                            .foregroundStyle(Palette.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Palette.inkSoft.opacity(0.6))
                                }
                                .padding(12)
                                .card(cornerRadius: 24)
                            }
                            .buttonStyle(BouncyButtonStyle())

                            Button {
                                Sfx.tap()
                                Sfx.bump()
                                CallEngine.shared.startCall()
                            } label: {
                                HStack(spacing: 12) {
                                    SymbolAvatar(symbol: "phone.arrow.up.right.fill", color: Palette.blue, size: 52)
                                    Text("Live call the family phone")
                                        .font(.rounded(18, weight: .semibold))
                                        .foregroundStyle(Palette.ink)
                                    Spacer()
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Palette.green, in: Circle())
                                }
                                .padding(12)
                                .card(cornerRadius: 24)
                            }
                            .buttonStyle(BouncyButtonStyle())
                            Button {
                                Sfx.tap()
                                showPhotoWall = true
                            } label: {
                                HStack(spacing: 12) {
                                    SymbolAvatar(symbol: "photo.stack.fill", color: Palette.teal, size: 52)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Photo Wall")
                                            .font(.rounded(18, weight: .semibold))
                                            .foregroundStyle(Palette.ink)
                                        Text("Every photo from the kid camera")
                                            .font(.rounded(13, weight: .medium))
                                            .foregroundStyle(Palette.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Palette.inkSoft.opacity(0.6))
                                }
                                .padding(12)
                                .card(cornerRadius: 24)
                            }
                            .buttonStyle(BouncyButtonStyle())

                            // Quick sends — one tap, straight into the family chat.
                            HStack(spacing: 8) {
                                quickSend("heart.fill", "❤️", Palette.pink)
                                quickSend("hand.wave.fill", "Hi! Thinking of you!", Palette.orange)
                                quickSend("fork.knife", "Time to eat!", Palette.green)
                                quickSend("moon.zzz.fill", "Almost bedtime!", Palette.indigo)
                            }
                        } else {
                            Text("Set up Family Connect in settings (gear, top right) to chat and call in-app with your kid's phone.")
                                .font(.rounded(14, weight: .medium))
                                .foregroundStyle(Palette.inkSoft)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .card(cornerRadius: 22)
                        }

                        // Connection doctor
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                Sfx.tap()
                                testing = true
                                testResult = nil
                                Task {
                                    testResult = await familyStore.connectionTest()
                                    testing = false
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    SymbolAvatar(symbol: "stethoscope", color: Palette.red, size: 44)
                                    Text(testing ? "Testing…" : "Test the connection")
                                        .font(.rounded(16, weight: .semibold))
                                        .foregroundStyle(Palette.ink)
                                    Spacer()
                                    if testing { ProgressView() }
                                }
                            }
                            .buttonStyle(BouncyButtonStyle())
                            .disabled(testing)

                            if let testResult {
                                Text(testResult)
                                    .font(.rounded(13, weight: .medium))
                                    .foregroundStyle(Palette.ink)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(12)
                        .card(cornerRadius: 24)

                        // Try the kid experience
                        Button {
                            Sfx.tap()
                            model.kidPreview = true
                        } label: {
                            HStack(spacing: 12) {
                                SymbolAvatar(symbol: "figure.child", color: Palette.orange, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Preview kid mode")
                                        .font(.rounded(16, weight: .semibold))
                                        .foregroundStyle(Palette.ink)
                                    Text("Browse the books, games and TV yourself")
                                        .font(.rounded(13, weight: .medium))
                                        .foregroundStyle(Palette.inkSoft)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Palette.inkSoft.opacity(0.6))
                            }
                            .padding(12)
                            .card(cornerRadius: 24)
                        }
                        .buttonStyle(BouncyButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            ParentGateView()
        }
        .fullScreenCover(isPresented: $showFamilyChat) {
            FamilyChatView(isKid: false)
        }
        .fullScreenCover(isPresented: $showPhotoWall) {
            FamilyPhotoWallView()
        }
        .task {
            // Poll for incoming rings/messages and kid-phone status.
            var lastStatusFetch = Date.distantPast
            while !Task.isCancelled {
                if familyStore.isConnected {
                    await familyStore.refresh()
                    if familyStore.incomingRing() != nil {
                        Sfx.ring()
                        Sfx.bump(.heavy)
                        showFamilyChat = true
                    }
                    if Date.now.timeIntervalSince(lastStatusFetch) > 60 {
                        lastStatusFetch = .now
                        kidStatuses = await familyStore.fetchStatuses()
                    }
                }
                try? await Task.sleep(for: .seconds(12))
            }
        }
    }

    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case ..<15: "battery.0percent"
        case ..<40: "battery.25percent"
        case ..<65: "battery.50percent"
        case ..<90: "battery.75percent"
        default: "battery.100percent"
        }
    }

    private func quickSend(_ icon: String, _ text: String, _ color: Color) -> some View {
        Button {
            Sfx.bump(.light)
            quickSent = text
            Task {
                await familyStore.sendText(text)
                try? await Task.sleep(for: .seconds(1.5))
                if quickSent == text { quickSent = nil }
            }
        } label: {
            Image(systemName: quickSent == text ? "checkmark" : icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(quickSent == text ? .white : color)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    quickSent == text ? AnyShapeStyle(color) : AnyShapeStyle(Palette.card),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}
