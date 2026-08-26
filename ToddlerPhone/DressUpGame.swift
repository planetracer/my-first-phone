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
        .onChange(of: outfit) { _, _ in
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

        if FamilyStore.shared.isConnected {
            Button {
                sendToFamily()
            } label: {
                Image(systemName: sentConfirmation ? "checkmark" : "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(sentConfirmation ? Palette.green : Palette.ink)
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

/// A friendly flat-design character drawn entirely with shapes.
struct CharacterView: View {
    let outfit: DressOutfit
    var blinking: Bool = false

    private var isDress: Bool { outfit.top == 1 }
    private var isOveralls: Bool { outfit.top == 4 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let head = min(w, h) * 0.30
            let cx = w / 2
            let headY = h * 0.24

            ZStack {
                if outfit.extra == 2 {
                    // Backpack behind the body
                    RoundedRectangle(cornerRadius: head * 0.24)
                        .fill(outfit.bottomShade)
                        .frame(width: head * 1.5, height: head * 1.2)
                        .position(x: cx, y: h * 0.54)
                }

                legsView(head: head, cx: cx, h: h)
                shoesView(head: head, cx: cx, h: h)
                armsView(head: head, cx: cx, y: h * 0.50)
                torsoView(head: head, cx: cx, h: h)

                if outfit.extra == 2 {
                    // Straps across the chest
                    HStack(spacing: head * 0.5) {
                        Capsule().fill(outfit.bottomShade).frame(width: head * 0.14, height: head * 0.9)
                        Capsule().fill(outfit.bottomShade).frame(width: head * 0.14, height: head * 0.9)
                    }
                    .position(x: cx, y: h * 0.5)
                }

                if outfit.extra == 3 {
                    // Necklace under the chin
                    ZStack {
                        Circle()
                            .trim(from: 0, to: 0.5)
                            .stroke(Palette.yellow, style: StrokeStyle(lineWidth: head * 0.05, lineCap: .round))
                            .frame(width: head * 0.62, height: head * 0.62)
                        Circle().fill(Palette.pink).frame(width: head * 0.14)
                            .offset(y: head * 0.33)
                    }
                    .position(x: cx, y: headY + head * 0.58)
                }

                if outfit.extra == 4 {
                    // A little wand in one hand
                    ZStack {
                        Capsule().fill(Palette.brown)
                            .frame(width: head * 0.09, height: head * 0.8)
                        StarShape().fill(Palette.yellow)
                            .frame(width: head * 0.36, height: head * 0.36)
                            .offset(y: -head * 0.46)
                    }
                    .rotationEffect(.degrees(18))
                    .position(x: cx + head * 0.86, y: h * 0.5)
                }

                // Neck
                RoundedRectangle(cornerRadius: head * 0.08)
                    .fill(outfit.skinColor)
                    .frame(width: head * 0.3, height: head * 0.26)
                    .position(x: cx, y: headY + head * 0.5)

                DressHead(outfit: outfit, blinking: blinking, head: head)
                    .frame(width: head * 2.6, height: head * 2.6)
                    .position(x: cx, y: headY)
            }
            .animation(.spring(response: 0.35), value: outfit)
        }
        .aspectRatio(0.72, contentMode: .fit)
    }

    // MARK: Body parts

    @ViewBuilder
    private func legsView(head: CGFloat, cx: CGFloat, h: CGFloat) -> some View {
        let pantsColor: Color = isOveralls ? outfit.topShade : outfit.bottomShade
        let full = !isDress && (outfit.bottom == 0 || isOveralls)
        let legColor: Color = full ? pantsColor : outfit.skinColor

        ZStack {
            HStack(spacing: head * 0.16) {
                Capsule().fill(legColor).frame(width: head * 0.3, height: head * 0.95)
                Capsule().fill(legColor).frame(width: head * 0.3, height: head * 0.95)
            }
            .position(x: cx, y: h * 0.74)

            // Shorts sit over the top of the legs
            if outfit.bottom == 2 && !isDress && !isOveralls {
                HStack(spacing: head * 0.12) {
                    Capsule().fill(outfit.bottomShade).frame(width: head * 0.34, height: head * 0.46)
                    Capsule().fill(outfit.bottomShade).frame(width: head * 0.34, height: head * 0.46)
                }
                .position(x: cx, y: h * 0.68)
            }
        }
    }

    @ViewBuilder
    private func shoesView(head: CGFloat, cx: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: head * 0.14) {
            shoe(head: head)
            shoe(head: head)
        }
        .position(x: cx, y: h * 0.86)
    }

    @ViewBuilder
    private func shoe(head: CGFloat) -> some View {
        switch outfit.shoes {
        case 1:
            VStack(spacing: head * 0.01) {
                Capsule().fill(.white).frame(width: head * 0.34, height: head * 0.14)
                Capsule().fill(Palette.ink).frame(width: head * 0.38, height: head * 0.08)
            }
        case 2:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: head * 0.06)
                    .fill(Palette.brown)
                    .frame(width: head * 0.28, height: head * 0.28)
                Capsule().fill(Palette.ink.opacity(0.85)).frame(width: head * 0.38, height: head * 0.1)
            }
        case 3:
            ZStack {
                Capsule().fill(Palette.brown).frame(width: head * 0.34, height: head * 0.1)
                Capsule().fill(Palette.brown.opacity(0.7))
                    .frame(width: head * 0.07, height: head * 0.2)
                    .rotationEffect(.degrees(22))
            }
        default:
            Capsule().fill(outfit.skinColor).frame(width: head * 0.32, height: head * 0.16)
        }
    }

    private func armsView(head: CGFloat, cx: CGFloat, y: CGFloat) -> some View {
        let sleeve: Color = isOveralls ? .white : outfit.topShade
        return HStack(spacing: head * 1.3) {
            VStack(spacing: 0) {
                Capsule().fill(sleeve).frame(width: head * 0.22, height: head * 0.62)
                Circle().fill(outfit.skinColor).frame(width: head * 0.24)
            }
            .rotationEffect(.degrees(14))
            VStack(spacing: 0) {
                Capsule().fill(sleeve).frame(width: head * 0.22, height: head * 0.62)
                Circle().fill(outfit.skinColor).frame(width: head * 0.24)
            }
            .rotationEffect(.degrees(-14))
        }
        .position(x: cx, y: y)
    }

    @ViewBuilder
    private func torsoView(head: CGFloat, cx: CGFloat, h: CGFloat) -> some View {
        switch outfit.top {
        case 1:
            TrapezoidShape(topInset: 0.28)
                .fill(outfit.topShade)
                .frame(width: head * 1.55, height: head * 1.5)
                .position(x: cx, y: h * 0.55)
        case 2:
            ZStack {
                // Hood behind the shoulders
                Circle()
                    .fill(outfit.topShade.opacity(0.85))
                    .frame(width: head * 0.9, height: head * 0.9)
                    .offset(y: -head * 0.62)
                RoundedRectangle(cornerRadius: head * 0.3)
                    .fill(outfit.topShade)
                    .frame(width: head * 1.32, height: head * 1.16)
                Capsule()
                    .fill(outfit.topShade.opacity(0.7))
                    .frame(width: head * 0.6, height: head * 0.22)
                    .offset(y: head * 0.3)
            }
            .position(x: cx, y: h * 0.52)
            skirtIfNeeded(head: head, cx: cx, h: h)
        case 3:
            RoundedRectangle(cornerRadius: head * 0.3)
                .fill(outfit.topShade)
                .frame(width: head * 1.25, height: head * 1.1)
                .overlay(
                    VStack(spacing: head * 0.16) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule().fill(.white.opacity(0.85)).frame(height: head * 0.1)
                        }
                    }
                    .frame(width: head * 1.25, height: head * 1.1)
                    .clipShape(RoundedRectangle(cornerRadius: head * 0.3))
                )
                .position(x: cx, y: h * 0.52)
            skirtIfNeeded(head: head, cx: cx, h: h)
        case 4:
            ZStack {
                RoundedRectangle(cornerRadius: head * 0.3)
                    .fill(.white)
                    .frame(width: head * 1.25, height: head * 1.1)
                RoundedRectangle(cornerRadius: head * 0.16)
                    .fill(outfit.topShade)
                    .frame(width: head * 0.86, height: head * 0.8)
                    .offset(y: head * 0.18)
                HStack(spacing: head * 0.54) {
                    Capsule().fill(outfit.topShade).frame(width: head * 0.16, height: head * 0.62)
                    Capsule().fill(outfit.topShade).frame(width: head * 0.16, height: head * 0.62)
                }
                .offset(y: -head * 0.3)
            }
            .position(x: cx, y: h * 0.52)
        default:
            RoundedRectangle(cornerRadius: head * 0.3)
                .fill(outfit.topShade)
                .frame(width: head * 1.25, height: head * 1.1)
                .position(x: cx, y: h * 0.52)
            skirtIfNeeded(head: head, cx: cx, h: h)
        }
    }

    @ViewBuilder
    private func skirtIfNeeded(head: CGFloat, cx: CGFloat, h: CGFloat) -> some View {
        if outfit.bottom == 1 {
            TrapezoidShape(topInset: 0.3)
                .fill(outfit.bottomShade)
                .frame(width: head * 1.45, height: head * 0.75)
                .position(x: cx, y: h * 0.65)
        }
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

    var body: some View {
        ZStack {
            // Scarf sits low, around the neck
            if outfit.head == 3 {
                ZStack {
                    Capsule()
                        .fill(outfit.headShade)
                        .frame(width: head * 0.72, height: head * 0.34)
                    RoundedRectangle(cornerRadius: head * 0.08)
                        .fill(outfit.headShade)
                        .frame(width: head * 0.22, height: head * 0.5)
                        .offset(x: head * 0.22, y: head * 0.34)
                }
                .offset(y: head * 0.56)
            }

            if isHijab {
                Circle()
                    .fill(outfit.headShade)
                    .frame(width: head * 1.32, height: head * 1.32)
                RoundedRectangle(cornerRadius: head * 0.3)
                    .fill(outfit.headShade)
                    .frame(width: head * 1.2, height: head * 0.95)
                    .offset(y: head * 0.55)
            }

            if !isHijab {
                earsView
            }

            // Head
            Circle()
                .fill(outfit.skinColor)
                .frame(width: head, height: head)

            if kind.isAnimal {
                // Muzzle
                Ellipse()
                    .fill(.white.opacity(0.55))
                    .frame(width: head * 0.46, height: head * 0.32)
                    .offset(y: head * 0.18)
            }

            if !isHijab && !kind.isAnimal {
                hairView
            }

            // Blush cheeks
            HStack(spacing: head * 0.34) {
                Circle().fill(Palette.pink.opacity(0.5)).frame(width: head * 0.15)
                Circle().fill(Palette.pink.opacity(0.5)).frame(width: head * 0.15)
            }
            .offset(y: head * 0.12)

            eyesView
            mouthView

            if kind.isAnimal {
                Ellipse()
                    .fill(Palette.ink)
                    .frame(width: head * 0.16, height: head * 0.11)
                    .offset(y: head * 0.11)
            }

            if outfit.extra == 1 {
                glassesView
            }

            headwearView
        }
        .frame(width: head * 2.6, height: head * 2.6)
        .animation(.spring(response: 0.35), value: outfit)
    }

    // MARK: Ears

    @ViewBuilder
    private var earsView: some View {
        switch kind {
        case .child:
            HStack(spacing: head * 0.8) {
                Circle().fill(outfit.skinColor).frame(width: head * 0.2)
                Circle().fill(outfit.skinColor).frame(width: head * 0.2)
            }
        case .bear:
            HStack(spacing: head * 0.6) {
                ZStack {
                    Circle().fill(outfit.skinColor).frame(width: head * 0.36)
                    Circle().fill(Palette.pink.opacity(0.45)).frame(width: head * 0.18)
                }
                ZStack {
                    Circle().fill(outfit.skinColor).frame(width: head * 0.36)
                    Circle().fill(Palette.pink.opacity(0.45)).frame(width: head * 0.18)
                }
            }
            .offset(y: -head * 0.44)
        case .bunny:
            HStack(spacing: head * 0.24) {
                ZStack {
                    Capsule().fill(outfit.skinColor).frame(width: head * 0.22, height: head * 0.66)
                    Capsule().fill(Palette.pink.opacity(0.45)).frame(width: head * 0.1, height: head * 0.44)
                }
                .rotationEffect(.degrees(-10))
                ZStack {
                    Capsule().fill(outfit.skinColor).frame(width: head * 0.22, height: head * 0.66)
                    Capsule().fill(Palette.pink.opacity(0.45)).frame(width: head * 0.1, height: head * 0.44)
                }
                .rotationEffect(.degrees(10))
            }
            .offset(y: -head * 0.62)
        }
    }

    // MARK: Hair

    @ViewBuilder
    private var hairView: some View {
        let style = isHat ? 1 : outfit.hairStyle
        switch style {
        case 0:
            EmptyView()
        case 1:
            Circle()
                .trim(from: 0.5, to: 1.0)
                .fill(outfit.hairShade)
                .frame(width: head * 1.08, height: head * 1.08)
                .offset(y: -head * 0.04)
        case 2:
            HStack(spacing: -head * 0.1) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle().fill(outfit.hairShade).frame(width: head * 0.32)
                }
            }
            .offset(y: -head * 0.34)
        default:
            ZStack {
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .fill(outfit.hairShade)
                    .frame(width: head * 1.06, height: head * 1.06)
                    .offset(y: -head * 0.02)
                HStack(spacing: head * 0.94) {
                    Circle().fill(outfit.hairShade).frame(width: head * 0.3)
                    Circle().fill(outfit.hairShade).frame(width: head * 0.3)
                }
                .offset(y: -head * 0.28)
            }
        }
    }

    // MARK: Face

    @ViewBuilder
    private var eyesView: some View {
        HStack(spacing: head * 0.28) {
            eye
            eye
        }
        .offset(y: -head * 0.04)
    }

    @ViewBuilder
    private var eye: some View {
        if blinking && outfit.mood != .sleepy {
            Capsule()
                .fill(Palette.ink)
                .frame(width: head * 0.13, height: head * 0.035)
        } else {
            switch outfit.mood {
            case .happy:
                Circle().fill(Palette.ink).frame(width: head * 0.09, height: head * 0.09)
            case .giggly:
                SmileShape()
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: head * 0.035, lineCap: .round))
                    .frame(width: head * 0.16, height: head * 0.08)
                    .rotationEffect(.degrees(180))
            case .surprised:
                ZStack {
                    Circle().fill(Palette.ink).frame(width: head * 0.15, height: head * 0.15)
                    Circle().fill(.white).frame(width: head * 0.05, height: head * 0.05)
                        .offset(x: head * 0.03, y: -head * 0.03)
                }
            case .sleepy:
                SmileShape()
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: head * 0.035, lineCap: .round))
                    .frame(width: head * 0.16, height: head * 0.06)
            }
        }
    }

    @ViewBuilder
    private var mouthView: some View {
        switch outfit.mood {
        case .giggly:
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(Palette.ink)
                .frame(width: head * 0.3, height: head * 0.3)
                .offset(y: head * 0.16)
        case .surprised:
            Ellipse()
                .fill(Palette.ink)
                .frame(width: head * 0.14, height: head * 0.18)
                .offset(y: head * 0.24)
        case .sleepy:
            SmileShape()
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: head * 0.03, lineCap: .round))
                .frame(width: head * 0.2, height: head * 0.1)
                .offset(y: head * 0.22)
        default:
            SmileShape()
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: head * 0.035, lineCap: .round))
                .frame(width: head * 0.32, height: head * 0.16)
                .offset(y: head * 0.2)
        }
    }

    private var glassesView: some View {
        HStack(spacing: head * 0.04) {
            Circle()
                .stroke(Palette.ink, lineWidth: head * 0.035)
                .frame(width: head * 0.26, height: head * 0.26)
            Capsule().fill(Palette.ink).frame(width: head * 0.08, height: head * 0.03)
            Circle()
                .stroke(Palette.ink, lineWidth: head * 0.035)
                .frame(width: head * 0.26, height: head * 0.26)
        }
        .offset(y: -head * 0.04)
    }

    // MARK: Headwear

    @ViewBuilder
    private var headwearView: some View {
        switch outfit.head {
        case 1:
            // Baseball cap: dome plus a brim
            ZStack {
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .fill(outfit.headShade)
                    .frame(width: head * 1.04, height: head * 1.04)
                Capsule()
                    .fill(outfit.headShade)
                    .frame(width: head * 0.7, height: head * 0.16)
                    .offset(x: head * 0.45, y: head * 0.02)
            }
            .offset(y: -head * 0.34)
        case 2:
            // Sun hat: wide brim plus a dome
            ZStack {
                Ellipse()
                    .fill(outfit.headShade)
                    .frame(width: head * 1.7, height: head * 0.36)
                    .offset(y: head * 0.06)
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .fill(outfit.headShade)
                    .frame(width: head * 0.9, height: head * 0.9)
                    .offset(y: -head * 0.08)
            }
            .offset(y: -head * 0.3)
        case 5:
            // Winter beanie with a bobble and a folded brim
            ZStack {
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .fill(outfit.headShade)
                    .frame(width: head * 1.1, height: head * 1.1)
                Capsule()
                    .fill(outfit.headShade.opacity(0.75))
                    .frame(width: head * 1.12, height: head * 0.2)
                    .offset(y: head * 0.02)
                Circle()
                    .fill(outfit.headShade.opacity(0.85))
                    .frame(width: head * 0.26)
                    .offset(y: -head * 0.52)
            }
            .offset(y: -head * 0.3)
        case 6:
            // Party hat with a pom on top
            ZStack {
                Triangle()
                    .fill(outfit.headShade)
                    .frame(width: head * 0.62, height: head * 0.78)
                Circle()
                    .fill(Palette.pink)
                    .frame(width: head * 0.2)
                    .offset(y: -head * 0.44)
                VStack(spacing: head * 0.1) {
                    Circle().fill(.white.opacity(0.8)).frame(width: head * 0.1)
                    Circle().fill(.white.opacity(0.8)).frame(width: head * 0.1)
                }
                .offset(y: head * 0.1)
            }
            .offset(y: -head * 0.72)
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
            Color(red: 0.96, green: 0.93, blue: 0.88)
            Rectangle()
                .fill(Color(red: 0.87, green: 0.79, blue: 0.68))
                .frame(height: h * 0.24)
                .position(x: w / 2, y: h * 0.88)
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.03)
                    .fill(Color(red: 0.78, green: 0.88, blue: 0.95))
                Rectangle().fill(.white.opacity(0.9)).frame(width: w * 0.012)
                Rectangle().fill(.white.opacity(0.9)).frame(height: h * 0.012)
            }
            .frame(width: w * 0.28, height: h * 0.26)
            .overlay(
                RoundedRectangle(cornerRadius: w * 0.03)
                    .stroke(.white, lineWidth: 4)
                    .frame(width: w * 0.28, height: h * 0.26)
            )
            .position(x: w * 0.22, y: h * 0.26)
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.04)
                    .fill(Palette.blue.opacity(0.55))
                    .frame(width: w * 0.42, height: h * 0.16)
                RoundedRectangle(cornerRadius: w * 0.03)
                    .fill(.white)
                    .frame(width: w * 0.14, height: h * 0.07)
                    .offset(x: -w * 0.12, y: -h * 0.03)
            }
            .position(x: w * 0.78, y: h * 0.74)
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
