import SwiftUI
import SwiftData

struct FeedView: View {
    let me: Player

    @Query(sort: \Round.createdAt, order: .reverse) private var rounds: [Round]
    @Query(sort: \Post.createdAt, order: .reverse) private var allPosts: [Post]
    @Query private var players: [Player]
    @Query private var friendships: [Friendship]
    @Query private var groups: [PlayerGroup]

    @State private var expanded: Set<UUID> = []
    @State private var showComposer = false

    /// Shared with the leaderboard, so both screens show the same population.
    @AppStorage("audienceScope") private var scopeRaw = AudienceScope.everyone.rawValue
    private var scope: AudienceScope {
        get { AudienceScope(rawValue: scopeRaw) ?? .everyone }
        nonmutating set { scopeRaw = newValue.rawValue }
    }

    private var graph: SocialGraph {
        SocialGraph(friendships: friendships, groups: groups, players: players)
    }

    private var friendCount: Int { graph.friends(of: me.id).count }

    /// Everyone whose activity belongs on screen, or nil for no filter.
    private var scopedIDs: Set<UUID>? { graph.scopedIDs(scope, viewer: me.id) }

    /// Rounds are visible to everyone by permission; this only narrows the
    /// view. Posts are audience-scoped first, then narrowed the same way.
    private var visibleRounds: [Round] {
        guard let scopedIDs else { return rounds }
        return rounds.filter { scopedIDs.contains($0.playerID) }
    }

    private var posts: [Post] {
        let allowed = graph.visiblePosts(from: allPosts, as: me.id)
        guard let scopedIDs else { return allowed }
        return allowed.filter { scopedIDs.contains($0.authorID) }
    }

    /// One timeline, newest first, rounds and posts interleaved by time.
    private enum Item: Identifiable {
        case round(Round)
        case post(Post)

        var id: UUID {
            switch self {
            case .round(let r): return r.id
            case .post(let p):  return p.id
            }
        }
        var date: Date {
            switch self {
            case .round(let r): return r.createdAt
            case .post(let p):  return p.createdAt
            }
        }
    }

    private var timeline: [Item] {
        (visibleRounds.map(Item.round) + posts.map(Item.post)).sorted { $0.date > $1.date }
    }

    private func name(_ id: UUID) -> String { players.first { $0.id == id }?.name ?? "Someone" }

    /// Marked against the card owner's handicap, but only if *I've* asked to
    /// see net scoring.
    private func context(for round: Round) -> ScoringContext {
        guard let course = Course.by(round.courseID) else {
            return ScoringContext(holePars: [], netPars: [], caption: "vs par", index: nil)
        }
        guard let owner = players.first(where: { $0.id == round.playerID }) else {
            return .par(course)
        }
        return .make(player: owner, course: course, rounds: rounds, mode: me.scoringMode)
    }

    /// Par plus the strokes the owner receives, for reading the total badge net.
    private func referenceTotal(for round: Round) -> Int {
        let nets = context(for: round).netPars
        return nets.isEmpty ? round.par : nets.reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                composerPrompt

                ScopePicker(scope: Binding(get: { scope }, set: { scope = $0 }),
                            friendCount: friendCount)

                if timeline.isEmpty {
                    EmptyState(systemImage: "figure.golf",
                               title: scope == .friends ? "Nothing from your friends yet" : "Nothing here yet",
                               message: scope == .friends
                                   ? "Add more friends, or switch to Everyone to see the whole clubhouse."
                                   : "Log a round or say something and it shows up here for your friends.")
                } else {
                    ForEach(timeline) { item in
                        switch item {
                        case .round(let round): roundCard(round)
                        case .post(let post):   postCard(post)
                        }
                    }
                    legend
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showComposer) { PostComposer(me: me) }
    }

    private var composerPrompt: some View {
        Button(action: { showComposer = true }) {
            HStack(spacing: 12) {
                Avatar(name: me.name)
                Text("Say something to your friends…")
                    .font(.subheadline).foregroundStyle(Color.inkSoft)
                Spacer()
                Image(systemName: "square.and.pencil").foregroundStyle(Color.fairway800)
            }
            .padding(12)
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.paper200, lineWidth: 1))
        }
    }

    private func postCard(_ post: Post) -> some View {
        let liked = post.likes.contains(me.id.uuidString)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Avatar(name: name(post.authorID))
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(name(post.authorID)).font(.headline)
                            if post.authorID == me.id {
                                Text("YOU").font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Color.fairway700)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Color.fairway50).clipShape(Capsule())
                            }
                        }
                        Text(post.createdAt, format: .relative(presentation: .named))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.inkSoft.opacity(0.7))
                    }
                    Spacer()
                    // Only the author needs reminding who they sent it to.
                    if post.authorID == me.id {
                        Label(post.audience.label, systemImage: post.audience.systemImage)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.inkSoft)
                    }
                }

                Text(post.text).font(.subheadline).foregroundStyle(Color.ink)

                HStack(spacing: 6) {
                    Button(action: { toggleLike(post) }) {
                        Label(post.likes.isEmpty ? "Like" : "\(post.likes.count)",
                              systemImage: liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(liked ? Color.fairway800 : Color.inkSoft)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
        }
    }

    private func toggleLike(_ post: Post) {
        let mine = me.id.uuidString
        if post.likes.contains(mine) {
            post.likes = post.likes.filter { $0 != mine }
        } else {
            post.likes = post.likes + [mine]
        }
    }

    private func roundCard(_ round: Round) -> some View {
        let course = Course.by(round.courseID)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                header(round, course: course)

                if round.hasScorecard {
                    Divider()
                    scorecardSection(round)
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
                let reference = referenceTotal(for: round)
                let net = round.strokes - reference
                ScoreBadge(strokes: round.strokes, par: round.par, large: true, reference: reference)
                Text(toParText(net))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(net < 0 ? Color.fairway700 : Color.inkSoft)
            }
        }
    }

    @ViewBuilder
    private func scorecardSection(_ round: Round) -> some View {
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
            ScorecardTable(holeScores: round.holeScores, context: context(for: round))
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
