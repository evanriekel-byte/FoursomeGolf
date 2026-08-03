import XCTest
import SwiftData
@testable import Foursome

/// Exercises the SwiftData layer against a real store.
///
/// The rest of the suite tests pure values — `Handicap`, `SocialGraph`, and the
/// free functions in `Models` — which is why it never needed a container. That
/// left everything `@Model` untested: whether the models actually persist,
/// whether the array-backed properties survive a round trip, and whether the
/// mutations the views perform leave the store in the state the UI assumes.
///
/// The container is in-memory, so these run at unit-test speed and leave
/// nothing on disk between runs.
final class StoreTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try Self.makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    /// Every `@Model` in the app, matching the container declared in
    /// `FoursomeApp`. A model missing here fails to fetch rather than failing
    /// to compile, so the two lists have to be kept in step by hand.
    static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Player.self, Round.self, OpenRound.self,
                 Friendship.self, PlayerGroup.self, Post.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    // MARK: - Round trips

    func testPlayerSurvivesASaveAndFetch() throws {
        let player = Player(name: "Marcus Vale")
        player.handicapIndex = 8.2
        player.homeCourseID = "c5"
        context.insert(player)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<Player>()).first)
        XCTAssertEqual(fetched.name, "Marcus Vale")
        XCTAssertEqual(fetched.handle, "marcusvale", "handle is derived at init and must persist")
        XCTAssertEqual(fetched.handicapIndex, 8.2)
        XCTAssertEqual(fetched.homeCourseID, "c5")
        XCTAssertFalse(fetched.isDemo)
    }

    /// `scoringMode` is a computed bridge over `scoringModeRaw`. Only the raw
    /// string is persisted, so the accessor is the part that can silently stop
    /// agreeing with the store.
    func testScoringModeBridgesThroughItsRawValue() throws {
        let player = Player(name: "Tyler")
        XCTAssertEqual(player.scoringMode, .personal, "personal is the default")
        player.scoringMode = .scratch
        context.insert(player)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<Player>()).first)
        XCTAssertEqual(fetched.scoringModeRaw, "scratch")
        XCTAssertEqual(fetched.scoringMode, .scratch)
    }

    /// An unrecognised raw value has to degrade to the default rather than
    /// trap — this is the shape a future schema change arrives in.
    func testUnknownScoringModeFallsBackToPersonal() throws {
        let player = Player(name: "Deshawn")
        player.scoringModeRaw = "handicap-v2-from-the-future"
        context.insert(player)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<Player>()).first)
        XCTAssertEqual(fetched.scoringMode, .personal)
    }

    /// `holeScores` is an `[Int]` attribute. Array-backed properties are the
    /// ones that quietly come back empty when a schema detail is wrong, and an
    /// empty card reads as a total-only round rather than as data loss.
    func testScorecardArraySurvivesTheStore() throws {
        let scores = [4, 5, 3, 6, 4, 4, 4, 5, 4, 5, 5, 3, 4, 5, 3, 4, 5, 6]
        context.insert(Round(playerID: UUID(), courseID: "c1", holeScores: scores, par: 71))
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<Round>()).first)
        XCTAssertEqual(fetched.holeScores, scores)
        XCTAssertTrue(fetched.hasScorecard)
        XCTAssertEqual(fetched.strokes, 79, "the derived total has to persist alongside the card")
        XCTAssertEqual(fetched.frontNine, Array(scores.prefix(9)))
    }

    func testOpenRoundRosterArraysSurviveTheStore() throws {
        let host = UUID()
        let guest = UUID()
        let round = OpenRound(hostID: host, courseID: "c1", date: .now, time: "8:10 AM",
                              spots: 4, note: "Saturday loop.", visibility: .friendsOfFriends)
        round.joined = [host.uuidString, guest.uuidString]
        round.pending = [UUID().uuidString]
        context.insert(round)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<OpenRound>()).first)
        XCTAssertEqual(fetched.joined.count, 2)
        XCTAssertEqual(fetched.pending.count, 1)
        XCTAssertEqual(fetched.openSpots, 2)
        XCTAssertEqual(fetched.visibility, .friendsOfFriends,
                       "visibility bridges through visibilityRaw the same way scoringMode does")
    }

    /// The host occupies a spot from the moment the round is posted, which is
    /// what makes `openSpots` read correctly on a freshly posted round.
    func testHostOccupiesASpotOnCreation() throws {
        let host = UUID()
        let round = OpenRound(hostID: host, courseID: "c1", date: .now, time: "9:00 AM",
                              spots: 4, note: "")
        XCTAssertEqual(round.joined, [host.uuidString])
        XCTAssertEqual(round.openSpots, 3)
    }

    // MARK: - Mutation paths the views drive

    /// `FeedView.delete(_:)` — the round has to be gone from the store, not
    /// just from the view, or a relaunch brings it back.
    func testDeletingARoundRemovesItFromTheStore() throws {
        let round = Round(playerID: UUID(), courseID: "c1", strokes: 83, par: 72)
        context.insert(round)
        try context.save()
        XCTAssertEqual(try count(Round.self), 1)

        context.delete(round)
        try context.save()
        XCTAssertEqual(try count(Round.self), 0)
    }

    /// `OpenRoundsView.cancel(_:)`.
    func testCancellingAnOpenRoundRemovesItFromTheStore() throws {
        let round = OpenRound(hostID: UUID(), courseID: "c3", date: .now, time: "3:40 PM",
                              spots: 2, note: "Twilight nine.")
        context.insert(round)
        try context.save()

        context.delete(round)
        try context.save()
        XCTAssertEqual(try count(OpenRound.self), 0)
    }

    /// The recovery path added to `delete` and `cancel`: when the save throws,
    /// the context is rolled back so the row returns instead of vanishing from
    /// a screen it is still present on for everyone else.
    func testRollbackRestoresADeleteThatWasNotSaved() throws {
        let round = Round(playerID: UUID(), courseID: "c1", strokes: 83, par: 72)
        context.insert(round)
        try context.save()

        context.delete(round)
        context.rollback()

        XCTAssertEqual(try count(Round.self), 1,
                       "a rolled-back delete has to leave the round in the store")
    }

    // MARK: - DemoData.wipe

    /// `wipe` clears the store so `seedIfNeeded` can rebuild it. Anything it
    /// misses becomes an orphan: a round or friendship pointing at a player ID
    /// that no longer resolves, which renders as "Someone" forever.
    func testWipeEmptiesEveryModel() throws {
        let marcus = Player(name: "Marcus")
        let tyler = Player(name: "Tyler")
        [marcus, tyler].forEach { context.insert($0) }
        context.insert(Round(playerID: marcus.id, courseID: "c1", strokes: 79, par: 71))
        context.insert(OpenRound(hostID: tyler.id, courseID: "c1", date: .now,
                                 time: "8:10 AM", spots: 4, note: ""))
        context.insert(Friendship(requesterID: marcus.id, addresseeID: tyler.id, accepted: true))
        context.insert(PlayerGroup(name: "Saturday regulars", ownerID: tyler.id,
                                   memberIDs: [marcus.id]))
        context.insert(Post(authorID: marcus.id, text: "New irons.", audience: .friends))
        try context.save()

        try DemoData.wipe(context)

        XCTAssertEqual(try count(Player.self), 0)
        XCTAssertEqual(try count(Round.self), 0)
        XCTAssertEqual(try count(OpenRound.self), 0)
        XCTAssertEqual(try count(Friendship.self), 0)
        XCTAssertEqual(try count(PlayerGroup.self), 0)
        XCTAssertEqual(try count(Post.self), 0)
    }

    func testWipeOnAnEmptyStoreIsHarmless() throws {
        XCTAssertNoThrow(try DemoData.wipe(context))
        XCTAssertEqual(try count(Player.self), 0)
    }

    // MARK: - Seeding guard

    /// `seedIfNeeded` decides from the store, not a flag: it seeds only when no
    /// demo player is present. A real sign-in must not look like a seeded
    /// clubhouse, or a reset never reseeds.
    func testDemoFlagDistinguishesSeededPlayersFromRealOnes() throws {
        let seeded = Player(name: "Marcus")
        seeded.isDemo = true
        let real = Player(name: "Evan")
        [seeded, real].forEach { context.insert($0) }
        try context.save()

        let players = try context.fetch(FetchDescriptor<Player>())
        XCTAssertFalse(players.allSatisfy { !$0.isDemo },
                       "a demo player is present, so seeding must not run again")
        XCTAssertEqual(players.filter(\.isDemo).count, 1)

        try DemoData.wipe(context)
        let afterWipe = try context.fetch(FetchDescriptor<Player>())
        XCTAssertTrue(afterWipe.allSatisfy { !$0.isDemo },
                      "an emptied store must be seedable again")
    }
}
