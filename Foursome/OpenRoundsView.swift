import SwiftUI
import SwiftData

struct OpenRoundsView: View {
    let me: Player
    @Environment(\.modelContext) private var context
    @Query(sort: \OpenRound.date, order: .forward) private var allRounds: [OpenRound]
    @Query private var players: [Player]
    @Query private var friendships: [Friendship]
    @Query private var groups: [PlayerGroup]
    @Query private var playedRounds: [Round]
    @State private var showPost = false
    @State private var roundToCancel: OpenRound?

    private var graph: SocialGraph {
        SocialGraph(friendships: friendships, groups: groups, players: players)
    }

    /// Only the rounds this player is allowed to see, with finished tee times
    /// dropped. A round stays up through its whole day — day-of coordination
    /// is the point — and falls off at midnight, instead of a stale Tuesday
    /// round sitting at the top of the list forever.
    private var rounds: [OpenRound] {
        let areas = SocialGraph.areas(forPlayer: me.id, rounds: playedRounds, openRounds: allRounds)
        let today = Calendar.current.startOfDay(for: .now)
        return graph.visibleRounds(from: allRounds, as: me.id, viewerAreas: areas)
            .filter { $0.date >= today }
    }

    private func name(_ idString: String) -> String {
        players.first { $0.id.uuidString == idString }?.name ?? "Someone"
    }
    private func name(_ id: UUID) -> String { name(id.uuidString) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: { showPost = true }) {
                    Label("Post an open round", systemImage: "plus")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.fairway800).clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if rounds.isEmpty {
                    EmptyState(systemImage: "door.left.hand.open",
                               title: "No open spots right now",
                               message: "Post a round with an open spot and friends can jump in.")
                } else {
                    ForEach(rounds) { round in
                        openCard(round)
                    }
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showPost) { PostOpenRoundSheet(me: me) }
        .confirmationDialog("Cancel this round?",
                            isPresented: Binding(
                                get: { roundToCancel != nil },
                                set: { if !$0 { roundToCancel = nil } }),
                            titleVisibility: .visible,
                            presenting: roundToCancel) { round in
            Button("Cancel the round", role: .destructive) { cancel(round) }
            Button("Keep it", role: .cancel) {}
        } message: { round in
            Text("Removes it for everyone — \(round.joined.count) in the group so far. There's no undo.")
        }
    }

    private func openCard(_ round: OpenRound) -> some View {
        let course = Course.by(round.courseID)
        let isHost = round.hostID == me.id
        let joined = round.joined.contains(me.id.uuidString)
        let pending = round.pending.contains(me.id.uuidString)

        let card = Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course?.name ?? "Unknown course").font(.headline)
                        HStack(spacing: 12) {
                            Label(round.date.formatted(.dateTime.weekday().month().day()), systemImage: "calendar")
                            Label(round.time, systemImage: "clock")
                        }
                        .font(.system(.subheadline, design: .monospaced)).foregroundStyle(Color.inkSoft)
                    }
                    Spacer()
                    Text(round.openSpots > 0 ? "\(round.openSpots) open" : "full")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(round.openSpots > 0 ? Color.fairway800 : Color.inkSoft)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        // Turf green, not flagstick red — an open spot is the
                        // good news on this card, and red read as a warning.
                        .background(round.openSpots > 0 ? Color.dew : Color.paper100)
                        .clipShape(Capsule())
                }

                if !round.note.isEmpty {
                    Text(round.note).font(.subheadline).foregroundStyle(Color.ink)
                }

                HStack(spacing: -8) {
                    ForEach(round.joined, id: \.self) { id in
                        Avatar(name: name(id)).overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                    ForEach(0..<round.openSpots, id: \.self) { _ in
                        Image(systemName: "plus")
                            .font(.footnote).foregroundStyle(Color.paper200)
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Color.paper200, style: StrokeStyle(lineWidth: 1.5, dash: [3])))
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("host: \(name(round.hostID))").font(.caption).foregroundStyle(Color.inkSoft)
                        Label(round.visibility.label, systemImage: round.visibility.systemImage)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Color.inkSoft.opacity(0.8))
                    }
                }

                if !isHost && !joined {
                    Button(action: { request(round) }) {
                        Text(pending ? "Requested" : (round.openSpots == 0 ? "Full" : "Request to join"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(pending || round.openSpots == 0 ? Color.inkSoft : .white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(pending || round.openSpots == 0 ? Color.paper100 : Color.fairway800)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(pending || round.openSpots == 0)
                }

                if joined && !isHost {
                    Label("You're in this group", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium)).foregroundStyle(Color.fairway700)
                }

                if isHost && !round.pending.isEmpty {
                    Divider()
                    Eyebrow("Requests to join")
                    ForEach(round.pending, id: \.self) { id in
                        HStack(spacing: 12) {
                            Avatar(name: name(id))
                            Text(name(id)).font(.subheadline.weight(.medium))
                            Spacer()
                            // Same pair as a friend request: decline is an
                            // outlined x, approve a filled check.
                            Button(action: { decline(round, id) }) {
                                Image(systemName: "xmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.inkSoft)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(Color.paper200, lineWidth: 1))
                            }
                            .accessibilityLabel("Decline \(name(id))")
                            Button(action: { approve(round, id) }) {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(round.openSpots > 0 ? Color.fairway800 : Color.paper200)
                                    .clipShape(Circle())
                            }
                            .disabled(round.openSpots == 0)
                            .accessibilityLabel("Approve \(name(id))")
                        }
                    }
                }
            }
        }

        // Long-press to call the whole thing off — host only.
        return Group {
            if isHost {
                card.contextMenu {
                    Button(role: .destructive) {
                        roundToCancel = round
                    } label: {
                        Label("Cancel this round", systemImage: "trash")
                    }
                }
            } else {
                card
            }
        }
    }

    private func request(_ round: OpenRound) {
        let mine = me.id.uuidString
        guard !round.joined.contains(mine), !round.pending.contains(mine) else { return }
        round.pending = round.pending + [mine]
    }

    /// A full group can't take another player, so approving past capacity is
    /// refused here as well as disabled in the UI.
    private func approve(_ round: OpenRound, _ idString: String) {
        guard round.openSpots > 0 else { return }
        round.pending = round.pending.filter { $0 != idString }
        round.joined = round.joined + [idString]
    }

    /// Drops the request outright, the same shape as declining a friend
    /// request — the other player just sees the spot still open and can ask
    /// again.
    private func decline(_ round: OpenRound, _ idString: String) {
        round.pending = round.pending.filter { $0 != idString }
    }

    /// Saved eagerly rather than left to autosave — a cancelled round coming
    /// back after a relaunch reads as a bug.
    private func cancel(_ round: OpenRound) {
        context.delete(round)
        try? context.save()
    }
}

