# Foursome — everything about this app

*Accurate as of July 2026, commit `cfe19dd` (30 commits in). Sources: 15 Swift
files, ~3,600 lines of app code, plus 58 unit tests across three files.*

Foursome is a native iOS app for golfers who play in groups: track your
rounds, see when your friends play, and open a spot when your foursome needs
one more. The name is the pitch — Saturday is a group project, and the app's
job is filling the fourth seat.

It is **local-first by design**: SwiftUI + SwiftData, iOS 17+, iPhone-only,
portrait. Everything runs on-device with no backend — yet. The multiplayer
backend (Firebase) is fully designed in [`docs/milestone-2.md`](docs/milestone-2.md)
and is the next thing to build.

---

## The product

Five tabs under a turf-green masthead with a flagstick:

| Tab | What it does |
| --- | --- |
| **Feed** | Rounds and social posts in one timeline, newest first. Expandable scorecards. A composer prompt up top. |
| **Log** | Enter a score — hole by hole or just the total — with a date field for backdating. |
| **Open** | Browse and post open rounds: a course, a tee time, open spots, and who's allowed to see it. Request to join; hosts approve or decline. |
| **Friends** | Send/accept/decline friend requests, remove friends, build named groups ("Saturday regulars"). |
| **Board** | Leaderboards by week / month / year / all time, for every course or one, plus the clubhouse roster of who hasn't posted. |

Every screen header carries two buttons: scoring settings and an invite sheet
(a real iOS share sheet via `ShareLink`; the invite link itself is a
placeholder until the backend exists).

**Onboarding** asks for a first name and, optionally, a home course — required
nothing, because a wall in front of the door loses players. Typing the name of
an existing player (case-insensitive) signs in as them.

**The demo clubhouse.** The app seeds four players so it feels alive at first
launch, and their shape is deliberate:

- **Marcus** — 8.2 index, member at Brookstone (private). *Log in as him to see everything.*
- **Tyler** — 2.4, also a Brookstone member.
- **Deshawn** — 16.1, plays out of Cherokee Run.
- **Ryan** — 5.0, no home course.

