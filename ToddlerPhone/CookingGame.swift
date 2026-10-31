import SwiftUI

// MARK: - Little Chef (a tiny restaurant: customers, orders, hands-on stations)

/// Everything the little kitchen can cook with. All drawn with shapes.
enum ChefIngredient: String, CaseIterable, Identifiable {
    case carrot, tomato, egg, broccoli, corn, mushroom
    case potato, cheese, banana, berry, milk

    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

/// One hands-on step in a recipe.
enum ChefStation: String, Identifiable {
    case wash, chop, stir, flip, blend, plate, garnish

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .wash: return "drop.fill"
        case .chop: return "scissors"
        case .stir: return "flame.fill"
        case .flip: return "frying.pan.fill"
        case .blend: return "tornado"
        case .plate: return "fork.knife"
        case .garnish: return "leaf.fill"
        }
    }

    var title: String {
        switch self {
        case .wash: return "Rub the food to wash it clean!"
        case .chop: return "Swipe across the food to cut it!"
        case .stir: return "Stir the pot round and round!"
        case .flip: return "Tap the pan when it sizzles!"
        case .blend: return "Hold the blender to mix it up!"
        case .plate: return "Drag the food onto the plate!"
        case .garnish: return "Shake on some green herbs!"
        }
    }

    var spoken: String {
        switch self {
        case .wash: return "Let us wash it clean!"
        case .chop: return "Now cut it up!"
        case .stir: return "Stir the pot round and round!"
        case .flip: return "Tap the pan when it sizzles!"
        case .blend: return "Hold the blender!"
        case .plate: return "Put it on the plate!"
        case .garnish: return "Shake some herbs on top!"
        }
    }
}

/// How the finished dish is served.
enum ChefPlating {
    case bowl, plate, cup, stack, pizza, pan
}

/// A named recipe: what it is made of and which stations it needs.
struct ChefDish: Identifiable, Equatable {
    let id: Int
    let name: String
    let ingredients: [ChefIngredient]
    let stations: [ChefStation]
    let plating: ChefPlating
    let color: Color
    let order: String

    static func == (a: ChefDish, b: ChefDish) -> Bool { a.id == b.id }

    static let all: [ChefDish] = [
        ChefDish(
            id: 0, name: "Soup",
            ingredients: [.carrot, .tomato],
            stations: [.wash, .chop, .stir, .garnish],
            plating: .bowl, color: Palette.orange,
            order: "Can I have soup please?"
        ),
        ChefDish(
            id: 1, name: "Salad",
            ingredients: [.tomato, .broccoli, .corn],
            stations: [.wash, .chop, .plate],
            plating: .plate, color: Palette.green,
            order: "I would love a salad please!"
        ),
        ChefDish(
            id: 2, name: "Pancakes",
            ingredients: [.egg, .milk],
            stations: [.blend, .flip],
            plating: .stack, color: Palette.yellow,
            order: "Some warm pancakes please!"
        ),
        ChefDish(
            id: 3, name: "Stew",
            ingredients: [.potato, .carrot, .mushroom],
            stations: [.wash, .chop, .stir],
            plating: .bowl, color: Palette.brown,
            order: "Can you make me a stew?"
        ),
        ChefDish(
            id: 4, name: "Smoothie",
            ingredients: [.banana, .berry, .milk],
            stations: [.wash, .blend],
            plating: .cup, color: Palette.purple,
            order: "One cold smoothie please!"
        ),
        ChefDish(
            id: 5, name: "Pizza",
            ingredients: [.tomato, .cheese, .mushroom],
            stations: [.chop, .plate, .garnish],
            plating: .pizza, color: Palette.red,
            order: "I would like a pizza please!"
        ),
        ChefDish(
            id: 6, name: "Omelette",
            ingredients: [.egg, .cheese, .broccoli],
            stations: [.chop, .flip, .garnish],
            plating: .pan, color: Palette.yellow,
            order: "Can I have an omelette?"
        ),
        ChefDish(
            id: 7, name: "Fruit Bowl",
            ingredients: [.banana, .berry],
            stations: [.wash, .chop, .plate],
            plating: .bowl, color: Palette.pink,
            order: "A fruity bowl please!"
        ),
    ]
}

/// A friendly customer, made from the same simple shapes with a different
/// color and hat every time.
/// Whoever walks in for lunch. Customers are the same little people the
/// child dresses in Dress Up, so the whole app shares one cast.
struct ChefCustomer: Equatable {
    var look: DressOutfit

    static func random() -> ChefCustomer {
        var look = DressOutfit.random()
        look.face = 0
        // Nothing in their hands or on their back while they are at the table.
        look.extra = [0, 0, 0, 1, 3].randomElement() ?? 0
        return ChefCustomer(look: look)
    }

    /// The same person, beaming.
    var delighted: DressOutfit {
        look.changing { $0.face = 1 }
    }
}

// MARK: - The game

