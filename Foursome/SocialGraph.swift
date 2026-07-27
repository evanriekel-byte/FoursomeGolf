import Foundation

/// Resolves the friend graph and answers "who can see this open round".
///
/// Deliberately a plain value type over already-fetched arrays rather than
/// something that queries a store. That keeps it (a) trivially testable and
/// (b) portable: the same `audience(for:)` call runs locally at read time
/// today, and at *write* time against Firestore later, where its result is
/// stored on the document as a denormalized `audienceIDs` field. Firestore
/// can't join, so "friends of friends" has to be answered by data shape, and
/// this is the single place that shape gets computed.
struct SocialGraph {
    let friendships: [Friendship]
    let groups: [PlayerGroup]

    init(friendships: [Friendship], groups: [PlayerGroup] = []) {
        self.friendships = friendships
        self.groups = groups
    }

    // MARK: - Graph queries

    /// Accepted friends of `playerID`.
    func friends(of playerID: UUID) -> Set<UUID> {
        var result = Set<UUID>()
        for f in friendships where f.accepted {
            if let other = f.other(than: playerID) { result.insert(other) }
        }
        return result
    }

    /// Friends-of-friends, excluding `playerID` and their direct friends.
    func friendsOfFriends(of playerID: UUID) -> Set<UUID> {
        let direct = friends(of: playerID)
        var result = Set<UUID>()
        for friend in direct {
            result.formUnion(friends(of: friend))
        }
        result.subtract(direct)
        result.remove(playerID)
        return result
    }

    /// Incoming requests awaiting `playerID`'s response.
    func pendingRequests(for playerID: UUID) -> [Friendship] {
        friendships.filter { !$0.accepted && $0.addresseeID == playerID }
    }

    /// Requests `playerID` has sent that haven't been accepted yet.
    func sentRequests(from playerID: UUID) -> [Friendship] {
        friendships.filter { !$0.accepted && $0.requesterID == playerID }
    }

    /// The existing edge between two players, in either direction.
    func edge(between a: UUID, and b: UUID) -> Friendship? {
        friendships.first { $0.involves(a) && $0.involves(b) }
    }

    func members(ofGroup groupID: UUID) -> Set<UUID> {
        guard let group = groups.first(where: { $0.id == groupID }) else { return [] }
        return Set(group.memberIDs.compactMap(UUID.init(uuidString:)))
    }

    // MARK: - Visibility

    /// The explicit set of players who can see `round`.
    ///
    /// Returns `nil` for `.area`, which is intentional: an area-visible round
    /// has an unbounded audience, so materializing a list is wrong. Callers
    /// treat `nil` as "not a member-list check — match on `areaKey` instead".
    /// In Firestore this is the difference between querying
    /// `audienceIDs contains me` and querying `areaKey == myArea`.
    func audience(for round: OpenRound) -> Set<UUID>? {
        let host = round.hostID

        switch round.visibility {
        case .area:
            return nil

        case .friendsOfFriends:
            var set = friends(of: host)
            set.formUnion(friendsOfFriends(of: host))
            set.insert(host)
            return set

        case .friends:
            var set = friends(of: host)
            set.insert(host)
            return set

        case .selected:
            var set = Set(round.invitedPlayerIDs.compactMap(UUID.init(uuidString:)))
            for groupID in round.invitedGroupIDs.compactMap(UUID.init(uuidString:)) {
                set.formUnion(members(ofGroup: groupID))
            }
            set.insert(host)
            return set
        }
    }

    /// Whether `viewer` can see `round`.
    ///
    /// `viewerAreas` is the set of area keys the viewer counts as "nearby" —
    /// today, the cities of courses they've played or have a round posted at.
    /// Anyone already joined or requested stays able to see the round even if
    /// the host later narrows visibility, so a group never loses the thread.
    func canView(_ round: OpenRound, as viewer: UUID, viewerAreas: Set<String> = []) -> Bool {
        if round.hostID == viewer { return true }

        let viewerKey = viewer.uuidString
        if round.joined.contains(viewerKey) || round.pending.contains(viewerKey) { return true }

        guard let audience = audience(for: round) else {
            // .area — match on the course's city.
            guard let key = round.areaKey else { return false }
            return viewerAreas.contains(key)
        }
        return audience.contains(viewer)
    }

    /// Filters a list of rounds down to what `viewer` is allowed to see.
    func visibleRounds(from rounds: [OpenRound], as viewer: UUID,
                       viewerAreas: Set<String> = []) -> [OpenRound] {
        rounds.filter { canView($0, as: viewer, viewerAreas: viewerAreas) }
    }
}

// MARK: - Area helpers

extension SocialGraph {
    /// The areas a player counts as local to, derived from where they actually
    /// play. Avoids asking for location permission before there's a reason to.
    static func areas(forPlayer playerID: UUID,
                      rounds: [Round],
                      openRounds: [OpenRound]) -> Set<String> {
        var keys = Set<String>()
        for r in rounds where r.playerID == playerID {
            if let city = Course.by(r.courseID)?.city { keys.insert(city) }
        }
        for o in openRounds where o.joined.contains(playerID.uuidString) {
            if let key = o.areaKey { keys.insert(key) }
        }
        return keys
    }
}
