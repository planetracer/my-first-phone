import SwiftUI

// MARK: - Dress Up Studio (characters, wardrobe, saved looks and a weather game)

/// Who is being dressed. All three share the same clothing system.
enum DressCharacter: Int, CaseIterable, Identifiable {
    case child, bear, bunny
    var id: Int { rawValue }
    var name: String {
        switch self {
        case .child: return "Child"
        case .bear: return "Bear"
        case .bunny: return "Bunny"
        }
    }
    var isAnimal: Bool { self != .child }
}

/// The face the character is pulling.
enum DressFace: Int, CaseIterable, Identifiable {
    case happy, giggly, surprised, sleepy
    var id: Int { rawValue }
    var name: String {
        switch self {
        case .happy: return "Happy"
        case .giggly: return "Giggly"
        case .surprised: return "Surprised"
        case .sleepy: return "Sleepy"
        }
    }
}

/// Which part of the outfit a weather card is looking at.
enum DressSlot: Hashable {
    case top, bottom, shoes, head, extra
}

/// Every color the studio can use.
enum DressPalette {
    static let skins: [Color] = [
        Color(red: 0.99, green: 0.88, blue: 0.78),
        Color(red: 0.95, green: 0.78, blue: 0.62),
        Color(red: 0.86, green: 0.64, blue: 0.45),
        Color(red: 0.70, green: 0.48, blue: 0.32),
        Color(red: 0.55, green: 0.36, blue: 0.24),
        Color(red: 0.38, green: 0.25, blue: 0.17),
    ]
    static let hairs: [Color] = [
        Color(red: 0.13, green: 0.11, blue: 0.10),
        Color(red: 0.35, green: 0.22, blue: 0.12),
        Color(red: 0.78, green: 0.60, blue: 0.30),
        Color(red: 0.55, green: 0.24, blue: 0.12),
    ]
    static let tops: [Color] = [Palette.blue, Palette.pink, Palette.green, Palette.yellow, Palette.purple]
    static let bottoms: [Color] = [Palette.indigo, Palette.brown, Palette.teal, Palette.red]
    static let heads: [Color] = [
        Color(red: 0.82, green: 0.55, blue: 0.58),   // dusty rose
        Color(red: 0.60, green: 0.68, blue: 0.55),   // sage
        Color(red: 0.20, green: 0.27, blue: 0.45),   // navy
        Color(red: 0.93, green: 0.90, blue: 0.80),   // cream
    ]

    static let topNames = ["T-shirt", "Dress", "Hoodie", "Stripes", "Overalls"]
    static let bottomNames = ["Pants", "Skirt", "Shorts"]
    static let shoeNames = ["Bare feet", "Sneakers", "Boots", "Sandals"]
    static let headNames = ["None", "Cap", "Sun hat", "Scarf", "Hijab", "Beanie", "Party hat"]
    static let extraNames = ["None", "Glasses", "Backpack", "Necklace", "Wand"]
}

/// One whole look, small enough to store as a single number.
struct DressOutfit: Equatable {
    var character = 0     // 0 child, 1 bear, 2 bunny
    var skin = 2          // 0 to 5
    var hairStyle = 1     // 0 none, 1 short, 2 curly, 3 buns
    var hairColor = 0     // 0 to 3
    var top = 0           // 0 t-shirt, 1 dress, 2 hoodie, 3 stripes, 4 overalls
    var topColor = 0      // 0 to 4
    var bottom = 0        // 0 pants, 1 skirt, 2 shorts
    var bottomColor = 0   // 0 to 3
    var shoes = 1         // 0 bare, 1 sneakers, 2 boots, 3 sandals
    var head = 0          // 0 none, 1 cap, 2 sun hat, 3 scarf, 4 hijab, 5 beanie, 6 party hat
    var headColor = 0     // 0 to 3
    var extra = 0         // 0 none, 1 glasses, 2 backpack, 3 necklace, 4 wand
    var face = 0          // 0 happy, 1 giggly, 2 surprised, 3 sleepy

    static let radices = [3, 6, 4, 4, 5, 5, 3, 4, 4, 7, 4, 5, 4]

    var kind: DressCharacter { DressCharacter(rawValue: character) ?? .child }
    var mood: DressFace { DressFace(rawValue: face) ?? .happy }

    var skinColor: Color { DressPalette.skins[min(skin, DressPalette.skins.count - 1)] }
    var hairShade: Color { DressPalette.hairs[min(hairColor, DressPalette.hairs.count - 1)] }
    var topShade: Color { DressPalette.tops[min(topColor, DressPalette.tops.count - 1)] }
    var bottomShade: Color { DressPalette.bottoms[min(bottomColor, DressPalette.bottoms.count - 1)] }
    var headShade: Color { DressPalette.heads[min(headColor, DressPalette.heads.count - 1)] }

    var values: [Int] {
        [character, skin, hairStyle, hairColor, top, topColor,
         bottom, bottomColor, shoes, head, headColor, extra, face]
    }

    /// The whole look packed into one integer for @AppStorage.
    var code: Int {
        var packed = 0
        for (value, radix) in zip(values, Self.radices) {
            packed = packed * radix + min(max(value, 0), radix - 1)
        }
        return packed
    }
}

extension DressOutfit {
    init(code: Int) {
        var rest = max(code, 0)
        var out = [Int](repeating: 0, count: Self.radices.count)
        for i in stride(from: Self.radices.count - 1, through: 0, by: -1) {
            out[i] = rest % Self.radices[i]
            rest /= Self.radices[i]
        }
        self.init(
            character: out[0], skin: out[1], hairStyle: out[2], hairColor: out[3],
            top: out[4], topColor: out[5], bottom: out[6], bottomColor: out[7],
            shoes: out[8], head: out[9], headColor: out[10], extra: out[11], face: out[12]
        )
    }

    func changing(_ change: (inout DressOutfit) -> Void) -> DressOutfit {
        var copy = self
        change(&copy)
        return copy
    }

    static func random() -> DressOutfit {
        var out = DressOutfit()
        for (i, radix) in radices.enumerated() {
            let value = Int.random(in: 0..<radix)
            switch i {
            case 0: out.character = value
            case 1: out.skin = value
            case 2: out.hairStyle = value
            case 3: out.hairColor = value
            case 4: out.top = value
            case 5: out.topColor = value
            case 6: out.bottom = value
            case 7: out.bottomColor = value
            case 8: out.shoes = value
            case 9: out.head = value
            case 10: out.headColor = value
            case 11: out.extra = value
            default: out.face = value
            }
        }
        return out
    }
}

/// The scenes behind the character.
enum DressBackdrop: Int, CaseIterable, Identifiable {
    case bedroom, park, night, snow, rain, beach
    var id: Int { rawValue }
    var name: String {
        switch self {
        case .bedroom: return "Bedroom"
        case .park: return "Park"
        case .night: return "Night"
        case .snow: return "Snow"
        case .rain: return "Rain"
        case .beach: return "Beach"
        }
    }
}

/// One card in the gentle dress for the weather game.
struct WeatherCard: Identifiable, Equatable {
    let id: Int
    let title: String
    let symbol: String
    let backdrop: DressBackdrop
    let spoken: String
    let praise: String

    static let all: [WeatherCard] = [
        WeatherCard(id: 0, title: "It is snowy!", symbol: "snowflake",
                    backdrop: .snow, spoken: "It is snowy outside. Can you dress warm?",
                    praise: "That will keep you cosy!"),
        WeatherCard(id: 1, title: "It is rainy!", symbol: "cloud.rain.fill",
                    backdrop: .rain, spoken: "It is rainy. What should we wear?",
                    praise: "Good idea for the rain!"),
        WeatherCard(id: 2, title: "Beach day!", symbol: "sun.max.fill",
                    backdrop: .beach, spoken: "It is sunny at the beach. Let us get ready!",
                    praise: "Perfect for the sunshine!"),
        WeatherCard(id: 3, title: "Bedtime!", symbol: "moon.stars.fill",
                    backdrop: .night, spoken: "It is bedtime. Let us get comfy!",
                    praise: "Nice and comfy!"),
    ]

    /// Which parts of this outfit suit the weather. Nothing is ever wrong,
    /// these are just the ones that sparkle.
    func matches(_ outfit: DressOutfit) -> Set<DressSlot> {
        var found: Set<DressSlot> = []
        switch id {
        case 0:
            if outfit.top == 2 { found.insert(.top) }
            if outfit.bottom == 0 { found.insert(.bottom) }
            if outfit.shoes == 2 { found.insert(.shoes) }
            if outfit.head == 5 || outfit.head == 3 { found.insert(.head) }
        case 1:
            if outfit.top == 2 { found.insert(.top) }
            if outfit.bottom == 0 { found.insert(.bottom) }
            if outfit.shoes == 2 { found.insert(.shoes) }
            if outfit.head == 1 || outfit.head == 3 { found.insert(.head) }
        case 2:
            if outfit.top == 0 || outfit.top == 1 { found.insert(.top) }
            if outfit.bottom == 1 || outfit.bottom == 2 { found.insert(.bottom) }
            if outfit.shoes == 0 || outfit.shoes == 3 { found.insert(.shoes) }
            if outfit.head == 2 { found.insert(.head) }
            if outfit.extra == 1 { found.insert(.extra) }
        default:
            if outfit.top == 3 { found.insert(.top) }
            if outfit.bottom == 0 || outfit.bottom == 2 { found.insert(.bottom) }
            if outfit.shoes == 0 { found.insert(.shoes) }
            if outfit.head == 0 { found.insert(.head) }
        }
        return found
    }
}