struct CookingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Roomier layout on an iPad, where everything looked lost in the middle.
    private var roomy: Bool { sizeClass == .regular }

    @AppStorage("chefCustomersServed") private var customersServed = 0
    @AppStorage("chefStars") private var stars = 0

    private enum Phase { case order, cook, serve }

    @State private var phase: Phase = .order
    @State private var dish: ChefDish = ChefDish.all[0]
    @State private var customer = ChefCustomer.random()
    @State private var shelf: [ChefIngredient] = []
    @State private var picked: [ChefIngredient] = []
    @State private var stationIndex = 0
    @State private var nudged: ChefIngredient?
    @State private var nudgeWiggle = false
    @State private var bob = false
    @State private var happy = false
    @State private var showCelebration = false
    @State private var unlockedDish: ChefDish?
    @State private var canTakeNext = false

    /// Two recipes to start with and one more for every three customers.
    private var unlockedCount: Int {
        min(ChefDish.all.count, 2 + customersServed / 3)
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 10) {
                GameTopBar(title: "Little Chef", stars: stars, onClose: { dismiss() })

                switch phase {
                case .order: orderScene
                case .cook: cookScene
                case .serve: serveScene
                }

                Spacer(minLength: 0)
            }

            if showCelebration, let unlockedDish {
                CelebrationOverlay(
                    title: "New recipe!",
                    subtitle: "You can cook \(unlockedDish.name.lowercased()) now",
                    buttonLabel: "Next customer",
                    symbol: "star.fill",
                    tint: Palette.orange
                ) {
                    showCelebration = false
                    self.unlockedDish = nil
                    newCustomer()
                }
            }
        }
        .onAppear {
            bob = true
            if shelf.isEmpty { newCustomer() }
            #if DEBUG
            debugJump()
            #endif
        }
    }

    // MARK: Order scene

    private var orderScene: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                ChefShopScene()
                HStack(alignment: .bottom, spacing: 10) {
                    ChefCustomerView(customer: customer, happy: false)
                        .frame(width: roomy ? 168 : 118, height: roomy ? 240 : 168)
                    ChefSpeechBubble(dish: dish, picked: picked)
                        .padding(.bottom, roomy ? 86 : 54)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, roomy ? 14 : 10)
            }
            .frame(height: roomy ? 300 : 206)
            .padding(.horizontal, 20)

            ChefShopSign(count: customersServed)

            Spacer(minLength: 0)

            if let nudged {
                Text("\(nudged.name) is yummy too. Look at the pictures!")
                    .font(.rounded(14, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .transition(.opacity)
            } else {
                Text("Tap the food the customer asked for!")
                    .font(.rounded(14, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }

            shelfGrid

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    private var shelfGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(Array(shelf.enumerated()), id: \.element.id) { index, item in
                Button {
                    pick(item)
                } label: {
                    VStack(spacing: 6) {
                        ChefIngredientView(ingredient: item)
                            .frame(width: roomy ? 76 : 46, height: roomy ? 76 : 46)
                            .offset(y: bob ? -3.5 : 3.5)
                            .animation(
                                .easeInOut(duration: 1.15 + Double(index) * 0.11)
                                    .repeatForever(autoreverses: true),
                                value: bob
                            )
                        Text(item.name)
                            .font(.rounded(13, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: roomy ? 150 : 96)
                    .card(cornerRadius: 20)
                    .opacity(picked.contains(item) ? 0.45 : 1)
                    .rotationEffect(.degrees(nudged == item && nudgeWiggle ? 5 : 0))
                }
                .buttonStyle(BouncyButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }

    private func pick(_ item: ChefIngredient) {
        guard phase == .order else { return }
        if dish.ingredients.contains(item), !picked.contains(item) {
            Sfx.pop()
            Sfx.bump(.light)
            withAnimation(.spring(response: 0.35)) {
                picked.append(item)
                nudged = nil
            }
            if picked.count == dish.ingredients.count {
                Speaker.shared.say("That is everything! Let us cook.")
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.9))
                    startCooking()
                }
            }
        } else {
            softNudge(item)
        }
    }

    /// Wrong taps are never punished. The tile wiggles and a kind line appears.
    private func softNudge(_ item: ChefIngredient) {
        Sfx.bump(.light)
        ToneEngine.shared.play("tap")
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            nudged = item
            nudgeWiggle = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { nudgeWiggle = false }
            try? await Task.sleep(for: .seconds(2.4))
            if nudged == item { withAnimation(.easeOut(duration: 0.3)) { nudged = nil } }
        }
    }

    // MARK: Cook scene

    private var cookScene: some View {
        VStack(spacing: 10) {
            ChefProgressTrail(stations: dish.stations, current: stationIndex)

            Text(dish.stations[stationIndex].title)
                .font(.rounded(16, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer(minLength: 0)

            stationView
                .id("\(dish.id)-\(stationIndex)")

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var stationView: some View {
        switch dish.stations[stationIndex] {
        case .wash:
            ChefWashStation(ingredients: dish.ingredients, onDone: advanceStation)
        case .chop:
            ChefChopStation(ingredients: dish.ingredients, onDone: advanceStation)
        case .stir:
            ChefStirStation(dish: dish, onDone: advanceStation)
        case .flip:
            ChefFlipStation(dish: dish, onDone: advanceStation)
        case .blend:
            ChefBlendStation(dish: dish, onDone: advanceStation)
        case .plate:
            ChefPlateStation(dish: dish, onDone: advanceStation)
        case .garnish:
            ChefGarnishStation(dish: dish, onDone: advanceStation)
        }
    }

    private func startCooking() {
        withAnimation(.spring(response: 0.4)) {
            phase = .cook
            stationIndex = 0
        }
        Speaker.shared.say(dish.stations[0].spoken)
    }

    private func advanceStation() {
        if stationIndex + 1 < dish.stations.count {
            let next = stationIndex + 1
            withAnimation(.spring(response: 0.4)) { stationIndex = next }
            Speaker.shared.say(dish.stations[next].spoken)
        } else {
            withAnimation(.spring(response: 0.4)) { phase = .serve }
            Speaker.shared.say("The \(dish.name.lowercased()) is ready! Take it over.")
        }
    }

    // MARK: Serve scene

    private var serveScene: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            ZStack {
                if happy {
                    ConfettiBurst(count: 30, spread: 190, duration: 1.8)
                        .offset(y: -20)
                }

                HStack(alignment: .bottom, spacing: 10) {
                    ZStack(alignment: .top) {
                        ChefCustomerView(customer: customer, happy: happy)
                            .frame(width: roomy ? 170 : 130, height: roomy ? 236 : 180)
                        if happy {
                            ForEach(0..<4, id: \.self) { i in
                                ChefFloatingHeart(delay: Double(i) * 0.16, drift: CGFloat(i - 2) * 22)
                            }
                        }
                    }
                    ChefPlatedDish(dish: dish, garnished: dish.stations.contains(.garnish))
                        .frame(width: 170, height: 150)
                }
            }
            .frame(height: 200)

            Text(happy ? "Thank you little chef!" : "Here is the \(dish.name.lowercased())!")
                .font(.rounded(19))
                .foregroundStyle(Palette.ink)

            if !happy {
                bigButton("Serve it", color: Palette.green) { serve() }
            } else if canTakeNext {
                bigButton("Next customer", color: Palette.orange) { newCustomer() }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity)
    }

    private func serve() {
        Sfx.received()
        Sfx.bump(.heavy)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { happy = true }
        stars += 1
        customersServed += 1
        Speaker.shared.cheer("Yummy! Thank you little chef!")

        let newlyUnlocked = unlockedCount
        let justUnlocked = (customersServed % 3 == 0) && newlyUnlocked <= ChefDish.all.count
            && newlyUnlocked > 2 + (customersServed - 1) / 3

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if justUnlocked {
                unlockedDish = ChefDish.all[newlyUnlocked - 1]
                withAnimation(.spring(response: 0.4)) { showCelebration = true }
            } else {
                withAnimation(.spring(response: 0.35)) { canTakeNext = true }
            }
        }
    }

    // MARK: New customer

    private func newCustomer() {
        let choice = ChefDish.all[Int.random(in: 0..<unlockedCount)]
        var tray = choice.ingredients
        let extras = ChefIngredient.allCases.filter { !tray.contains($0) }.shuffled()
        for extra in extras where tray.count < 6 { tray.append(extra) }

        withAnimation(.spring(response: 0.45)) {
            dish = choice
            customer = ChefCustomer.random()
            shelf = tray.shuffled()
            picked = []
            stationIndex = 0
            nudged = nil
            happy = false
            canTakeNext = false
            phase = .order
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.55))
            Speaker.shared.say(choice.order)
        }
    }

    #if DEBUG
    /// Lets `simctl launch ... -chefDish 0 -chefStation 2` open one station.
    private func debugJump() {
        guard let raw = UserDefaults.standard.string(forKey: "chefDish"),
              let index = Int(raw) else { return }
        dish = ChefDish.all[min(max(index, 0), ChefDish.all.count - 1)]
        picked = dish.ingredients
        let step = UserDefaults.standard.string(forKey: "chefStation").flatMap(Int.init) ?? 0
        if step >= dish.stations.count {
            phase = .serve
        } else {
            stationIndex = step
            phase = .cook
        }
    }
    #endif

    private func bigButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            Sfx.tap()
            Sfx.bump(.light)
            action()
        } label: {
            Text(title)
                .font(.rounded(20))
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 16)
                .background(color, in: Capsule())
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Shop furniture

/// The little sign in the shop counting everyone who has been fed.
struct ChefShopSign: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.brown)
            Text("Served \(count)")
                .font(.rounded(16, weight: .semibold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Palette.brown.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Palette.brown.opacity(0.5), lineWidth: 2.5)
        )
    }
}

/// The order: a rounded bubble with a tail and the wanted food inside.
struct ChefSpeechBubble: View {
    let dish: ChefDish
    let picked: [ChefIngredient]

