import SwiftUI
import SwiftData

struct OpenRoundsView: View {
    let me: Player
    @Environment(\.modelContext) private var context
    @Query(sort: \OpenRound.date, order: .forward) private var rounds: [OpenRound]
    @Query private var players: [Player]
    @State private var showPost = false

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
                               body: "Post a round with an open spot and friends can jump in.")
                } else {
                    ForEach(rounds) { round in
                        openCard(round)
                    }
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showPost) { PostOpenRoundSheet(me: me) }
    }

    private func openCard(_ round: OpenRound) -> some View {
        let course = Course.by(round.courseID)
        let isHost = round.hostID == me.id
        let joined = round.joined.contains(me.id.uuidString)
        let pending = round.pending.contains(me.id.uuidString)

        return Card {
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
                        .background(round.openSpots > 0 ? Color.flag.opacity(0.25) : Color.paper100)
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
                    Text("host: \(name(round.hostID))").font(.caption).foregroundStyle(Color.inkSoft)
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
                        HStack {
                            Avatar(name: name(id))
                            Text(name(id)).font(.subheadline.weight(.medium))
                            Spacer()
                            Button(action: { approve(round, id) }) {
                                Label("Approve", systemImage: "checkmark")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.fairway800)
                            }
                        }
                    }
                }
            }
        }
    }

    private func request(_ round: OpenRound) {
        let mine = me.id.uuidString
        guard !round.joined.contains(mine), !round.pending.contains(mine) else { return }
        round.pending = round.pending + [mine]
    }

    private func approve(_ round: OpenRound, _ idString: String) {
        round.pending = round.pending.filter { $0 != idString }
        round.joined = round.joined + [idString]
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
                                            .background(spots == s ? Color.fairway800 : .white)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
                                    }
                                }
                            }
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
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Color.inkSoft)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
        }
    }

    private func post() {
        let date = Date.now.addingTimeInterval(Double(daysOut) * 86_400)
        let round = OpenRound(hostID: me.id, courseID: courseID, date: date,
                              time: time, spots: spots, note: note.trimmingCharacters(in: .whitespaces))
        context.insert(round)
        dismiss()
    }
}