// MARK: - The studio

struct DressUpView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var familyStore = FamilyStore.shared

    @AppStorage("dressStars") private var stars = 0
    @AppStorage("dressLook0") private var look0 = -1
    @AppStorage("dressLook1") private var look1 = -1
    @AppStorage("dressLook2") private var look2 = -1
    @AppStorage("dressLook3") private var look3 = -1
    @AppStorage("dressLookNext") private var lookNext = 0

    @State private var outfit = DressOutfit()
    @State private var category: Category = .who
    @State private var backdrop: DressBackdrop = .bedroom

    @State private var breathe = false
    @State private var blinking = false
    @State private var bounce = false
    @State private var sparkle = false
    @State private var sending = false
    @State private var sentConfirmation = false

    @State private var weather: WeatherCard?
    @State private var matched: Set<DressSlot> = []
    @State private var showCelebration = false

    private let blinkTimer = Timer.publish(every: 3.1, on: .main, in: .common).autoconnect()

    enum Category: String, CaseIterable, Identifiable {
        case who = "Who", skin = "Skin", hair = "Hair", face = "Face"
        case top = "Top", bottom = "Bottom", shoes = "Shoes"
        case head = "Head", extra = "Extra", looks = "Looks"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .who: return "person.fill"
            case .skin: return "paintpalette.fill"
            case .hair: return "comb.fill"
            case .face: return "face.smiling"
            case .top: return "tshirt.fill"
            case .bottom: return "rectangle.split.2x1.fill"
            case .shoes: return "shoe.fill"
            case .head: return "crown.fill"
            case .extra: return "eyeglasses"
            case .looks: return "heart.fill"
            }
        }
    }

    private var savedLooks: [Int] { [look0, look1, look2, look3] }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 10) {
                GameTopBar(title: "Dress Up", stars: stars, starColor: Palette.pink, onClose: { dismiss() })

                stage

                controlRow

                categoryRow

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        optionsRow
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                }
                .frame(height: 84)
                .padding(.bottom, 10)
            }

            if showCelebration, let card = weather {
                CelebrationOverlay(
                    title: "All dressed!",
                    subtitle: card.title,
                    buttonLabel: "New card",
                    symbol: card.symbol,
                    tint: Palette.pink
                ) {
                    showCelebration = false
                    nextWeatherCard()
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
            #if DEBUG
            debugJump()
            #endif
        }
        .onReceive(blinkTimer) { _ in
            guard Int.random(in: 0...3) > 0 else { return }
            blinking = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.15))
                blinking = false
            }
        }
        .onChange(of: outfit) { _ in
            bounceCharacter()
            checkWeather()
        }
    }

    // MARK: Toolbar

    @ViewBuilder
    private var toolbarButtons: some View {
        Button {
            Sfx.tap()
            Sfx.bump(.light)
            if weather == nil { startWeather() } else { stopWeather() }
        } label: {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(weather == nil ? Palette.ink : .white)
                .frame(width: 48, height: 48)
                .background(weather == nil ? Palette.card : Palette.pink, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(BouncyButtonStyle())

        Button {
            Sfx.bump()
            withAnimation(.spring(response: 0.35)) { outfit = DressOutfit.random() }
        } label: {
            Image(systemName: "dice.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 48, height: 48)
                .card(cornerRadius: 16)
        }
        .buttonStyle(BouncyButtonStyle())

        if familyStore.isConnected {
            Button {
                sendToFamily()
            } label: {
                Group {
                    if sending {
                        ProgressView().progressViewStyle(.circular)
                    } else {
                        Image(systemName: sentConfirmation ? "checkmark" : "paperplane.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(sentConfirmation ? Palette.green : Palette.ink)
                    }
                }
                .frame(width: 48, height: 48)
                .card(cornerRadius: 16)
            }
            .buttonStyle(BouncyButtonStyle())
            .disabled(sending || sentConfirmation)
        }
    }

    // MARK: Stage

    private var stage: some View {
        ZStack {
            BackdropScene(kind: backdrop)

            CharacterView(outfit: outfit, blinking: blinking)
                .padding(.horizontal, 40)
                .padding(.vertical, 10)
                .scaleEffect(breathe ? 1.015 : 0.99)
                .scaleEffect(bounce ? 1.06 : 1)

            if sparkle {
                ZStack {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: 26 + CGFloat(i % 3) * 8))
                            .foregroundStyle(Palette.yellow)
                            .offset(
                                x: CGFloat([-70, 60, -40, 74, 20][i]),
                                y: CGFloat([-60, -30, 50, 24, -90][i])
                            )
                    }
                }
                .transition(.scale.combined(with: .opacity))
                .allowsHitTesting(false)

                ConfettiBurst(count: 18, spread: 130, duration: 1.2)
                    .allowsHitTesting(false)
            }

            if let card = weather {
                weatherCardView(card)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        .padding(.horizontal, 20)
    }

    private func weatherCardView(_ card: WeatherCard) -> some View {
        HStack(spacing: 10) {
            Image(systemName: card.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.pink)
            Text(card.title)
                .font(.rounded(16, weight: .semibold))
                .foregroundStyle(Palette.ink)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < matched.count ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(i < matched.count ? Palette.yellow : Palette.inkSoft.opacity(0.55))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .card(cornerRadius: 20)
    }

    // MARK: Rows

    private var controlRow: some View {
        HStack(spacing: 8) {
            toolbarButtons
            backdropRow
        }
        .padding(.leading, 20)
        .frame(height: 60)
    }

    private var backdropRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DressBackdrop.allCases) { scene in
                    Button {
                        Sfx.tap()
                        Sfx.bump(.light)
                        bounceCharacter()
                        withAnimation(.spring(response: 0.35)) { backdrop = scene }
                    } label: {
                        BackdropScene(kind: scene)
                            .frame(width: 72, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(backdrop == scene ? Palette.pink : .white, lineWidth: 3)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .accessibilityLabel(scene.name)
                }
            }
            .padding(.trailing, 20)
            .padding(.vertical, 4)
        }
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Category.allCases) { cat in
                    Button {
                        Sfx.tap()
                        Sfx.bump(.light)
                        withAnimation(.spring(response: 0.3)) { category = cat }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cat.symbol)
                                .font(.system(size: 14, weight: .semibold))
                            Text(cat.rawValue)
                                .font(.rounded(15, weight: .semibold))
                        }
                        .foregroundStyle(category == cat ? .white : Palette.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(
                            category == cat ? Palette.pink : Palette.card,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .frame(height: 56)
    }

    @ViewBuilder
    private var optionsRow: some View {
        switch category {
        case .who:
            ForEach(DressCharacter.allCases) { who in
                styleSwatch(selected: outfit.character == who.rawValue) {
                    outfit.character = who.rawValue
                } content: {
                    MiniHead(outfit: outfit.changing { $0.character = who.rawValue })
                }
            }
        case .skin:
            ForEach(0..<DressPalette.skins.count, id: \.self) { i in
                colorSwatch(DressPalette.skins[i], selected: outfit.skin == i) { outfit.skin = i }
            }
        case .hair:
            ForEach(0..<4, id: \.self) { style in
                styleSwatch(selected: outfit.hairStyle == style) {
                    outfit.hairStyle = style
                } content: {
                    MiniHead(outfit: outfit.changing { $0.hairStyle = style; $0.head = 0; $0.extra = 0 })
                }
            }
            divider
            ForEach(0..<DressPalette.hairs.count, id: \.self) { i in
                colorSwatch(DressPalette.hairs[i], selected: outfit.hairColor == i) { outfit.hairColor = i }
            }
        case .face:
            ForEach(DressFace.allCases) { mood in
                styleSwatch(selected: outfit.face == mood.rawValue) {
                    outfit.face = mood.rawValue
                } content: {
                    MiniHead(outfit: outfit.changing { $0.face = mood.rawValue; $0.head = 0 })
                }
            }
        case .top:
            ForEach(0..<DressPalette.topNames.count, id: \.self) { style in
                styleSwatch(selected: outfit.top == style) {
                    outfit.top = style
                } content: {
                    TopPreview(style: style, color: outfit.topShade)
                }
            }
            divider
            ForEach(0..<DressPalette.tops.count, id: \.self) { i in
                colorSwatch(DressPalette.tops[i], selected: outfit.topColor == i) { outfit.topColor = i }
            }
        case .bottom:
            ForEach(0..<DressPalette.bottomNames.count, id: \.self) { style in
                styleSwatch(selected: outfit.bottom == style) {
                    outfit.bottom = style
                } content: {
                    BottomPreview(style: style, color: outfit.bottomShade)
                }
            }
            divider
            ForEach(0..<DressPalette.bottoms.count, id: \.self) { i in
                colorSwatch(DressPalette.bottoms[i], selected: outfit.bottomColor == i) { outfit.bottomColor = i }
            }
        case .shoes:
            ForEach(0..<DressPalette.shoeNames.count, id: \.self) { style in
                styleSwatch(selected: outfit.shoes == style) {
                    outfit.shoes = style
                } content: {
                    ShoePreview(style: style, skin: outfit.skinColor)
                }
            }
        case .head:
            ForEach(0..<DressPalette.headNames.count, id: \.self) { style in
                styleSwatch(selected: outfit.head == style) {
                    outfit.head = style
                } content: {
                    MiniHead(outfit: outfit.changing { $0.head = style; $0.extra = 0 })
                }
            }
            divider
            ForEach(0..<DressPalette.heads.count, id: \.self) { i in
                colorSwatch(DressPalette.heads[i], selected: outfit.headColor == i) { outfit.headColor = i }
            }
        case .extra:
            ForEach(0..<DressPalette.extraNames.count, id: \.self) { style in
                styleSwatch(selected: outfit.extra == style) {
                    outfit.extra = style
                } content: {
                    ExtraPreview(style: style, color: outfit.topShade)
                }
            }
        case .looks:
            Button {
                saveLook()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.pink)
                    Text("Save")
                        .font(.rounded(13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 68, height: 64)
                .background(Palette.field, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(BouncyButtonStyle())

            divider

            ForEach(0..<4, id: \.self) { slot in
                Button {
                    loadLook(slot)
                } label: {
                    Group {
                        if savedLooks[slot] >= 0 {
                            CharacterView(outfit: DressOutfit(code: savedLooks[slot]))
                                .padding(4)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Palette.inkSoft.opacity(0.6))
                        }
                    }
                    .frame(width: 56, height: 64)
                    .background(Palette.field, in: RoundedRectangle(cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
    }

    private var divider: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Palette.inkSoft.opacity(0.25))
            .frame(width: 2, height: 48)
    }

    private func colorSwatch(_ color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Sfx.tap()
            Sfx.bump(.light)
            withAnimation(.spring(response: 0.3)) { action() }
        } label: {
            Circle()
                .fill(color)
                .frame(width: 52, height: 52)
                .overlay(
                    Circle().stroke(selected ? Palette.ink : .white, lineWidth: selected ? 4 : 2)
                )
                .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private func styleSwatch<Content: View>(
        selected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            Sfx.tap()
            Sfx.bump(.light)
            withAnimation(.spring(response: 0.3)) { action() }
        } label: {
            content()
                .frame(width: 64, height: 64)
                .background(Palette.field, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selected ? Palette.pink : .clear, lineWidth: 4)
                )
        }
        .buttonStyle(BouncyButtonStyle())
    }

    // MARK: Saved looks

    private func setLook(_ slot: Int, _ code: Int) {
        switch slot {
        case 0: look0 = code
        case 1: look1 = code
        case 2: look2 = code
        default: look3 = code
        }
    }

    private func saveLook() {
        Sfx.pop()
        Sfx.bump()
        let empty = savedLooks.firstIndex(of: -1)
        let slot = empty ?? min(max(lookNext, 0), 3)
        setLook(slot, outfit.code)
        lookNext = (slot + 1) % 4
        Speaker.shared.say("Look saved!")
    }

    private func loadLook(_ slot: Int) {
        let code = savedLooks[slot]
        guard code >= 0 else {
            Sfx.tap()
            Speaker.shared.say("Tap save to keep this look!")
            return
        }
        Sfx.pop()
        Sfx.bump(.light)
        withAnimation(.spring(response: 0.35)) { outfit = DressOutfit(code: code) }
    }

    // MARK: Weather game

    private func startWeather() {
        let card = WeatherCard.all.randomElement() ?? WeatherCard.all[0]
        withAnimation(.spring(response: 0.4)) {
            weather = card
            backdrop = card.backdrop
            matched = card.matches(outfit)
        }
        Speaker.shared.say(card.spoken)
    }

    private func nextWeatherCard() {
        let others = WeatherCard.all.filter { $0.id != weather?.id }
        let card = others.randomElement() ?? WeatherCard.all[0]
        withAnimation(.spring(response: 0.4)) {
            weather = card
            backdrop = card.backdrop
            matched = card.matches(outfit)
        }
        Speaker.shared.say(card.spoken)
    }

    private func stopWeather() {
        withAnimation(.spring(response: 0.35)) {
            weather = nil
            matched = []
        }
    }

    /// Every pick is accepted. Sensible ones sparkle and earn a star.
    private func checkWeather() {
        guard let card = weather, !showCelebration else { return }
        let now = card.matches(outfit)
        let fresh = now.subtracting(matched)
        matched = now

        if !fresh.isEmpty {
            stars += fresh.count
            Sfx.pop()
            Sfx.bump(.light)
            Speaker.shared.say(card.praise)
            withAnimation(.spring(response: 0.3)) { sparkle = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.1))
                withAnimation(.easeOut(duration: 0.4)) { sparkle = false }
            }
        }

        if now.count >= 3 {
            Speaker.shared.cheer("You are all dressed for it!")
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.spring(response: 0.4)) { showCelebration = true }
            }
        }
    }

    // MARK: Bits and pieces

    #if DEBUG
    /// Lets `simctl launch ... -dressOutfit 1234 -dressCard 0 -dressTab Top` set up a look.
    private func debugJump() {
        if let raw = UserDefaults.standard.string(forKey: "dressOutfit"), let code = Int(raw) {
            outfit = DressOutfit(code: code)
        }
        if let raw = UserDefaults.standard.string(forKey: "dressCard"), let index = Int(raw) {
            let card = WeatherCard.all[min(max(index, 0), WeatherCard.all.count - 1)]
            weather = card
            backdrop = card.backdrop
            matched = card.matches(outfit)
        }
        if let raw = UserDefaults.standard.string(forKey: "dressTab"),
           let tab = Category(rawValue: raw) {
            category = tab
        }
    }
    #endif

    private func bounceCharacter() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.42)) { bounce = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) { bounce = false }
        }
    }

    /// Renders the dressed character on its backdrop and sends it to family.
    private func sendToFamily() {
        guard !sending else { return }
        Sfx.bump()
        sending = true

        let card = ZStack {
            BackdropScene(kind: backdrop)
            CharacterView(outfit: outfit, blinking: false)
                .padding(.horizontal, 46)
                .padding(.vertical, 16)
        }
        .frame(width: 420, height: 560)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 2

        guard let image = renderer.uiImage,
              let data = image.jpegData(compressionQuality: 0.85) else {
            sending = false
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dressup-\(UUID().uuidString).jpg")
        try? data.write(to: url)

        Task { @MainActor in
            await FamilyStore.shared.sendPhoto(fileURL: url)
            sending = false
            sentConfirmation = true
            Speaker.shared.say("Sent to your family!")
            try? await Task.sleep(for: .seconds(2.5))
            sentConfirmation = false
        }
    }
}