    var body: some View {
        HStack(spacing: 0) {
            ChefBubbleTail()
                .fill(Palette.card)
                .frame(width: 14, height: 22)
                .offset(x: 2, y: 12)
            VStack(spacing: 8) {
                Text(dish.name)
                    .font(.rounded(18))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 10) {
                    ForEach(dish.ingredients) { item in
                        ZStack {
                            Circle()
                                .fill(picked.contains(item) ? Palette.green.opacity(0.18) : Palette.field)
                                .frame(width: 52, height: 52)
                            ChefIngredientView(ingredient: item)
                                .frame(width: 36, height: 36)
                            if picked.contains(item) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Palette.green)
                                    .offset(x: 18, y: 18)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .card(cornerRadius: 22)
        }
    }
}

/// The little pointer on the side of the speech bubble.
struct ChefBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A hungry visitor drawn from circles and capsules.
struct ChefCustomerView: View {
    let customer: ChefCustomer
    var happy: Bool = false

    var body: some View {
        CharacterView(outfit: happy ? customer.delighted : customer.look)
            .animation(.spring(response: 0.4), value: happy)
    }
}

/// The little shop the customer stands in: a warm wall and a wooden floor.
struct ChefShopScene: View {
    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.95, blue: 0.88),
                        Color(red: 0.97, green: 0.92, blue: 0.84),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                ChefCounter()
                    .frame(height: h * 0.22)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Palette.ink.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

/// The floor of the shop: warm wood with a lighter seam along the top.
struct ChefCounter: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.84, green: 0.72, blue: 0.56),
                            Color(red: 0.74, green: 0.60, blue: 0.44),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(height: 3)
                .padding(.horizontal, 6)
                .padding(.top, 3)
        }
        .shadow(color: .black.opacity(0.08), radius: 5, y: 3)
    }
}

/// A little heart that floats up from a happy customer.
struct ChefFloatingHeart: View {
    let delay: Double
    let drift: CGFloat
    @State private var up = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 22))
            .foregroundStyle(Palette.pink)
            .offset(x: drift, y: up ? -110 : 0)
            .opacity(up ? 0 : 0.95)
            .scaleEffect(up ? 1.2 : 0.6)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).delay(delay)) { up = true }
            }
    }
}

/// The trail of steps across the top of the kitchen.
struct ChefProgressTrail: View {
    let stations: [ChefStation]
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(stations.enumerated()), id: \.offset) { index, station in
                if index > 0 {
                    Capsule()
                        .fill(index <= current ? Palette.orange : Palette.field)
                        .frame(width: 16, height: 5)
                }
                Image(systemName: index < current ? "checkmark" : station.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(index == current ? .white : (index < current ? Palette.green : Palette.inkSoft))
                    .frame(width: 46, height: 46)
                    .background(index == current ? Palette.orange : Palette.field, in: Circle())
                    .scaleEffect(index == current ? 1.08 : 1)
            }
        }
        .animation(.spring(response: 0.35), value: current)
    }
}

// MARK: - Station: wash

struct ChefWashStation: View {
    let ingredients: [ChefIngredient]
    let onDone: () -> Void

    @State private var progress: CGFloat = 0
    @State private var lastPoint: CGPoint?
    @State private var sinceSound: CGFloat = 0
    @State private var sinceBubble: CGFloat = 0
    @State private var bubbles: [ChefBubbleSpot] = []
    @State private var sparkle = false
    @State private var rubbing = false
    @State private var finished = false

    struct ChefBubbleSpot: Identifiable {
        let id = UUID()
        let point: CGPoint
        let size: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Palette.blue.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Palette.blue.opacity(0.75), lineWidth: 4)
                    )

                ChefFaucet(running: rubbing)
                    .position(x: geo.size.width * 0.5, y: 44)

                HStack(spacing: 10) {
                    ForEach(ingredients) { item in
                        ChefIngredientView(ingredient: item)
                            .frame(width: 54, height: 54)
                            .rotationEffect(.degrees(rubbing ? 6 : -6))
                            .animation(
                                rubbing
                                    ? .easeInOut(duration: 0.16).repeatForever(autoreverses: true)
                                    : .easeOut(duration: 0.3),
                                value: rubbing
                            )
                    }
                }
                .offset(y: 26)

                ForEach(bubbles) { bubble in
                    ChefWashBubble(size: bubble.size).position(bubble.point)
                }

                if sparkle {
                    Image(systemName: "sparkles")
                        .font(.system(size: 70))
                        .foregroundStyle(Palette.yellow)
                        .transition(.scale.combined(with: .opacity))
                }

                ChefProgressRing(progress: progress, color: Palette.blue)
                    .frame(width: 44, height: 44)
                    .position(x: geo.size.width - 32, y: 32)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in rub(to: value.location) }
                    .onEnded { _ in
                        lastPoint = nil
                        rubbing = false
                    }
            )
        }
        .frame(height: 300)
        .padding(.horizontal, 20)
    }

    private func rub(to point: CGPoint) {
        if let last = lastPoint {
            let d = hypot(point.x - last.x, point.y - last.y)
            guard progress < 1 else { return }
            if !rubbing { rubbing = true }
            progress = min(progress + d / 800, 1)
            sinceSound += d
            if sinceSound > 60 {
                sinceSound = 0
                ToneEngine.shared.playSplash()
            }
            sinceBubble += d
            if sinceBubble > 14, bubbles.count < 16 {
                sinceBubble = 0
                let bubble = ChefBubbleSpot(point: point, size: .random(in: 10...22))
                bubbles.append(bubble)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.9))
                    bubbles.removeAll { $0.id == bubble.id }
                }
            }
            if progress >= 1 { finish() }
        }
        lastPoint = point
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        Sfx.pop()
        Sfx.bump()
        rubbing = false
        withAnimation(.spring(response: 0.3)) { sparkle = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            sparkle = false
            onDone()
        }
    }
}

// MARK: - Station: chop

struct ChefChopStation: View {
    let ingredients: [ChefIngredient]
    let onDone: () -> Void

    @State private var index = 0
    @State private var swipes = 0
    @State private var split = false
    @State private var startX: CGFloat = 0
    @State private var counted = false
    @State private var knifePoint: CGPoint?
    @State private var knifeTilt: Double = 0
    @State private var leftDrift: CGSize = .zero
    @State private var rightDrift: CGSize = .zero
    @State private var splitRotation: Double = 14
    @State private var bits: [ChefBit] = []
    @State private var finished = false

    struct ChefBit: Identifiable {
        let id = UUID()
        let angle: CGFloat
        let distance: CGFloat
        let size: CGFloat
        let spin: Double
    }

