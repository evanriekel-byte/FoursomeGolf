import SwiftUI
import SwiftData

struct LeaderboardView: View {
    let me: Player
    @Query private var players: [Player]
    @Query private var rounds: [Round]

    private struct Row: Identifiable {
        let id: UUID
        let player: Player
        let count: Int
        let best: Round?
    }

    private var ranked: [Row] {
        players.map { p in
            let rs = rounds.filter { $0.playerID == p.id }
            let best = rs.min { $0.toPar < $1.toPar }
            return Row(id: p.id, player: p, count: rs.count, best: best)
        }
        .filter { $0.best != nil }
        .sorted { ($0.best!.toPar) < ($1.best!.toPar) }
    }

    private var withoutRounds: [Player] {
        players.filter { p in !rounds.contains { $0.playerID == p.id } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("By best round")
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { index, row in
                        rankRow(index: index, row: row)
                    }
                }

                if !withoutRounds.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow("In the clubhouse")
                        Text("Players (\(players.count))").font(.system(.headline, design: .serif))
                        FlexWrap(items: withoutRounds.map { $0.name })
                    }
                }
            }
            .padding(16)
        }
    }

    private func rankRow(index: Int, row: Row) -> some View {
        let mine = row.player.id == me.id
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
                Text("\(row.count) round\(row.count == 1 ? "" : "s") · best at \(Course.by(row.best!.courseID)?.city ?? "—")")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            ScoreBadge(strokes: row.best!.strokes, par: row.best!.par)
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
