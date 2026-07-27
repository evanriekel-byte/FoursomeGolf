import SwiftUI
import SwiftData

struct FeedView: View {
    let me: Player
    @Query(sort: \Round.createdAt, order: .reverse) private var rounds: [Round]
    @Query private var players: [Player]
    @State private var expanded: Set<UUID> = []

    private func name(_ id: UUID) -> String { players.first { $0.id == id }?.name ?? "Someone" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if rounds.isEmpty {
                    EmptyState(systemImage: "figure.golf",
                               title: "No rounds yet",
                               message: "Log your first round and it shows up here for your friends.")
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
            VStack(alignment: .leading, spacing: 10) {
                header(round, course: course)

                if round.hasScorecard, let course {
                    Divider()
                    scorecardSection(round, course: course)
                }
            }
        }
    }

    private func header(_ round: Round, course: Course?) -> some View {
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

    @ViewBuilder
    private func scorecardSection(_ round: Round, course: Course) -> some View {
        let open = expanded.contains(round.id)

        Button {
            withAnimation(.snappy(duration: 0.22)) {
                if open { expanded.remove(round.id) } else { expanded.insert(round.id) }
            }
        } label: {
            HStack {
                Text(open ? "Hide scorecard" : "Scorecard")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(Color.inkSoft)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSoft)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
        }
        .buttonStyle(.plain)

        if open {
            ScorecardTable(holeScores: round.holeScores, holePars: course.holePars)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var legend: some View {
        HStack {
            legendItem(shape: AnyView(Circle().stroke(Color.fairwayLit, lineWidth: 1.4)), label: "birdie")
            Spacer()
            legendItem(shape: AnyView(Color.clear), label: "par")
            Spacer()
            legendItem(shape: AnyView(RoundedRectangle(cornerRadius: 3).stroke(Color.inkSoft, lineWidth: 1.4)), label: "bogey")
            Spacer()
            legendItem(shape: AnyView(
                ZStack {
                    RoundedRectangle(cornerRadius: 3).stroke(Color.overPar, lineWidth: 1.2)
                    RoundedRectangle(cornerRadius: 2).stroke(Color.overPar, lineWidth: 1.2).padding(2.5)
                }
            ), label: "double+")
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