    private var current: ChefIngredient { ingredients[min(index, ingredients.count - 1)] }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Palette.brown.opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Palette.brown, lineWidth: 4))

                    if split {
                        ZStack {
                            ChefHalfIngredient(ingredient: current, leftSide: true)
                                .frame(width: 130, height: 130)
                                .rotationEffect(.degrees(-splitRotation))
                                .offset(x: -16 + leftDrift.width, y: leftDrift.height)
                            ChefHalfIngredient(ingredient: current, leftSide: false)
                                .frame(width: 130, height: 130)
                                .rotationEffect(.degrees(splitRotation))
                                .offset(x: 16 + rightDrift.width, y: rightDrift.height)
                        }
                    } else {
                        ZStack {
                            ChefIngredientView(ingredient: current)
                                .frame(width: 130, height: 130)
                            // The line to swipe along, with an arrow at each end.
                            ChefCutGuide()
                                .frame(width: 190, height: 130)
                                .allowsHitTesting(false)
                        }
                    }

                    ForEach(bits) { bit in
                        ChefScatterBit(ingredient: current, bit: bit)
                    }

                    if let knifePoint {
                        ChefKnife()
                            .rotationEffect(.degrees(knifeTilt))
                            .position(knifePoint)
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            knifePoint = value.location
                            withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
                                knifeTilt = min(max(Double(value.translation.width) * 0.22, -34), 34)
                            }
                            if !counted {
                                if startX == 0 { startX = value.startLocation.x }
                                let center = geo.size.width / 2
                                let crossed = (startX < center && value.location.x > center)
                                    || (startX > center && value.location.x < center)
                                if crossed && abs(value.translation.width) > 40 {
                                    counted = true
                                    chop()
                                }
                            }
                        }
                        .onEnded { _ in
                            counted = false
                            startX = 0
                            withAnimation(.easeOut(duration: 0.25)) {
                                knifePoint = nil
                                knifeTilt = 0
                            }
                        }
                )
            }
            .frame(height: 280)
            .padding(.horizontal, 20)

            Text("\(ingredients.count - index) to go")
                .font(.rounded(15, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
        }
    }

    private func chop() {
        guard !split else { return }
        ToneEngine.shared.playChop()
        Sfx.bump(.light)
        withAnimation(.spring(response: 0.14, dampingFraction: 0.4)) { knifeTilt += 18 }
        swipes += 1
        guard swipes >= 3 else { return }

        leftDrift = CGSize(width: .random(in: -18 ... -4), height: .random(in: -6...8))
        rightDrift = CGSize(width: .random(in: 4...18), height: .random(in: -6...8))
        splitRotation = .random(in: 10...24)
        bits = (0..<6).map { i in
            ChefBit(
                angle: CGFloat(i) / 6 * .pi * 2 + .random(in: -0.3...0.3),
                distance: .random(in: 60...110),
                size: .random(in: 14...22),
                spin: .random(in: -160...160)
            )
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.45)) { split = true }
        Sfx.pop()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.85))
            advance()
        }
    }

    private func advance() {
        swipes = 0
        split = false
        bits = []
        leftDrift = .zero
        rightDrift = .zero
        if index + 1 < ingredients.count {
            index += 1
        } else if !finished {
            finished = true
            onDone()
        }
    }
}

/// One chopped piece flying off the board.
struct ChefScatterBit: View {
    let ingredient: ChefIngredient
    let bit: ChefChopStation.ChefBit

    @State private var out = false

    var body: some View {
        ChefChoppedIngredient(ingredient: ingredient)
            .frame(width: bit.size, height: bit.size)
            .rotationEffect(.degrees(out ? bit.spin : 0))
            .offset(
                x: out ? cos(bit.angle) * bit.distance : 0,
                y: out ? sin(bit.angle) * bit.distance : 0
            )
            .opacity(out ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) { out = true }
            }
    }
}

// MARK: - Station: stir

struct ChefStirStation: View {
    let dish: ChefDish
    let onDone: () -> Void

    @State private var rotation: CGFloat = 0
    @State private var lastAngle: CGFloat?
    @State private var sinceSound: CGFloat = 0
    @State private var stirring = false
    @State private var finished = false
    /// Where the ladle is sitting on its circle, so it follows the finger.
    @State private var ladleAngle: CGFloat = -.pi / 2

    private let target: CGFloat = .pi * 6

    private var progress: CGFloat { min(rotation / target, 1) }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.5)
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.35, green: 0.36, blue: 0.42))
                    .frame(height: 150)
                    .overlay(
                        Circle()
                            .fill(Palette.red.opacity(0.5 + progress * 0.4))
                            .frame(width: 160, height: 40)
                            .blur(radius: 12)
                            .offset(y: 55)
                    )
                    .padding(.horizontal, 30)
                    .offset(y: 40)

                if stirring || progress >= 1 {
                    HStack(spacing: 26) {
                        ForEach(0..<3, id: \.self) { i in
                            ChefSteamPuff(delay: Double(i) * 0.35)
                        }
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.5 - 92)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }

                // A dashed ring showing the way round, until the stirring starts.
                if !stirring && progress < 1 {
                    Circle()
                        .strokeBorder(
                            Palette.card.opacity(0.55),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [10, 12])
                        )
                        .frame(width: 128, height: 128)
                        .position(center)
                        .allowsHitTesting(false)
                }

                potView

                // The ladle rides round the pot with the child's finger.
                ChefLadle()
                    .rotationEffect(.radians(Double(ladleAngle) + .pi / 2))
                    .position(
                        x: center.x + cos(ladleAngle) * 46,
                        y: center.y + sin(ladleAngle) * 30 - 10
                    )
                    .allowsHitTesting(false)

                ChefProgressRing(progress: progress, color: Palette.orange)
                    .frame(width: 46, height: 46)
                    .position(x: geo.size.width - 30, y: 26)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in stir(at: value.location, center: center) }
                    .onEnded { _ in
                        lastAngle = nil
                        withAnimation(.easeOut(duration: 0.5)) { stirring = false }
                    }
            )
        }
        .frame(height: 300)
        .padding(.horizontal, 20)
    }

    private var potView: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(red: 0.55, green: 0.57, blue: 0.63))
                .frame(width: 236, height: 16)
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.62, green: 0.64, blue: 0.70))
                .frame(width: 214, height: 116)
                .overlay(alignment: .top) {
                    ZStack {
                        Ellipse()
                            .fill(dish.color.opacity(0.45 + progress * 0.4))
                            .frame(width: 194, height: 36)
                            .offset(y: 4)
                        ForEach(0..<3, id: \.self) { i in
                            ChefRisingBubble(delay: Double(i) * 0.5, active: progress > 0.1)
                                .offset(x: CGFloat(i - 1) * 40, y: 8)
                        }
                        HStack(spacing: -6) {
                            ForEach(dish.ingredients) { item in
                                ChefChoppedIngredient(ingredient: item)
                                    .frame(width: 34, height: 34)
                            }
                        }
                        .offset(y: 6)
                    }
                }
        }
    }

    private func stir(at point: CGPoint, center: CGPoint) {
        let angle = atan2(point.y - center.y, point.x - center.x)
        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.8)) {
            ladleAngle = angle
        }
        if let last = lastAngle {
            var delta = angle - last
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            let step = abs(delta)
            if progress < 1 {
                if !stirring, step > 0.02 {
                    withAnimation(.easeIn(duration: 0.3)) { stirring = true }
                }
                rotation += step
                sinceSound += step
                if sinceSound > .pi * 0.8 {
                    sinceSound = 0
                    ToneEngine.shared.playSizzle()
                }
                if progress >= 1 { finish() }
            }
        }
        lastAngle = angle
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        Sfx.bump()
        Sfx.pop()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            onDone()
        }
    }
}

// MARK: - Station: flip

struct ChefFlipStation: View {
    let dish: ChefDish
    let onDone: () -> Void

    @State private var flips = 0
    @State private var ready = false
    @State private var flying = false
    @State private var pulse = false
    @State private var finished = false

    private let needed = 3

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if ready && !flying {
                    Circle()
                        .stroke(Palette.orange.opacity(0.5), lineWidth: 5)
                        .frame(width: 150, height: 150)
                        .scaleEffect(pulse ? 1.25 : 0.95)
                        .opacity(pulse ? 0 : 0.9)
                        .animation(.easeOut(duration: 0.9).repeatForever(autoreverses: false), value: pulse)
                }

