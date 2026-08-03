# Codebase Map

**Project:** Foursome
**Analyzed:** 2026-08-03
**Branch:** claude/apple-indie-apple-stack-plugin-48stqs

---

## Project Overview

| Metric | Value |
|--------|-------|
| Swift files | 17 (14 app, 3 test) |
| Lines of Swift | 4,218 total — 3,628 app / 590 test |
| Test files | 3 |
| Test functions | 58 |
| Deployment target | iOS 17.0 (SwiftData floor) |
| Swift version | 5.9 |
| Device family | iPhone only, portrait only |

There is no checked-in `.xcodeproj`. The project is generated from
`project.yml` via XcodeGen (`brew install xcodegen && xcodegen generate`),
which is also what CI does on every push.

## Structure

```
.
├── Foursome/          14 files, 3,628 LOC — app target
├── FoursomeTests/      3 files,   590 LOC — unit tests
├── .github/workflows/ci.yml
└── project.yml         XcodeGen spec (source of truth for the project)
```

Flat — no directory grouping inside the target. At 14 files that is still
navigable, but it is the first thing that will hurt as the app grows.

## Architecture

**Pattern:** View-driven SwiftData. No ViewModels, no MVVM layer.
**State management:** SwiftData `@Query` (24 uses) + SwiftUI-native property
wrappers. Zero `@Observable`, zero `ObservableObject`, zero Combine.
**Persistence:** SwiftData — 6 `@Model` classes, container declared in
`FoursomeApp.swift`.
**Navigation:** `NavigationStack` (6 uses). No `NavigationView`, no UIKit.
**Concurrency:** Essentially none — 1 `async`, no actors, no `@MainActor`.

Views read the store directly through `@Query` and write through
`modelContext`. This is the current Apple-recommended shape for a SwiftData
app of this size, and the code is consistent about it — there is no mixed
legacy layer to unwind.

## Key Files

### Entry point
- `Foursome/FoursomeApp.swift:4` — 14 lines. Declares the `WindowGroup` and
  the `modelContainer` for all six models.

### Views
| View | Purpose | Location |
|------|---------|----------|
| `RootView` | Onboarding gate, tab shell, invite sheet, demo data | `Foursome/RootView.swift:4` |
| `FeedView` | Social feed of posts | `Foursome/FeedView.swift` |
| `OpenRoundsView` | Open-round browse, join, host cancel/decline | `Foursome/OpenRoundsView.swift` |
| `FriendsView` | Friendships and groups | `Foursome/FriendsView.swift` |
| `LeaderboardView` | Standings by scope and period | `Foursome/LeaderboardView.swift` |
| `LogRoundView` | Round entry | `Foursome/LogRoundView.swift` |
| `ScoringSettingsView` | Scoring mode configuration | `Foursome/ScoringSettingsView.swift` |
| `PostComposer` | Post authoring | `Foursome/PostComposer.swift` |
| `Scorecard` | `HoleScoreMark`, `ScorecardTable`, `ScorecardEditor` | `Foursome/Scorecard.swift` |
| `Theme` | 13 design-system components (`Card`, `Avatar`, `ScoreBadge`, `CourseHeader`, `EmptyState`, …) | `Foursome/Theme.swift` |

### Models — `Foursome/Models.swift` (460 LOC, the domain core)
| Type | Kind | Line |
|------|------|------|
| `Course` | `struct`, `Identifiable`, `Hashable` | `Models.swift:6` |
| `Player` | `@Model` | `Models.swift:59` |
| `Round` | `@Model` | `Models.swift:126` |
| `Friendship` | `@Model` | `Models.swift:179` |
| `PlayerGroup` | `@Model` | `Models.swift:209` |
| `OpenRound` | `@Model` | `Models.swift:280` |
| `Post` | `@Model` | `Models.swift:379` |
| `ScoringMode`, `RoundVisibility`, `PostAudience`, `AudienceScope`, `ScoreKind` | `enum` | various |

### Pure logic (the well-tested part)
| Unit | Purpose | Location |
|------|---------|----------|
| `Handicap` | Handicap computation, `ScoringContext` | `Foursome/Handicap.swift:22` |
| `SocialGraph` | Friend/group resolution, audience scoping | `Foursome/SocialGraph.swift:12` |

## Dependencies

**None.** No `Package.swift`, no SPM packages in `project.yml`, no Podfile.
The app is pure first-party frameworks.