// MARK: - Option previews

/// A small drawing of one top style.
struct TopPreview: View {
    let style: Int
    let color: Color

    var body: some View {
        switch style {
        case 1:
            TrapezoidShape(topInset: 0.3)
                .fill(color)
                .frame(width: 34, height: 40)
        case 2:
            ZStack {
                Circle().fill(color.opacity(0.7)).frame(width: 22, height: 22).offset(y: -16)
                RoundedRectangle(cornerRadius: 8).fill(color).frame(width: 36, height: 34)
                Capsule().fill(color.opacity(0.6)).frame(width: 18, height: 7).offset(y: 8)
            }
        case 3:
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay(
                    VStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule().fill(.white.opacity(0.8)).frame(height: 4)
                        }
                    }
                    .padding(.horizontal, 4)
                )
        case 4:
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(.white).frame(width: 36, height: 34)
                RoundedRectangle(cornerRadius: 6).fill(color).frame(width: 24, height: 24).offset(y: 5)
                HStack(spacing: 16) {
                    Capsule().fill(color).frame(width: 6, height: 18)
                    Capsule().fill(color).frame(width: 6, height: 18)
                }
                .offset(y: -10)
            }
        default:
            Image(systemName: "tshirt.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

/// A small drawing of one bottom style.
struct BottomPreview: View {
    let style: Int
    let color: Color

    var body: some View {
        switch style {
        case 1:
            TrapezoidShape(topInset: 0.34)
                .fill(color)
                .frame(width: 36, height: 30)
        case 2:
            HStack(spacing: 5) {
                Capsule().fill(color).frame(width: 13, height: 20)
                Capsule().fill(color).frame(width: 13, height: 20)
            }
        default:
            HStack(spacing: 4) {
                Capsule().fill(color).frame(width: 12, height: 36)
                Capsule().fill(color).frame(width: 12, height: 36)
            }
        }
    }
}

/// A small drawing of one pair of shoes.
struct ShoePreview: View {
    let style: Int
    let skin: Color

    var body: some View {
        HStack(spacing: 6) {
            shoe
            shoe
        }
    }

    @ViewBuilder
    private var shoe: some View {
        switch style {
        case 1:
            VStack(spacing: 1) {
                Capsule().fill(.white).frame(width: 20, height: 12)
                Capsule().fill(Palette.ink).frame(width: 22, height: 6)
            }
        case 2:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Palette.brown)
                    .frame(width: 16, height: 22)
                Capsule().fill(Palette.ink.opacity(0.8)).frame(width: 22, height: 7)
            }
        case 3:
            ZStack {
                Capsule().fill(Palette.brown).frame(width: 20, height: 8)
                Capsule().fill(Palette.brown.opacity(0.7))
                    .frame(width: 5, height: 14)
                    .rotationEffect(.degrees(24))
            }
        default:
            Capsule().fill(skin).frame(width: 18, height: 11)
        }
    }
}

/// A small drawing of one accessory.
struct ExtraPreview: View {
    let style: Int
    let color: Color

    var body: some View {
        switch style {
        case 1:
            HStack(spacing: 3) {
                Circle().stroke(Palette.ink, lineWidth: 3).frame(width: 17, height: 17)
                Capsule().fill(Palette.ink).frame(width: 6, height: 3)
                Circle().stroke(Palette.ink, lineWidth: 3).frame(width: 17, height: 17)
            }
        case 2:
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color).frame(width: 32, height: 34)
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.6)).frame(width: 18, height: 12).offset(y: 6)
                Capsule().fill(color.opacity(0.7)).frame(width: 14, height: 6).offset(y: -19)
            }
        case 3:
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Palette.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 30, height: 30)
                Circle().fill(Palette.pink).frame(width: 10, height: 10).offset(y: 16)
            }
        case 4:
            ZStack {
                Capsule().fill(Palette.brown).frame(width: 6, height: 34).rotationEffect(.degrees(20))
                StarShape().fill(Palette.yellow).frame(width: 22, height: 22).offset(x: 6, y: -14)
            }
        default:
            Image(systemName: "minus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Palette.inkSoft.opacity(0.6))
        }
    }
}