                // Pan
                ZStack {
                    Circle()
                        .fill(Color(red: 0.30, green: 0.31, blue: 0.36))
                        .frame(width: 190, height: 190)
                    Circle()
                        .fill(Color(red: 0.40, green: 0.41, blue: 0.46))
                        .frame(width: 160, height: 160)
                    Capsule()
                        .fill(Palette.brown)
                        .frame(width: 92, height: 20)
                        .offset(x: 130)
                }

                // The food in the pan
                ChefPanFood(dish: dish, done: flips)
                    .frame(width: 120, height: 120)
                    .rotation3DEffect(.degrees(flying ? 180 : 0), axis: (x: 1, y: 0, z: 0))
                    .offset(y: flying ? -90 : 0)
                    .scaleEffect(flying ? 1.15 : 1)

                if ready && !flying {
                    Text("Tap!")
                        .font(.rounded(20))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Palette.orange, in: Capsule())
                        .offset(y: -110)
                }
            }
            .frame(height: 230)
            .contentShape(Rectangle())
            .onTapGesture { flip() }

            HStack(spacing: 10) {
                ForEach(0..<needed, id: \.self) { i in
                    Image(systemName: i < flips ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(i < flips ? Palette.green : Palette.inkSoft.opacity(0.5))
                }
            }
        }
        .onAppear {
            pulse = true
            armSizzle()
        }
    }

    private func armSizzle() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            guard !finished else { return }
            ToneEngine.shared.playSizzle()
            withAnimation(.spring(response: 0.3)) { ready = true }
        }
    }

    /// Taps always count. The glow just teaches when the pan is hottest.
    private func flip() {
        guard !flying, !finished else { return }
        ToneEngine.shared.playSizzle()
        Sfx.bump()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) {
            flying = true
            ready = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.42))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { flying = false }
            flips += 1
            Sfx.pop()
            if flips >= needed {
                finished = true
                Speaker.shared.say("Golden and yummy!")
                try? await Task.sleep(for: .seconds(0.7))
                onDone()
            } else {
                armSizzle()
            }
        }
    }
}

/// What is sizzling in the pan, browning a little with every flip.
struct ChefPanFood: View {
    let dish: ChefDish
    let done: Int

    var body: some View {
        ZStack {
            switch dish.plating {
            case .stack:
                Circle()
                    .fill(Color(red: 0.88, green: 0.72, blue: 0.45).opacity(0.7 + Double(done) * 0.1))
                    .overlay(Circle().stroke(Palette.brown.opacity(0.5), lineWidth: 3))
            default:
                Ellipse()
                    .fill(Palette.yellow.opacity(0.75 + Double(done) * 0.08))
                    .overlay(Ellipse().stroke(Palette.orange.opacity(0.6), lineWidth: 3))
            }
            HStack(spacing: -4) {
                ForEach(dish.ingredients) { item in
                    ChefChoppedIngredient(ingredient: item)
                        .frame(width: 26, height: 26)
                }
            }
        }
    }
}

// MARK: - Station: blend

struct ChefBlendStation: View {
    let dish: ChefDish
    let onDone: () -> Void

    @State private var holding = false
    @State private var progress: CGFloat = 0
    @State private var finished = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    blender(spin: holding ? t * 420 : 0)
                }
                .rotationEffect(.degrees(holding ? 2.5 : 0))
                .animation(
                    holding
                        ? .easeInOut(duration: 0.07).repeatForever(autoreverses: true)
                        : .spring(response: 0.3),
                    value: holding
                )

                ChefProgressRing(progress: progress, color: dish.color)
                    .frame(width: 46, height: 46)
                    .offset(x: 110, y: -80)
            }
            .frame(height: 240)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginBlend() }
                    .onEnded { _ in holding = false }
            )

            Text(holding ? "Whizzzz!" : "Press and hold the blender")
                .font(.rounded(15, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(.horizontal, 20)
    }

    private func blender(spin: Double) -> some View {
        VStack(spacing: 0) {
            // Lid
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.55, green: 0.57, blue: 0.63))
                .frame(width: 118, height: 16)

            // Jar with the swirling mix
            ZStack {
                ChefJarShape()
                    .fill(.white.opacity(0.45))
                ChefJarShape()
                    .fill(
                        AngularGradient(
                            colors: [dish.color, dish.color.opacity(0.55), Palette.card, dish.color],
                            center: .center
                        )
                    )
                    .rotationEffect(.degrees(spin))
                    .mask(ChefJarShape().scale(0.94))
                    .opacity(0.25 + Double(progress) * 0.7)

                if progress < 0.85 {
                    HStack(spacing: -6) {
                        ForEach(dish.ingredients) { item in
                            ChefIngredientView(ingredient: item)
                                .frame(width: 34, height: 34)
                                .rotationEffect(.degrees(spin * 0.6))
                        }
                    }
                    .opacity(1 - Double(progress) / 0.85)
                }

                ChefJarShape()
                    .stroke(Color(red: 0.70, green: 0.72, blue: 0.78), lineWidth: 5)
            }
            .frame(width: 110, height: 132)

            // Motor base
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.45, green: 0.47, blue: 0.53))
                .frame(width: 130, height: 46)
                .overlay(
                    Circle()
                        .fill(holding ? Palette.green : Palette.field)
                        .frame(width: 16, height: 16)
                        .offset(x: 44)
                )
        }
    }

    private func beginBlend() {
        guard !holding, !finished else { return }
        holding = true
        Sfx.bump(.light)
        ToneEngine.shared.playSizzle()
        Task { @MainActor in
            var beat = 0
            while holding && progress < 1 {
                try? await Task.sleep(for: .seconds(0.05))
                progress = min(progress + 0.022, 1)
                beat += 1
                if beat % 12 == 0 {
                    ToneEngine.shared.playSizzle()
                    Sfx.bump(.light)
                }
            }
            if progress >= 1 { finish() }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        holding = false
        Sfx.pop()
        Sfx.bump()
        Speaker.shared.say("All smooth and mixed!")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            onDone()
        }
    }
}

/// The tapered jar of the blender.
struct ChefJarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset = rect.width * 0.1
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Station: plate

struct ChefPlateStation: View {
    let dish: ChefDish
    let onDone: () -> Void

    struct Piece: Identifiable {
        let id = UUID()
        let ingredient: ChefIngredient
        var position: CGPoint
        var home: CGPoint
        var slot: CGPoint
        var placed = false
    }

    @State private var pieces: [Piece] = []
    @State private var plateCenter: CGPoint = .zero
    @State private var finished = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Counter top
                RoundedRectangle(cornerRadius: 26)
                    .fill(Palette.brown.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(Palette.brown.opacity(0.4), lineWidth: 3))

                // The plate waiting to be filled
                ZStack {
                    Ellipse()
                        .fill(.white)
                        .frame(width: 190, height: 96)
                        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
                    Ellipse()
                        .stroke(dish.color.opacity(0.35), style: StrokeStyle(lineWidth: 4, dash: [8, 7]))
                        .frame(width: 150, height: 70)
                }
                .position(x: geo.size.width / 2, y: geo.size.height * 0.34)