### Frameworks in use
- [x] SwiftUI
- [x] SwiftData
- [ ] UIKit
- [ ] Core Data
- [ ] CloudKit
- [ ] WidgetKit
- [ ] App Intents
- [ ] StoreKit

## Code Quality

Unusually clean for the size. The scans that normally produce a list came
back empty:

| Issue | Count |
|-------|-------|
| TODO / FIXME / HACK / XXX | **0** |
| Debug `print(` in app target | **0** |
| `try!` / `as!` force unwraps | **0** |
| Files with doc comments | 13 of 14 |

`Models.swift` carries 60 doc-comment lines and `Handicap.swift` 45 — the
domain logic is genuinely documented, not just annotated.

### Testing
- Unit tests: 3 files, 58 test functions, XCTest.
- UI tests: none.
- **What is covered:** pure logic only — `Handicap` (22 tests), `SocialGraph`
  (24 tests), and the pure helpers in `Models` (12 tests: course coherence,
  score kinds, audience rules, period boundaries).
- **What is not covered:** the SwiftData layer and every view. The tests
  never construct a `ModelContainer` or `ModelContext` — there is no
  in-memory store fixture, so `@Model` persistence, queries, and the
  view-to-store writes are untested.

Coverage is therefore high on the ~820 LOC of pure logic and near zero on
the ~2,800 LOC of views and persistence. A raw "coverage %" would be
misleading; the split is what matters.

## Patterns Identified

### Good
- **Generated project file.** `project.yml` + XcodeGen keeps the
  merge-hostile `.xcodeproj` out of git, and CI regenerates it every run, so
  the spec is proven rather than trusted.
- **Consistent modern stack.** SwiftData + `NavigationStack` + `@Query`
  throughout, with no legacy `ObservableObject`/Combine residue.
- **Extracted design system.** `Theme.swift` holds 13 reusable components,
  so the feature views stay about behavior.
- **Pure logic separated from views.** `Handicap` and `SocialGraph` are
  plain values with no SwiftUI or SwiftData import — which is exactly why
  they could be tested this thoroughly.
- **CI on every push**, with a shared scheme deliberately spelled out in the
  spec so `xcodebuild test` works headlessly.

### Areas for improvement
- **Silent save failures.** Three of the five `context.save()` calls use
  `try?` and drop the error: `FeedView.swift:234`,
  `OpenRoundsView.swift:215`, `RootView.swift:239`. A failed write is
  invisible to the user — the UI will look like it worked. The other two
  (`RootView.swift:98`, `RootView.swift:220`) do use `try`.
- **No SwiftData test fixture.** An in-memory `ModelContainer` would let the
  model layer and the mutation paths be tested with the same rigor the pure
  logic already gets. This is the single highest-value gap.
- **Accessibility is thin.** 5 accessibility modifiers across the whole app,
  in 3 files. `Scorecard` — a dense numeric grid, the hardest thing here for
  VoiceOver — has 2. This is also a compliance concern under the EU
  Accessibility Act.
- **Flat file layout.** 14 files in one directory with no grouping; worth
  splitting into `Models/`, `Views/`, `DesignSystem/` before it grows.
- **`RootView.swift` is doing four jobs** (477 LOC: onboarding, tab shell,
  invite sheet, `DemoData`). The natural first split.
- **iPhone-portrait only.** `TARGETED_DEVICE_FAMILY: "1"` and a single
  supported orientation — fine as a deliberate choice, worth confirming it
  is one.
- **iOS 17 floor** predates the iOS 26 Liquid Glass design language; if a
  visual refresh is planned, that target needs revisiting.

---

## Recommendations

### Before continuing development
1. [ ] Replace the three `try?` saves with real error handling and a
       user-visible failure path.
2. [ ] Add an in-memory `ModelContainer` fixture and cover the `@Model`
       layer and the mutation paths.
3. [ ] Run `/apple:accessibility` — the audit is cheap and the current
       surface is close to bare.

### Integration with SwiftShip
This repo has no `.planning/` history and no `APP.md`; this file is the
first artifact.

1. Run `/apple:new-app Foursome` — creates `APP.md`, pre-filled from this
   analysis.
2. Run `/apple:roadmap` — phases the remaining work.
3. `/apple:review` and `/apple:test` are both immediately useful without
   any further setup.

---

*Generated by SwiftShip /apple:map*