// MARK: - The character
//
// Everything is drawn from shapes, but every part carries the same soft dark
// outline and the proportions come from one set of measurements, so the whole
// character reads as a single sticker rather than a pile of rectangles.

/// The ink all of the outlines share.
enum DressInk {
    static let line = Color(red: 0.27, green: 0.23, blue: 0.28)
    static let soft = Color(red: 0.27, green: 0.23, blue: 0.28).opacity(0.22)

    /// A hint of light from above and shadow underneath. Every part of the
    /// character gets it, which is what stops the flat shapes reading like
    /// cut out card.
    static let shading = LinearGradient(
        colors: [.white.opacity(0.17), .white.opacity(0.03), .clear, .black.opacity(0.10)],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Shape {
    /// Fill, a soft round of shading, then the character outline.
    func inked(_ color: Color, _ width: CGFloat, opacity: Double = 0.85) -> some View {
        self.fill(color)
            .overlay(self.fill(DressInk.shading))
            .overlay(self.stroke(DressInk.line.opacity(opacity), lineWidth: width))
    }
}

/// An arm or a leg: fuller at the shoulder or hip and a little narrower at the
/// wrist or ankle. Plain capsules read as broom handles.
struct LimbShape: Shape {
    /// Width at the bottom as a fraction of the width at the top.
    var taper: CGFloat = 0.84

    func path(in r: CGRect) -> Path {
        let topR = r.width / 2
        let botR = max(1, r.width * taper / 2)
        var path = Path()
        path.move(to: CGPoint(x: r.midX - topR, y: r.minY + topR))
        path.addArc(
            center: CGPoint(x: r.midX, y: r.minY + topR), radius: topR,
            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: r.midX + botR, y: r.maxY - botR))
        path.addArc(
            center: CGPoint(x: r.midX, y: r.maxY - botR), radius: botR,
            startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

/// A head: round at the top, a touch narrower at the chin.
struct HeadShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let cx = r.midX
        let top = r.minY
        let bottom = r.maxY
        let temple = top + h * 0.46

        var path = Path()
        path.move(to: CGPoint(x: cx, y: top))
        path.addCurve(
            to: CGPoint(x: r.maxX, y: temple),
            control1: CGPoint(x: cx + w * 0.30, y: top),
            control2: CGPoint(x: r.maxX, y: top + h * 0.17)
        )
        path.addCurve(
            to: CGPoint(x: cx, y: bottom),
            control1: CGPoint(x: r.maxX, y: bottom - h * 0.22),
            control2: CGPoint(x: cx + w * 0.30, y: bottom)
        )
        path.addCurve(
            to: CGPoint(x: r.minX, y: temple),
            control1: CGPoint(x: cx - w * 0.30, y: bottom),
            control2: CGPoint(x: r.minX, y: bottom - h * 0.22)
        )
        path.addCurve(
            to: CGPoint(x: cx, y: top),
            control1: CGPoint(x: r.minX, y: top + h * 0.17),
            control2: CGPoint(x: cx - w * 0.30, y: top)
        )
        path.closeSubpath()
        return path
    }
}

/// Where every part of the body sits, worked out once from the canvas size.
struct DressMetrics {
    let w: CGFloat
    let h: CGFloat
    let headD: CGFloat
    let cx: CGFloat
    let headY: CGFloat
    let torsoTop: CGFloat
    let torsoH: CGFloat
    let torsoW: CGFloat
    let hipY: CGFloat
    let legH: CGFloat
    let legW: CGFloat
    let legGap: CGFloat
    let footY: CGFloat
    let lw: CGFloat

    init(_ size: CGSize) {
        w = size.width
        h = size.height
        headD = min(h * 0.248, w * 0.55)
        cx = size.width / 2
        // Low enough that tall hats and bunny ears stay on the canvas.
        headY = h * 0.250
        // Far enough below the chin to leave a glimpse of neck.
        torsoTop = headY + headD * 0.60
        torsoH = h * 0.260
        torsoW = headD * 1.06
        hipY = torsoTop + torsoH
        legH = h * 0.162
        legW = headD * 0.26
        legGap = headD * 0.16
        footY = hipY + legH
        lw = max(1.1, headD * 0.036)
    }

    /// Middle of one leg. Side is -1 for the left leg, 1 for the right.
    func legX(_ side: CGFloat) -> CGFloat { cx + side * (legW + legGap) / 2 }

    var armW: CGFloat { headD * 0.21 }
    var armL: CGFloat { torsoH * 0.95 }
    var shoulderY: CGFloat { torsoTop + torsoH * 0.03 }
    /// Arms hang just clear of the body so they are always visible.
    func shoulderX(_ side: CGFloat) -> CGFloat { cx + side * (torsoW * 0.5 - armW * 0.30) }
    /// How far the arms swing away from the body.
    static let armAngle: Double = 16
    /// Where the hand ends up once the arm is swung out.
    func handPoint(_ side: CGFloat) -> CGPoint {
        let angle = CGFloat(Self.armAngle) * .pi / 180
        let reach = armL - armW * 0.3
        return CGPoint(
            x: shoulderX(side) + side * sin(angle) * reach,
            y: shoulderY + cos(angle) * reach
        )
    }
}

/// Body outline: narrow at the shoulders, rounded at the hips. The same shape
/// draws a t-shirt, a hoodie, a striped jumper and, flared out, a dress.
struct DressBodyShape: Shape {
    var shoulder: CGFloat = 0.84
    var hip: CGFloat = 1.0

    func path(in r: CGRect) -> Path {
        let sw = r.width * shoulder
        let hw = r.width * hip
        let cx = r.midX
        let top = r.minY
        let bottom = r.maxY
        let shoulderDrop = r.height * 0.11

        var path = Path()
        path.move(to: CGPoint(x: cx - sw / 2, y: top + shoulderDrop))
        path.addQuadCurve(
            to: CGPoint(x: cx, y: top),
            control: CGPoint(x: cx - sw * 0.30, y: top - r.height * 0.015)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx + sw / 2, y: top + shoulderDrop),
            control: CGPoint(x: cx + sw * 0.30, y: top - r.height * 0.015)
        )
        path.addCurve(
            to: CGPoint(x: cx + hw / 2, y: bottom - r.height * 0.14),
            control1: CGPoint(x: cx + sw * 0.52, y: top + r.height * 0.42),
            control2: CGPoint(x: cx + hw * 0.50, y: bottom - r.height * 0.34)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx, y: bottom),
            control: CGPoint(x: cx + hw * 0.36, y: bottom)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx - hw / 2, y: bottom - r.height * 0.14),
            control: CGPoint(x: cx - hw * 0.36, y: bottom)
        )
        path.addCurve(
            to: CGPoint(x: cx - sw / 2, y: top + shoulderDrop),
            control1: CGPoint(x: cx - hw * 0.50, y: bottom - r.height * 0.34),
            control2: CGPoint(x: cx - sw * 0.52, y: top + r.height * 0.42)
        )
        path.closeSubpath()
        return path
    }
}

/// A friendly outlined character: child, bear or bunny.
struct CharacterView: View {
    let outfit: DressOutfit
    var blinking: Bool = false

    private var isDress: Bool { outfit.top == 1 }
    private var isOveralls: Bool { outfit.top == 4 }
    private var isHoodie: Bool { outfit.top == 2 }
    private var wideBottom: Bool { isDress || (outfit.bottom == 1 && !isOveralls) }

    var body: some View {
        GeometryReader { geo in
            let m = DressMetrics(geo.size)

            ZStack {
                // Soft shadow on the floor keeps the character standing up.
                Ellipse()
                    .fill(DressInk.line.opacity(0.12))
                    .frame(width: m.headD * 1.5, height: m.headD * 0.22)
                    .position(x: m.cx, y: min(m.h - m.headD * 0.08, m.footY + m.headD * 0.30))

                backpack(m)
                legs(m)
                shoes(m)
                // A dress or a skirt flares out over the hands, so the arms
                // come forward in front of those instead of behind them.
                if !wideBottom {
                    arm(-1, m)
                    arm(1, m)
                }
                neck(m)
                clothes(m)
                if wideBottom {
                    arm(-1, m)
                    arm(1, m)
                }
                accessories(m)

                DressHead(outfit: outfit, blinking: blinking, head: m.headD)
                    .frame(width: m.headD * 2.6, height: m.headD * 2.6)
                    .position(x: m.cx, y: m.headY)
            }
            .animation(.spring(response: 0.35), value: outfit)
        }
        .aspectRatio(0.72, contentMode: .fit)
    }

    // MARK: Legs and feet

    @ViewBuilder
    private func legs(_ m: DressMetrics) -> some View {
        let pants: Color = isOveralls ? outfit.topShade : outfit.bottomShade
        let covered = !isDress && (outfit.bottom == 0 || isOveralls)
        let legColor: Color = covered ? pants : outfit.skinColor
        let legH = m.legH + m.headD * 0.12

        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                LimbShape(taper: 0.86)
                    .inked(legColor, m.lw)
                    .frame(width: m.legW, height: legH)
                    .position(x: m.legX(CGFloat(side)), y: m.hipY + legH / 2 - m.headD * 0.10)
            }