                ForEach(pieces.indices, id: \.self) { i in
                    ChefIngredientView(ingredient: pieces[i].ingredient)
                        .frame(width: pieces[i].placed ? 46 : 62, height: pieces[i].placed ? 46 : 62)
                        .position(pieces[i].position)
                        .gesture(
                            DragGesture(coordinateSpace: .named("plateArea"))
                                .onChanged { value in
                                    guard i < pieces.count, !pieces[i].placed else { return }
                                    pieces[i].position = value.location
                                }
                                .onEnded { value in
                                    guard i < pieces.count, !pieces[i].placed else { return }
                                    drop(i, at: value.location)
                                }
                        )
                }
            }
            .coordinateSpace(name: "plateArea")
            .onAppear { layout(in: geo.size) }
        }
        .frame(height: 300)
        .padding(.horizontal, 20)
    }

    private func layout(in size: CGSize) {
        guard pieces.isEmpty else { return }
        plateCenter = CGPoint(x: size.width / 2, y: size.height * 0.34)
        let count = dish.ingredients.count
        pieces = dish.ingredients.enumerated().map { index, item in
            let spread = size.width * 0.62
            let x = size.width / 2 - spread / 2 + spread * CGFloat(index) / CGFloat(max(count - 1, 1))
            let home = CGPoint(x: count == 1 ? size.width / 2 : x, y: size.height * 0.82)
            let angle = CGFloat(index) / CGFloat(count) * .pi * 2
            let slot = CGPoint(
                x: plateCenter.x + cos(angle) * 42,
                y: plateCenter.y + sin(angle) * 20
            )
            return Piece(ingredient: item, position: home, home: home, slot: slot)
        }
    }

    private func drop(_ i: Int, at point: CGPoint) {
        let d = hypot(point.x - plateCenter.x, point.y - plateCenter.y)
        if d < 110 {
            Sfx.pop()
            Sfx.bump(.light)
            pieces[i].placed = true
            withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
                pieces[i].position = pieces[i].slot
            }
            checkFinished()
        } else {
            Sfx.bump(.light)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                pieces[i].position = pieces[i].home
            }
        }
    }

    private func checkFinished() {
        let placedCount = pieces.filter { $0.placed }.count
        guard placedCount >= pieces.count, !finished else { return }
        finished = true
        Speaker.shared.say("It looks lovely!")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            onDone()
        }
    }
}

// MARK: - Station: garnish

struct ChefGarnishStation: View {
    let dish: ChefDish
    let onDone: () -> Void

    struct Fleck: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let spin: Double
        let delay: Double
    }

    @State private var flecks: [Fleck] = []
    @State private var shakes = 0
    @State private var tilt = false
    @State private var finished = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                ChefPlatedDish(dish: dish, garnished: false)
                    .frame(width: 210, height: 150)
                ForEach(flecks) { fleck in
                    ChefParsleyFleck(x: fleck.x, y: fleck.y, spin: fleck.spin, delay: fleck.delay)
                }
            }
            .frame(height: 160)

            Button {
                shake()
            } label: {
                ChefShaker()
                    .rotationEffect(.degrees(tilt ? -26 : -8))
                    .frame(width: 96, height: 96)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BouncyButtonStyle())

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < shakes ? Palette.green : Palette.field)
                        .frame(width: 14, height: 14)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func shake() {
        guard !finished else { return }
        ToneEngine.shared.playShake()
        Sfx.bump(.light)
        withAnimation(.spring(response: 0.16, dampingFraction: 0.4)) { tilt = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { tilt = false }
        }

        if flecks.count < 30 {
            let fresh = (0..<9).map { _ in
                Fleck(
                    x: .random(in: -62...62),
                    y: .random(in: -14...16),
                    spin: .random(in: -50...50),
                    delay: .random(in: 0...0.22)
                )
            }
            flecks.append(contentsOf: fresh)
        }

        shakes += 1
        guard shakes >= 3 else { return }
        finished = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            onDone()
        }
    }
}

// MARK: - Plated dishes

/// The finished dish, drawn differently for every recipe.
struct ChefPlatedDish: View {
    let dish: ChefDish
    var garnished: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                switch dish.plating {
                case .bowl: bowl(w: w, h: h)
                case .plate: flatPlate(w: w, h: h)
                case .cup: cup(w: w, h: h)
                case .stack: stack(w: w, h: h)
                case .pizza: pizza(w: w, h: h)
                case .pan: pan(w: w, h: h)
                }

                if garnished {
                    HStack(spacing: w * 0.05) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Palette.green)
                                .frame(width: w * 0.05, height: w * 0.035)
                                .rotationEffect(.degrees(Double(i) * 34 - 40))
                        }
                    }
                    .position(x: w / 2, y: h * 0.5)
                }
            }
        }
    }

    private func steam(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: w * 0.12) {
            ForEach(0..<3, id: \.self) { i in
                ChefSteamPuff(delay: Double(i) * 0.4)
            }
        }
        .position(x: w / 2, y: h * 0.18)
        .allowsHitTesting(false)
    }

    private func bowl(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            steam(w: w, h: h)
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(.white)
                .frame(width: w * 0.78, height: w * 0.78)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 3)
                .position(x: w / 2, y: h * 0.56)
            Ellipse()
                .fill(dish.color.opacity(0.75))
                .frame(width: w * 0.66, height: w * 0.17)
                .position(x: w / 2, y: h * 0.57)
            HStack(spacing: -w * 0.02) {
                ForEach(dish.ingredients) { item in
                    ChefChoppedIngredient(ingredient: item)
                        .frame(width: w * 0.15, height: w * 0.15)
                }
            }
            .position(x: w / 2, y: h * 0.55)
        }
    }

    private func flatPlate(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(.white)
                .frame(width: w * 0.86, height: w * 0.42)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 3)
                .position(x: w / 2, y: h * 0.58)
            Ellipse()
                .fill(dish.color.opacity(0.25))
                .frame(width: w * 0.62, height: w * 0.26)
                .position(x: w / 2, y: h * 0.58)
            HStack(spacing: -w * 0.02) {
                ForEach(Array(dish.ingredients.enumerated()), id: \.offset) { index, item in
                    ChefChoppedIngredient(ingredient: item, tilt: index.isMultiple(of: 2) ? -14 : 12)
                        .frame(width: w * 0.19, height: w * 0.19)
                        .rotationEffect(.degrees(Double(index) * 12 - 14))
                }
            }
            .position(x: w / 2, y: h * 0.54)
        }
    }

    private func cup(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // Straw
            Capsule()
                .fill(Palette.pink)
                .frame(width: w * 0.06, height: h * 0.5)
                .rotationEffect(.degrees(12))
                .position(x: w * 0.56, y: h * 0.32)
            ChefJarShape()
                .fill(.white.opacity(0.55))
                .frame(width: w * 0.4, height: h * 0.6)
                .position(x: w / 2, y: h * 0.56)
            ChefJarShape()
                .fill(dish.color.opacity(0.8))
                .frame(width: w * 0.34, height: h * 0.46)
                .position(x: w / 2, y: h * 0.62)
            ChefJarShape()
                .stroke(Palette.inkSoft.opacity(0.35), lineWidth: 4)
                .frame(width: w * 0.4, height: h * 0.6)
                .position(x: w / 2, y: h * 0.56)
        }
    }

    private func stack(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(.white)
                .frame(width: w * 0.8, height: w * 0.34)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 3)
                .position(x: w / 2, y: h * 0.7)
            ForEach(0..<3, id: \.self) { i in
                Ellipse()
                    .fill(Color(red: 0.90, green: 0.74, blue: 0.47))
                    .overlay(Ellipse().stroke(Palette.brown.opacity(0.45), lineWidth: 2.5))
                    .frame(width: w * 0.56 - CGFloat(i) * w * 0.03, height: w * 0.2)
                    .position(x: w / 2, y: h * 0.66 - CGFloat(i) * h * 0.1)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Palette.yellow)
                .frame(width: w * 0.14, height: w * 0.09)
                .position(x: w / 2, y: h * 0.42)
        }
    }

    private func pizza(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.90, green: 0.76, blue: 0.52))
                .frame(width: w * 0.68, height: w * 0.68)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 3)
            Circle()
                .fill(Palette.red.opacity(0.75))
                .frame(width: w * 0.56, height: w * 0.56)
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(i.isMultiple(of: 2) ? Palette.yellow : Color(red: 0.72, green: 0.45, blue: 0.35))
                    .frame(width: w * 0.09, height: w * 0.09)
                    .offset(
                        x: cos(CGFloat(i) / 6 * .pi * 2) * w * 0.17,
                        y: sin(CGFloat(i) / 6 * .pi * 2) * w * 0.17
                    )
            }
        }
        .position(x: w / 2, y: h * 0.52)
    }

    private func pan(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(Palette.brown)
                .frame(width: w * 0.34, height: w * 0.08)
                .offset(x: w * 0.36)
            Circle()
                .fill(Color(red: 0.30, green: 0.31, blue: 0.36))
                .frame(width: w * 0.62, height: w * 0.62)
            Circle()
                .fill(Color(red: 0.40, green: 0.41, blue: 0.46))
                .frame(width: w * 0.52, height: w * 0.52)
            Ellipse()
                .fill(Palette.yellow.opacity(0.9))
                .frame(width: w * 0.42, height: w * 0.3)
            HStack(spacing: -w * 0.01) {
                ForEach(dish.ingredients) { item in
                    ChefChoppedIngredient(ingredient: item)
                        .frame(width: w * 0.11, height: w * 0.11)
                }
            }
        }
        .position(x: w / 2, y: h * 0.54)
    }
}