Marcus is friends with Tyler and Deshawn; Tyler is friends with Ryan; Ryan has
a **pending request** out to Marcus (seeded so the accept/decline UI is
reachable — you can't be the other player, so without it that path is dead).
Signed in as Marcus, Ryan is a friend-of-a-friend: exactly enough graph to
tell the visibility tiers apart by eye. Seeding includes five rounds (four
with full cards, one total-only on purpose), four open rounds spanning four
visibility tiers, two posts, and one group. The whole thing can be rebuilt
from "Reset all data" in scoring settings.

## Scoring and handicaps

**Entry** starts every hole at par, so a level round is zero taps and most
rounds are a few. Scores clamp to 1–15 per hole. The total is derived from
the card so the two can never disagree; total-only entry exists for rounds
logged quickly. Rounds can be backdated (capped at today) — the feed orders
by *log* time, the leaderboard by *play* date, so backdating fixes the week
without resurfacing an old round at the top of the feed.

**Notation** is real scorecard marking, and it's the app's visual signature:
birdie in a circle, eagle in a double circle, bogey in a square, double-plus
in a double square, par bare. Whole-round badges use looser bands (−3 eagle
territory, +1..+3 a "bogey" round) because one stroke over 18 holes is noise.

**Handicaps.** Scorecards are marked against the player's *own baseline* by
default, not scratch — a 95-shooter playing their number should read mostly
pars, because that's what happened. Two modes: "My game" (net) and "Scratch",
and when you view someone else's card, *your* mode choice applies but the
strokes come off *their* number.

The baseline is either a hand-entered index (accepts "+2.1" for plus
handicaps, clamped −10…54) or one computed from logged rounds once there are
three. The computed number follows the real World Handicap System shape —
lowest few of the last 20 differentials with WHS's sliding table — but
approximates each differential as `strokes − par` because the app carries no
slope or rating. That makes it a sound personal baseline and an **invalid
official index**; the app never presents it as GHIN/WHS. GHIN can't be linked
automatically (USGA licensed-partner program, no public API); manual entry
writes the same field a licensed sync would, so nothing downstream changes if
that ever happens. Strokes land on holes by stroke index: a 9 gets one on the
nine hardest holes, a 22 gets one everywhere plus a second on index 1–4.

## The visibility model (the core design)

`SocialGraph` is the one place "who can see this" is computed. Open rounds go
out to one of five audiences, ordered widest to narrowest:

1. **Anyone nearby** — matched on the course's city, which is derived from
   where you've actually played or joined rounds. No location permission,
   ever.
2. **Friends of friends**
3. **Members here** — players whose home course is this one; only offered at
   courses flagged private, because it means nothing where anyone can book.
4. **Friends only**
5. **Specific people** — hand-picked players and/or groups.

Posts use the same machinery minus the unbounded tier (no course to be near,
and a public feed is a moderation problem this app doesn't need). Two
contracts are load-bearing and pinned by tests: an area round's audience is
`nil` (unbounded — a query, never a list), and anyone already joined or
pending **keeps seeing a round** even if the host narrows visibility — a
group never loses the thread.

The feed and leaderboard share one **Everyone / Friends** filter (a single
stored preference, so the two screens can never show different populations).
It is a *view* control, not privacy: everything it hides was already visible.
That's what lets the default stay "Everyone", so a brand-new player lands on
a populated app instead of an empty one. Rounds themselves are visible to the
whole clubhouse by permission; only open-round invitations and posts are
audience-scoped.

Lifecycle controls, all added in the hardening pass: long-press your own feed
round to delete it (confirmed, eagerly saved), long-press an open round you
host to cancel it, decline join requests, and approve is capacity-guarded.
Open rounds fall off the list at midnight after their day.

## Design language

The palette is sampled off an actual course, with a rule: every color must
name something you'd walk past between the first tee and the clubhouse.
Greens lean warm and olive (`rough`, `fairway`, `fairwayLit`, `putting`,
`dew`) because chlorophyll does; neutrals are bunker sand and scorecard stock
(`sand`, `paper`, `card`), ink is warm pencil-grey, and red is reserved for
the flagstick and over-par. Turf surfaces carry faint mown stripes. Display
type is serif, data is monospaced — a scorecard tell. Small text on cream
uses `fairwayLit` rather than `putting` for WCAG AA contrast.

## Architecture

```
Foursome/
  FoursomeApp.swift        app entry; registers the SwiftData container
  Models.swift             Player, Round, OpenRound, Friendship, PlayerGroup,
                           Post, visibility enums, the course table
  SocialGraph.swift        pure value type resolving the friend graph and audiences
  Handicap.swift           pure WHS-shaped index + stroke allocation; ScoringContext
  Scorecard.swift          notation marks, read-only card, entry grid
  Theme.swift              palette, stripes, masthead, shared components
  RootView.swift           onboarding, demo seeding, reset, tab shell, invite sheet
  FeedView.swift           timeline of rounds + posts, scope filter, delete
  LogRoundView.swift       score entry, backdating
  OpenRoundsView.swift     browse/post/request/approve/decline/cancel, expiry
  FriendsView.swift        requests, friends, groups
  PostComposer.swift       write a post, pick its audience
  LeaderboardView.swift    periods, course filter, ranking, roster
  ScoringSettingsView.swift  mode, index entry, reset
FoursomeTests/             58 tests: SocialGraph, Handicap, models/courses
```

Patterns that matter:

- **Logic lives in pure value types** (`SocialGraph`, `Handicap`,
  `ScoringContext`) fed arrays by the views — trivially testable, and
  portable to the backend unchanged.
- **Enums store raw strings** in SwiftData so Firestore sees plain strings
  later; models were shaped for the sync from day one.
- **Decisions read the store, not flags.** Seeding asks "is the demo
  clubhouse present?" (via `Player.isDemo`) instead of trusting a
  UserDefaults flag that can drift from the data it describes. Hard-won: the
  onboarding/seeding saga consumed eight commits.
- **Reset signs out before wiping** — deleting models under live views is a
  fatal error in SwiftData, so onboarding swaps in first and the wipe runs
  after.
- **Deletes save eagerly; small mutations ride autosave.** Autosave dropping
  a like is noise; autosave resurrecting a deleted round reads as a bug.
- **Derived, never duplicated**: a round's total comes from its hole scores,
  a course's par from its hole pars.
- The generated `.xcodeproj` is not committed; **`project.yml` (XcodeGen) is
  the source of truth.**

## Data model

Six SwiftData models: `Player` (name, handle, optional handicap index,
optional home course, scoring mode, `isDemo`), `Round` (player, course,
strokes, par, play date, log date, 18 hole scores or empty), `Friendship`
(one row per pair; `requesterID` preserved so the receiver gets the prompt;
`accepted` flag), `PlayerGroup` (name, owner, member ids), `OpenRound` (host,
course, date, freeform time string, spots, note, joined/pending id lists,
visibility + invited people/groups), `Post` (author, text, audience + invited
lists, likes). `Course` is static reference data, not stored: six Atlanta-area
courses with per-hole pars and stroke indexes (verified 18 pars and a 1–18
stroke-index permutation each, by test). The `isPrivate` flags are
placeholders to verify before real users.

## Tests and CI

58 tests pin the logic that must not regress: every audience tier for rounds
and posts (including the nil-for-area contract and the grandfather rule), the
WHS sliding table at every boundary, stroke allocation, scoring-context
fallbacks, course-table integrity, and leaderboard period boundaries. The
visibility tests double as the Milestone 2 spec — the same audiences get
denormalized onto Firestore documents.

CI (GitHub Actions, `macos-15`) regenerates the project with XcodeGen and
runs the suite on an iPhone 16 simulator on every push. Locally: ⌘U, or
`xcodegen generate && xcodebuild test -project Foursome.xcodeproj -scheme
Foursome -destination 'platform=iOS Simulator,name=iPhone 16'`.

## History and roadmap

- **Milestone 1 — a real app on your phone.** Done. The full local loop:
  feed, scoring, open rounds, friends, leaderboards, demo clubhouse. Includes
  the retheme, hole-by-hole scoring, the friend graph, and the
  onboarding/seeding stabilization.
- **Milestone 1.5 — make it trustworthy.** Done (merged as PR #1): the test
  suite, CI, the four lifecycle fixes (delete, backdate, expire/cancel,
  decline), and a truthful README.
- **Milestone 2 — make it multiplayer.** Designed, not yet built:
  [`docs/milestone-2.md`](docs/milestone-2.md). Firebase; Firestore as the
  single source of truth (no SwiftData mirror); **Sign in with Apple from day
  one** (the Developer Program account exists); denormalized `audienceIDs`
  written by the same `SocialGraph` function the tests pin; audiences freeze
  at write time; security rules with emulator tests; five build phases, each
  leaving the app shippable.
- **Milestone 3 — friends' phones.** TestFlight (up to 10,000 external
  testers), then the App Store. Unblocked — the $99 membership exists.

## Honest caveats and open gaps

- The seeded friends are demo data; "friends see each other's rounds" isn't
  truly multiplayer until Milestone 2 ships.
- The invite link is a placeholder domain, and its code isn't stable across
  launches (it hashes a UUID with a per-launch seed).
- No way yet to leave a joined open round, delete a post, or tap through to a
  player profile; handles aren't unique; feeds don't paginate.
- Expired open rounds are hidden, not deleted — fine locally, a TTL job later.
- The computed handicap is a personal baseline, never an official index.
- Course data (including which courses are private) is hand-typed placeholder
  reference data.

## Running it

```
brew install xcodegen
xcodegen generate
open Foursome.xcodeproj
```

Pick any iPhone simulator or a device, hit Run, and enter the clubhouse —
type `Marcus` to land in the populated demo. Full setup detail, including the
no-XcodeGen path, is in the [README](README.md).
