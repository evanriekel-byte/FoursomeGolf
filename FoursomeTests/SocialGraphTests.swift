import XCTest
@testable import Foursome

/// SocialGraph is the one place "who can see this" gets computed, and the
/// audiences it resolves locally today are exactly what gets denormalized onto
/// Firestore documents in Milestone 2 — so these tests are the spec the sync
/// layer has to keep true.
///
/// The cast mirrors the seeded demo clubhouse: Marcus–Tyler and Marcus–Deshawn
/// are friends, Tyler–Ryan are friends, and Ryan has a pending request out to
/// Marcus. Marcus and Tyler call Brookstone (c5, private) home, Deshawn plays
/// out of Cherokee Run (c2), and Ryan has no home course.
final class SocialGraphTests: XCTestCase {
    private var marcus: Player!
    private var tyler: Player!
    private var deshawn: Player!
    private var ryan: Player!
    private var saturdayCrew: PlayerGroup!
    private var graph: SocialGraph!

    override func setUp() {
        super.setUp()
        marcus = Player(name: "Marcus")
        tyler = Player(name: "Tyler")
        deshawn = Player(name: "Deshawn")
        ryan = Player(name: "Ryan")
        marcus.homeCourseID = "c5"
        tyler.homeCourseID = "c5"
        deshawn.homeCourseID = "c2"

        let friendships = [
            Friendship(requesterID: marcus.id, addresseeID: tyler.id, accepted: true),
            Friendship(requesterID: marcus.id, addresseeID: deshawn.id, accepted: true),
            Friendship(requesterID: tyler.id, addresseeID: ryan.id, accepted: true),
            Friendship(requesterID: ryan.id, addresseeID: marcus.id, accepted: false),
        ]
        saturdayCrew = PlayerGroup(name: "Saturday regulars", ownerID: tyler.id,
                                   memberIDs: [marcus.id, ryan.id])
        graph = SocialGraph(friendships: friendships,
                            groups: [saturdayCrew],
                            players: [marcus, tyler, deshawn, ryan])
    }

    private func openRound(host: Player, courseID: String = "c1",
                           visibility: RoundVisibility,
                           invitedPlayerIDs: [UUID] = [],
                           invitedGroupIDs: [UUID] = []) -> OpenRound {
        OpenRound(hostID: host.id, courseID: courseID,
                  date: .now.addingTimeInterval(86_400), time: "8:00 AM",
                  spots: 4, note: "", visibility: visibility,
                  invitedPlayerIDs: invitedPlayerIDs,
                  invitedGroupIDs: invitedGroupIDs)
    }

    // MARK: - Graph queries

    func testFriendsCountsOnlyAcceptedEdges() {
        XCTAssertEqual(graph.friends(of: marcus.id), [tyler.id, deshawn.id])
        // Ryan's request to Marcus is still pending, so neither side counts it.
        XCTAssertEqual(graph.friends(of: ryan.id), [tyler.id])
    }

    func testFriendsOfFriendsExcludesSelfAndDirectFriends() {
        // Marcus's only two-hop reach is Ryan, through Tyler.
        XCTAssertEqual(graph.friendsOfFriends(of: marcus.id), [ryan.id])
        // And Ryan's is Marcus, back through the same edge.
        XCTAssertEqual(graph.friendsOfFriends(of: ryan.id), [marcus.id])
    }

    func testScopedIDsEveryoneMeansNoFilter() {
        // nil is "no filter" — distinct from an empty set, which would mean
        // "show nothing".
        XCTAssertNil(graph.scopedIDs(.everyone, viewer: marcus.id))
    }

    func testScopedIDsFriendsIncludesTheViewer() {
        // Filtering to friends must never hide your own rounds.
        XCTAssertEqual(graph.scopedIDs(.friends, viewer: marcus.id),
                       [marcus.id, tyler.id, deshawn.id])
    }

    func testPendingAndSentRequestsAreDirectional() {
        XCTAssertEqual(graph.pendingRequests(for: marcus.id).map(\.requesterID), [ryan.id])
        // The requester sees the same edge as sent, not pending.
        XCTAssertTrue(graph.pendingRequests(for: ryan.id).isEmpty)
        XCTAssertEqual(graph.sentRequests(from: ryan.id).map(\.addresseeID), [marcus.id])
    }

    func testEdgeLookupIgnoresDirection() {
        XCTAssertNotNil(graph.edge(between: tyler.id, and: marcus.id))
        XCTAssertNotNil(graph.edge(between: marcus.id, and: tyler.id))
        // A pending edge still counts — it's what blocks a duplicate request.
        XCTAssertNotNil(graph.edge(between: marcus.id, and: ryan.id))
        XCTAssertNil(graph.edge(between: deshawn.id, and: ryan.id))
    }

    func testGroupMembersResolveFromStoredStrings() {
        XCTAssertEqual(graph.members(ofGroup: saturdayCrew.id),
                       [tyler.id, marcus.id, ryan.id])
        XCTAssertTrue(graph.members(ofGroup: UUID()).isEmpty)
    }

    func testCourseMembersComeFromHomeCourse() {
        XCTAssertEqual(graph.members(ofCourse: "c5"), [marcus.id, tyler.id])
        XCTAssertTrue(graph.members(ofCourse: "c1").isEmpty)
    }

    // MARK: - Open round audiences

    func testAreaRoundHasNoMaterializedAudience() {
        // Unbounded on purpose: callers match on areaKey instead. In Firestore
        // terms, `areaKey == myArea` rather than `audienceIDs contains me`.
        XCTAssertNil(graph.audience(for: openRound(host: tyler, visibility: .area)))
    }

    func testFriendsAudienceIsFriendsPlusHost() {
        XCTAssertEqual(graph.audience(for: openRound(host: tyler, visibility: .friends)),
                       [tyler.id, marcus.id, ryan.id])
    }