// MARK: - Small kitchen parts

/// A circular progress ring used by the cooking stations.
struct ChefProgressRing: View {
    let progress: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 7)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.42, dampingFraction: 0.62), value: progress)
        }
        .scaleEffect(progress >= 1 ? 1.12 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.45), value: progress >= 1)
    }
}

/// The kitchen tap above the sink, with running water while scrubbing.
struct ChefFaucet: View {
    let running: Bool
    private let metal = Color(red: 0.62, green: 0.64, blue: 0.68)

    var body: some View {
        ZStack {
            Capsule()
                .fill(metal)
                .frame(width: 62, height: 15)
                .offset(x: -16, y: -26)
            Capsule()
                .fill(metal)
                .frame(width: 15, height: 28)
                .offset(x: 12, y: -16)
            if running {
                ChefWaterStream().offset(x: 12, y: 18)
            }
        }
        .frame(width: 96, height: 88)
        .allowsHitTesting(false)
    }
}

/// Water falling from the faucet.
struct ChefWaterStream: View {
    @State private var down = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Palette.blue.opacity(0.55))
                    .frame(width: 9, height: 24)
                    .offset(y: down ? 34 : -12)
                    .opacity(down ? 0 : 0.9)
                    .animation(
                        .easeIn(duration: 0.55)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.18),
                        value: down
                    )
            }
        }
        .onAppear { down = true }
    }
}

/// A soap bubble that drifts up and pops.
struct ChefWashBubble: View {
    let size: CGFloat
    @State private var up = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.75))
            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
            .frame(width: size, height: size)
            .scaleEffect(up ? 1.55 : 0.85)
            .offset(y: up ? -52 : 0)
            .opacity(up ? 0 : 0.9)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.85)) { up = true }
            }
    }
}

/// The blade of the chopping knife.
struct ChefBladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A friendly vector knife that follows the cutting swipe.
struct ChefKnife: View {
    var body: some View {
        ZStack {
            ChefBladeShape()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.86, green: 0.87, blue: 0.90),
                                 Color(red: 0.68, green: 0.70, blue: 0.74)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 84, height: 26)
                .offset(x: -14)
            Capsule()
                .fill(Palette.brown)
                .frame(width: 40, height: 16)
                .offset(x: 44)
        }
        .frame(width: 130, height: 34)
        .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
    }
}

/// A soup ladle resting in the pot when the dish is ready.
struct ChefLadle: View {
    private let metal = Color(red: 0.66, green: 0.68, blue: 0.73)

    var body: some View {
        ZStack {
            Capsule()
                .fill(metal)
                .frame(width: 13, height: 86)
                .rotationEffect(.degrees(16))
                .offset(y: -22)
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(metal)
                .frame(width: 44, height: 44)
                .offset(y: 24)
        }
        .frame(width: 60, height: 120)
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }
}

/// A little herb shaker to tap at the garnish station.
struct ChefShaker: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(red: 0.72, green: 0.74, blue: 0.78))
                    .frame(width: 34, height: 18)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Palette.ink.opacity(0.35))
                            .frame(width: 4, height: 4)
                    }
                }
                .offset(y: -3)
            }
            RoundedRectangle(cornerRadius: 12)
                .fill(Palette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Palette.field, lineWidth: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Palette.green.opacity(0.55))
                        .frame(width: 26, height: 26)
                        .offset(y: 8)
                )
                .frame(width: 44, height: 54)
        }
        .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
    }
}

/// One fleck of green herb falling onto the dish.
struct ChefParsleyFleck: View {
    let x: CGFloat
    let y: CGFloat
    let spin: Double
    let delay: Double

    @State private var fallen = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Palette.green)
            .frame(width: 7, height: 5)
            .rotationEffect(.degrees(fallen ? spin : 0))
            .offset(x: x, y: fallen ? y : y - 96)
            .opacity(fallen ? 1 : 0)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeIn(duration: 0.5).delay(delay)) { fallen = true }
            }
    }
}

/// One half of an ingredient, masked to the left or right side.
/// A piece of a chopped ingredient as it looks on the plate. Half of a small
/// icon came out as a sliver — broccoli was a green line — so a serving is a
/// whole little piece, tipped over as if it had been tossed into the dish.
struct ChefChoppedIngredient: View {
    let ingredient: ChefIngredient
    var tilt: Double = -12

    var body: some View {
        ChefIngredientView(ingredient: ingredient)
            .rotationEffect(.degrees(tilt))
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
    }
}

struct ChefHalfIngredient: View {
    let ingredient: ChefIngredient
    let leftSide: Bool

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ChefIngredientView(ingredient: ingredient)
                .frame(width: s, height: s)
                .mask(
                    Rectangle()
                        .frame(width: s / 2)
                        .frame(maxWidth: .infinity, alignment: leftSide ? .leading : .trailing)
                )
        }
    }
}

/// The dashed line across an ingredient showing where to cut, with a little
/// arrow at each end so it reads as "swipe across here".
struct ChefCutGuide: View {
    @State private var swing = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.06, y: h / 2))
                    path.addLine(to: CGPoint(x: w * 0.94, y: h / 2))
                }
                .stroke(
                    .white.opacity(0.95),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [9, 9])
                )
                .shadow(color: .black.opacity(0.25), radius: 2)

                HStack {
                    Image(systemName: "arrow.left")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 2)
                .frame(width: w * 0.98, height: h)
                .offset(x: swing ? 5 : -5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                swing = true
            }
        }
    }
}

/// A small bubble that rises and fades inside the soup.
struct ChefRisingBubble: View {
    let delay: Double
    let active: Bool
    @State private var up = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.55))
            .frame(width: 9, height: 9)
            .offset(y: up ? -20 : 4)
            .opacity(active ? (up ? 0 : 0.7) : 0)
            .onAppear { animate() }
            .onChange(of: active) { _ in animate() }
    }

    private func animate() {
        guard active else { return }
        up = false
        withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false).delay(delay)) {
            up = true
        }
    }
}

