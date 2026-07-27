import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var players: [Player]
    @AppStorage("meID") private var meID: String = ""
    @AppStorage("didSeed") private var didSeed: Bool = false

    private var me: Player? { players.first { $0.id.uuidString == meID } }

    var body: some View {
        Group {
            if let me {
                MainTabs(me: me)
            } else {
                OnboardingView(onEnter: enter)
            }
        }
        .onAppear(perform: seedIfNeeded)
    }

    private func enter(name: String) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        if let existing = players.first(where: { $0.name.lowercased() == clean.lowercased() }) {
            meID = existing.id.uuidString
            return
        }
        let player = Player(name: clean)
        context.insert(player)
        meID = player.id.uuidString
    }

    // Demo clubhouse so the app feels alive on first run.
    private func seedIfNeeded() {
        guard !didSeed, players.isEmpty else { return }
        didSeed = true

        let marcus = Player(name: "Marcus")
        let tyler = Player(name: "Tyler")
        let deshawn = Player(name: "Deshawn")
        let ryan = Player(name: "Ryan")
        [marcus, tyler, deshawn, ryan].forEach { context.insert($0) }

        let day: TimeInterval = 86_400
        let seededRounds: [Round] = [
            Round(playerID: marcus.id, courseID: "c1", strokes: 79, par: 71, date: .now.addingTimeInterval(-day)),
            Round(playerID: tyler.id, courseID: "c3", strokes: 71, par: 72, date: .now.addingTimeInterval(-2*day)),
            Round(playerID: deshawn.id, courseID: "c2", strokes: 88, par: 72, date: .now.addingTimeInterval(-3*day)),
            Round(playerID: ryan.id, courseID: "c4", strokes: 74, par: 72, date: .now.addingTimeInterval(-4*day)),
            Round(playerID: marcus.id, courseID: "c5", strokes: 83, par: 72, date: .now.addingTimeInterval(-6*day)),
        ]
        seededRounds.forEach { context.insert($0) }

        // A small graph with a deliberate shape: log in as Marcus and Tyler and
        // Deshawn are friends, Ryan is only a friend-of-a-friend. That's enough
        // to tell the visibility tiers apart by eye.
        let friendships = [
            Friendship(requesterID: marcus.id, addresseeID: tyler.id, accepted: true),
            Friendship(requesterID: marcus.id, addresseeID: deshawn.id, accepted: true),
            Friendship(requesterID: tyler.id, addresseeID: ryan.id, accepted: true),
        ]
        friendships.forEach { context.insert($0) }

        let saturdayCrew = PlayerGroup(name: "Saturday regulars", ownerID: tyler.id,
                                       memberIDs: [marcus.id, ryan.id])
        context.insert(saturdayCrew)

        let g1 = OpenRound(hostID: tyler.id, courseID: "c1", date: .now.addingTimeInterval(2*day), time: "8:10 AM", spots: 4, note: "Saturday loop, casual pace.", visibility: .friendsOfFriends)
        g1.joined = [tyler.id.uuidString, ryan.id.uuidString]
        let g2 = OpenRound(hostID: deshawn.id, courseID: "c3", date: .now.addingTimeInterval(5*day), time: "3:40 PM", spots: 2, note: "Twilight nine after work.", visibility: .friends)
        let g3 = OpenRound(hostID: ryan.id, courseID: "c4", date: .now.addingTimeInterval(3*day), time: "10:20 AM", spots: 4, note: "Anyone around? Need two.", visibility: .area)
        context.insert(g1)
        context.insert(g2)
        context.insert(g3)
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    var onEnter: (String) -> Void
    @State private var name = ""

    var body: some View {
        ZStack {
            Color.fairway.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill").foregroundStyle(Color.flag)
                    Text("Foursome").font(.system(.largeTitle, design: .serif))
                }
                .foregroundStyle(.white)
                .padding(.bottom, 20)

                Text("Fill your foursome.")
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text("Track your rounds, see when your friends play, and open a spot when your group needs one more.")
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 8)
                    .padding(.bottom, 36)

                Eyebrow("Get started").foregroundStyle(Color.flagSoft)
                    .padding(.bottom, 6)
                TextField("", text: $name, prompt: Text("Your first name").foregroundStyle(.white.opacity(0.5)))
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Color.black.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fairway700, lineWidth: 1))
                    .submitLabel(.go)
                    .onSubmit { onEnter(name) }

                Button(action: { onEnter(name) }) {
                    Text("Enter the clubhouse")
                        .font(.headline).foregroundStyle(Color.fairway)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.flag).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 12)

                Text("Runs entirely on your phone for now. Try \"Marcus\" to log in as a seeded player.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 16)
                Spacer()
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Tab shell

struct MainTabs: View {
    let me: Player
    @State private var showInvite = false

    var body: some View {
        TabView {
            NavWrap(title: "Foursome", me: me, showInvite: $showInvite) { FeedView(me: me) }
                .tabItem { Label("Feed", systemImage: "house.fill") }
            NavWrap(title: "Log a round", me: me, showInvite: $showInvite) { LogRoundView(me: me) }
                .tabItem { Label("Log", systemImage: "square.and.pencil") }
            NavWrap(title: "Open rounds", me: me, showInvite: $showInvite) { OpenRoundsView(me: me) }
                .tabItem { Label("Open", systemImage: "door.left.hand.open") }
            NavWrap(title: "Leaderboard", me: me, showInvite: $showInvite) { LeaderboardView(me: me) }
                .tabItem { Label("Board", systemImage: "trophy.fill") }
        }
        .sheet(isPresented: $showInvite) { InviteSheet(me: me) }
    }
}

struct NavWrap<Content: View>: View {
    let title: String
    let me: Player
    @Binding var showInvite: Bool
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            ZStack { Color.paper.ignoresSafeArea(); content }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showInvite = true }) {
                            Label("Invite", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

// MARK: - Invite (real iOS share sheet via ShareLink)

struct InviteSheet: View {
    let me: Player
    @Environment(\.dismiss) private var dismiss

    private var code: String {
        String(me.handle.uppercased().prefix(4)) + String(abs(me.id.hashValue), radix: 36).uppercased().prefix(4)
    }
    private var link: String { "https://foursome.app/join/\(code)" }
    private var message: String {
        "Come play on Foursome — track our rounds and I'll open a spot next time I tee off. Join: \(link)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paper.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Every friend you add makes an open spot easier to fill. Share your invite — when they join, they land in your clubhouse.")
                        .foregroundStyle(Color.inkSoft)

                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow("Your invite link")
                        Text(link)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.fairway800)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.paper100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    ShareLink(item: message) {
                        Label("Share invite", systemImage: "square.and.arrow.up")
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.fairway800).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Invite friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
