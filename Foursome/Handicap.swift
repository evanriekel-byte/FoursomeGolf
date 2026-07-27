import Foundation

/// Works out what a given player should be expected to shoot, and turns that
/// into strokes on specific holes.
///
/// ## How close is this to a real handicap?
///
/// The shape is real World Handicap System: take your recent score
/// differentials, average the lowest few, and use a sliding table so someone
/// with five rounds still gets a number. What's approximated is the
/// differential itself. WHS computes it as
///
///     (113 / slope) * (adjusted gross score - course rating)
///
/// which needs each course's slope and rating, plus per-hole stroke controls
/// on the gross score. This app carries neither, so it substitutes
/// `strokes - par`. On a course whose rating is near par that lands close;
/// on a very hard or very easy course it drifts.
///
/// The consequence: this is a good *personal baseline* and a bad *official
/// index*. Never show it as a GHIN or WHS handicap.
enum Handicap {

    // MARK: - Index

    /// WHS's sliding table: how many of the lowest differentials count, and
    /// what adjustment applies, given how many rounds exist. Fewer than three
    /// rounds isn't enough to say anything.
    static func selection(forRoundCount n: Int) -> (count: Int, adjustment: Double)? {
        switch n {
        case ..<3:   return nil
        case 3:      return (1, -2.0)
        case 4:      return (1, -1.0)
        case 5:      return (1,  0.0)
        case 6:      return (2, -1.0)
        case 7...8:  return (2,  0.0)
        case 9...11: return (3,  0.0)
        case 12...14: return (4, 0.0)
        case 15...16: return (5, 0.0)
        case 17...18: return (6, 0.0)
        case 19:      return (7, 0.0)
        default:      return (8, 0.0)
        }
    }

    /// `differentials` must be most-recent-first; only the last 20 count.
    static func index(differentials: [Double]) -> Double? {
        let recent = Array(differentials.prefix(20))
        guard let (count, adjustment) = selection(forRoundCount: recent.count) else { return nil }

        let lowest = recent.sorted().prefix(count)
        guard !lowest.isEmpty else { return nil }

        let mean = lowest.reduce(0, +) / Double(lowest.count)
        return ((mean + adjustment) * 10).rounded() / 10
    }

    /// A player's differentials from their rounds, most-recent-first.
    static func differentials(for playerID: UUID, rounds: [Round]) -> [Double] {
        rounds
            .filter { $0.playerID == playerID }
            .sorted { $0.date > $1.date }
            .map { Double($0.strokes - $0.par) }
    }

    /// The index to use for a player: whatever they entered, else one worked
    /// out from their rounds.
    static func effectiveIndex(for player: Player, rounds: [Round]) -> Double? {
        if let entered = player.handicapIndex { return entered }
        return index(differentials: differentials(for: player.id, rounds: rounds))
    }

    // MARK: - Strokes on holes

    /// Strokes received on each hole, allocated by stroke index.
    ///
    /// Everyone gets `handicap / 18` on every hole, and the remainder falls on
    /// the hardest holes first. A 22 gets one stroke everywhere plus a second
    /// on stroke index 1-4.
    static func strokesReceived(courseHandicap: Int, strokeIndex: [Int]) -> [Int] {
        guard !strokeIndex.isEmpty else { return [] }
        let holes = strokeIndex.count
        let total = max(0, courseHandicap)
        let base = total / holes
        let remainder = total % holes
        return strokeIndex.map { base + ($0 <= remainder ? 1 : 0) }
    }

    /// Without slope and rating there's no conversion to do, so the course
    /// handicap is just the index rounded. Kept as its own step so the real
    /// formula can slot in once courses carry a rating.
    static func courseHandicap(index: Double) -> Int {
        Int(index.rounded())
    }
}

// MARK: - Scoring context

/// Everything a scorecard needs in order to mark a hole: what par is, and what
/// par is *for this player*.
struct ScoringContext {
    let holePars: [Int]
    /// Par plus strokes received. Equal to `holePars` under scratch scoring.
    let netPars: [Int]
    /// Short description of the baseline, for showing next to a card.
    let caption: String
    /// The index in play, if there is one.
    let index: Double?

    static func par(_ course: Course) -> ScoringContext {
        ScoringContext(holePars: course.holePars,
                       netPars: course.holePars,
                       caption: "vs par",
                       index: nil)
    }

    /// Builds the context for a player on a course, falling back to plain par
    /// when there aren't enough rounds to say anything yet.
    ///
    /// `mode` is the *viewer's* preference while `player` owns the handicap —
    /// reading someone else's card, you choose whether to see net, but the
    /// strokes come off their number, not yours.
    static func make(player: Player, course: Course, rounds: [Round],
                     mode: ScoringMode? = nil) -> ScoringContext {
        guard (mode ?? player.scoringMode) == .personal,
              let index = Handicap.effectiveIndex(for: player, rounds: rounds)
        else { return .par(course) }

        let ch = Handicap.courseHandicap(index: index)
        guard ch > 0 else { return .par(course) }

        let strokes = Handicap.strokesReceived(courseHandicap: ch, strokeIndex: course.strokeIndex)
        let nets = zip(course.holePars, strokes).map(+)

        let source = player.handicapIndex == nil ? "your recent rounds" : "your index"
        return ScoringContext(holePars: course.holePars,
                              netPars: nets,
                              caption: "vs \(formatted(index)) — \(source)",
                              index: index)
    }

    static func formatted(_ index: Double) -> String {
        index < 0 ? String(format: "+%.1f", -index) : String(format: "%.1f", index)
    }
}