            // Shorts sit over the top of the legs.
            if outfit.bottom == 2 && !isDress && !isOveralls {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    RoundedRectangle(cornerRadius: m.legW * 0.34)
                        .inked(outfit.bottomShade, m.lw)
                        .frame(width: m.legW * 1.32, height: m.legH * 0.78)
                        .position(
                            x: m.legX(CGFloat(side)) + CGFloat(side) * m.legW * 0.08,
                            y: m.hipY + m.legH * 0.18
                        )
                }
            }
        }
    }

    @ViewBuilder
    private func shoes(_ m: DressMetrics) -> some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            shoe(m)
                .scaleEffect(x: CGFloat(side), y: 1)
                .position(x: m.legX(CGFloat(side)), y: m.footY + m.headD * 0.05)
        }
    }

    /// One shoe, always drawn facing right and mirrored for the other foot.
    @ViewBuilder
    private func shoe(_ m: DressMetrics) -> some View {
        let unit = m.headD
        switch outfit.shoes {
        case 1:
            // Sneaker: a rounded toe, a white sole and one stripe.
            ZStack(alignment: .bottom) {
                ShoeShape()
                    .inked(.white, m.lw)
                    .frame(width: unit * 0.46, height: unit * 0.28)
                Capsule()
                    .inked(outfit.topShade, m.lw * 0.8)
                    .frame(width: unit * 0.50, height: unit * 0.10)
                    .offset(y: unit * 0.01)
            }
            .frame(width: unit * 0.54, height: unit * 0.32, alignment: .bottom)
        case 2:
            // Boot with a thick sole.
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: unit * 0.09)
                    .inked(Palette.brown, m.lw)
                    .frame(width: unit * 0.33, height: unit * 0.38)
                Capsule()
                    .inked(Palette.brown.opacity(0.75), m.lw * 0.8)
                    .frame(width: unit * 0.42, height: unit * 0.12)
            }
            .frame(width: unit * 0.46, height: unit * 0.42, alignment: .bottom)
        case 3:
            // Sandal: a flat sole with a strap over the foot.
            ZStack {
                Capsule()
                    .inked(outfit.skinColor, m.lw)
                    .frame(width: unit * 0.36, height: unit * 0.15)
                    .offset(y: -unit * 0.07)
                Capsule()
                    .inked(Palette.brown, m.lw * 0.8)
                    .frame(width: unit * 0.40, height: unit * 0.09)
                Capsule()
                    .inked(Palette.brown, m.lw * 0.7)
                    .frame(width: unit * 0.24, height: unit * 0.07)
                    .offset(y: -unit * 0.10)
            }
            .frame(width: unit * 0.44, height: unit * 0.26)
        default:
            // Bare foot.
            ShoeShape()
                .inked(outfit.skinColor, m.lw)
                .frame(width: unit * 0.40, height: unit * 0.21)
        }
    }

    // MARK: Arms

    @ViewBuilder
    private func arm(_ side: CGFloat, _ m: DressMetrics) -> some View {
        let armW = m.armW
        let armL = m.armL
        let handD = armW * 1.2
        let sleeveColor: Color = isOveralls ? .white : outfit.topShade
        let sleeve: CGFloat = {
            switch outfit.top {
            case 1: return armL * 0.34        // dress, little cap sleeve
            case 2: return armL * 0.94        // hoodie, long sleeve
            case 3: return armL * 0.62        // jumper, three quarter sleeve
            case 4: return armL * 0.40        // overalls over a white tee
            default: return armL * 0.38       // t-shirt
            }
        }()

        ZStack(alignment: .top) {
            LimbShape(taper: 0.80)
                .inked(outfit.skinColor, m.lw)
                .frame(width: armW, height: armL)
            LimbShape(taper: 0.88)
                .inked(sleeveColor, m.lw)
                .frame(width: armW * 1.16, height: sleeve)
            Ellipse()
                .inked(outfit.skinColor, m.lw)
                .frame(width: handD, height: handD * 1.08)
                .offset(y: armL - handD * 0.76)
        }
        .frame(width: armW * 1.3, height: armL + handD * 0.3, alignment: .top)
        .rotationEffect(.degrees(-Double(side) * DressMetrics.armAngle), anchor: .top)
        .position(
            x: m.shoulderX(side),
            y: m.shoulderY + (armL + handD * 0.3) / 2
        )
    }

    // MARK: Neck, body and clothes

    @ViewBuilder
    private func neck(_ m: DressMetrics) -> some View {
        LimbShape(taper: 1.18)
            .inked(outfit.skinColor, m.lw)
            .frame(width: m.headD * 0.27, height: m.headD * 0.40)
            .position(x: m.cx, y: m.headY + m.headD * 0.50)
    }

    @ViewBuilder
    private func clothes(_ m: DressMetrics) -> some View {
        ZStack {
            if isHoodie {
                // The hood sits behind the shoulders.
                Circle()
                    .inked(outfit.topShade, m.lw)
                    .frame(width: m.headD * 0.96, height: m.headD * 0.96)
                    .position(x: m.cx, y: m.torsoTop - m.headD * 0.04)
            }

            switch outfit.top {
            case 1:
                dressBody(m)
            case 2:
                hoodieBody(m)
            case 3:
                stripedBody(m)
            case 4:
                overallsBody(m)
            default:
                plainBody(m)
            }

            if outfit.bottom == 1 && !isDress && !isOveralls {
                skirt(m)
            }
        }
    }

    /// The body panel every top is built on.
    private func bodyPanel(_ m: DressMetrics, hip: CGFloat = 1.0, height: CGFloat? = nil) -> some View {
        let height = height ?? m.torsoH
        return DressBodyShape(shoulder: 0.84, hip: hip)
            .frame(width: m.torsoW * max(1, hip), height: height)
            .position(x: m.cx, y: m.torsoTop + height / 2)
    }

    @ViewBuilder
    private func plainBody(_ m: DressMetrics) -> some View {
        let shape = DressBodyShape(shoulder: 0.86, hip: 0.96)
        shape
            .inked(outfit.topShade, m.lw)
            .frame(width: m.torsoW, height: m.torsoH)
            .overlay(
                // Collar.
                Circle()
                    .trim(from: 0.04, to: 0.46)
                    .stroke(DressInk.line.opacity(0.4), style: StrokeStyle(lineWidth: m.lw, lineCap: .round))
                    .frame(width: m.headD * 0.34, height: m.headD * 0.26)
                    .offset(y: -m.torsoH * 0.40)
            )
            .position(x: m.cx, y: m.torsoTop + m.torsoH / 2)
    }

    @ViewBuilder
    private func dressBody(_ m: DressMetrics) -> some View {
        let height = m.torsoH * 1.12
        DressBodyShape(shoulder: 0.78, hip: 1.26)
            .inked(outfit.topShade, m.lw)
            .frame(width: m.torsoW * 1.26, height: height)
            .overlay(
                // Waistband and a hem line.
                VStack(spacing: 0) {
                    Capsule()
                        .fill(DressInk.line.opacity(0.18))
                        .frame(width: m.torsoW * 0.66, height: m.lw * 1.6)
                        .offset(y: height * 0.08)
                    Spacer(minLength: 0)
                }
                .frame(height: height)
            )
            .position(x: m.cx, y: m.torsoTop + height / 2)
    }

    @ViewBuilder
    private func hoodieBody(_ m: DressMetrics) -> some View {
        let shape = DressBodyShape(shoulder: 0.88, hip: 1.06)
        shape
            .inked(outfit.topShade, m.lw)
            .frame(width: m.torsoW * 1.06, height: m.torsoH)
            .overlay(
                ZStack {
                    // Zip.
                    Capsule()
                        .fill(DressInk.line.opacity(0.28))
                        .frame(width: m.lw * 1.2, height: m.torsoH * 0.62)
                        .offset(y: -m.torsoH * 0.06)
                    // Pocket.
                    Capsule()
                        .strokeBorder(DressInk.line.opacity(0.35), lineWidth: m.lw)
                        .frame(width: m.torsoW * 0.62, height: m.torsoH * 0.22)
                        .offset(y: m.torsoH * 0.26)
                }
            )
            .position(x: m.cx, y: m.torsoTop + m.torsoH / 2)
    }

    @ViewBuilder
    private func stripedBody(_ m: DressMetrics) -> some View {
        let shape = DressBodyShape(shoulder: 0.86, hip: 0.96)
        shape
            .inked(outfit.topShade, m.lw)
            .frame(width: m.torsoW, height: m.torsoH)
            .overlay(
                VStack(spacing: m.torsoH * 0.11) {
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule()
                            .fill(.white.opacity(0.9))
                            .frame(height: m.torsoH * 0.09)
                    }
                }
                .frame(width: m.torsoW, height: m.torsoH)
                .clipShape(shape)
            )
            .overlay(shape.stroke(DressInk.line.opacity(0.85), lineWidth: m.lw))
            .position(x: m.cx, y: m.torsoTop + m.torsoH / 2)
    }

    @ViewBuilder
    private func overallsBody(_ m: DressMetrics) -> some View {
        let shape = DressBodyShape(shoulder: 0.86, hip: 0.96)
        ZStack {
            // White tee underneath.
            shape
                .inked(.white, m.lw)
                .frame(width: m.torsoW, height: m.torsoH)
            // Bib and straps.
            RoundedRectangle(cornerRadius: m.headD * 0.10)
                .inked(outfit.topShade, m.lw)
                .frame(width: m.torsoW * 0.62, height: m.torsoH * 0.58)
                .offset(y: m.torsoH * 0.16)
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .inked(outfit.topShade, m.lw * 0.9)
                    .frame(width: m.torsoW * 0.14, height: m.torsoH * 0.46)
                    .offset(x: CGFloat(side) * m.torsoW * 0.22, y: -m.torsoH * 0.19)
            }
            // Two buttons on the bib.
            HStack(spacing: m.torsoW * 0.38) {
                Circle().inked(Palette.yellow, m.lw * 0.7).frame(width: m.headD * 0.09)
                Circle().inked(Palette.yellow, m.lw * 0.7).frame(width: m.headD * 0.09)
            }
            .offset(y: -m.torsoH * 0.02)
        }
        .frame(width: m.torsoW, height: m.torsoH)
        .position(x: m.cx, y: m.torsoTop + m.torsoH / 2)
    }

    @ViewBuilder
    private func skirt(_ m: DressMetrics) -> some View {
        TrapezoidShape(topInset: 0.30)
            .inked(outfit.bottomShade, m.lw)
            .frame(width: m.torsoW * 1.26, height: m.headD * 0.56)
            .position(x: m.cx, y: m.hipY - m.headD * 0.10)
    }

    // MARK: Extras

    @ViewBuilder
    private func backpack(_ m: DressMetrics) -> some View {
        if outfit.extra == 2 {
            RoundedRectangle(cornerRadius: m.headD * 0.20)
                .inked(outfit.bottomShade, m.lw)
                .frame(width: m.torsoW * 1.34, height: m.torsoH * 0.82)
                .position(x: m.cx, y: m.torsoTop + m.torsoH * 0.52)
        }
    }

    @ViewBuilder
    private func accessories(_ m: DressMetrics) -> some View {
        if outfit.extra == 2 {
            // Straps over the shoulders.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .inked(outfit.bottomShade.opacity(0.95), m.lw * 0.8)
                    .frame(width: m.headD * 0.13, height: m.torsoH * 0.56)
                    .position(
                        x: m.cx + CGFloat(side) * m.torsoW * 0.26,
                        y: m.torsoTop + m.torsoH * 0.28
                    )
            }
        }

        if outfit.extra == 3 {
            ZStack {
                Circle()
                    .trim(from: 0.08, to: 0.42)
                    .stroke(Palette.yellow, style: StrokeStyle(lineWidth: m.lw * 1.6, lineCap: .round))
                    .frame(width: m.headD * 0.52, height: m.headD * 0.40)
                Circle()
                    .inked(Palette.pink, m.lw * 0.7)
                    .frame(width: m.headD * 0.13)
                    .offset(y: m.headD * 0.22)
            }
            .position(x: m.cx, y: m.torsoTop + m.headD * 0.04)
        }

        if outfit.extra == 4 {
            // A little wand, held in the right hand.
            ZStack {
                Capsule()
                    .inked(Palette.brown, m.lw * 0.8)
                    .frame(width: m.headD * 0.09, height: m.headD * 0.72)
                StarShape()
                    .inked(Palette.yellow, m.lw * 0.8)
                    .frame(width: m.headD * 0.34, height: m.headD * 0.34)
                    .offset(y: -m.headD * 0.44)
            }
            .rotationEffect(.degrees(16))
            .position(
                x: m.handPoint(1).x + m.headD * 0.04,
                y: m.handPoint(1).y - m.headD * 0.16
            )
        }
    }
}

