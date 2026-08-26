import SwiftUI

struct StoryBook: Identifiable {
    let id: String
    let title: String
    let color: Color
    let pages: [Page]

    /// Every page carries a real illustration, so the art is not optional.
    struct Page {
        let text: String
        let image: String

        init(_ image: String, _ text: String) {
            self.image = image
            self.text = text
        }
    }
}

// Classic tales in the public domain, retold for toddlers.
extension StoryBook {
    static let all: [StoryBook] = [
        // Illustrations: L. Leslie Brooke, 1904 (public domain, via Project Gutenberg #18155).
        StoryBook(
            id: "pigs", title: "The Three Little Pigs", color: Palette.pink,
            pages: [
                Page("pigs-1", "Once upon a time, a mother pig sent her three little pigs out into the world to build their very own houses."),
                Page("pigs-2", "The first pig built a house of straw. Along came the wolf! \"I'll huff and I'll puff and I'll blow your house in!\" And he did! The little pig ran to his brother."),
                Page("pigs-3", "His brother built a house of strong red bricks. The wolf huffed and he puffed… but the brick house would not fall!"),
                Page("pigs-4", "The wolf tried a trick. \"Let's get turnips tomorrow!\" But the clever little pig went early and got his turnips first."),
                Page("pigs-5", "When the wolf peeked in the window, the little pig was already home, cooking his turnips. \"Too slow, Mister Wolf!\""),
                Page("pigs-6", "\"Let's pick apples!\" said the wolf. The pig climbed the tree early and tossed an apple far away. While the wolf chased it, the pig hopped down!"),
                Page("pigs-7", "Next day the pig bought a butter churn at the fair. On the way home he hid inside and rolled right past the wolf. It gave the wolf such a surprise that he ran away and never came back. The end."),
            ]
        ),
        // Illustrations: L. Leslie Brooke, 1905 (public domain, via Project Gutenberg #17034).
        StoryBook(
            id: "goldilocks", title: "Goldilocks and the Three Bears", color: Palette.brown,
            pages: [
                Page("bears-g0030", "Three bears lived in a snug little house beside the wood. Papa Bear dug in the garden while Baby Bear helped him."),
                Page("bears-g0033", "One morning they made porridge for breakfast. It was far too hot to eat, so the bears went out for a walk while it cooled."),
                Page("bears-g0036", "Along came a girl called Goldilocks. She peeked inside and tasted the porridge. Baby Bear's bowl was just right, so she ate it all up."),
                Page("bears-g0039", "Then Goldilocks felt sleepy. Baby Bear's little bed was soft and warm, so she snuggled down and fell fast asleep."),
                Page("bears-g0040", "Home came the bears. \"Somebody has been eating my porridge,\" said Papa Bear in his big rumbly voice."),
                Page("bears-g0043", "\"Somebody has been sitting in my chair,\" said Baby Bear. His little cushion was all squashed flat."),
                Page("bears-g0046", "Upstairs they tiptoed to the little bed. \"Somebody is sleeping here!\" cried Baby Bear. Goldilocks woke up with a jump."),
                Page("bears-g0049", "Out of the window she hopped and away she ran home. The bears waved goodbye and sat down to their breakfast at last. The end."),
            ]
        ),
        // Illustrations: L. Leslie Brooke, 1905 (public domain, via Project Gutenberg #17034).
        StoryBook(
            id: "goose", title: "The Golden Goose", color: Palette.yellow,
            pages: [
                Page("goose-g0006", "A woodcutter's big son went off to the wood with his axe. A little grey man asked him for a bite to eat, but the big son said no and walked away."),
                Page("goose-g0009", "Then the youngest son came along. He shared his little cake and his drink, and the little grey man smiled a very kind smile."),
                Page("goose-g0012", "\"Look inside that old tree,\" said the little grey man. And there sat a goose with feathers of shining gold!"),
                Page("goose-g0015", "The young man carried the goose to the inn. Three sisters touched a golden feather and oh! Their hands stuck fast."),
                Page("goose-g0016", "A parson saw the funny line hurrying by. He caught hold to help them and away he went too, trotting along behind."),
                Page("goose-g0019", "The whole wobbly line went past the palace. The princess who had never laughed saw them and laughed and laughed."),
                Page("goose-g0022", "The king set some funny tasks. A very thirsty friend drank a whole cellar of drink. Glug, glug, glug!"),
                Page("goose-g0025", "A very hungry friend ate a mountain of bread. So the young man married the laughing princess and they were happy ever after. The end."),
            ]
        ),
        // Illustrations: L. Leslie Brooke, 1904 (public domain, via Project Gutenberg #17034).
        StoryBook(
            id: "thumb", title: "Tom Thumb", color: Palette.green,
            pages: [
                Page("thumb-g0078", "A kind ploughman wished for a child, even a tiny one no bigger than his thumb. So he went to a wise old man and asked very politely."),
                Page("thumb-g0081", "The Fairy Queen heard the wish. She came with all her fairies and granted it. Soon a tiny boy called Tom Thumb came along."),
                Page("thumb-g0084", "Tom loved to help his mother cook. One day he tumbled into the pudding, and the pudding hopped and bobbed all round the pot."),
                Page("thumb-g0087", "Out in the meadow Tom sat on a thistle. A big red cow came for a nibble and scooped him up with the grass."),
                Page("thumb-g0088", "Tom called out in his tiny voice. The cow was so surprised that she gave a hop, and out popped Tom, safe and sound."),
                Page("thumb-g0091", "Then a puff of wind sent Tom whirling over the trees and splash into the sea. A big silver fish caught him and carried him along."),
                Page("thumb-g0094", "The fish went straight to the king. Out stepped Tom, and the queen held him gently in her hand. The whole court cheered for the tiniest boy in the land."),
                Page("thumb-g0097", "Tom rode home again on the back of a butterfly. Everyone ran along waving as he sailed above the fields. The end."),
            ]
        ),
        // Illustrations: Beatrix Potter, 1902 (public domain, via Project Gutenberg #14838).
        StoryBook(
            id: "peter", title: "The Tale of Peter Rabbit", color: Palette.blue,
            pages: [
                Page("peter-08", "Once upon a time there were four little rabbits: Flopsy, Mopsy, Cotton-tail and Peter. They lived with their mother under the root of a very big fir tree."),
                Page("peter-11", "\"You may play in the fields,\" said their mother, \"but don't go into Mr. McGregor's garden!\""),
                Page("peter-19", "But naughty Peter ran straight to the garden and squeezed under the gate!"),
                Page("peter-23", "Peter ate radishes and beans and then went looking for parsley. But who did he meet? Mr. McGregor! \"Stop, rabbit!\""),
                Page("peter-31", "Oh no! Peter got tangled in the gooseberry net. He wiggled and wiggled until he was free."),
                Page("peter-40", "Peter jumped out a window. CRASH went the flowerpots! And he ran and ran."),
                Page("peter-44", "Peter felt lost. \"Which way is home?\" he sniffed. Even the little mouse couldn't tell him."),
                Page("peter-51", "At last, Peter found the gate! He squeezed underneath and ran all the way home to his soft bed. Safe at last! The end."),
            ]
        ),
    ]
}

