import Foundation
import SwiftData

// MARK: - Course (static reference data, not stored in SwiftData)

struct Course: Identifiable, Hashable {
    let id: String
    let name: String
    let city: String

    /// Par for each of the 18 holes, in play order.
    let holePars: [Int]

    /// Difficulty ranking, 1 (hardest) to 18 (easiest). Handicap strokes are
    /// given out in this order, so a 9-handicap gets one on stroke index 1-9
    /// and nothing on the rest. Without it, strokes could only be spread evenly
    /// and a net score would be meaningless on any single hole.
    let strokeIndex: [Int]

    /// Members-only. Gates the club-only visibility tier, which is meaningless
    /// on a course anyone can book.
    ///
    /// Placeholder data — verify each course before this reaches real users.
    var isPrivate: Bool = false

    /// Derived, so course par can never drift out of step with the holes.
    var par: Int { holePars.reduce(0, +) }
    var frontNinePar: Int { holePars.prefix(9).reduce(0, +) }
    var backNinePar: Int { holePars.suffix(9).reduce(0, +) }

    static let all: [Course] = [
        Course(id: "c1", name: "Cobblestone Golf Course", city: "Acworth",
               holePars:    [4, 4, 3, 5, 4, 4, 3, 4, 4,  4, 5, 3, 4, 4, 3, 4, 4, 5],   // 35 + 36 = 71
               strokeIndex: [5, 11, 17, 1, 7, 13, 15, 3, 9,  6, 2, 18, 10, 4, 16, 12, 8, 14]),
        Course(id: "c2", name: "Cherokee Run", city: "Conyers",
               holePars:    [4, 5, 3, 4, 4, 3, 5, 4, 4,  4, 3, 4, 5, 4, 4, 3, 5, 4],   // 36 + 36 = 72
               strokeIndex: [3, 9, 17, 7, 1, 15, 11, 5, 13,  8, 18, 4, 12, 2, 10, 16, 14, 6]),
        Course(id: "c3", name: "Towne Lake Hills", city: "Woodstock",
               holePars:    [5, 4, 4, 3, 4, 5, 3, 4, 4,  4, 4, 3, 5, 4, 3, 4, 5, 4],   // 36 + 36 = 72
               strokeIndex: [7, 1, 11, 17, 5, 9, 15, 3, 13,  4, 10, 18, 8, 2, 16, 12, 14, 6]),
        Course(id: "c4", name: "Bear's Best Atlanta", city: "Suwanee",
               holePars:    [4, 3, 5, 4, 4, 4, 3, 5, 4,  5, 4, 3, 4, 4, 4, 3, 4, 5],   // 36 + 36 = 72
               strokeIndex: [1, 15, 9, 5, 11, 7, 17, 13, 3,  10, 2, 18, 6, 12, 8, 16, 4, 14]),
        Course(id: "c5", name: "Brookstone", city: "Acworth",
               holePars:    [4, 4, 5, 3, 4, 4, 4, 3, 5,  4, 5, 4, 3, 4, 4, 5, 3, 4],   // 36 + 36 = 72
               strokeIndex: [9, 3, 13, 17, 1, 7, 11, 15, 5,  2, 14, 6, 18, 4, 10, 12, 16, 8],
               isPrivate: true),
        Course(id: "c6", name: "The Frog at The Georgian", city: "Villa Rica",
               holePars:    [4, 4, 3, 4, 5, 4, 3, 4, 5,  4, 3, 5, 4, 4, 3, 4, 4, 5],   // 36 + 36 = 72
               strokeIndex: [5, 1, 15, 9, 11, 3, 17, 7, 13,  6, 18, 12, 2, 8, 16, 10, 4, 14]),
    ]

    static func by(_ id: String) -> Course? { all.first { $0.id == id } }
}

// MARK: - Player

@Model
final class Player {
    @Attribute(.unique) var id: UUID
    var name: String
    var handle: String
    var createdAt: Date

    /// A handicap index the player entered by hand. This is the field a GHIN
    /// sync would populate if we ever get licensed access, so nothing
    /// downstream has to change when that happens. Nil means "work it out from
    /// my rounds instead".
    var handicapIndex: Double?

    /// Where this player usually plays. Optional on purpose — plenty of people
    /// have no home course, and demanding one at signup would be a wall in
    /// front of the door. Also decides who counts as a fellow member for
    /// club-only invites.
    var homeCourseID: String?

    /// Whether scores are marked against this player's own baseline or against
    /// scratch. Stored raw for SwiftData; read through `scoringMode`.
    var scoringModeRaw: String

    var scoringMode: ScoringMode {
        get { ScoringMode(rawValue: scoringModeRaw) ?? .personal }
        set { scoringModeRaw = newValue.rawValue }
    }

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.handle = name.lowercased().replacingOccurrences(of: " ", with: "")
        self.createdAt = .now
        self.handicapIndex = nil
        self.homeCourseID = nil
        self.scoringModeRaw = ScoringMode.personal.rawValue
    }
}