/// Simple shoe outline: flat underneath, rounded over the toes.
struct ShoeShape: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.midY))
        path.addQuadCurve(
            to: CGPoint(x: r.midX, y: r.minY),
            control: CGPoint(x: r.minX + r.width * 0.06, y: r.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.18),
            control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.32)
        )
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.12, y: r.maxY),
            control: CGPoint(x: r.maxX, y: r.maxY)
        )
        path.closeSubpath()
        return path
    }
}

/// The head, ears, hair, face and headwear. Shared by the big character and
/// by the little option swatches so the previews always match.
struct DressHead: View {
    let outfit: DressOutfit
    var blinking: Bool = false
    let head: CGFloat

    private var isHijab: Bool { outfit.head == 4 }
    private var isHat: Bool { outfit.head == 1 || outfit.head == 2 || outfit.head == 5 }
    private var kind: DressCharacter { outfit.kind }
    private var lw: CGFloat { max(1.1, head * 0.036) }

    var body: some View {
        ZStack {
            if outfit.head == 3 { scarfView }
            if isHijab { hijabView }
            if !isHijab { earsView }

            // The head itself.
            HeadShape()
                .inked(outfit.skinColor, lw)
                .frame(width: head, height: head * 1.04)

            if kind.isAnimal { muzzleView }
            if !isHijab && !kind.isAnimal { hairView }

            // Blush.
            HStack(spacing: head * 0.40) {
                Ellipse().fill(Palette.pink.opacity(0.35)).frame(width: head * 0.16, height: head * 0.10)
                Ellipse().fill(Palette.pink.opacity(0.35)).frame(width: head * 0.16, height: head * 0.10)
            }
            .offset(y: head * 0.14)

            if !blinking { browsView }
            eyesView
            noseView
            mouthView
            if outfit.extra == 1 { glassesView }
            headwearView
        }
        .frame(width: head * 2.6, height: head * 2.6)
        .animation(.spring(response: 0.35), value: outfit)
    }

    // MARK: Scarf and hijab

    private var scarfView: some View {
        ZStack {
            Capsule()
                .inked(outfit.headShade, lw)
                .frame(width: head * 0.78, height: head * 0.32)
            RoundedRectangle(cornerRadius: head * 0.08)
                .inked(outfit.headShade, lw)
                .frame(width: head * 0.22, height: head * 0.48)
                .offset(x: head * 0.24, y: head * 0.32)
        }
        .offset(y: head * 0.56)
    }

    private var hijabView: some View {
        ZStack {
            // Drape over the shoulders, then the part framing the face.
            RoundedRectangle(cornerRadius: head * 0.34)
                .inked(outfit.headShade, lw)
                .frame(width: head * 1.16, height: head * 0.98)
                .offset(y: head * 0.48)
            Circle()
                .inked(outfit.headShade, lw)
                .frame(width: head * 1.26, height: head * 1.26)
        }
    }

    // MARK: Ears

    @ViewBuilder
    private var earsView: some View {
        switch kind {
        case .child:
            HStack(spacing: head * 0.78) {
                Circle().inked(outfit.skinColor, lw).frame(width: head * 0.22)
                Circle().inked(outfit.skinColor, lw).frame(width: head * 0.22)
            }
            .offset(y: head * 0.04)
        case .bear:
            HStack(spacing: head * 0.56) {
                bearEar
                bearEar
            }
            .offset(y: -head * 0.42)
        case .bunny:
            HStack(spacing: head * 0.20) {
                bunnyEar.rotationEffect(.degrees(-11))
                bunnyEar.rotationEffect(.degrees(11))
            }
            .offset(y: -head * 0.60)
        }
    }

    private var bearEar: some View {
        ZStack {
            Circle().inked(outfit.skinColor, lw).frame(width: head * 0.38)
            Circle().fill(Palette.pink.opacity(0.40)).frame(width: head * 0.18)
        }
    }

    private var bunnyEar: some View {
        ZStack {
            Capsule().inked(outfit.skinColor, lw).frame(width: head * 0.24, height: head * 0.70)
            Capsule().fill(Palette.pink.opacity(0.40)).frame(width: head * 0.10, height: head * 0.46)
        }
    }

    private var muzzleView: some View {
        Ellipse()
            .inked(.white.opacity(0.92), lw * 0.8, opacity: 0.35)
            .frame(width: head * 0.50, height: head * 0.34)
            .offset(y: head * 0.20)
    }

    // MARK: Hair

