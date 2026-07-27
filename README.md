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

The friend graph, groups, and invite visibility are modeled and enforced. An
open round goes out to one of five audiences — anyone nearby, friends of
friends, members at the course, friends only, or hand-picked people and groups —
and `SocialGraph` resolves who that actually is.

The Friends tab covers the whole loop: search for someone, send a request,
accept or decline incoming ones, remove a friend, and build groups out of
people you've added.

Posts live in the same feed as rounds rather than a separate tab — a sixth tab
would overflow iOS's tab bar, and a social feed split from the rounds feed
gives you two half-empty timelines instead of one worth opening. A post carries
its own audience (friends of friends, club, friends, or hand-picked), resolved
by the same `SocialGraph` that scopes open rounds.

Rounds themselves stay visible to everyone, and the feed and leaderboard both
default to showing the whole clubhouse. An Everyone / Friends filter narrows
either one, and both read the same stored preference so they can never show
different populations.

That filter is a *view* control, not a privacy one — everything it hides was
already visible to you. Keeping it that way is what lets the default stay
global, so a new player with no friends still lands on a populated app rather
than an empty one.

Players can pick a home course at signup, which is optional and also decides who
counts as a fellow member for club-only invites. Club-only is offered only on
courses flagged private, since it means nothing on a course anyone can book.

## Handicaps and GHIN

Scorecards are marked against the player's own baseline by default, not against
scratch. Marking against par is close to useless for most golfers: a 95-shooter
sees a double bogey on nearly every hole, and a mark that never varies carries
no information. Net of a handicap, the same round reads as mostly pars with a
few bogeys — which is what actually happened.

The baseline comes from one of two places:

1. A handicap index the player types in, or
2. One worked out from their logged rounds, once there are at least three.

**GHIN cannot be linked automatically.** Handicap data is only available through
the USGA's licensed partner program, which requires a signed agreement — there
is no public API and no key to plug in. Apps that display GHIN indexes are
licensed. Manual entry writes to `Player.handicapIndex`, which is the same field
a GHIN sync would populate, so if that access is ever granted nothing downstream
has to change.

The computed number follows the real World Handicap System shape — lowest few of
your last 20 differentials, with WHS's sliding table so five rounds still yields
something — but approximates each differential as `strokes - par`. Real WHS uses
`(113 / slope) * (adjusted gross - course rating)`, and this app carries neither
slope nor rating. That makes it a sound personal baseline and an invalid official
index. It must never be presented as a GHIN or WHS handicap, and adding course
rating and slope is what would close the gap.

## Roadmap

**Milestone 1 (this): a real app on your phone.** Done. Shows friends the thing exists, and gets you comfortable in SwiftUI.

**Milestone 2: make it multiplayer.** Add real accounts and sync so friends share one clubhouse for real. **Backend: Firebase** (Firestore + Auth) — chosen because there's already an account on it. Firestore is quick to wire up for a social feed and has solid iOS support. Add Sign in with Apple on top of Firebase Auth. This is where the friend graph and open-spot matchmaking become genuinely shared.

Firestore is a document store, not relational, so the friend graph and invite visibility need to be designed around its query model up front — Firestore can't do joins, and "show me rounds from friends-of-friends" has to be answered by data shape (denormalized audience lists on each document) rather than by a query. Worth settling before writing sync code.

**Milestone 3: get it onto your friends' phones.** TestFlight is how a real, unreleased iOS app reaches people. It needs the Apple Developer Program ($99/year). You can invite up to 10,000 external testers with a link, which is also your real "does it spread" test. After that, App Store submission.

## Notes

- Colors live in `Theme.swift`. Rename the app or retheme there.
- If any SF Symbol shows blank on your Xcode version, swap the `systemImage` name. They don't affect logic.
- When you're ready for Milestone 2, I can scaffold the Supabase or Firebase layer, the auth flow, and the sync code.