struct BooksView: View {
    @State private var openBook: StoryBook?

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 8) {
                TopBar(title: "Books")

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(StoryBook.all) { book in
                            Button {
                                Sfx.tap()
                                Sfx.bump(.light)
                                openBook = book
                            } label: {
                                BookCover(book: book)
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .fullScreenCover(item: $openBook) { book in
            BookReaderView(book: book)
        }
        #if DEBUG
        .onAppear {
            if let id = UserDefaults.standard.string(forKey: "book") {
                openBook = StoryBook.all.first { $0.id == id }
            }
        }
        #endif
    }
}

/// A cover styled like a classic hardback: solid color, thin frame, serif title.
struct BookCover: View {
    let book: StoryBook

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(.black.opacity(0.18))
                .frame(width: 10)

            VStack(spacing: 14) {
                Rectangle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 34, height: 2)
                Text(book.title)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 12)
                Rectangle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 34, height: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.35), lineWidth: 1.5)
                    .padding(10)
            )
        }
        .frame(height: 180)
        .background(book.color)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 5)
    }
}

/// Folds a page around its leading edge so a turn reads like real paper.
private struct PageFoldEffect: ViewModifier, Animatable, Equatable {
    var angle: Double
    var fade: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(angle, fade) }
        set {
            angle = newValue.first
            fade = newValue.second
        }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.55
            )
            .opacity(fade)
    }
}

