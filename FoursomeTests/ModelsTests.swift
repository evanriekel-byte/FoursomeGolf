import XCTest
@testable import Foursome

final class ModelsTests: XCTestCase {

    // MARK: - Course table integrity

    /// The course list is hand-typed reference data, which is exactly the kind
    /// of thing a stray edit breaks silently. Every card has to hold together:
    /// 18 pars, and a stroke index that's a permutation of 1–18 — a duplicated
    /// or missing stroke index would misallocate handicap strokes.
    func testEveryCourseCardIsCoherent() {
        XCTAssertFalse(Course.all.isEmpty)
        for course in Course.all {
            XCTAssertEqual(course.holePars.count, 18, course.name)
            XCTAssertEqual(course.strokeIndex.count, 18, course.name)
            XCTAssertEqual(Set(course.strokeIndex), Set(1...18), course.name)
            XCTAssertEqual(course.frontNinePar + course.backNinePar, course.par, course.name)
            XCTAssertTrue((68...74).contains(course.par), course.name)
        }
    }

    func testCourseLookup() {
        XCTAssertEqual(Course.by("c1")?.name, "Cobblestone Golf Course")
        XCTAssertNil(Course.by("nope"))
    }

    // MARK: - Round

    func testScorecardRoundDerivesItsTotal() {
        let scores = [4, 5, 3, 6, 4, 4, 4, 5, 4, 5, 5, 3, 4, 5, 3, 4, 5, 6]
        let round = Round(playerID: UUID(), courseID: "c1", holeScores: scores, par: 71)
        XCTAssertEqual(round.strokes, 79)
        XCTAssertEqual(round.toPar, 8)
        XCTAssertTrue(round.hasScorecard)
        XCTAssertEqual(round.frontNine, Array(scores.prefix(9)))
        XCTAssertEqual(round.backNine, Array(scores.suffix(9)))
    }

    func testTotalOnlyRoundHasNoScorecard() {
        let round = Round(playerID: UUID(), courseID: "c1", strokes: 83, par: 72)
        XCTAssertFalse(round.hasScorecard)
        XCTAssertEqual(round.toPar, 11)
    }

    // MARK: - Groups

    func testGroupContainsItsOwnerExactlyOnce() {
        let owner = UUID()
        let member = UUID()
        let group = PlayerGroup(name: "Crew", ownerID: owner,
                                memberIDs: [member, owner, member])
        XCTAssertEqual(group.memberIDs, [owner.uuidString, member.uuidString])
    }

    func testUniquedPreservesOrder() {
        XCTAssertEqual([3, 1, 3, 2, 1].uniqued(), [3, 1, 2])
    }

    // MARK: - Visibility gating

    func testClubVisibilityIsOnlyOfferedAtPrivateCourses() {
        let publicCourse = Course.by("c1")   // anyone can book it
        let privateCourse = Course.by("c5")  // Brookstone

        XCTAssertFalse(RoundVisibility.options(for: publicCourse).contains(.club))
        XCTAssertTrue(RoundVisibility.options(for: privateCourse).contains(.club))
        XCTAssertFalse(RoundVisibility.options(for: nil).contains(.club))
        // Every other tier is always on the table.
        XCTAssertEqual(RoundVisibility.options(for: publicCourse),
                       [.area, .friendsOfFriends, .friends, .selected])
    }

    func testClubPostsNeedAHomeCourse() {
        let homeless = Player(name: "Ryan")
        XCTAssertFalse(PostAudience.options(for: homeless).contains(.club))

        let member = Player(name: "Marcus")
        member.homeCourseID = "c5"
        XCTAssertTrue(PostAudience.options(for: member).contains(.club))
    }

    // MARK: - Score kinds

    func testPerHoleScoreKinds() {
        XCTAssertEqual(scoreKind(toPar: -2), .eagle)
        XCTAssertEqual(scoreKind(toPar: -1), .birdie)
        XCTAssertEqual(scoreKind(toPar: 0), .par)
        XCTAssertEqual(scoreKind(toPar: 1), .bogey)
        XCTAssertEqual(scoreKind(toPar: 2), .doublePlus)
    }

    /// Whole-round bands are looser on purpose — one stroke across 18 holes is
    /// noise, not a bogey.
    func testWholeRoundScoreKinds() {
        XCTAssertEqual(roundScoreKind(toPar: -3), .eagle)
        XCTAssertEqual(roundScoreKind(toPar: -1), .birdie)
        XCTAssertEqual(roundScoreKind(toPar: 0), .par)
        XCTAssertEqual(roundScoreKind(toPar: 3), .bogey)
        XCTAssertEqual(roundScoreKind(toPar: 4), .doublePlus)
    }

    func testToParText() {
        XCTAssertEqual(toParText(0), "E")
        XCTAssertEqual(toParText(3), "+3")
        XCTAssertEqual(toParText(-2), "-2")
    }

    // MARK: - Leaderboard periods

    func testPeriodStartsLandOnCalendarBoundaries() throws {
        let calendar = Calendar.current
        let now = Date.now

        XCTAssertNil(LeaderboardPeriod.allTime.start(now: now, calendar: calendar))

        let week = try XCTUnwrap(LeaderboardPeriod.week.start(now: now, calendar: calendar))
        XCTAssertLessThanOrEqual(week, now)
        XCTAssertEqual(calendar.startOfDay(for: week), week,
                       "a week starts at midnight, not mid-day")

        let month = try XCTUnwrap(LeaderboardPeriod.month.start(now: now, calendar: calendar))
        XCTAssertLessThanOrEqual(month, now)
        XCTAssertEqual(calendar.component(.day, from: month), 1)

        let year = try XCTUnwrap(LeaderboardPeriod.year.start(now: now, calendar: calendar))
        XCTAssertEqual(calendar.component(.day, from: year), 1)
        XCTAssertEqual(calendar.component(.month, from: year), 1)
        XCTAssertEqual(calendar.component(.year, from: year),
                       calendar.component(.year, from: now))
    }
}
