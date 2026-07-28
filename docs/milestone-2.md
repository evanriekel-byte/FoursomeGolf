# Milestone 2 — make it multiplayer

The goal: friends share one clubhouse for real. Accounts, sync, a shared friend
graph, and open-spot matchmaking that actually reaches other phones. Backend is
**Firebase** (Firestore + Auth), as committed in the README.

This document settles the decisions the sync code hangs on, so the code never
has to. Non-goals for this milestone: push notifications, moderation tooling,
public discovery, GHIN. Those all want the sync layer to exist first.

## One source of truth

Firestore replaces SwiftData for every synced entity. Views read from
repositories driven by Firestore snapshot listeners; writes go through the same
repositories. Firestore's built-in offline cache (on by default on iOS) keeps
the app usable without signal — reads serve from cache, writes queue.

The rejected alternative is mirroring Firestore into SwiftData and keeping
`@Query`. Two stores means reconciling them, and every reconciliation bug looks
like data loss to a user. One store, one direction.

`SocialGraph` and `Handicap` don't change. They're pure value types over
arrays, fed today by `@Query` and tomorrow by repository snapshots. The unit
tests keep passing untouched through the whole migration — that's what they're
for. (One mechanical change: synced IDs are Firebase uid strings, not UUIDs, so
`SocialGraph` generalizes from `UUID` to `String` keys. The tests port 1:1.)

**The app stays runnable throughout.** Cloud mode turns on only when a
`GoogleService-Info.plist` is present and the feature flag says so; without it,
the current local-first app runs exactly as it does today, demo clubhouse and
all. Local demo mode survives the cutover as the offline/dev configuration.

## Identity

**Anonymous Firebase Auth first, Sign in with Apple linked later.**

At first launch the app signs in anonymously and gets a stable uid; onboarding
writes the display name to `players/{uid}`. This is the same UX the app has
today — type a name, enter the clubhouse — with zero extra friction.

Why not Sign in with Apple immediately: the entitlement isn't available on a
free personal team. It arrives with the $99 Apple Developer Program enrollment,
which Milestone 3 (TestFlight) needs anyway. When that happens, the anonymous
account links a Sign in with Apple credential via `user.link(with:)` — same
uid, all data kept, and the account stops being device-bound.

Documented risk until then: an anonymous account lives on one device, and
deleting the app deletes the account. Acceptable for the friends-testing
window; the Sign in with Apple link is the durable fix.

The demo clubhouse never syncs. Cloud mode doesn't seed Marcus and Tyler — the
real clubhouse is the people you invite. On first cloud sign-in the app offers
to upload the local player's own rounds (and nothing belonging to demo
players), then the cloud is the record.

## Schema

Collections map 1:1 from the current models — the raw-string enums were stored
that way for exactly this moment.

| Collection | Fields | Notes |
| --- | --- | --- |
| `players/{uid}` | name, handle, handicapIndex?, homeCourseID?, scoringModeRaw, createdAt | doc id is the auth uid |
| `rounds/{id}` | playerID, courseID, strokes, par, date, createdAt, holeScores | holeScores is 18 ints or empty, as today |
| `friendships/{id}` | requesterID, addresseeID, accepted, createdAt, memberIDs | memberIDs = [requester, addressee], so one `array-contains` query fetches all my edges |
| `groups/{id}` | name, ownerID, memberIDs, createdAt | uids as strings, same as today |
| `openRounds/{id}` | hostID, courseID, date, time, spots, note, joined, pending, visibilityRaw, invitedPlayerIDs, invitedGroupIDs, createdAt, **audienceIDs?**, **areaKey?** | audienceIDs is the denormalized audience; null for area rounds |
| `posts/{id}` | authorID, text, createdAt, audienceRaw, invitedPlayerIDs, invitedGroupIDs, likes, **audienceIDs** | never null — every post has a bounded audience |

**audienceIDs is the whole trick.** Firestore can't join, so "who can see
this" is answered by data shape: the host's client computes the audience with
the same `SocialGraph.audience(for:)` that runs locally today, and writes it
onto the document. The unit tests over that function are the spec for what
lands in this field. Area rounds stay `audienceIDs: null` + `areaKey` — an
unbounded audience is a query (`areaKey == myArea`), never a list, exactly the
nil-contract the tests pin.