// MARK: - Post sheet

struct PostOpenRoundSheet: View {
    let me: Player
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var courseID = Course.all.first!.id
    @State private var daysOut = 2
    @State private var time = "8:00 AM"
    @State private var spots = 4
    @State private var note = ""
    @State private var visibility: RoundVisibility = .friends

    private var selectedCourse: Course? { Course.by(courseID) }
    private var visibilityOptions: [RoundVisibility] {
        RoundVisibility.options(for: selectedCourse)
    }

    private let dayOptions = [0, 1, 2, 3, 5, 7]
    private func dayLabel(_ d: Int) -> String {
        if d == 0 { return "Today" }
        if d == 1 { return "Tomorrow" }
        return Date.now.addingTimeInterval(Double(d) * 86_400).formatted(.dateTime.weekday().month().day())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        field("Course") {
                            Picker("Course", selection: $courseID) {
                                ForEach(Course.all) { Text("\($0.name) — \($0.city)").tag($0.id) }
                            }.pickerStyle(.menu).tint(.fairway800)
                        }

                        HStack(spacing: 12) {
                            field("When") {
                                Picker("When", selection: $daysOut) {
                                    ForEach(dayOptions, id: \.self) { Text(dayLabel($0)).tag($0) }
                                }.pickerStyle(.menu).tint(.fairway800)
                            }
                            field("Tee time") {
                                TextField("8:00 AM", text: $time)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Group size").font(.subheadline.weight(.medium)).foregroundStyle(Color.inkSoft)
                            HStack(spacing: 8) {
                                ForEach([2, 3, 4], id: \.self) { s in
                                    Button(action: { spots = s }) {
                                        Text("\(s)").font(.system(.body, design: .monospaced).weight(.semibold))
                                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                                            .foregroundStyle(spots == s ? .white : Color.inkSoft)
                                            .background(spots == s ? Color.fairway : Color.card)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Who can see this").font(.subheadline.weight(.medium)).foregroundStyle(Color.inkSoft)
                            VStack(spacing: 0) {
                                ForEach(Array(visibilityOptions.enumerated()), id: \.element.id) { index, option in
                                    if index > 0 { Divider() }
                                    Button(action: { visibility = option }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: option.systemImage)
                                                .foregroundStyle(visibility == option ? Color.fairway800 : Color.inkSoft)
                                                .frame(width: 22)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(option.label).font(.subheadline.weight(.medium))
                                                    .foregroundStyle(Color.ink)
                                                Text(option.detail).font(.caption).foregroundStyle(Color.inkSoft)
                                            }
                                            Spacer()
                                            if visibility == option {
                                                Image(systemName: "checkmark").font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(Color.fairway800)
                                            }
                                        }
                                        .padding(14)
                                    }
                                }
                            }
                            .background(Color.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
                        }

                        field("Note (optional)") {
                            TextField("Casual pace, walking, etc.", text: $note)
                        }

                        Button(action: post) {
                            Text("Post open round")
                                .font(.headline).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.fairway800).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Post an open round")
            .navigationBarTitleDisplayMode(.inline)
            // Switching to a public course strands a club-only selection.
            .onChange(of: courseID) { _, _ in
                if !visibility.isAvailable(for: selectedCourse) { visibility = .friends }
            }
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Color.inkSoft)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).background(Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
        }
    }

    private func post() {
        let date = Date.now.addingTimeInterval(Double(daysOut) * 86_400)
        let round = OpenRound(hostID: me.id, courseID: courseID, date: date,
                              time: time, spots: spots, note: note.trimmingCharacters(in: .whitespaces),
                              visibility: visibility)
        context.insert(round)
        dismiss()
    }
}