private extension AnyTransition {
    /// New page swings in from the left, old page folds away to the right.
    static var pageTurn: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: PageFoldEffect(angle: 78, fade: 0),
                identity: PageFoldEffect(angle: 0, fade: 1)
            ),
            removal: .modifier(
                active: PageFoldEffect(angle: -62, fade: 0),
                identity: PageFoldEffect(angle: 0, fade: 1)
            )
        )
    }
}

struct BookReaderView: View {
    let book: StoryBook
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    @State private var autoTurn = true
    @State private var turnTask: Task<Void, Never>?

    private var isLastPage: Bool { page == book.pages.count - 1 }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    CloseButton { closeBook() }
                    Spacer()
                    roundButton(icon: autoTurn ? "pause.fill" : "play.fill", tint: book.color) {
                        autoTurn.toggle()
                        if autoTurn { scheduleAutoTurn() } else { turnTask?.cancel() }
                    }
                    roundButton(icon: "speaker.wave.2.fill", tint: book.color) {
                        readPage()
                        scheduleAutoTurn()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // The page, styled like paper.
                VStack(spacing: 0) {
                    Text(book.title.uppercased())
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .kerning(1.5)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 26)

                    Rectangle()
                        .fill(book.color.opacity(0.5))
                        .frame(width: 44, height: 2)
                        .padding(.top, 18)

                    ZStack {
                        pageContent(for: page)
                            .id(page)
                            .transition(.pageTurn)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .card(cornerRadius: 30)
                .padding(.horizontal, 20)

                if isLastPage {
                    HStack(spacing: 14) {
                        Text("The end!")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundStyle(book.color)

                        Button {
                            Sfx.tap()
                            autoTurn = true
                            turnPage(to: 0)
                        } label: {
                            Text("Read again")
                                .font(.rounded(16, weight: .bold))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 20)
                                .frame(height: 46)
                                .card(cornerRadius: 18)
                        }
                        .buttonStyle(BouncyButtonStyle())
                    }
                    .transition(.opacity)
                }

                HStack(spacing: 20) {
                    pageButton(icon: "chevron.left") {
                        if page > 0 { turnPage(to: page - 1) }
                    }
                    .opacity(page == 0 ? 0.35 : 1)

                    Text("Page \(page + 1) of \(book.pages.count)")
                        .font(.rounded(14, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity)

                    pageButton(icon: isLastPage ? "arrow.counterclockwise" : "chevron.right") {
                        turnPage(to: isLastPage ? 0 : page + 1)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            readPage()
            scheduleAutoTurn()
        }
        .onDisappear {
            turnTask?.cancel()
            turnTask = nil
            Speaker.shared.stop()
        }
    }

    @ViewBuilder
    private func pageContent(for index: Int) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            if let artwork = UIImage(named: "\(book.pages[index].image).jpg")
                ?? UIImage(named: book.pages[index].image) {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(book.color.opacity(0.25), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 16)

            Text(book.pages[index].text)
                .font(.system(size: 19, weight: .medium, design: .serif))
                .foregroundStyle(Palette.ink)
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            Spacer(minLength: 22)
        }
    }

    private func closeBook() {
        turnTask?.cancel()
        turnTask = nil
        Speaker.shared.stop()
        dismiss()
    }

    private func turnPage(to newPage: Int) {
        withAnimation(.easeInOut(duration: 0.55)) { page = newPage }
        read(newPage)
        scheduleAutoTurn(after: newPage)
    }

    private func readPage() {
        read(page)
    }

    private func read(_ index: Int) {
        Sfx.bump(.light)
        Speaker.shared.say(book.pages[index].text, pitch: 1.05)
    }

    private func scheduleAutoTurn() {
        scheduleAutoTurn(after: page)
    }

    /// Speaker has no finished callback, so the narration length is estimated
    /// from the word count, then a calm beat is added before the page turns.
    private func scheduleAutoTurn(after index: Int) {
        turnTask?.cancel()
        turnTask = nil
        guard autoTurn, index < book.pages.count - 1 else { return }

        let words = book.pages[index].text.split { $0 == " " || $0 == "\n" }.count
        let spoken = Double(words) * 0.36 + 0.8
        let delay = spoken + 1.2
        let next = index + 1

        turnTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            turnPage(to: next)
        }
    }

    private func roundButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Sfx.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .card(cornerRadius: 18)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private func pageButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Sfx.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 64, height: 64)
                .card(cornerRadius: 22)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}
