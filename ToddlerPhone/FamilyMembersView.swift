import SwiftUI

// MARK: - Who is in the family
//
// One screen for everything about family membership: what this phone is
// called, who else is in the family, how to invite someone new and how to
// take a phone back out again. Reachable from both the grown-up dashboard
// and the grown-ups settings, so it works the same on every phone.

struct FamilyMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var familyStore = FamilyStore.shared

    @State private var draftName = ""
    @State private var editingName = false
    @State private var joinCode = ""
    @State private var pendingRemoval: FamilyStore.DeviceStatus?
    @State private var busy = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                thisPhoneSection

                if familyStore.isConnected {
                    membersSection
                    inviteSection
                    leaveSection
                } else {
                    joinSection
                }

                if let error = familyStore.lastError {
                    Section {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Remove \(pendingRemoval?.name ?? "")?",
                isPresented: Binding(
                    get: { pendingRemoval != nil },
                    set: { if !$0 { pendingRemoval = nil } }
                )
            ) {
                Button("Remove", role: .destructive) {
                    if let member = pendingRemoval { remove(member) }
                    pendingRemoval = nil
                }
                Button("Keep", role: .cancel) { pendingRemoval = nil }
            } message: {
                Text("That phone leaves the family. It stops showing up as a contact and can no longer see family messages. You can always add it back with the family code.")
            }
            .task {
                draftName = familyStore.displayName
                if familyStore.isConnected {
                    await familyStore.publishStatus()
                    _ = await familyStore.fetchStatuses()
                }
            }
        }
    }

    // MARK: This phone

    private var thisPhoneSection: some View {
        Section("This phone") {
            HStack(spacing: 12) {
                InitialsAvatar(
                    name: familyStore.displayName.isEmpty ? "?" : familyStore.displayName,
                    color: Palette.blue,
                    size: 44
                )
                VStack(alignment: .leading, spacing: 2) {
                    if editingName {
                        TextField("Name", text: $draftName)
                            .font(.body.bold())
                            .submitLabel(.done)
                            .onSubmit { saveName() }
                    } else {
                        Text(familyStore.displayName.isEmpty ? "No name yet" : familyStore.displayName)
                            .font(.body.bold())
                    }
                    Text(isParent ? "Grown-up's phone" : "Kid's phone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if editingName {
                    Button("Save") { saveName() }
                        .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Button("Edit") {
                        draftName = familyStore.displayName
                        editingName = true
                    }
                }
            }

            Text("This is the name the rest of the family sees on their phones. Every grown-up in the family can have their own — Mom, Dad, Grandma — and each one shows up as a separate contact on the kid's phone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Everyone else

    private var membersSection: some View {
        Section("In this family") {
            if familyStore.members.isEmpty {
                Text("Nobody else has joined yet. Share the family code below and the other phone will appear here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(familyStore.members) { member in
                    HStack(spacing: 12) {
                        InitialsAvatar(
                            name: member.name,
                            color: Palette.colorFor(member.name),
                            size: 40
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.body.bold())
                            HStack(spacing: 4) {
                                Text(member.isKid ? "Kid's phone" : "Grown-up")
                                if member.battery >= 0 {
                                    Text("· \(member.battery)%")
                                }
                                Text("· seen")
                                Text(member.updatedAt, style: .relative)
                                Text("ago")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) { pendingRemoval = member }
                    }
                    .contextMenu {
                        Button("Remove from family", role: .destructive) { pendingRemoval = member }
                    }
                }
            }

            if busy {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Updating…").foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    busy = true
                    await familyStore.publishStatus()
                    _ = await familyStore.fetchStatuses()
                    busy = false
                }
            } label: {
                Label("Refresh the list", systemImage: "arrow.clockwise")
            }
            .disabled(busy)

            Text("Swipe a name to remove that phone from the family.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Adding someone

    private var inviteSection: some View {
        Section("Add someone") {
            if let code = familyStore.code {
                HStack {
                    Text("Family code")
                    Spacer()
                    Text(code)
                        .font(.system(.title3, design: .monospaced).bold())
                }

                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy the code", systemImage: copied ? "checkmark" : "doc.on.doc")
                }

                ShareLink(
                    item: "Join our family on My First Phone. Install the app, choose \"My phone (parent)\" and enter the family code \(code)."
                ) {
                    Label("Share an invite", systemImage: "square.and.arrow.up")
                }

                Text("On the new phone: install My First Phone, pick whose phone it is, give it a name, then enter this code. It joins the family and appears here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var joinSection: some View {
        Section("Start a family") {
            Button("Create a new family code") {
                familyStore.code = FamilyStore.newCode()
                Task { await familyStore.publishStatus() }
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
                    Task {
                        await familyStore.publishStatus()
                        _ = await familyStore.fetchStatuses()
                    }
                }
                .disabled(!(6...8).contains(joinCode.trimmingCharacters(in: .whitespaces).count))
            }
        }
    }

    private var leaveSection: some View {
        Section {
            Button("Leave this family", role: .destructive) {
                familyStore.leaveFamily()
            }
        } footer: {
            Text("This phone stops sharing with the family. Nothing is deleted from the other phones.")
        }
    }

    // MARK: Actions

    private var isParent: Bool {
        UserDefaults.standard.string(forKey: "phoneRole") == "parent"
    }

    private func saveName() {
        let name = draftName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        editingName = false
        Task {
            busy = true
            await familyStore.rename(to: name)
            busy = false
        }
    }

    private func remove(_ member: FamilyStore.DeviceStatus) {
        Task {
            busy = true
            await familyStore.removeMember(member.name)
            _ = await familyStore.fetchStatuses()
            busy = false
        }
    }
}
