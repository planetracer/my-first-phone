import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    @StateObject private var callEngine = CallEngine.shared
    @State private var quietNow = false

    var body: some View {
        ZStack {
            switch model.kidPreview ? .kid : model.role {
            case nil:
                SetupView().transition(.opacity)
            case .parent:
                ParentHomeView().transition(.opacity)
            case .kid:
                kidScreens
            }

            if quietNow, model.role == .kid {
                BedtimeView { quietNow = model.isQuietNow() }
                    .transition(.opacity)
                    .zIndex(5)
            }

            if callEngine.phase != .idle {
                LiveCallView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: quietNow)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.role)
        .animation(.spring(response: 0.35), value: callEngine.phase == .idle)
        .task {
            // Push subscriptions + status beacon, then poll for incoming calls.
            if FamilyStore.shared.isConnected {
                await FamilyStore.shared.enableNotifications()
            }
            var lastStatusPush = Date.distantPast
            while !Task.isCancelled {
                quietNow = model.isQuietNow()
                // No polling while a call is already on screen.
                if callEngine.phase == .idle {
                    await callEngine.checkForIncoming()
                }
                // Every device announces itself so it appears as a contact
                // on the other family phones.
                if FamilyStore.shared.isConnected,
                   Date.now.timeIntervalSince(lastStatusPush) > 240 {
                    lastStatusPush = .now
                    await FamilyStore.shared.publishStatus()
                    _ = await FamilyStore.shared.fetchStatuses()
                }
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    @ViewBuilder
    private var kidScreens: some View {
        ZStack {
            switch model.screen {
            case .home:
                HomeView().transition(.opacity)
            case .phone:
                PhoneView().transition(.move(edge: .trailing))
            case .messages:
                MessagesView().transition(.move(edge: .trailing))
            case .camera:
                KidCameraView().transition(.move(edge: .trailing))
            case .books:
                BooksView().transition(.move(edge: .trailing))
            case .games:
                GamesView().transition(.move(edge: .trailing))
            case .tv:
                TVView().transition(.move(edge: .trailing))
            case .doodle:
                DoodleView().transition(.move(edge: .trailing))
            case .coloring:
                ColoringView().transition(.move(edge: .trailing))
            case .sounds:
                SoundboardView().transition(.move(edge: .trailing))
            case .flashlight:
                FlashlightView().transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.screen)
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showParentSheet = false

    private static let apps: [(icon: String, label: String, color: Color, screen: AppScreen)] = [
        ("phone.fill", "Phone", Palette.green, .phone),
        ("message.fill", "Messages", Palette.blue, .messages),
        ("camera.fill", "Camera", Palette.teal, .camera),
        ("books.vertical.fill", "Books", Palette.pink, .books),
        ("puzzlepiece.fill", "Games", Palette.red, .games),
        ("play.tv.fill", "TV", Palette.indigo, .tv),
        ("paintbrush.pointed.fill", "Doodle", Palette.orange, .doodle),
        ("paintpalette.fill", "Coloring", Palette.yellow, .coloring),
        ("speaker.wave.2.fill", "Sounds", Palette.purple, .sounds),
        ("flashlight.on.fill", "Light", Palette.brown, .flashlight),
    ]

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(Self.apps, id: \.label) { app in
                            HomeTile(icon: app.icon, label: app.label, color: app.color) {
                                model.screen = app.screen
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }

                grownUpsButton
            }
        }
        .sheet(isPresented: $showParentSheet) {
            ParentAccessView()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hello!")
                    .font(.rounded(17, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                Text(Date.now, style: .time)
                    .font(.rounded(36))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var grownUpsButton: some View {
        Group {
            if model.kidPreview {
                Button {
                    Sfx.tap()
                    model.kidPreview = false
                    model.screen = .home
                } label: {
                    Label("Done previewing kid mode", systemImage: "arrow.uturn.backward")
                        .font(.rounded(14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Palette.blue, in: Capsule())
                }
                .buttonStyle(BouncyButtonStyle())
            } else {
                Button {
                    Sfx.tap()
                    showParentSheet = true
                } label: {
                    Label("For grown-ups", systemImage: "lock.fill")
                        .font(.rounded(14, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
        .padding(.bottom, 10)
    }
}

/// Full-screen bedtime lock shown during quiet hours on the kid phone.
struct BedtimeView: View {
    @EnvironmentObject private var model: AppModel
    let onUnlock: () -> Void
    @State private var showCodePad = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.22), Color(red: 0.14, green: 0.12, blue: 0.34)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 0.5)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ForEach(0..<14, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: 8 + CGFloat(i % 3) * 5))
                            .foregroundStyle(.white)
                            .opacity(0.2 + 0.5 * abs(sin(t * 0.8 + Double(i))))
                            .position(
                                x: geo.size.width * abs(sin(Double(i) * 127.3)),
                                y: geo.size.height * (0.05 + 0.5 * abs(sin(Double(i) * 311.7)))
                            )
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Palette.yellow.opacity(0.9))

                Text("Shhh… bedtime!")
                    .font(.rounded(32))
                    .foregroundStyle(.white)

                Text("The phone is sleeping too.\nSweet dreams!")
                    .font(.rounded(17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    Sfx.tap()
                    showCodePad = true
                } label: {
                    Label("Grown-ups", systemImage: "lock.fill")
                        .font(.rounded(14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showCodePad) {
            CodePadView {
                model.overrideQuietHours()
                showCodePad = false
                onUnlock()
            }
        }
    }
}

struct HomeTile: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            Sfx.tap()
            Sfx.bump(.light)
            action()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 68, height: 68)
                    .background(color.opacity(0.13), in: Circle())
                Text(label)
                    .font(.rounded(17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .card()
        }
        .buttonStyle(BouncyButtonStyle())
    }
}