/// What a hole's score gets measured against.
enum ScoringMode: String, Codable, CaseIterable, Identifiable {
    /// Net of the player's handicap — a bogey golfer playing to their number
    /// sees bare pars, not a wall of doubles.
    case personal
    /// Classic scratch notation, measured straight against par.
    case scratch

    var id: String { rawValue }

    var label: String { self == .personal ? "My game" : "Scratch" }
    var detail: String {
        self == .personal
            ? "Marks holes against your handicap, so par means par for you."
            : "Marks holes against the card, the way a scratch player reads it."
    }
}

// MARK: - Round (a played, scored round)

@Model
final class Round {
    @Attribute(.unique) var id: UUID
    var playerID: UUID
    var courseID: String
    var strokes: Int
    var par: Int
    var date: Date
    var createdAt: Date

    /// Strokes per hole, in play order. Empty when only a total was logged —
    /// a round entered quickly, or one imported before scorecards existed.
    /// `strokes` stays authoritative either way, so nothing has to branch on
    /// this just to show a score.
    var holeScores: [Int]

    /// Total-only entry.
    init(playerID: UUID, courseID: String, strokes: Int, par: Int, date: Date = .now) {
        self.id = UUID()
        self.playerID = playerID
        self.courseID = courseID
        self.strokes = strokes
        self.par = par
        self.date = date
        self.createdAt = .now
        self.holeScores = []
    }

    /// Full scorecard. The total is derived, so the two can't disagree.
    init(playerID: UUID, courseID: String, holeScores: [Int], par: Int, date: Date = .now) {
        self.id = UUID()
        self.playerID = playerID
        self.courseID = courseID
        self.strokes = holeScores.reduce(0, +)
        self.par = par
        self.date = date
        self.createdAt = .now
        self.holeScores = holeScores
    }

    var toPar: Int { strokes - par }

    /// Whether there's a hole-by-hole card to show.
    var hasScorecard: Bool { holeScores.count == 18 }

    var frontNine: [Int] { Array(holeScores.prefix(9)) }
    var backNine: [Int] { Array(holeScores.suffix(9)) }
}

// MARK: - Friendship (an edge in the friend graph)

/// One row per pair, regardless of direction. `requesterID` is who asked, so
/// the receiving side can be shown an accept/decline prompt.
@Model
final class Friendship {
    @Attribute(.unique) var id: UUID
    var requesterID: UUID
    var addresseeID: UUID
    var accepted: Bool
    var createdAt: Date

    init(requesterID: UUID, addresseeID: UUID, accepted: Bool = false) {
        self.id = UUID()
        self.requesterID = requesterID
        self.addresseeID = addresseeID
        self.accepted = accepted
        self.createdAt = .now
    }

    func involves(_ playerID: UUID) -> Bool {
        requesterID == playerID || addresseeID == playerID
    }

    /// The other end of the edge, given one end.
    func other(than playerID: UUID) -> UUID? {
        if requesterID == playerID { return addresseeID }
        if addresseeID == playerID { return requesterID }
        return nil
    }
}

// MARK: - PlayerGroup (a named set of players, e.g. "Saturday regulars")

@Model
final class PlayerGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var ownerID: UUID
    var memberIDs: [String]   // player id uuidStrings, includes the owner
    var createdAt: Date

    init(name: String, ownerID: UUID, memberIDs: [UUID] = []) {
        self.id = UUID()
        self.name = name
        self.ownerID = ownerID
        self.memberIDs = ([ownerID] + memberIDs).map(\.uuidString).uniqued()
        self.createdAt = .now
    }
}

// MARK: - Visibility

/// Who can see an open round. Ordered widest to narrowest.
enum RoundVisibility: String, Codable, CaseIterable, Identifiable {
    case area             // anyone playing in this course's area
    case friendsOfFriends
    case club             // members whose home course is this course
    case friends
    case selected         // specific people and/or groups

    var id: String { rawValue }

    var label: String {
        switch self {
        case .area:             return "Anyone nearby"
        case .friendsOfFriends: return "Friends of friends"
        case .club:             return "Members here"
        case .friends:          return "Friends only"
        case .selected:         return "Specific people"
        }
    }

    var detail: String {
        switch self {
        case .area:             return "Shows to any player in the course's area."
        case .friendsOfFriends: return "Your friends, and their friends."
        case .club:             return "Only players whose home course is this one."
        case .friends:          return "Only people you've added."
        case .selected:         return "Only the people and groups you pick."
        }
    }

    var systemImage: String {
        switch self {
        case .area:             return "globe.americas"
        case .friendsOfFriends: return "person.2.wave.2"
        case .club:             return "building.columns"
        case .friends:          return "person.2"
        case .selected:         return "person.crop.circle.badge.checkmark"
        }
    }

    /// Club-only makes no sense on a course anyone can book a tee time at.
    func isAvailable(for course: Course?) -> Bool {
        self != .club || (course?.isPrivate ?? false)
    }

    static func options(for course: Course?) -> [RoundVisibility] {
        allCases.filter { $0.isAvailable(for: course) }
    }
}

// MARK: - OpenRound (a future round with open spots)