    @ViewBuilder
    private var hairView: some View {
        let style = isHat ? 1 : outfit.hairStyle
        switch style {
        case 0:
            EmptyView()
        case 1:
            // Short bowl cut. Under a hat only the sides show.
            ZStack {
                if !isHat {
                    // Side locks beside the ears.
                    ForEach([-1.0, 1.0], id: \.self) { side in
                        Capsule()
                            .inked(outfit.hairShade, lw)
                            .frame(width: head * 0.15, height: head * 0.34)
                            .offset(x: CGFloat(side) * head * 0.46, y: -head * 0.08)
                    }
                }
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .inked(outfit.hairShade, lw)
                    .frame(width: head * 1.06, height: head * 1.06)
                    .offset(y: isHat ? -head * 0.26 : -head * 0.20)
            }
        case 2:
            // Curls all around the top of the head.
            ZStack {
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .inked(outfit.hairShade, lw)
                    .frame(width: head * 1.0, height: head * 1.0)
                    .offset(y: -head * 0.12)
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .inked(outfit.hairShade, lw)
                        .frame(width: head * 0.30)
                        .offset(
                            x: head * (-0.38 + 0.19 * CGFloat(i)),
                            y: -head * (0.46 - abs(2 - CGFloat(i)) * 0.05)
                        )
                }
            }
        default:
            // Two little buns.
            ZStack {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Circle()
                        .inked(outfit.hairShade, lw)
                        .frame(width: head * 0.32)
                        .offset(x: CGFloat(side) * head * 0.48, y: -head * 0.38)
                }
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .inked(outfit.hairShade, lw)
                    .frame(width: head * 1.04, height: head * 1.04)
                    .offset(y: -head * 0.13)
            }
        }
    }

    // MARK: Face

    private var eyesView: some View {
        HStack(spacing: head * 0.17) {
            eye
            eye
        }
        .offset(y: head * 0.005)
    }

    /// Two soft brows. They lift when the face is surprised and tilt down a
    /// little when it is sleepy, which is most of what makes a face read.
    private var browsView: some View {
        HStack(spacing: head * 0.21) {
            brow(flip: false)
            brow(flip: true)
        }
        .offset(y: -head * (outfit.mood == .surprised ? 0.20 : 0.17))
    }

    private func brow(flip: Bool) -> some View {
        SmileShape()
            .stroke(
                outfit.kind.isAnimal ? DressInk.line.opacity(0.5) : outfit.hairShade.opacity(0.85),
                style: StrokeStyle(lineWidth: head * 0.035, lineCap: .round)
            )
            .frame(width: head * 0.17, height: head * 0.055)
            .rotationEffect(.degrees(180))
            .rotationEffect(.degrees(outfit.mood == .sleepy ? (flip ? -8 : 8) : 0))
            .scaleEffect(x: flip ? -1 : 1)
    }

    @ViewBuilder
    private var eye: some View {
        if blinking && outfit.mood != .sleepy {
            Capsule()
                .fill(DressInk.line)
                .frame(width: head * 0.17, height: head * 0.035)
        } else {
            switch outfit.mood {
            case .happy, .surprised:
                let white = outfit.mood == .surprised ? head * 0.24 : head * 0.21
                ZStack {
                    Circle().inked(.white, lw * 0.7, opacity: 0.6)
                        .frame(width: white, height: white)
                    Circle().fill(DressInk.line)
                        .frame(width: white * 0.56, height: white * 0.56)
                        .offset(y: white * 0.04)
                    Circle().fill(.white)
                        .frame(width: white * 0.18, height: white * 0.18)
                        .offset(x: white * 0.14, y: -white * 0.12)
                }
            case .giggly:
                SmileShape()
                    .stroke(DressInk.line, style: StrokeStyle(lineWidth: head * 0.04, lineCap: .round))
                    .frame(width: head * 0.19, height: head * 0.10)
                    .rotationEffect(.degrees(180))
            case .sleepy:
                SmileShape()
                    .stroke(DressInk.line, style: StrokeStyle(lineWidth: head * 0.04, lineCap: .round))
                    .frame(width: head * 0.19, height: head * 0.07)
            }
        }
    }

    @ViewBuilder
    private var mouthView: some View {
        switch outfit.mood {
        case .giggly:
            // Open laugh with a little tongue.
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.5)
                    .fill(DressInk.line)
                    .frame(width: head * 0.30, height: head * 0.30)
                Circle()
                    .trim(from: 0, to: 0.5)
                    .fill(Palette.pink)
                    .frame(width: head * 0.15, height: head * 0.15)
                    .offset(y: head * 0.07)
            }
            .offset(y: head * 0.17)
        case .surprised:
            Ellipse()
                .fill(DressInk.line)
                .frame(width: head * 0.15, height: head * 0.19)
                .offset(y: head * 0.25)
        case .sleepy:
            Ellipse()
                .fill(DressInk.line.opacity(0.9))
                .frame(width: head * 0.13, height: head * 0.11)
                .offset(y: head * 0.24)
        default:
            SmileShape()
                .stroke(DressInk.line, style: StrokeStyle(lineWidth: head * 0.038, lineCap: .round))
                .frame(width: head * 0.28, height: head * 0.14)
                .offset(y: head * 0.23)
        }
    }

    @ViewBuilder
    private var noseView: some View {
        if kind.isAnimal {
            Ellipse()
                .inked(DressInk.line, lw * 0.5, opacity: 0.0)
                .frame(width: head * 0.15, height: head * 0.10)
                .offset(y: head * 0.10)
        } else {
            // Just a soft curve: a filled blob would look like a snout.
            SmileShape()
                .stroke(
                    DressInk.line.opacity(0.45),
                    style: StrokeStyle(lineWidth: head * 0.03, lineCap: .round)
                )
                .frame(width: head * 0.09, height: head * 0.05)
                .offset(y: head * 0.10)
        }
    }

    private var glassesView: some View {
        HStack(spacing: head * 0.02) {
            Circle()
                .stroke(DressInk.line, lineWidth: head * 0.035)
                .frame(width: head * 0.28, height: head * 0.28)
            Capsule().fill(DressInk.line).frame(width: head * 0.07, height: head * 0.03)
            Circle()
                .stroke(DressInk.line, lineWidth: head * 0.035)
                .frame(width: head * 0.28, height: head * 0.28)
        }
        .offset(y: -head * 0.04)
    }

    // MARK: Headwear

    @ViewBuilder
    private var headwearView: some View {
        switch outfit.head {
        case 1:
            // Baseball cap: dome plus a brim.
            ZStack {
                Capsule()
                    .inked(outfit.headShade, lw)
                    .frame(width: head * 0.72, height: head * 0.17)
                    .offset(x: head * 0.46, y: head * 0.02)
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .inked(outfit.headShade, lw)
                    .frame(width: head * 1.02, height: head * 1.02)
                Circle()
                    .inked(outfit.headShade, lw * 0.7)
                    .frame(width: head * 0.12)
                    .offset(y: -head * 0.46)
            }
            .offset(y: -head * 0.32)
        case 2:
            // Sun hat: wide brim plus a dome.
            ZStack {
                Ellipse()
                    .inked(outfit.headShade, lw)
                    .frame(width: head * 1.66, height: head * 0.34)
                    .offset(y: head * 0.06)
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .inked(outfit.headShade, lw)
                    .frame(width: head * 0.92, height: head * 0.92)
                    .offset(y: -head * 0.06)
                Capsule()
                    .fill(Palette.pink.opacity(0.75))
                    .frame(width: head * 0.88, height: head * 0.09)
                    .offset(y: -head * 0.02)
            }
            .offset(y: -head * 0.28)
        case 5:
            // Winter beanie with a folded brim and a bobble.
            ZStack {
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .inked(outfit.headShade, lw)
                    .frame(width: head * 1.08, height: head * 1.08)
                Capsule()
                    .inked(outfit.headShade.opacity(0.85), lw)
                    .frame(width: head * 1.12, height: head * 0.20)
                    .offset(y: head * 0.03)
                Circle()
                    .inked(.white.opacity(0.9), lw * 0.8)
                    .frame(width: head * 0.26)
                    .offset(y: -head * 0.52)
            }
            .offset(y: -head * 0.30)
        case 6:
            // Party hat with a pom on top.
            ZStack {
                Triangle()
                    .inked(outfit.headShade, lw)
                    .frame(width: head * 0.62, height: head * 0.72)
                Circle()
                    .inked(Palette.pink, lw * 0.8)
                    .frame(width: head * 0.20)
                    .offset(y: -head * 0.40)
                VStack(spacing: head * 0.11) {
                    Circle().fill(.white.opacity(0.85)).frame(width: head * 0.10)
                    Circle().fill(.white.opacity(0.85)).frame(width: head * 0.10)
                }
                .offset(y: head * 0.12)
            }
            .offset(y: -head * 0.62)
        default:
            EmptyView()
        }
    }
}