/// A wavy steam puff that drifts upward and fades.
struct ChefSteamPuff: View {
    let delay: Double
    @State private var up = false

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.55))
            .frame(width: 10, height: 28)
            .rotationEffect(.degrees(up ? 8 : -8))
            .offset(y: up ? -46 : 0)
            .opacity(up ? 0 : 0.7)
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false).delay(delay)) {
                    up = true
                }
            }
    }
}

/// A soft banana curve.
struct ChefCrescentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY + rect.height * 0.1)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.5)
        )
        p.closeSubpath()
        return p
    }
}

/// Vector-drawn food, no emoji.
struct ChefIngredientView: View {
    let ingredient: ChefIngredient

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let lw = max(0.9, min(w, h) * 0.05)
            switch ingredient {
            case .carrot:
                ZStack {
                    LimbShape(taper: 0.16)
                        .inked(Palette.orange, lw)
                        .frame(width: w * 0.42, height: h * 0.76)
                        .position(x: w / 2, y: h * 0.60)
                    HStack(spacing: 1) {
                        Capsule()
                        .inked(Palette.green, lw).frame(width: w * 0.08, height: h * 0.24)
                        Capsule()
                        .inked(Palette.green, lw).frame(width: w * 0.08, height: h * 0.3)
                        Capsule()
                        .inked(Palette.green, lw).frame(width: w * 0.08, height: h * 0.24)
                    }
                    .position(x: w / 2, y: h * 0.12)
                }
            case .tomato:
                ZStack {
                    Circle()
                        .inked(Palette.red, lw).frame(width: w * 0.8)
                        .position(x: w / 2, y: h * 0.56)
                    HStack(spacing: 1) {
                        Capsule()
                        .inked(Palette.green, lw).frame(width: w * 0.1, height: h * 0.18)
                            .rotationEffect(.degrees(-30))
                        Capsule()
                        .inked(Palette.green, lw).frame(width: w * 0.1, height: h * 0.2)
                        Capsule()
                        .inked(Palette.green, lw).frame(width: w * 0.1, height: h * 0.18)
                            .rotationEffect(.degrees(30))
                    }
                    .position(x: w / 2, y: h * 0.14)
                }
            case .egg:
                ZStack {
                    Ellipse()
                        .inked(.white, lw).frame(width: w * 0.8, height: h * 0.85)
                        .shadow(color: .black.opacity(0.1), radius: 2)
                    Circle()
                        .inked(Palette.yellow, lw).frame(width: w * 0.35)
                }
                .position(x: w / 2, y: h / 2)
            case .broccoli:
                ZStack {
                    Capsule()
                        .inked(Color(red: 0.65, green: 0.75, blue: 0.45), lw)
                        .frame(width: w * 0.2, height: h * 0.5)
                        .position(x: w / 2, y: h * 0.7)
                    ZStack {
                        Circle()
                        .inked(Palette.green, lw).frame(width: w * 0.42).offset(x: -w * 0.18)
                        Circle()
                        .inked(Palette.green, lw).frame(width: w * 0.5).offset(y: -h * 0.08)
                        Circle()
                        .inked(Palette.green, lw).frame(width: w * 0.42).offset(x: w * 0.18)
                    }
                    .position(x: w / 2, y: h * 0.34)
                }
            case .corn:
                ZStack {
                    Capsule()
                        .inked(Palette.yellow, lw).frame(width: w * 0.42, height: h * 0.85)
                    Capsule()
                        .inked(Palette.green, lw).frame(width: w * 0.16, height: h * 0.55)
                        .rotationEffect(.degrees(24))
                        .offset(x: w * 0.22, y: h * 0.14)
                }
                .position(x: w / 2, y: h / 2)
            case .mushroom:
                ZStack {
                    Capsule()
                        .inked(Color(red: 0.93, green: 0.89, blue: 0.82), lw)
                        .frame(width: w * 0.3, height: h * 0.5)
                        .position(x: w / 2, y: h * 0.68)
                    Circle()
                        .trim(from: 0.5, to: 1.0)
                        .fill(Color(red: 0.72, green: 0.45, blue: 0.35))
                        .frame(width: w * 0.85)
                        .position(x: w / 2, y: h * 0.62)
                }
            case .potato:
                ZStack {
                    Ellipse()
                        .inked(Color(red: 0.82, green: 0.68, blue: 0.47), lw)
                        .frame(width: w * 0.82, height: h * 0.62)
                    Ellipse()
                        .inked(Color(red: 0.68, green: 0.54, blue: 0.36), lw)
                        .frame(width: w * 0.1, height: h * 0.07)
                        .offset(x: -w * 0.14, y: -h * 0.06)
                    Ellipse()
                        .inked(Color(red: 0.68, green: 0.54, blue: 0.36), lw)
                        .frame(width: w * 0.08, height: h * 0.06)
                        .offset(x: w * 0.12, y: h * 0.08)
                }
                .position(x: w / 2, y: h / 2)
            case .cheese:
                ZStack {
                    Triangle()
                        .inked(Palette.yellow, lw)
                        .frame(width: w * 0.8, height: h * 0.62)
                    Circle()
                        .inked(Palette.yellow.opacity(0.55), lw)
                        .frame(width: w * 0.12)
                        .offset(x: -w * 0.12, y: h * 0.12)
                    Circle()
                        .inked(Palette.yellow.opacity(0.55), lw)
                        .frame(width: w * 0.1)
                        .offset(x: w * 0.13, y: h * 0.16)
                }
                .position(x: w / 2, y: h / 2)
            case .banana:
                ZStack {
                    ChefCrescentShape()
                        .inked(Palette.yellow, lw)
                        .frame(width: w * 0.68, height: h * 0.66)
                        .rotationEffect(.degrees(-20))
                    Capsule()
                        .inked(Palette.brown, lw)
                        .frame(width: w * 0.08, height: h * 0.12)
                        .offset(x: -w * 0.24, y: -h * 0.24)
                }
                .position(x: w / 2, y: h / 2)
            case .berry:
                ZStack {
                    Circle()
                        .inked(Palette.purple, lw).frame(width: w * 0.42)
                        .offset(x: -w * 0.14, y: h * 0.06)
                    Circle()
                        .inked(Palette.purple.opacity(0.9), lw).frame(width: w * 0.42)
                        .offset(x: w * 0.14, y: h * 0.06)
                    Circle()
                        .inked(Palette.purple.opacity(0.85), lw).frame(width: w * 0.38)
                        .offset(y: -h * 0.12)
                    Capsule()
                        .inked(Palette.green, lw)
                        .frame(width: w * 0.22, height: h * 0.1)
                        .rotationEffect(.degrees(-24))
                        .offset(x: w * 0.14, y: -h * 0.3)
                }
                .position(x: w / 2, y: h / 2)
            case .milk:
                ZStack {
                    RoundedRectangle(cornerRadius: w * 0.12)
                        .inked(.white, lw)
                        .overlay(
                            RoundedRectangle(cornerRadius: w * 0.12)
                                .stroke(Palette.field, lineWidth: 2.5)
                        )
                        .frame(width: w * 0.5, height: h * 0.7)
                    RoundedRectangle(cornerRadius: w * 0.04)
                        .inked(Palette.blue.opacity(0.8), lw)
                        .frame(width: w * 0.5, height: h * 0.16)
                        .offset(y: h * 0.14)
                    Capsule()
                        .inked(Palette.blue, lw)
                        .frame(width: w * 0.18, height: h * 0.12)
                        .offset(y: -h * 0.4)
                }
                .position(x: w / 2, y: h / 2)
            }
        }
    }
}
