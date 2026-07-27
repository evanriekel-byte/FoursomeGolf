import SwiftUI
import SwiftData

struct FeedView: View {
    let me: Player
    @Query(sort: \Round.createdAt, order: .reverse) private var rounds: [Round]
    @Query private var players: [Player]

    private func name(_ id: UUID) -> String { players.first { $0.id == id }?.name ?? "Someone" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if rounds.isEmpty {
                    EmptyState(systemImage: "figure.golf",
                               title: "No rounds yet",
                               body: "Log your first round and it shows up here for your friends.")
                } else {
                    ForEach(rounds) { round in
                        roundCard(round)
                    }
                    legend
                }
            }
            .padding(16)
        }
    }

    private func roundCard(_ round: Round) -> some View {
        let course = Course.by(round.courseID)
        return Card {
            HStack(spacing: 12) {
                Avatar(name: name(round.playerID))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name(round.playerID)).font(.headline)
                        if round.playerID == me.id {
                            Text("YOU").font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Color.fairway700)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Color.fairway50).clipShape(Capsule())
                        }
                    }
                    Label(course?.name ?? "Unknown course", systemImage: "mappin.and.ellipse")
                        .font(.subheadline).foregroundStyle(Color.inkSoft).lineLimit(1)
                    Text(round.date, format: .relative(presentation: .named))
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(Color.inkSoft.opacity(0.7))
                }
                Spacer()
                VStack(spacing: 4) {
                    ScoreBadge(strokes: round.strokes, par: round.par, large: true)
                    Text(toParText(round.toPar))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(round.toPar < 0 ? Color.fairway700 : Color.inkSoft)
                }
            }
        }
    }

    private var legend: some View {
        HStack {
            legendItem(shape: AnyView(Circle().stroke(Color.fairway700, lineWidth: 2)), label: "birdie+")
            Spacer()
            legendItem(shape: AnyView(RoundedRectangle(cornerRadius: 5).stroke(Color.paper200, lineWidth: 1.5)), label: "par")
            Spacer()
            legendItem(shape: AnyView(RoundedRectangle(cornerRadius: 5).stroke(Color.inkSoft, lineWidth: 1.5)), label: "bogey")
        }
        .padding(14)
        .background(Color.paper100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 4)
    }

    private func legendItem(shape: AnyView, label: String) -> some View {
        HStack(spacing: 6) {
            shape.frame(width: 20, height: 20)
            Text(label).font(.system(.caption, design: .monospaced)).foregroundStyle(Color.inkSoft)
        }
    }
}