/// A small self-contained head preview used by the option swatches.
struct MiniHead: View {
    let outfit: DressOutfit

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            DressHead(outfit: outfit, head: s * 0.34)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Backdrops

/// One of six simple vector scenes behind the dressed character.
struct BackdropScene: View {
    let kind: DressBackdrop

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            switch kind {
            case .bedroom: bedroom(w: w, h: h)
            case .park: park(w: w, h: h)
            case .night: night(w: w, h: h)
            case .snow: snow(w: w, h: h)
            case .rain: rain(w: w, h: h)
            case .beach: beach(w: w, h: h)
            }
        }
        .allowsHitTesting(false)
    }

    private func bedroom(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // Wall, skirting board and wooden floor.
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.94, blue: 0.90),
                    Color(red: 0.94, green: 0.90, blue: 0.85),
                ],
                startPoint: .top, endPoint: .bottom
            )
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.88, green: 0.79, blue: 0.67),
                            Color(red: 0.81, green: 0.70, blue: 0.56),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: h * 0.24)
                .position(x: w / 2, y: h * 0.88)
            Rectangle()
                .fill(.white.opacity(0.75))
                .frame(height: h * 0.012)
                .position(x: w / 2, y: h * 0.76)

            // Window with a sky behind it.
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.03)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.72, green: 0.86, blue: 0.96),
                                Color(red: 0.86, green: 0.93, blue: 0.98),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                Circle()
                    .fill(.white.opacity(0.85))
                    .frame(width: w * 0.07, height: w * 0.07)
                    .offset(x: w * 0.05, y: -h * 0.05)
                Rectangle().fill(.white.opacity(0.95)).frame(width: w * 0.014)
                Rectangle().fill(.white.opacity(0.95)).frame(height: h * 0.014)
            }
            .frame(width: w * 0.28, height: h * 0.26)
            .overlay(
                RoundedRectangle(cornerRadius: w * 0.03)
                    .stroke(.white, lineWidth: 5)
                    .frame(width: w * 0.28, height: h * 0.26)
            )
            .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
            .position(x: w * 0.22, y: h * 0.26)

            // A bed with a headboard, a blanket folded over and a pillow.
            ZStack {
                // Headboard.
                RoundedRectangle(cornerRadius: w * 0.02)
                    .fill(Palette.brown.opacity(0.75))
                    .frame(width: w * 0.045, height: h * 0.13)
                    .offset(x: w * 0.168, y: -h * 0.028)
                // Mattress.
                RoundedRectangle(cornerRadius: w * 0.02)
                    .fill(.white)
                    .frame(width: w * 0.36, height: h * 0.075)
                // Blanket folded over the foot of the bed.
                RoundedRectangle(cornerRadius: w * 0.018)
                    .fill(
                        LinearGradient(
                            colors: [Palette.blue.opacity(0.8), Palette.blue.opacity(0.55)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: w * 0.22, height: h * 0.062)
                    .offset(x: -w * 0.068)
                // Pillow.
                RoundedRectangle(cornerRadius: w * 0.015)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: w * 0.015)
                            .stroke(Palette.ink.opacity(0.10), lineWidth: 1)
                    )
                    .frame(width: w * 0.10, height: h * 0.038)
                    .offset(x: w * 0.113, y: -h * 0.032)
                // Legs.
                HStack(spacing: w * 0.28) {
                    RoundedRectangle(cornerRadius: w * 0.008)
                        .fill(Palette.brown.opacity(0.7))
                        .frame(width: w * 0.022, height: h * 0.03)
                    RoundedRectangle(cornerRadius: w * 0.008)
                        .fill(Palette.brown.opacity(0.7))
                        .frame(width: w * 0.022, height: h * 0.03)
                }
                .offset(y: h * 0.05)
            }
            .frame(width: w * 0.40, height: h * 0.18)
            .shadow(color: .black.opacity(0.08), radius: 6, y: 4)
            .position(x: w * 0.70, y: h * 0.755)
        }
    }

    private func park(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.76, green: 0.88, blue: 0.96),
                         Color(red: 0.90, green: 0.95, blue: 0.98)],
                startPoint: .top, endPoint: .bottom
            )
            Circle()
                .fill(Palette.yellow.opacity(0.75))
                .frame(width: w * 0.16, height: w * 0.16)
                .position(x: w * 0.2, y: h * 0.16)
            Ellipse()
                .fill(Color(red: 0.55, green: 0.76, blue: 0.53))
                .frame(width: w * 1.1, height: h * 0.38)
                .position(x: w * 0.25, y: h * 0.92)
            Ellipse()
                .fill(Color(red: 0.47, green: 0.70, blue: 0.47))
                .frame(width: w * 1.0, height: h * 0.32)
                .position(x: w * 0.85, y: h * 0.95)
            ZStack {
                Capsule()
                    .fill(Palette.brown)
                    .frame(width: w * 0.05, height: h * 0.24)
                    .offset(y: h * 0.10)
                ZStack {
                    Circle().fill(Color(red: 0.42, green: 0.66, blue: 0.44))
                        .frame(width: w * 0.17, height: w * 0.17).offset(x: -w * 0.06)
                    Circle().fill(Color(red: 0.46, green: 0.71, blue: 0.47))
                        .frame(width: w * 0.21, height: w * 0.21).offset(y: -h * 0.03)
                    Circle().fill(Color(red: 0.42, green: 0.66, blue: 0.44))
                        .frame(width: w * 0.16, height: w * 0.16).offset(x: w * 0.07)
                }
            }
            .position(x: w * 0.84, y: h * 0.5)
        }
    }

    private func night(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.70, green: 0.72, blue: 0.90),
                         Color(red: 0.86, green: 0.86, blue: 0.95)],
                startPoint: .top, endPoint: .bottom
            )
            Circle()
                .fill(Color(red: 0.99, green: 0.97, blue: 0.86))
                .frame(width: w * 0.16, height: w * 0.16)
                .position(x: w * 0.79, y: h * 0.17)
            ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, star in
                StarShape()
                    .fill(.white.opacity(0.9))
                    .frame(width: w * star.size, height: w * star.size)
                    .position(x: w * star.x, y: h * star.y)
            }
            Ellipse()
                .fill(Color(red: 0.56, green: 0.56, blue: 0.76))
                .frame(width: w * 1.4, height: h * 0.28)
                .position(x: w / 2, y: h * 1.0)
        }
    }

    private func snow(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.82, green: 0.88, blue: 0.95),
                         Color(red: 0.94, green: 0.96, blue: 0.98)],
                startPoint: .top, endPoint: .bottom
            )
            // Snowy ground
            Ellipse()
                .fill(.white)
                .frame(width: w * 1.5, height: h * 0.34)
                .position(x: w / 2, y: h * 1.02)
            // Little snowman
            ZStack {
                Circle().fill(.white).frame(width: w * 0.16, height: w * 0.16)
                    .offset(y: w * 0.11)
                Circle().fill(.white).frame(width: w * 0.11, height: w * 0.11)
                Circle().fill(Palette.ink.opacity(0.7)).frame(width: w * 0.014)
                    .offset(x: -w * 0.02, y: -w * 0.01)
                Circle().fill(Palette.ink.opacity(0.7)).frame(width: w * 0.014)
                    .offset(x: w * 0.02, y: -w * 0.01)
                Triangle().fill(Palette.orange)
                    .frame(width: w * 0.04, height: w * 0.03)
                    .rotationEffect(.degrees(90))
                    .offset(y: w * 0.015)
            }
            .position(x: w * 0.79, y: h * 0.66)
            // Falling flakes
            ForEach(Array(Self.flakes.enumerated()), id: \.offset) { _, flake in
                Circle()
                    .fill(.white.opacity(0.95))
                    .frame(width: w * flake.size, height: w * flake.size)
                    .position(x: w * flake.x, y: h * flake.y)
            }
        }
    }

    private func rain(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.66, green: 0.71, blue: 0.78),
                         Color(red: 0.86, green: 0.89, blue: 0.92)],
                startPoint: .top, endPoint: .bottom
            )
            // Clouds
            ZStack {
                Capsule().fill(.white.opacity(0.9)).frame(width: w * 0.4, height: h * 0.09)
                Circle().fill(.white.opacity(0.9)).frame(width: w * 0.17, height: w * 0.17)
                    .offset(x: -w * 0.1, y: -h * 0.03)
                Circle().fill(.white.opacity(0.95)).frame(width: w * 0.22, height: w * 0.22)
                    .offset(x: w * 0.03, y: -h * 0.05)
            }
            .position(x: w * 0.32, y: h * 0.19)
            // Rain
            ForEach(Array(Self.drops.enumerated()), id: \.offset) { _, drop in
                Capsule()
                    .fill(Palette.blue.opacity(0.45))
                    .frame(width: w * 0.014, height: h * 0.05)
                    .rotationEffect(.degrees(10))
                    .position(x: w * drop.x, y: h * drop.y)
            }
            // Wet ground with a puddle
            Ellipse()
                .fill(Color(red: 0.58, green: 0.64, blue: 0.60))
                .frame(width: w * 1.4, height: h * 0.26)
                .position(x: w / 2, y: h * 1.02)
            Ellipse()
                .fill(Palette.blue.opacity(0.35))
                .frame(width: w * 0.3, height: h * 0.05)
                .position(x: w * 0.24, y: h * 0.9)
        }
    }

    private func beach(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.62, green: 0.83, blue: 0.95),
                         Color(red: 0.88, green: 0.95, blue: 0.98)],
                startPoint: .top, endPoint: .bottom
            )
            Circle()
                .fill(Palette.yellow.opacity(0.85))
                .frame(width: w * 0.19, height: w * 0.19)
                .position(x: w * 0.8, y: h * 0.15)
            // Sea
            Rectangle()
                .fill(Color(red: 0.38, green: 0.68, blue: 0.82))
                .frame(height: h * 0.22)
                .position(x: w / 2, y: h * 0.62)
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(0.7))
                    .frame(width: w * 0.16, height: h * 0.012)
                    .position(x: w * (0.2 + CGFloat(i) * 0.3), y: h * (0.58 + CGFloat(i % 2) * 0.05))
            }
            // Sand
            Ellipse()
                .fill(Color(red: 0.95, green: 0.88, blue: 0.70))
                .frame(width: w * 1.6, height: h * 0.36)
                .position(x: w / 2, y: h * 1.0)
            // Beach ball
            ZStack {
                Circle().fill(.white).frame(width: w * 0.12, height: w * 0.12)
                Circle().trim(from: 0.25, to: 0.5).fill(Palette.red.opacity(0.8))
                    .frame(width: w * 0.12, height: w * 0.12)
                Circle().trim(from: 0.75, to: 1.0).fill(Palette.blue.opacity(0.8))
                    .frame(width: w * 0.12, height: w * 0.12)
            }
            .position(x: w * 0.16, y: h * 0.84)
        }
    }

    private static let stars: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.14, 0.12, 0.07), (0.34, 0.22, 0.05), (0.52, 0.09, 0.06),
        (0.24, 0.36, 0.04), (0.66, 0.30, 0.05), (0.90, 0.42, 0.04),
        (0.09, 0.52, 0.05),
    ]

    private static let flakes: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.12, 0.16, 0.035), (0.3, 0.08, 0.028), (0.46, 0.24, 0.032),
        (0.62, 0.12, 0.026), (0.82, 0.3, 0.034), (0.2, 0.42, 0.03),
        (0.55, 0.46, 0.026), (0.88, 0.5, 0.03), (0.36, 0.6, 0.028),
    ]

    private static let drops: [(x: CGFloat, y: CGFloat)] = [
        (0.1, 0.34), (0.24, 0.5), (0.38, 0.3), (0.52, 0.56),
        (0.66, 0.38), (0.8, 0.54), (0.92, 0.32), (0.46, 0.72), (0.16, 0.68),
    ]
}

// MARK: - Shared shapes

/// A narrow-top, wide-bottom shape used for dresses and skirts.
struct TrapezoidShape: Shape {
    var topInset: CGFloat = 0.25
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset = rect.width * topInset
        p.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