The grandfather rule (joined and pending players keep seeing a round) is
implemented by construction: every uid added to `joined` or `pending` is also
unioned into `audienceIDs` at that moment, freezing their access.

Reads, per screen:

- **Open rounds**: two listeners merged client-side — `audienceIDs
  array-contains myUid`, and `areaKey in myAreas` (Firestore `in` takes up to
  30 values; a player has a handful of areas). Expired rounds are filtered
  client-side as today, and eventually TTL-deleted.
- **Posts**: `audienceIDs array-contains myUid`.
- **Feed rounds**: all rounds, newest first, limited — rounds stay globally
  visible by permission, matching the app's existing contract that the
  Everyone/Friends toggle is a view filter, not privacy.
- **Leaderboard**: rounds with `date >= periodStart`, filtered and ranked
  client-side like today.
- **Friendships**: `memberIDs array-contains myUid`.

Scale note: an audienceIDs array of friends-of-friends fits Firestore's 1 MiB
document limit until the graph reaches tens of thousands — not a friends-scale
problem. If it ever is, the escape hatch is membership subcollections; the
choke point in `SocialGraph` means one function changes.

## Staleness — decided

**Audiences freeze at write time.** Make a friend tomorrow and they don't see
yesterday's post; unfriend someone and they keep what they could already see —
which is the grandfather rule generalized, and matches how paper invitations
work. Recomputing old audiences on every friendship change needs server-side
fan-out (Cloud Functions) for marginal product value. Documented consequence,
revisit only if it confuses real users.

## Security rules

Client filtering becomes real enforcement where Firestore rules can express it
cheaply:

- `players`: any signed-in user reads; only `uid == docID` writes.
- `rounds`: any signed-in user reads; only the owner creates/updates/deletes.
- `friendships`: readable if `auth.uid in memberIDs`; created by the requester
  with `accepted == false`; accepted only by the addressee; deleted by either
  party (decline, unfriend).
- `groups`: readable by members and the owner; written by the owner.
- `openRounds`: readable if `auth.uid in audienceIDs` or the round is
  area-visible; created by the host. Updates are field-scoped: the host edits
  freely, a non-host may only append their own uid to `pending`.
- `posts`: readable if `auth.uid in audienceIDs`; written by the author, except
  `likes`, which anyone in the audience may toggle for their own uid only.

Rules get their own tests against the Firestore emulator
(`@firebase/rules-unit-testing`), running in CI on a cheap Ubuntu job next to
the macOS build.

The plist is config, not a secret (Firebase security lives in rules), but it
stays gitignored anyway — this repo is public, and CI builds fine without it
because cloud mode defaults off.

## Build order

Each phase leaves the app shippable and CI green.

- **A — bootstrap.** Firebase SDK via SPM (FirebaseAuth, FirebaseFirestore),
  a `Cloud` bootstrap that no-ops without config, anonymous sign-in behind the
  flag. App behavior unchanged when unconfigured.
- **B — players and rounds.** First end-to-end sync: profile and round
  repositories, feed and leaderboard reading cloud data in cloud mode, the
  one-time local-rounds migration prompt.
- **C — friendships and groups.** The Friends tab goes live against real
  edges; requests, accept/decline, groups.
- **D — open rounds and posts.** Audience denormalization at write, the
  join/approve/decline flow writing `pending`/`joined`/`audienceIDs`.
- **E — cutover.** Cloud mode becomes the default when configured; SwiftData
  retires for synced entities; local demo mode remains behind the flag.

## What Evan does

1. Firebase console: create the project, add an iOS app with bundle id
   `com.foursome.app`, download `GoogleService-Info.plist` (it stays out of
   git).
2. Enable **Anonymous** authentication, and create the Firestore database.
3. Decide timing on the $99 Developer Program — it unlocks Sign in with Apple
   linking here and TestFlight in Milestone 3. Nothing in phases A–E blocks on
   it.
