import SwiftUI

struct PhoneView: View {
    @State private var mode: Mode = .contacts
    @State private var activeCall: Contact?

    enum Mode { case contacts, dialpad }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 16) {
                TopBar(title: "Phone")

                modeToggle

                if mode == .contacts {
                    contactsList
                } else {
                    DialPadView { friend in
                        activeCall = friend
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .fullScreenCover(item: $activeCall) { contact in
            CallView(contact: contact)
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 6) {
            toggleButton("Friends", isOn: mode == .contacts) { mode = .contacts }
            toggleButton("Numbers", isOn: mode == .dialpad) { mode = .dialpad }
        }
        .padding(5)
        .background(Palette.field, in: Capsule())
        .padding(.horizontal, 20)
    }

    private func toggleButton(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Sfx.tap()
            withAnimation(.spring(response: 0.3)) { action() }
        } label: {
            Text(title)
                .font(.rounded(17, weight: .semibold))
                .foregroundStyle(isOn ? Palette.ink : Palette.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isOn ? AnyShapeStyle(Palette.card) : AnyShapeStyle(.clear), in: Capsule())
        }
        .buttonStyle(BouncyButtonStyle())
    }

    @State private var showFamilyChat = false
    @State private var familyStore = FamilyStore.shared
    @State private var chatPeer: PeerChat?

    struct PeerChat: Identifiable {
        let name: String
        var id: String { name }
    }

    private var contactsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !familyStore.members.isEmpty {
                    sectionTitle("My Family")

                    ForEach(familyStore.members) { member in
                        HStack(spacing: 12) {
                            InitialsAvatar(name: member.name, color: Palette.colorFor(member.name))
                            Text(member.name)
                                .font(.rounded(19, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Spacer()

                            // Live in-app call, just to this person.
                            Button {
                                Sfx.tap()
                                Sfx.bump()
                                CallEngine.shared.startCall(to: member.name)
                            } label: {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 52, height: 52)
                                    .background(Palette.green, in: Circle())
                            }
                            .buttonStyle(BouncyButtonStyle())

                            // One-on-one chat.
                            Button {
                                Sfx.tap()
                                chatPeer = PeerChat(name: member.name)
                            } label: {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 52, height: 52)
                                    .background(Palette.blue, in: Circle())
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                        .padding(12)
                        .card(cornerRadius: 24)
                    }
                }

                if FamilyStore.shared.isConnected {
                    Button {
                        Sfx.tap()
                        Sfx.bump()
                        showFamilyChat = true
                    } label: {
                        HStack(spacing: 14) {
                            SymbolAvatar(symbol: "mic.fill", color: Palette.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Call My Family")
                                    .font(.rounded(19, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Text("Walkie-talkie fun!")
                                    .font(.rounded(13, weight: .medium))
                                    .foregroundStyle(Palette.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "bell.fill")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(Palette.orange, in: Circle())
                        }
                        .padding(12)
                        .card(cornerRadius: 24)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .fullScreenCover(isPresented: $showFamilyChat) {
                        FamilyChatView(isKid: true)
                    }

                    // Live internet call to the family (WebRTC).
                    Button {
                        Sfx.tap()
                        Sfx.bump()
                        CallEngine.shared.startCall()
                    } label: {
                        HStack(spacing: 14) {
                            SymbolAvatar(symbol: "phone.arrow.up.right.fill", color: Palette.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Live Call My Family")
                                    .font(.rounded(19, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Text("Talk live, like a real phone call!")
                                    .font(.rounded(13, weight: .medium))
                                    .foregroundStyle(Palette.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "phone.fill")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(Palette.green, in: Circle())
                        }
                        .padding(12)
                        .card(cornerRadius: 24)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }

                if !FamilyStore.shared.isConnected {
                    Text("Ask a grown-up to connect your family. Then you can call them right here!")
                        .font(.rounded(15, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .card(cornerRadius: 22)
                }

                sectionTitle("Pretend friends")
                    .padding(.top, 6)

                HStack(spacing: 16) {
                    ForEach(Contact.all) { contact in
                        Button {
                            Sfx.tap()
                            Sfx.bump()
                            activeCall = contact
                        } label: {
                            VStack(spacing: 10) {
                                SymbolAvatar(symbol: contact.symbol, color: contact.color, size: 84)
                                Text(contact.name)
                                    .font(.rounded(16, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 148)
                            .card()
                        }
                        .buttonStyle(BouncyButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .fullScreenCover(item: $chatPeer) { peer in
            FamilyChatView(isKid: true, peer: peer.name)
        }
        .task {
            while !Task.isCancelled {
                if familyStore.isConnected {
                    _ = await familyStore.fetchStatuses()
                }
                try? await Task.sleep(for: .seconds(45))
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.rounded(18))
            .foregroundStyle(Palette.inkSoft)
    }
}

struct DialPadView: View {
    var onCall: (Contact) -> Void
    @State private var dialed = ""

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]

    var body: some View {
        VStack(spacing: 18) {
            Text(dialed.isEmpty ? "· · ·" : dialed)
                .font(.rounded(30))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(height: 40)
                .padding(.horizontal, 24)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(keys, id: \.self) { key in
                    Button {
                        pressKey(key)
                    } label: {
                        Text(key)
                            .font(.rounded(28, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 80, height: 80)
                            .card(cornerRadius: 28)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }
            .padding(.horizontal, 40)

            HStack(spacing: 36) {
                // Pretend keypad calls always reach a pretend friend — never a real number.
                Button {
                    Sfx.bump()
                    if let friend = Contact.mysteryFriends.randomElement() {
                        onCall(friend)
                    }
                    dialed = ""
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(Palette.green, in: Circle())
                        .shadow(color: Palette.green.opacity(0.35), radius: 8, y: 4)
                }
                .buttonStyle(BouncyButtonStyle())

                Button {
                    Sfx.tap()
                    if !dialed.isEmpty { dialed.removeLast() }
                } label: {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 80, height: 80)
                        .card(cornerRadius: 28)
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
    }

    private func pressKey(_ key: String) {
        Sfx.bump(.light)
        if let digit = Int(key) {
            Sfx.dtmf(digit)
            Speaker.shared.say(key)
        } else {
            Sfx.tap()
        }
        if dialed.count < 14 { dialed += key }
    }
}

struct CallView: View {
    let contact: Contact
    @Environment(\.dismiss) private var dismiss
    @State private var answered = false
    @State private var seconds = 0
    @State private var pulsing = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Text(contact.name)
                    .font(.rounded(38))
                    .foregroundStyle(Palette.ink)

                Text(answered ? timeString : "Ring ring…")
                    .font(.rounded(20, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)

                Button {
                    guard answered else { return }
                    Sfx.bump(.light)
                    contact.speak()
                } label: {
                    SymbolAvatar(symbol: contact.symbol, color: contact.color, size: 200)
                        .overlay(Circle().stroke(contact.color.opacity(0.35), lineWidth: 4))
                        .scaleEffect(pulsing ? 1.05 : 0.95)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
                }
                .buttonStyle(BouncyButtonStyle())

                Text(answered ? "Tap \(contact.name) to chat!" : " ")
                    .font(.rounded(16, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)

                Spacer()

                Button {
                    Sfx.bump()
                    dismiss()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                        .background(Palette.red, in: Circle())
                        .shadow(color: Palette.red.opacity(0.35), radius: 8, y: 4)
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.bottom, 34)
            }
        }
        .onAppear {
            pulsing = true
            Sfx.ring()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.4))
                answered = true
                Sfx.bump()
                contact.speakGreeting()
            }
        }
        .onReceive(timer) { _ in
            if answered { seconds += 1 }
        }
        .onDisappear {
            Speaker.shared.stop()
        }
    }

    private var timeString: String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
