import SwiftUI
import Observation

enum AppScreen: Equatable {
    case home, phone, messages, camera, books, games, tv, doodle, coloring, sounds, flashlight
}

/// Whose phone this is — chosen on first launch, changeable behind the PIN.
enum PhoneRole: String {
    case kid, parent
}

// MARK: - Pretend friends (play-only; answer with speech and canned replies)

struct Contact: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let color: Color
    let greeting: String
    let phrases: [String]
    let replies: [String]
    /// Bundled recording played instead of synthesized speech (real animal sounds).
    var sound: String?

    func speak() {
        if let sound {
            SoundFile.shared.play(sound)
        } else {
            Speaker.shared.say(phrases.randomElement() ?? greeting)
        }
    }

    func speakGreeting() {
        if let sound {
            SoundFile.shared.play(sound)
        } else {
            Speaker.shared.say(greeting)
        }
    }
}

extension Contact {
    static let all: [Contact] = [
        Contact(
            id: "puppy", name: "Puppy", symbol: "dog.fill", color: Palette.orange,
            greeting: "Woof woof!",
            phrases: ["Woof woof!"],
            replies: ["Woof!", "Arf arf!", "Woof woof woof!"],
            sound: "dog"
        ),
        Contact(
            id: "kitty", name: "Kitty", symbol: "cat.fill", color: Palette.purple,
            greeting: "Meow!",
            phrases: ["Meow meow!"],
            replies: ["Meow!", "Purrrr!", "Meow meow!"],
            sound: "cat"
        ),
    ]

    /// Who answers when the toddler dials a "number" on the dial pad.
    static var mysteryFriends: [Contact] { all }
}

// MARK: - Stickers (what the child can send; symbols in the UI, text in the message)

struct Sticker: Identifiable {
    let symbol: String
    let text: String
    let color: Color
    var id: String { symbol }

    static let all: [Sticker] = [
        Sticker(symbol: "heart.fill", text: "❤️", color: Palette.pink),
        Sticker(symbol: "star.fill", text: "⭐️", color: Palette.yellow),
        Sticker(symbol: "hand.thumbsup.fill", text: "👍", color: Palette.blue),
        Sticker(symbol: "face.smiling", text: "😄", color: Palette.orange),
        Sticker(symbol: "car.fill", text: "🚗", color: Palette.red),
        Sticker(symbol: "balloon.fill", text: "🎈", color: Palette.purple),
        Sticker(symbol: "sun.max.fill", text: "☀️", color: Palette.yellow),
        Sticker(symbol: "moon.stars.fill", text: "🌙", color: Palette.indigo),
        Sticker(symbol: "gift.fill", text: "🎁", color: Palette.green),
        Sticker(symbol: "pawprint.fill", text: "🐾", color: Palette.brown),
    ]

    static let phrases = ["Hi!", "I love you!", "Miss you!", "Yay!"]
}

// MARK: - App model

struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isFromChild: Bool
}

@Observable
final class AppModel {
    var screen: AppScreen = .home
    var chats: [String: [Message]] = [:]
    var role: PhoneRole? = UserDefaults.standard.string(forKey: "phoneRole").flatMap(PhoneRole.init) {
        didSet { UserDefaults.standard.set(role?.rawValue, forKey: "phoneRole") }
    }
    /// Parent temporarily browsing the kid apps from grown-up mode (not persisted).
    var kidPreview = false

    init() {
        seedChats()
        #if DEBUG
        // Lets `simctl launch ... -screen phone` jump straight to a screen for testing.
        switch UserDefaults.standard.string(forKey: "screen") {
        case "phone": screen = .phone
        case "messages": screen = .messages
        case "books": screen = .books
        case "games": screen = .games
        case "tv": screen = .tv
        case "doodle": screen = .doodle
        case "coloring": screen = .coloring
        case "camera": screen = .camera
        case "flashlight": screen = .flashlight
        case "sounds": screen = .sounds
        default: break
        }
        #endif
    }

    func messages(for contact: Contact) -> [Message] {
        chats[contact.id] ?? []
    }

    func send(_ text: String, to contact: Contact) {
        chats[contact.id, default: []].append(Message(text: text, isFromChild: true))
        Sfx.sent()
        Sfx.bump(.light)

        let reply = contact.replies.randomElement() ?? "Hi!"
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Double.random(in: 1.2...2.4)))
            chats[contact.id, default: []].append(Message(text: reply, isFromChild: false))
            Sfx.received()
        }
    }

    func resetChats() {
        seedChats()
    }

    private func seedChats() {
        chats = [:]
        for contact in Contact.all {
            chats[contact.id] = [Message(text: contact.greeting, isFromChild: false)]
        }
    }

    // MARK: Quiet hours (bedtime lock on the kid phone)

    var quietEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "quietEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "quietEnabled") }
    }

    /// Minutes from midnight; defaults 7:30 pm – 7:00 am.
    var quietStart: Int {
        get { UserDefaults.standard.object(forKey: "quietStart") as? Int ?? 19 * 60 + 30 }
        set { UserDefaults.standard.set(newValue, forKey: "quietStart") }
    }

    var quietEnd: Int {
        get { UserDefaults.standard.object(forKey: "quietEnd") as? Int ?? 7 * 60 }
        set { UserDefaults.standard.set(newValue, forKey: "quietEnd") }
    }

    var quietOverrideUntil: Date? {
        get { UserDefaults.standard.object(forKey: "quietOverrideUntil") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "quietOverrideUntil") }
    }

    func isQuietNow(_ date: Date = .now) -> Bool {
        guard quietEnabled else { return false }
        if let override = quietOverrideUntil, date < override { return false }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if quietStart <= quietEnd {
            return minutes >= quietStart && minutes < quietEnd
        } else {
            return minutes >= quietStart || minutes < quietEnd
        }
    }

    /// Parent unlock: skip the rest of the current quiet window.
    func overrideQuietHours(from date: Date = .now) {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        var end = calendar.startOfDay(for: date).addingTimeInterval(TimeInterval(quietEnd * 60))
        if quietStart > quietEnd, minutes >= quietStart {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        quietOverrideUntil = end
    }

    /// 4-digit code protecting the grown-ups area. Changeable by the parent.
    var parentCode: String {
        get { UserDefaults.standard.string(forKey: "parentCode") ?? Self.defaultParentCode }
        set { UserDefaults.standard.set(newValue, forKey: "parentCode") }
    }

    var parentCodeIsDefault: Bool { parentCode == Self.defaultParentCode }

    static let defaultParentCode = "1234"
}
