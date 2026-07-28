import XCTest
@testable import Foursome

/// Pins the WHS-shaped baseline: the sliding selection table, the index
/// arithmetic, and how strokes land on specific holes. The differentials
/// themselves are approximations (`strokes - par`, no slope or rating), but
/// the machinery around them is real WHS and must not drift.
final class HandicapTests: XCTestCase {

    // MARK: - The sliding selection table

    func testSelectionNeedsAtLeastThreeRounds() {
        XCTAssertNil(Handicap.selection(forRoundCount: 0))
        XCTAssertNil(Handicap.selection(forRoundCount: 2))
    }

    func testSelectionTableMatchesWHS() throws {
        let expectations: [(rounds: Int, count: Int, adjustment: Double)] = [
            (3, 1, -2.0), (4, 1, -1.0), (5, 1, 0.0),
            (6, 2, -1.0), (7, 2, 0.0), (8, 2, 0.0),
            (9, 3, 0.0), (11, 3, 0.0),
            (12, 4, 0.0), (14, 4, 0.0),
            (15, 5, 0.0), (16, 5, 0.0),
            (17, 6, 0.0), (18, 6, 0.0),
            (19, 7, 0.0), (20, 8, 0.0), (40, 8, 0.0),
        ]
        for e in expectations {
            let sel = try XCTUnwrap(Handicap.selection(forRoundCount: e.rounds),
                                    "no selection for \(e.rounds) rounds")
            XCTAssertEqual(sel.count, e.count, "count for \(e.rounds) rounds")
            XCTAssertEqual(sel.adjustment, e.adjustment, "adjustment for \(e.rounds) rounds")
        }
    }

    // MARK: - Index

    func testIndexNeedsThreeDifferentials() {
        XCTAssertNil(Handicap.index(differentials: []))
        XCTAssertNil(Handicap.index(differentials: [5, 7]))
    }

    func testIndexOfThreeRoundsIsTheLowestMinusTwo() {
        XCTAssertEqual(Handicap.index(differentials: [10, 8, 12]), 6.0)
    }

    func testIndexAveragesOnlyTheLowest() {
        // Six rounds → lowest two (4 and 6), adjusted by -1.
        XCTAssertEqual(Handicap.index(differentials: [9, 6, 12, 4, 15, 11]), 4.0)
    }

    func testIndexRoundsToOneDecimal() {
        // Five rounds → the single lowest, no adjustment.
        XCTAssertEqual(Handicap.index(differentials: [7.25, 9, 11, 12, 13]), 7.3)
    }

    func testPlusGolferGoesNegative() {
        XCTAssertEqual(Handicap.index(differentials: [-1, 0, -2, 3, 1]), -2.0)
    }

    func testIndexIgnoresEverythingPastTwentyRounds() {
        // A career round 21 rounds ago must not drag the index down.
        let recentTwenty = Array(repeating: 10.0, count: 20)
        XCTAssertEqual(Handicap.index(differentials: recentTwenty + [-5]), 10.0)
    }

    // MARK: - Differentials from rounds

    func testDifferentialsAreMostRecentFirstAndOnlyMine() {
        let me = Player(name: "Me")
        let rival = Player(name: "Rival")
        let day: TimeInterval = 86_400

        let rounds = [
            Round(playerID: me.id, courseID: "c1", strokes: 80, par: 71,
                  date: .now.addingTimeInterval(-3 * day)),                  // +9, older
            Round(playerID: rival.id, courseID: "c1", strokes: 70, par: 71,
                  date: .now.addingTimeInterval(-2 * day)),                  // not mine
            Round(playerID: me.id, courseID: "c2", strokes: 77, par: 72,
                  date: .now.addingTimeInterval(-1 * day)),                  // +5, newest
        ]
        XCTAssertEqual(Handicap.differentials(for: me.id, rounds: rounds), [5.0, 9.0])
    }

    func testEffectiveIndexPrefersTheEnteredNumber() {
        let player = Player(name: "Entered")
        player.handicapIndex = 3.5
        // Rounds that would compute to something else entirely.
        let rounds = (0..<5).map { i in
            Round(playerID: player.id, courseID: "c1", strokes: 95, par: 71,
                  date: .now.addingTimeInterval(TimeInterval(-i) * 86_400))
        }
        XCTAssertEqual(Handicap.effectiveIndex(for: player, rounds: rounds), 3.5)
    }

    func testEffectiveIndexFallsBackToComputedThenNil() {
        let player = Player(name: "Fresh")
        XCTAssertNil(Handicap.effectiveIndex(for: player, rounds: []))

        let rounds = [78, 82, 80].enumerated().map { i, strokes in
            Round(playerID: player.id, courseID: "c1", strokes: strokes, par: 71,
                  date: .now.addingTimeInterval(TimeInterval(-i) * 86_400))
        }
        // Differentials 7, 11, 9 → the lowest minus 2.
        XCTAssertEqual(Handicap.effectiveIndex(for: player, rounds: rounds), 5.0)
    }

    // MARK: - Strokes on holes

