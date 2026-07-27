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

    init(hostID: UUID, courseID: String, date: Date, time: String, spots: Int, note: String) {
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
    }

    var openSpots: Int { max(0, spots - joined.count) }
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
