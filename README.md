# My First Phone

A toddler phone with a clean, calm design — warm paper background, white cards, muted accents, SF Symbol icons (no emoji in the UI). Phone and Messages reach **real family contacts** that a parent adds behind the PIN gate; everything else is make-believe and on-device.

## Family Connect — in-app chat and live calls between your phones

A guided setup wizard runs on first launch: whose phone this is → names → **create or join a family code** → (kid phones) set a custom grown-ups PIN. Once both phones share a code:

- **In-app chat**: the kid phone gets **My Family** in Messages (stickers, phrases, hold-to-talk voice messages, a ring bell that makes the parent's app ring); the parent gets Family Chat with a keyboard and voice notes.
- **Live calls** (WhatsApp-style): "Live Call My Family" starts a real-time call between the phones over the internet — peer-to-peer WebRTC with **mute**, **speaker on/off**, and a **camera toggle for live video** (front camera, with a picture-in-picture preview). Accept/decline screen on the other end. Signaling rides on the family's iCloud; media flows phone-to-phone via free public STUN/TURN. No third-party accounts.
- **Push notifications**: once a family code is joined, the app registers CloudKit subscriptions so "New message from your family" and "Your family is calling!" banners arrive even when the app is closed (requires the device to have granted notification permission).
- **CallKit**: incoming family calls also ring through iOS's native call UI — full-screen answer/decline like a regular phone call, including from the lock screen while the app is running.
- **Read receipts**: your latest message in family chat shows a green "Seen" once the other phone has read it.
- **Quiet hours**: in the grown-ups area on the kid phone, set a bedtime window — the kid phone shows a starry "Shhh… bedtime!" screen instead of the apps, unlockable for the night with the grown-ups code.
- **Doodles to family**: the kid's Doodle app gets a send button — the drawing is rendered to an image and appears in the family chat.
- **Kid-phone status**: the parent dashboard shows the kid phone's battery level and when it was last active (updated every few minutes while the kid app is open).
- **Sleepy sounds**: the Sounds app has looping Fan / Waves / Heartbeat sounds (synthesized on-device) for naps and bedtime.

### Making the connection actually work (checklist)

Family Connect runs on Apple's iCloud (CloudKit). If messages or calls don't go through, use **Test the connection** (parent dashboard, or grown-ups area → Family Connect) — it diagnoses the exact problem. The full setup:

1. **Apple Developer membership** ($99/yr) — iCloud features require it for device installs.
2. In Xcode: select the ToddlerPhone **target → Signing & Capabilities → Team** → pick your team. The entitlements file is already in the project; Xcode will register the container `iCloud.com.family.ToddlerPhone` automatically.
3. Install on both phones (both signed into **iCloud** in Settings).
4. Send one message from each phone — this auto-creates the CloudKit record types in the *development* environment.
5. **Indexes (the usual gotcha)**: if sending works but nothing arrives, go to [icloud.developer.apple.com](https://icloud.developer.apple.com) → your container → Development → **Indexes**, and add a **Queryable** index on the `code` field for each record type (FamilyMessage, CallSignal, FamilyStatus, FamilyReceipt, FamilyVideo, FamilyPing). The in-app test tells you if this is the problem.
6. Run **Test the connection** on BOTH phones until both show ✅.
7. Before sharing the app beyond your own devices, deploy the schema to Production in the CloudKit Console.

**Limits to know**: messages/calls arrive when the app is open or when a notification wakes it; ringing a fully force-quit app isn't possible without VoIP server infrastructure. Live calls need both phones online; very strict networks can occasionally block peer-to-peer media.

## Setup: kid phone vs. grown-up phone

On first launch the app asks **"Whose phone is this?"** Kid mode is the toddler phone below. Grown-up mode turns the app into a family dashboard with one-tap Call / FaceTime / Text buttons for the same family list — install the app on both phones and add each other. The mode can be changed later in the grown-ups area (PIN-protected on the kid phone).

## What's inside (kid mode)

- **Home screen** — a simple launcher with a greeting, the time, and seven app tiles.
- **Phone** — everything stays in-app: **Live Call My Family** (real-time WebRTC call to the parent's app), the walkie-talkie/ring card, pretend friends (Puppy, Kitty) with real animal sounds, and a dial pad whose call button only ever reaches a pretend friend. There is **no connection to the real phone, SMS, or FaceTime anywhere in kid mode**.
- **Messages** — **My Family** in-app chat: the child can **type messages with the keyboard**, tap stickers and phrases, hold-to-talk voice notes, and ring the parent's app. Read receipts show "Seen". Pretend friends keep the play chat with canned replies.
- **Camera** — a kid camera with a big shutter and flip button. Photos save only to the app's own private folder (never the system photo library); a gallery lets him review, delete, and **send photos to the family chat**.
- **Books** — five classic picture books where **every page has real illustration**: *The Three Little Pigs*, *Goldilocks and the Three Bears*, *The Golden Goose*, *Tom Thumb* (L. Leslie Brooke, 1904 to 1905) and *The Tale of Peter Rabbit* (Beatrix Potter, 1902), all public domain via Project Gutenberg. Pages turn themselves with a paper-fold animation as the narration finishes, with a pause button and manual arrows.
- **Games** — nine, grouped into Play, Learn and Calm shelves:
  - **Ball Run** — an arcade runner with 8 themed levels (meadow through space), 3 hearts, power-ups (magnet, shield, slow motion, star burst), six obstacle types and collectible ducklings. Running out of hearts just offers another go.
  - **Little Chef** — a little restaurant: customers order one of 8 dishes with picture menus, then you wash, chop, stir, flip, blend, plate and garnish it. New dishes unlock as you serve.
  - **Dress Up** — a studio with child, bear and bunny characters, six skin tones, full wardrobe including hijab, scarf, beanie and party hat, four expressions, six backdrops, saved outfits and a dress-for-the-weather game.
  - **Music** — xylophone, drums, piano and bells with real synthesized notes, a song mode that lights the next key for four nursery songs, and a record-and-replay toy.
  - **Puzzle** — jigsaws cut from the animal photos at 4, 6 or 9 pieces, with the animal's real sound on completion.
  - **Bubbles** — a calm sensory toy with a bubble wand, rainbow bubbles and hidden animal bubbles. No score, no timer.
  - **Balloon Pop** — six waves with rainbow, giant, tiny and bonus-cloud balloons.
  - **Shape Find** — shapes, colors and counting modes that grow harder as stars are earned.
  - **Memory** — three sizes, symbol or real-animal-photo cards, and gentle personal bests.
- **Coloring** — six real coloring-book pages (cat, fire truck, dinosaur, rocket, fish tank, flower garden) with 20 to 30 fillable regions each, hand-drawn as vector line art, plus 12 crayons, a rainbow surprise, undo and a celebration when a page is finished.

### Narration voice

The app automatically uses the best English voice installed on the phone. iOS ships with a robotic compact voice, so for natural narration open Settings, then Accessibility, then Spoken Content, then Voices, then English, and download a voice marked **Premium** (Zoe or Ava sound best). The grown-ups area shows which voice is currently in use.
- **Light** — a kid flashlight: the real torch LED plus a glowing colored screen.
- **Sounds** — all real recordings now: dog, cat, bird, cow, duck, horse, sheep, a car horn and a steam train whistle, each showing a real photo of the animal when pressed. Sleepy sounds (fan, waves, heartbeat) keep playing for naps. Audio and photos are public-domain or Creative Commons from Wikimedia Commons and the Internet Archive.
- **TV** — three built-in animated channels (Fish Tank, Dance Party, Starry Night), a **Cartoons** row streaming freely licensed films from the Internet Archive — public-domain classics (Steamboat Willie, ComiColor fairy tales, Casper) and modern Blender Foundation open movies (Big Buck Bunny, the Caminandes llama trilogy, CC-BY) — plus **My Shows** for parent-added videos. The player has play/pause, ±10-second skip, and a scrubber, and loops at the end. Streaming is the app's only internet feature and can be turned off in the grown-ups area.
- **Doodle** and **Sounds** — finger painting and a soundboard; the dog and cat use real recorded animal sounds (public-domain recordings), as do Puppy and Kitty on calls.

## Family setup (real calls & texts)

In the grown-ups area (behind the PIN), use **Add from Contacts** — the system contact picker shares only the specific number you tap, no Contacts permission needed. Added family appear in Phone and Messages with colored initial avatars; swipe to remove. Note: while Guided Access is locked, iOS blocks switching to the Phone app, so real calls only connect when not locked.

## Locking (important!)

Two layers:

1. **In-app code** — the grown-ups area (settings, video import, code change) is behind a **4-digit code pad**. The starter code is **1234**; change it inside on first use.
2. **Device lock — Guided Access** — iOS does not allow any regular app to block the home swipe itself; Apple's sanctioned mechanism is Guided Access, which locks the whole device into one app behind your passcode:
   - Settings → Accessibility → Guided Access → on, set a passcode.
   - Open My First Phone, triple-click the side button, tap Start.
   - Triple-click + passcode to exit.

   The grown-ups area shows a live **Locked / Not locked** status so you can confirm Guided Access is on before handing the phone over.

## Adding shows to the TV app

In the grown-ups area, use **Add from Photos** or **Add from Files** (.mp4/.mov). Videos are copied into the app and stay on-device. Streaming-app episodes (Netflix, Disney+, etc.) are DRM-protected and can't be exported — home videos, screen recordings, and DRM-free downloads work.

## Running it

Open `ToddlerPhone.xcodeproj` in Xcode, pick a simulator or your iPhone, and press Run (set your team under Signing & Capabilities for a real device).

## Customizing

- Contacts, greetings, call phrases, and replies: `Contact.all` in `ToddlerPhone/Models.swift`.
- Storybooks: `StoryBook.all` in `ToddlerPhone/BooksView.swift`.
- Colors/design system: `Palette` in `ToddlerPhone/Theme.swift`.