    func testStrokesFallOnTheHardestHolesFirst() throws {
        let course = try XCTUnwrap(Course.by("c1"))
        let strokes = Handicap.strokesReceived(courseHandicap: 9,
                                               strokeIndex: course.strokeIndex)
        XCTAssertEqual(strokes.reduce(0, +), 9)
        for (si, s) in zip(course.strokeIndex, strokes) {
            XCTAssertEqual(s, si <= 9 ? 1 : 0, "stroke index \(si)")
        }
    }

    func testHighHandicapGetsABaseStrokeEverywherePlusExtras() throws {
        // A 22 gets one stroke on every hole and a second on stroke index 1-4.
        let course = try XCTUnwrap(Course.by("c1"))
        let strokes = Handicap.strokesReceived(courseHandicap: 22,
                                               strokeIndex: course.strokeIndex)
        XCTAssertEqual(strokes.reduce(0, +), 22)
        for (si, s) in zip(course.strokeIndex, strokes) {
            XCTAssertEqual(s, si <= 4 ? 2 : 1, "stroke index \(si)")
        }
    }

    func testScratchAndPlusHandicapsGetNothing() {
        let si = Array(1...18)
        XCTAssertEqual(Handicap.strokesReceived(courseHandicap: 0, strokeIndex: si),
                       Array(repeating: 0, count: 18))
        XCTAssertEqual(Handicap.strokesReceived(courseHandicap: -3, strokeIndex: si),
                       Array(repeating: 0, count: 18))
        XCTAssertEqual(Handicap.strokesReceived(courseHandicap: 9, strokeIndex: []), [])
    }

    func testCourseHandicapIsTheRoundedIndex() {
        XCTAssertEqual(Handicap.courseHandicap(index: 8.2), 8)
        XCTAssertEqual(Handicap.courseHandicap(index: 8.6), 9)
        XCTAssertEqual(Handicap.courseHandicap(index: -2.4), -2)
    }

    // MARK: - Scoring context

    func testScratchModeMarksAgainstTheCard() throws {
        let course = try XCTUnwrap(Course.by("c1"))
        let player = Player(name: "Scratch")
        player.scoringMode = .scratch
        player.handicapIndex = 12.0  // present, but scratch mode ignores it

        let context = ScoringContext.make(player: player, course: course, rounds: [])
        XCTAssertEqual(context.netPars, course.holePars)
        XCTAssertNil(context.index)
        XCTAssertEqual(context.caption, "vs par")
    }

    func testPersonalModeWithNoBaselineFallsBackToPar() throws {
        let course = try XCTUnwrap(Course.by("c1"))
        let context = ScoringContext.make(player: Player(name: "Fresh"),
                                          course: course, rounds: [])
        XCTAssertEqual(context.netPars, course.holePars)
        XCTAssertNil(context.index)
    }

    func testPersonalModeAddsStrokesWhereTheyAreGiven() throws {
        let course = try XCTUnwrap(Course.by("c1"))
        let player = Player(name: "Eight")
        player.handicapIndex = 8.2

        let context = ScoringContext.make(player: player, course: course, rounds: [])
        XCTAssertEqual(context.index, 8.2)
        XCTAssertEqual(context.netPars.reduce(0, +), course.par + 8)
        for (i, si) in course.strokeIndex.enumerated() {
            XCTAssertEqual(context.netPars[i], course.holePars[i] + (si <= 8 ? 1 : 0),
                           "hole \(i + 1)")
        }
        XCTAssertTrue(context.caption.contains("8.2"))
        XCTAssertTrue(context.caption.contains("your index"))
    }

    func testComputedBaselineSaysWhereItCameFrom() throws {
        let course = try XCTUnwrap(Course.by("c2"))
        let player = Player(name: "Computed")
        let rounds = (0..<3).map { i in
            Round(playerID: player.id, courseID: "c2", strokes: 78 + i, par: 72,
                  date: .now.addingTimeInterval(TimeInterval(-i) * 86_400))
        }
        // Differentials 6, 7, 8 → lowest minus 2 → 4.0.
        let context = ScoringContext.make(player: player, course: course, rounds: rounds)
        XCTAssertEqual(context.index, 4.0)
        XCTAssertTrue(context.caption.contains("your recent rounds"))
    }

    func testPlusIndexReadsAsScratch() throws {
        // No strokes to hand out, so the card falls back to plain par.
        let course = try XCTUnwrap(Course.by("c1"))
        let player = Player(name: "Plus")
        player.handicapIndex = -2.0
        let context = ScoringContext.make(player: player, course: course, rounds: [])
        XCTAssertEqual(context.netPars, course.holePars)
        XCTAssertNil(context.index)
    }

    func testViewerModeOverridesTheOwnersPreference() throws {
        // Reading someone else's card, the *viewer* chooses net or scratch —
        // but the strokes always come off the owner's number.
        let course = try XCTUnwrap(Course.by("c1"))
        let player = Player(name: "Net")
        player.handicapIndex = 10.0
        let context = ScoringContext.make(player: player, course: course,
                                          rounds: [], mode: .scratch)
        XCTAssertEqual(context.netPars, course.holePars)
        XCTAssertNil(context.index)
    }

    func testFormattedIndexShowsPlusHandicapsWithAPlus() {
        XCTAssertEqual(ScoringContext.formatted(8.2), "8.2")
        XCTAssertEqual(ScoringContext.formatted(-2.4), "+2.4")
    }
}