@Model
final class OpenRound {
    @Attribute(.unique) var id: UUID
    var hostID: UUID
    var courseID: String
    var date: Date
    var time: String
    var spots: Int
    var note: String
    var joined: [String]   // player id uuidStrings
    var pending: [String]  // player id uuidStrings
    var createdAt: Date

    /// Stored as the raw value so SwiftData (and later Firestore) sees a plain
    /// string. Read through `visibility`.
    var visibilityRaw: String
    var invitedPlayerIDs: [String]  // used when visibility == .selected
    var invitedGroupIDs: [String]   // used when visibility == .selected

    var visibility: RoundVisibility {
        get { RoundVisibility(rawValue: visibilityRaw) ?? .friends }
        set { visibilityRaw = newValue.rawValue }
    }

    init(hostID: UUID, courseID: String, date: Date, time: String, spots: Int, note: String,
         visibility: RoundVisibility = .friends,
         invitedPlayerIDs: [UUID] = [], invitedGroupIDs: [UUID] = []) {
        self.id = UUID()
        self.hostID = hostID
        self.courseID = courseID
        self.date = date
        self.time = time
        self.spots = spots
        self.note = note
        self.joined = [hostID.uuidString]
        self.pending = []
        self.createdAt = .now
        self.visibilityRaw = visibility.rawValue
        self.invitedPlayerIDs = invitedPlayerIDs.map(\.uuidString)
        self.invitedGroupIDs = invitedGroupIDs.map(\.uuidString)
    }

    var openSpots: Int { max(0, spots - joined.count) }

    /// The area this round belongs to. Derived from the course rather than the
    /// device's location, so "nearby" needs no location permission.
    var areaKey: String? { Course.by(courseID)?.city }
}

// MARK: - Post (a plain social post, not tied to a round)

/// Who a post reaches. Narrower than `RoundVisibility` on purpose: there's no
/// "anyone nearby" tier, because a post has no course to be near, and an
/// unbounded public feed is a moderation problem this app doesn't need yet.
enum PostAudience: String, Codable, CaseIterable, Identifiable {
    case friendsOfFriends
    case club
    case friends
    case selected

    var id: String { rawValue }

    var label: String {
        switch self {
        case .friendsOfFriends: return "Friends of friends"
        case .club:             return "My club"
        case .friends:          return "Friends only"
        case .selected:         return "Specific people"
        }
    }

    var detail: String {
        switch self {
        case .friendsOfFriends: return "Your friends, and their friends."
        case .club:             return "Players whose home course is yours."
        case .friends:          return "Only people you've added."
        case .selected:         return "Only the people and groups you pick."
        }
    }

    var systemImage: String {
        switch self {
        case .friendsOfFriends: return "person.2.wave.2"
        case .club:             return "building.columns"
        case .friends:          return "person.2"
        case .selected:         return "person.crop.circle.badge.checkmark"
        }
    }

    /// Posting to "my club" needs a home course to post to.
    func isAvailable(for author: Player) -> Bool {
        self != .club || author.homeCourseID != nil
    }

    static func options(for author: Player) -> [PostAudience] {
        allCases.filter { $0.isAvailable(for: author) }
    }
}

@Model
final class Post {
    @Attribute(.unique) var id: UUID
    var authorID: UUID
    var text: String
    var createdAt: Date

    var audienceRaw: String
    var invitedPlayerIDs: [String]
    var invitedGroupIDs: [String]
    var likes: [String]   // player id uuidStrings

    var audience: PostAudience {
        get { PostAudience(rawValue: audienceRaw) ?? .friends }
        set { audienceRaw = newValue.rawValue }
    }

    init(authorID: UUID, text: String, audience: PostAudience = .friends,
         invitedPlayerIDs: [UUID] = [], invitedGroupIDs: [UUID] = []) {
        self.id = UUID()
        self.authorID = authorID
        self.text = text
        self.createdAt = .now
        self.audienceRaw = audience.rawValue
        self.invitedPlayerIDs = invitedPlayerIDs.map(\.uuidString)
        self.invitedGroupIDs = invitedGroupIDs.map(\.uuidString)
        self.likes = []
    }
}

// MARK: - Small helpers

extension Array where Element: Hashable {
    /// Order-preserving de-duplication.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Score helpers

enum ScoreKind { case eagle, birdie, par, bogey, doublePlus }

func scoreKind(toPar diff: Int) -> ScoreKind {
    if diff <= -2 { return .eagle }
    if diff == -1 { return .birdie }
    if diff == 0 { return .par }
    if diff == 1 { return .bogey }
    return .doublePlus
}

/// Same idea across a whole round, where one stroke either way is noise. Using
/// the per-hole thresholds on an 18-hole total would call almost every round a
/// double.
func roundScoreKind(toPar diff: Int) -> ScoreKind {
    if diff <= -3 { return .eagle }
    if diff <= -1 { return .birdie }
    if diff == 0 { return .par }
    if diff <= 3 { return .bogey }
    return .doublePlus
}

func toParText(_ diff: Int) -> String {
    if diff == 0 { return "E" }
    return diff > 0 ? "+\(diff)" : "\(diff)"
}
