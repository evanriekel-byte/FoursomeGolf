import SwiftUI
import SwiftData

/// How far back a leaderboard reaches. Weekly and monthly boards matter because
/// an all-time board goes stale: once someone posts a career round, the order
/// stops moving and there's no reason to check it again.
enum LeaderboardPeriod: String, CaseIterable, Identifiable {
    case week, month, year, allTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week:    return "This week"
        case .month:   return "This month"
        case .year:    return "This year"
        case .allTime: return "All time"
        }
    }

    var short: String {
        switch self {
        case .week:    return "Week"
        case .month:   return "Month"
        case .year:    return "Year"
        case .allTime: return "All"
        }
    }

    /// Start of the current calendar period, or nil for all time. Calendar
    /// based rather than "last 7 days", so everyone's week rolls over together
    /// and a Saturday round stays in the same week all weekend.
    func start(now: Date = .now, calendar: Calendar = .current) -> Date? {
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start
        case .month:
            return calendar.dateInterval(of: .month, for: now)?.start
        case .year:
            return calendar.dateInterval(of: .year, for: now)?.start
        case .allTime:
            return nil
        }
    }
}

struct LeaderboardView: View {
    let me: Player
    @Query private var players: [Player]
    @Query private var rounds: [Round]
    @Query private var friendships: [Friendship]

    @State private var period: LeaderboardPeriod = .month
    @State private var courseID: String? = nil   // nil = every course

    /// Shared with the feed, so both screens show the same population.
    @AppStorage("audienceScope") private var scopeRaw = AudienceScope.everyone.rawValue
    private var scope: AudienceScope {
        get { AudienceScope(rawValue: scopeRaw) ?? .everyone }
        nonmutating set { scopeRaw = newValue.rawValue }
    }

    private var graph: SocialGraph { SocialGraph(friendships: friendships) }
    private var friendCount: Int { graph.friends(of: me.id).count }
    private var scopedIDs: Set<UUID>? { graph.scopedIDs(scope, viewer: me.id) }

    /// The players eligible for this board.
    private var scopedPlayers: [Player] {
        guard let scopedIDs else { return players }
        return players.filter { scopedIDs.contains($0.id) }
    }

    private struct Row: Identifiable {
        let id: UUID
        let player: Player
        let count: Int
        let best: Round
    }

    /// Rounds inside the selected window and course.
    private var scopedRounds: [Round] {
        let cutoff = period.start()
        return rounds.filter { round in
            if let cutoff, round.date < cutoff { return false }
            if let courseID, round.courseID != courseID { return false }
            return true
        }
    }

    /// Ranked by best round to par — gross, deliberately. A net board would
    /// reward the handicap rather than the round.
    private var ranked: [Row] {
        scopedPlayers.compactMap { p in
            let rs = scopedRounds.filter { $0.playerID == p.id }
            guard let best = rs.min(by: { $0.toPar < $1.toPar }) else { return nil }
            return Row(id: p.id, player: p, count: rs.count, best: best)
        }
        .sorted { $0.best.toPar < $1.best.toPar }
    }

    private var withoutRounds: [Player] {
        scopedPlayers.filter { p in !scopedRounds.contains { $0.playerID == p.id } }
    }

    private var courseName: String? {
        courseID.flatMap { Course.by($0)?.name }
    }

    private var emptyMessage: String {
        let when = period.label.lowercased()
        let where_ = courseName.map { " at \($0)" } ?? ""
        if scope == .friends {
            return "None of your friends posted a round \(when)\(where_). Switch to Everyone to see the whole clubhouse."
        }
        return "No rounds \(when)\(where_). Post one and you'll top the board by default."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filters

                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(courseName.map { "Best round · \($0)" } ?? "Best round · every course")

                    if ranked.isEmpty {
                        EmptyState(systemImage: "trophy",
                                   title: "Nothing posted yet",
                                   message: emptyMessage)
                    } else {
                        ForEach(Array(ranked.enumerated()), id: \.element.id) { index, row in
                            rankRow(index: index, row: row)
                        }
                    }
                }

                if !withoutRounds.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow("In the clubhouse")
                        Text("Yet to post (\(withoutRounds.count))")
                            .font(.system(.headline, design: .serif))
                        FlexWrap(items: withoutRounds.map { $0.name })
                    }
                }
            }
            .padding(16)
        }
    }

    private var filters: some View {
        VStack(spacing: 10) {
            ScopePicker(scope: Binding(get: { scope }, set: { scope = $0 }),
                        friendCount: friendCount)

            Picker("Period", selection: $period) {
                ForEach(LeaderboardPeriod.allCases) { Text($0.short).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Course").font(.subheadline).foregroundStyle(Color.inkSoft)
                Spacer()
                Picker("Course", selection: $courseID) {
                    Text("Every course").tag(String?.none)
                    ForEach(Course.all) { c in
                        Text(c.name).tag(String?.some(c.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(.fairway800)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
        }
    }

    private func rankRow(index: Int, row: Row) -> some View {
        let mine = row.player.id == me.id
        // Where the best round happened only matters when the board spans
        // courses; scoped to one, it's the same line on every row.
        let detail: String = {
            let n = "\(row.count) round\(row.count == 1 ? "" : "s")"
            guard courseID == nil else { return n }
            return "\(n) · best at \(Course.by(row.best.courseID)?.city ?? "—")"
        }()

        return HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(Color.inkSoft).frame(width: 22)
            Avatar(name: row.player.name)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.player.name).font(.headline)
                    if mine {
                        Text("YOU").font(.system(.caption2, design: .monospaced)).foregroundStyle(Color.fairway700)
                    }
                }
                Text(detail)
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            VStack(spacing: 2) {
                ScoreBadge(strokes: row.best.strokes, par: row.best.par)
                Text(toParText(row.best.toPar))
                    .font(.system(size: 10, design: .monospaced).weight(.semibold))
                    .foregroundStyle(row.best.toPar < 0 ? Color.fairway700 : Color.inkSoft)
            }
        }
        .padding(12)
        .background(mine ? Color.dew : Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(mine ? Color.fairway700 : Color.paper200, lineWidth: 1))
    }
}

// Simple wrapping row of chips (avoids iOS 16 Layout complexity).
struct FlexWrap: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunked, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { chip($0) }
                }
            }
        }
    }

    private var chunked: [[String]] {
        var result: [[String]] = []
        var current: [String] = []
        for item in items {
            current.append(item)
            if current.count == 3 { result.append(current); current = [] }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private func chip(_ name: String) -> some View {
        HStack(spacing: 6) {
            Avatar(name: name)
            Text(name).font(.subheadline).foregroundStyle(Color.ink)
        }
        .padding(.trailing, 12).padding(.leading, 4).padding(.vertical, 4)
        .background(Color.card)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.paper200, lineWidth: 1))
    }
}