    func testFriendsOfFriendsAudienceReachesTwoHops() {
        // From Marcus that's the whole demo cast.
        XCTAssertEqual(graph.audience(for: openRound(host: marcus, visibility: .friendsOfFriends)),
                       [marcus.id, tyler.id, deshawn.id, ryan.id])
    }

    func testClubAudienceIsMembersPlusHost() {
        // Deshawn isn't a Brookstone member, but hosting there still keeps him
        // in his own round's audience.
        XCTAssertEqual(graph.audience(for: openRound(host: deshawn, courseID: "c5",
                                                     visibility: .club)),
                       [deshawn.id, marcus.id, tyler.id])
    }

    func testSelectedAudienceResolvesPeopleAndGroups() {
        let round = openRound(host: deshawn, visibility: .selected,
                              invitedPlayerIDs: [marcus.id],
                              invitedGroupIDs: [saturdayCrew.id])
        XCTAssertEqual(graph.audience(for: round),
                       [deshawn.id, marcus.id, tyler.id, ryan.id])
    }

    // MARK: - canView

    func testHostAlwaysSeesTheirOwnRound() {
        XCTAssertTrue(graph.canView(openRound(host: deshawn, visibility: .selected),
                                    as: deshawn.id))
    }

    func testFriendsRoundIsInvisibleOutsideTheAudience() {
        let round = openRound(host: tyler, visibility: .friends)
        XCTAssertTrue(graph.canView(round, as: ryan.id))
        XCTAssertFalse(graph.canView(round, as: deshawn.id))
    }

    func testJoinedAndPendingPlayersKeepSeeingANarrowedRound() {
        // Deshawn is not Tyler's friend, but he's already in the group (or has
        // asked to be) — narrowing visibility must never lose him the thread.
        let joined = openRound(host: tyler, visibility: .friends)
        joined.joined.append(deshawn.id.uuidString)
        XCTAssertTrue(graph.canView(joined, as: deshawn.id))

        let asked = openRound(host: tyler, visibility: .friends)
        asked.pending.append(deshawn.id.uuidString)
        XCTAssertTrue(graph.canView(asked, as: deshawn.id))
    }

    func testAreaRoundMatchesOnTheCourseCity() {
        let round = openRound(host: tyler, courseID: "c1", visibility: .area)  // Acworth
        XCTAssertTrue(graph.canView(round, as: deshawn.id, viewerAreas: ["Acworth"]))
        XCTAssertFalse(graph.canView(round, as: deshawn.id, viewerAreas: ["Conyers"]))
        // No areas at all — a brand-new player — sees nothing area-scoped.
        XCTAssertFalse(graph.canView(round, as: deshawn.id))
    }

    func testVisibleRoundsKeepsOrderAndDropsTheRest() {
        let mine = openRound(host: ryan, visibility: .friends)
        let friendly = openRound(host: tyler, visibility: .friends)
        let closed = openRound(host: deshawn, visibility: .friends)

        XCTAssertEqual(graph.visibleRounds(from: [mine, friendly, closed], as: ryan.id).map(\.id),
                       [mine.id, friendly.id])
    }

    // MARK: - Posts

    func testFriendsPostReachesFriendsOnly() {
        let post = Post(authorID: deshawn.id, text: "New irons", audience: .friends)
        XCTAssertEqual(graph.audience(for: post), [deshawn.id, marcus.id])
        XCTAssertTrue(graph.canView(post, as: marcus.id))
        XCTAssertFalse(graph.canView(post, as: tyler.id))
        XCTAssertTrue(graph.canView(post, as: deshawn.id),
                      "The author always sees their own post")
    }

    func testClubPostUsesTheAuthorsHomeCourse() {
        let post = Post(authorID: tyler.id, text: "Greens aerated", audience: .club)
        XCTAssertEqual(graph.audience(for: post), [tyler.id, marcus.id])
        XCTAssertFalse(graph.canView(post, as: deshawn.id))
    }

    func testClubPostWithNoHomeCourseReachesOnlyTheAuthor() {
        let post = Post(authorID: ryan.id, text: "Hello?", audience: .club)
        XCTAssertEqual(graph.audience(for: post), [ryan.id])
    }

    func testFriendsOfFriendsPostReachesTwoHops() {
        let post = Post(authorID: marcus.id, text: "Anyone Saturday?",
                        audience: .friendsOfFriends)
        XCTAssertEqual(graph.audience(for: post),
                       [marcus.id, tyler.id, deshawn.id, ryan.id])
    }

    func testSelectedPostResolvesGroups() {
        let post = Post(authorID: deshawn.id, text: "Crew only", audience: .selected,
                        invitedGroupIDs: [saturdayCrew.id])
        XCTAssertEqual(graph.audience(for: post),
                       [deshawn.id, tyler.id, marcus.id, ryan.id])
        XCTAssertEqual(graph.visiblePosts(from: [post], as: tyler.id).map(\.id), [post.id])
        XCTAssertTrue(graph.visiblePosts(from: [post], as: UUID()).isEmpty)
    }

    // MARK: - Areas

    func testAreasComeFromPlayedAndJoinedRounds() {
        let played = Round(playerID: deshawn.id, courseID: "c1", strokes: 90, par: 71)  // Acworth
        let joined = openRound(host: tyler, courseID: "c2", visibility: .area)          // Conyers
        joined.joined.append(deshawn.id.uuidString)
        let notJoined = openRound(host: tyler, courseID: "c3", visibility: .area)       // Woodstock

        XCTAssertEqual(SocialGraph.areas(forPlayer: deshawn.id,
                                         rounds: [played],
                                         openRounds: [joined, notJoined]),
                       ["Acworth", "Conyers"])
    }
}
