import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var target: Target?

    enum Target: Identifiable {
        case family
        case member(String)
        case pretend(Contact)

        var id: String {
            switch self {
            case .family: "family"
            case .member(let name): "member-\(name)"
            case .pretend(let contact): "pretend-\(contact.id)"
            }
        }
    }

    @StateObject private var familyStore = FamilyStore.shared

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 8) {
                TopBar(title: "Messages")

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if FamilyStore.shared.isConnected {
                            Button {
                                Sfx.tap()
                                target = .family
                            } label: {
                                row(
                                    avatar: SymbolAvatar(symbol: "person.3.fill", color: Palette.green),
                                    name: "My Family",
                                    detail: "Type, send stickers and voice notes"
                                )
                            }
                            .buttonStyle(BouncyButtonStyle())

                            ForEach(familyStore.members) { member in
                                Button {
                                    Sfx.tap()
                                    target = .member(member.name)
                                } label: {
                                    row(
                                        avatar: InitialsAvatar(name: member.name, color: Palette.colorFor(member.name)),
                                        name: member.name,
                                        detail: "Just you two"
                                    )
                                }
                                .buttonStyle(BouncyButtonStyle())
                            }
                        } else {
                            Text("Ask a grown-up to connect your family. Then you can message them right here!")
                                .font(.rounded(15, weight: .medium))
                                .foregroundStyle(Palette.inkSoft)
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .card(cornerRadius: 22)
                        }

                        sectionTitle("Pretend friends")
                            .padding(.top, 6)

                        ForEach(Contact.all) { contact in
                            Button {
                                Sfx.tap()
                                target = .pretend(contact)
                            } label: {
                                row(
                                    avatar: SymbolAvatar(symbol: contact.symbol, color: contact.color),
                                    name: contact.name,
                                    detail: model.messages(for: contact).last?.text ?? ""
                                )
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
        }
        .fullScreenCover(item: $target) { target in
            switch target {
            case .family: FamilyChatView(isKid: true)
            case .member(let name): FamilyChatView(isKid: true, peer: name)
            case .pretend(let contact): ChatView(contact: contact)
            }
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

    private func row(avatar: some View, name: String, detail: String) -> some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.rounded(18, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.rounded(15, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.inkSoft.opacity(0.6))
        }
        .padding(12)
        .card(cornerRadius: 22)
    }
}

// MARK: - Pretend chat (play-only, canned replies)

struct ChatView: View {
    let contact: Contact
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(model.messages(for: contact)) { message in
                                bubble(message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: model.messages(for: contact).count) { _ in
                        if let last = model.messages(for: contact).last {
                            withAnimation(.spring(response: 0.35)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    // iOS 16 has no bottom default scroll anchor: open on the
                    // newest message by scrolling there once laid out.
                    .onAppear {
                        if let last = model.messages(for: contact).last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                        Task {
                            try? await Task.sleep(for: .seconds(0.15))
                            if let last = model.messages(for: contact).last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                composer
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CloseButton { dismiss() }
            SymbolAvatar(symbol: contact.symbol, color: contact.color, size: 52)
            Text(contact.name)
                .font(.rounded(24))
                .foregroundStyle(Palette.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func bubble(_ message: Message) -> some View {
        HStack {
            if message.isFromChild { Spacer(minLength: 60) }
            Text(message.text)
                .font(.rounded(22, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    message.isFromChild ? AnyShapeStyle(contact.color) : AnyShapeStyle(Palette.card),
                    in: RoundedRectangle(cornerRadius: 20)
                )
                .foregroundStyle(message.isFromChild ? .white : Palette.ink)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            if !message.isFromChild { Spacer(minLength: 60) }
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach(Sticker.all) { sticker in
                    Button {
                        model.send(sticker.text, to: contact)
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

            HStack(spacing: 8) {
                ForEach(Sticker.phrases, id: \.self) { phrase in
                    Button {
                        model.send(phrase, to: contact)
                    } label: {
                        Text(phrase)
                            .font(.rounded(15, weight: .semibold))
                            .foregroundStyle(contact.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(contact.color.opacity(0.13), in: Capsule())
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Palette.field.opacity(0.6))
    }
}
