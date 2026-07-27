# Foursome — native iOS starter

A real SwiftUI app you can run on your phone this week. It's local-first, so it runs entirely on-device with no backend yet. The full core loop works: log rounds, see a feed, post open rounds, request and approve joiners, and a leaderboard. It's seeded with a demo clubhouse (Marcus, Tyler, Deshawn, Ryan) so it feels alive the moment it launches.

## What you need

- A Mac with Xcode 15 or newer
- Deployment target iOS 17 or newer (SwiftData requires it)
- About 30 minutes

## Setup

1. Open Xcode, File > New > Project > iOS > App.
2. Name it `Foursome`, Interface `SwiftUI`, Language `Swift`, Storage `None`.
3. Xcode generates `FoursomeApp.swift` and `ContentView.swift`. Delete `ContentView.swift`, and delete the generated `FoursomeApp.swift` too (you're replacing it with the one in this folder).
4. Drag all eight `.swift` files from the `Foursome/` folder in this repo into the project navigator. Check "Copy items if needed" and add them to the Foursome target.
5. Select the project > target > General, set Minimum Deployments to iOS 17.0.
6. Pick a simulator (iPhone 15 works) or your own device, and hit Run.

You should land on the onboarding screen. Enter your name, or type `Marcus` to log in as a seeded player and see a populated feed and leaderboard.

## Files

All sources live in `Foursome/`.

- `FoursomeApp.swift` — app entry, registers the SwiftData store
- `Models.swift` — Player, Round, OpenRound, and the course list
- `Theme.swift` — colors, the birdie-circle / bogey-square score badge, shared components
- `RootView.swift` — onboarding, seeding, tab shell, invite sheet
- `FeedView.swift` — the rounds feed
- `LogRoundView.swift` — log a score
- `OpenRoundsView.swift` — browse, post, request, approve
- `LeaderboardView.swift` — ranking and clubhouse roster

## What's real vs faked

Everything you tap is real and persists on-device via SwiftData. The one thing that's simulated is other people: the seeded friends and their rounds are demo data, so "friends see each other's rounds" isn't truly multiplayer yet. That's the next milestone.

Not modeled yet, from the intended product: an explicit friend graph (add/accept friends), groups, and invite visibility scoping (public to an area / friends-of-friends / friends only / specific people). Today every player sees every round and every open round. `OpenRound` has no audience field, and there is no `Friendship` or `Group` type.

## Roadmap

**Milestone 1 (this): a real app on your phone.** Done. Shows friends the thing exists, and gets you comfortable in SwiftUI.

**Milestone 2: make it multiplayer.** Add real accounts and sync so friends share one clubhouse for real. Two solid backend options:
- Supabase (Postgres, Auth, Swift SDK). Given your SQL background, the relational model will feel familiar and you'll move fast.
- Firebase (Firestore, Auth). Slightly quicker to wire up for a social feed, great iOS support.
Either way, add Sign in with Apple. This is where the friend graph and open-spot matchmaking become genuinely shared.

**Milestone 3: get it onto your friends' phones.** TestFlight is how a real, unreleased iOS app reaches people. It needs the Apple Developer Program ($99/year). You can invite up to 10,000 external testers with a link, which is also your real "does it spread" test. After that, App Store submission.

## Notes

- Colors live in `Theme.swift`. Rename the app or retheme there.
- If any SF Symbol shows blank on your Xcode version, swap the `systemImage` name. They don't affect logic.
- When you're ready for Milestone 2, I can scaffold the Supabase or Firebase layer, the auth flow, and the sync code.
