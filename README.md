# Foursome — native iOS starter

A real SwiftUI app you can run on your phone this week. It's local-first, so it runs entirely on-device with no backend yet. The full core loop works: log rounds, see a feed, post open rounds, request and approve joiners, and a leaderboard. It's seeded with a demo clubhouse (Marcus, Tyler, Deshawn, Ryan) so it feels alive the moment it launches.

## What you need

- A Mac with Xcode 15 or newer
- Deployment target iOS 17 or newer (SwiftData requires it)
- About 30 minutes

## Setup

The `.xcodeproj` is deliberately not committed — it's a generated artifact that merges badly. `project.yml` is the source of truth, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) turns it into a project:

```
brew install xcodegen
xcodegen generate
open Foursome.xcodeproj
```

Pick a simulator (any iPhone works) or your own device, and hit Run.

Prefer clicking it together instead? File > New > Project > iOS > App, name it `Foursome` (Interface `SwiftUI`, Language `Swift`, Storage `None`), delete the generated `ContentView.swift` and `FoursomeApp.swift`, drag every `.swift` file from this repo's `Foursome/` folder into the target, and set Minimum Deployments to iOS 17.0.

Either way you should land on the onboarding screen. Enter your name, or type `Marcus` to log in as a seeded player and see a populated feed and leaderboard.

## Files

App sources live in `Foursome/`, tests in `FoursomeTests/`.

- `FoursomeApp.swift` — app entry, registers the SwiftData store
- `Models.swift` — Player, Round, OpenRound, Friendship, PlayerGroup, Post, the visibility tiers, and the course list
- `SocialGraph.swift` — resolves the friend graph; the one place "who can see this" is computed
- `Handicap.swift` — the WHS-shaped baseline index and per-hole stroke allocation
- `Theme.swift` — the course-sampled palette and shared components
- `Scorecard.swift` — scorecard notation (birdie circles, bogey squares), the read-only card, the entry grid
- `RootView.swift` — onboarding, demo seeding, tab shell, invite sheet
- `FeedView.swift` — rounds and posts in one timeline
- `LogRoundView.swift` — log a score, hole by hole or just the total
- `OpenRoundsView.swift` — browse, post, request, approve, decline
- `FriendsView.swift` — friend requests, the friends list, and groups
- `PostComposer.swift` — write a post and pick its audience
- `LeaderboardView.swift` — period and course boards, clubhouse roster
- `ScoringSettingsView.swift` — scoring mode, handicap entry, reset

## Tests and CI

The logic that must not regress lives in plain value types, and `FoursomeTests/` pins it down: every visibility tier `SocialGraph` resolves (including the rule that joined and pending players keep seeing a round whose visibility was narrowed), the WHS sliding table and stroke allocation in `Handicap`, and the hand-typed course table — 18 pars per card, stroke indexes a permutation of 1–18.

Run them with ⌘U in Xcode, or:

```
xcodegen generate
xcodebuild test -project Foursome.xcodeproj -scheme Foursome \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Every push runs the same suite on GitHub Actions (`.github/workflows/ci.yml`). The visibility tests double as the Milestone 2 spec: the audiences `SocialGraph` computes locally are exactly what gets denormalized onto Firestore documents later, so they're what the sync layer has to keep true.

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

Everything you make, you can also take back: long-press one of your own rounds
in the feed to delete it, long-press an open round you host to cancel it, and
decline a join request instead of leaving it hanging. Rounds can be backdated
when they're logged, so a Saturday round entered on Monday lands in the right
leaderboard week, and an open round falls off the board at midnight after its
tee time instead of going stale at the top of the list.

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

**Milestone 1.5: make it trustworthy.** Done. Unit tests over the social graph, handicap engine, and course table; CI on every push; and the lifecycle gaps closed — delete a mistyped round, backdate one logged late, cancel an open round, decline a join request, and expire stale tee times.

**Milestone 2: make it multiplayer.** Add real accounts and sync so friends share one clubhouse for real. **Backend: Firebase** (Firestore + Auth) — chosen because there's already an account on it. Firestore is quick to wire up for a social feed and has solid iOS support. Auth is Sign in with Apple from day one — the Developer Program account already exists — so accounts survive reinstalls and are ready for TestFlight. This is where the friend graph and open-spot matchmaking become genuinely shared.

Firestore is a document store, not relational, so the friend graph and invite visibility need to be designed around its query model up front — Firestore can't do joins, and "show me rounds from friends-of-friends" has to be answered by data shape (denormalized audience lists on each document) rather than by a query. That design is settled in [`docs/milestone-2.md`](docs/milestone-2.md).

**Milestone 3: get it onto your friends' phones.** TestFlight is how a real, unreleased iOS app reaches people. It needs the Apple Developer Program ($99/year). You can invite up to 10,000 external testers with a link, which is also your real "does it spread" test. After that, App Store submission.

## Notes

- Colors live in `Theme.swift`. Rename the app or retheme there.
- If any SF Symbol shows blank on your Xcode version, swap the `systemImage` name. They don't affect logic.
- When you're ready for Milestone 2, I can scaffold the Firebase layer, the auth flow, and the sync code.
