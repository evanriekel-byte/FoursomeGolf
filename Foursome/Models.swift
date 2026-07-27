import Foundation
import SwiftData

// MARK: - Course (static reference data, not stored in SwiftData)

struct Course: Identifiable, Hashable {
    let id: String
    let name: String
    let city: String
    let par: Int

    static let all: [Course] = [
        Course(id: "c1", name: "Cobblestone Golf Course", city: "Acworth", par: 71),
        Course(id: "c2", name: "Cherokee Run", city: "Conyers", par: 72),
        Course(id: "c3", name: "Towne Lake Hills", city: "Woodstock", par: 72),
        Course(id: "c4", name: "Bear's Best Atlanta", city: "Suwanee", par: 72),
        Course(id: "c5", name: "Brookstone", city: "Acworth", par: 72),
        Course(id: "c6", name: "The Frog at The Georgian", city: "Villa Rica", par: 72),
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

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.handle = name.lowercased().replacingOccurrences(of: " ", with: "")
        self.createdAt = .now
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

    init(playerID: UUID, courseID: String, strokes: Int, par: Int, date: Date = .now) {
        self.id = UUID()
        self.playerID = playerID
        self.courseID = courseID
        self.strokes = strokes
        self.par = par
        self.date = date
        self.createdAt = .now
    }

    var toPar: Int { strokes - par }
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
    case friends
    case selected         // specific people and/or groups

    var id: String { rawValue }

    var label: String {
        switch self {
        case .area:             return "Anyone nearby"
        case .friendsOfFriends: return "Friends of friends"
        case .friends:          return "Friends only"
        case .selected:         return "Specific people"
        }
    }

    var detail: String {
        switch self {
        case .area:             return "Shows to any player in the course's area."
        case .friendsOfFriends: return "Your friends, and their friends."
        case .friends:          return "Only people you've added."
        case .selected:         return "Only the people and groups you pick."
        }
    }

    var systemImage: String {
        switch self {
        case .area:             return "globe.americas"
        case .friendsOfFriends: return "person.2.wave.2"
        case .friends:          return "person.2"
        case .selected:         return "person.crop.circle.badge.checkmark"
        }
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

func toParText(_ diff: Int) -> String {
    if diff == 0 { return "E" }
    return diff > 0 ? "+\(diff)" : "\(diff)"
}
