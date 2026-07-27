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

    private func enter(name: String, homeCourseID: String?) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }

        if let existing = players.first(where: { $0.name.lowercased() == clean.lowercased() }) {
            // Signing back in as a seeded player shouldn't wipe their course.
            if let homeCourseID, existing.homeCourseID == nil {
                existing.homeCourseID = homeCourseID
            }
            meID = existing.id.uuidString
            return
        }

        let player = Player(name: clean)
        player.homeCourseID = homeCourseID
        context.insert(player)

        // Save before handing off to `meID`. Without this the new player may
        // not be in `players` yet when the view re-renders, so `me` resolves to
        // nil and onboarding just sits there looking broken.
        try? context.save()

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

        // Explicit indexes because a computed baseline needs three rounds and
        // these players are seeded with one or two. A spread from low single
        // digits to mid-teens is what makes net scoring visibly different from
        // gross on the very first screen.
        marcus.handicapIndex = 8.2
        tyler.handicapIndex = 2.4
        deshawn.handicapIndex = 16.1
        ryan.handicapIndex = 5.0

        // Marcus and Tyler are members at Brookstone (private); Deshawn plays
        // elsewhere and Ryan has no home course. That's what makes a club-only
        // round visibly different: as Marcus you see it, as Deshawn you don't.
        marcus.homeCourseID = "c5"
        tyler.homeCourseID = "c5"
        deshawn.homeCourseID = "c2"
        ryan.homeCourseID = nil

        [marcus, tyler, deshawn, ryan].forEach { context.insert($0) }

        let day: TimeInterval = 86_400

        // Most seeded rounds carry a full card so the feed has something to
        // expand on first run. One is left total-only on purpose, to prove the
        // feed handles a round logged the quick way.
        let seededRounds: [Round] = [
            Round(playerID: marcus.id, courseID: "c1",
                  holeScores: [4, 5, 3, 6, 4, 4, 4, 5, 4,  5, 5, 3, 4, 5, 3, 4, 5, 6],  // 79
                  par: 71, date: .now.addingTimeInterval(-day)),
            Round(playerID: tyler.id, courseID: "c3",
                  holeScores: [5, 4, 4, 2, 4, 5, 3, 4, 4,  4, 4, 3, 5, 4, 3, 4, 4, 5],  // 71
                  par: 72, date: .now.addingTimeInterval(-2*day)),
            Round(playerID: deshawn.id, courseID: "c2",
                  holeScores: [5, 7, 4, 5, 5, 4, 6, 5, 4,  5, 4, 5, 6, 5, 5, 4, 5, 4],  // 88
                  par: 72, date: .now.addingTimeInterval(-3*day)),
            Round(playerID: ryan.id, courseID: "c4",
                  holeScores: [4, 3, 5, 5, 4, 4, 3, 5, 4,  5, 4, 4, 4, 4, 5, 3, 4, 4],  // 74
                  par: 72, date: .now.addingTimeInterval(-4*day)),
            Round(playerID: marcus.id, courseID: "c5", strokes: 83,
                  par: 72, date: .now.addingTimeInterval(-6*day)),
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
        // Marcus is friends with both authors, so signed in as Marcus you see
        // both; Tyler's club post is invisible to anyone who isn't a member.
        let p1 = Post(authorID: deshawn.id, text: "New irons showed up. Somebody come watch me hit them badly.", audience: .friends)
        let p2 = Post(authorID: tyler.id, text: "Greens got aerated this week — play the front if you can.", audience: .club)
        p1.likes = [marcus.id.uuidString]
        [p1, p2].forEach { context.insert($0) }

        let g4 = OpenRound(hostID: tyler.id, courseID: "c5", date: .now.addingTimeInterval(4*day), time: "9:00 AM", spots: 4, note: "Member guest warm-up. Members only.", visibility: .club)
        context.insert(g1)
        context.insert(g2)
        context.insert(g3)
        context.insert(g4)
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    var onEnter: (String, String?) -> Void
    @State private var name = ""
    @State private var homeCourseID: String? = nil

    private var canEnter: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            TurfBackground().ignoresSafeArea()
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

                Eyebrow("Get started", tint: Color.flagSoft)
                    .padding(.bottom, 6)
                TextField("", text: $name, prompt: Text("Your first name").foregroundStyle(.white.opacity(0.5)))
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Color.black.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fairway700, lineWidth: 1))
                    .submitLabel(.go)
                    .onSubmit { if canEnter { onEnter(name, homeCourseID) } }

                // Optional on purpose: asking for it is useful, requiring it
                // would be a wall in front of the door.
                HStack {
                    Text("Home course").foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Picker("Home course", selection: $homeCourseID) {
                        Text("Skip for now").tag(String?.none)
                        ForEach(Course.all) { c in
                            Text(c.isPrivate ? "\(c.name) (private)" : c.name)
                                .tag(String?.some(c.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.flagSoft)
                }
                .font(.subheadline)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fairway700, lineWidth: 1))
                .padding(.top, 10)

                Text("Optional. Members at a private club can post rounds only their fellow members see.")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 6)

                Button(action: { onEnter(name, homeCourseID) }) {
                    Text("Enter the clubhouse")
                        .font(.headline)
                        .foregroundStyle(canEnter ? Color.rough : Color.rough.opacity(0.45))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(canEnter ? Color.sand : Color.sand.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canEnter)
                .padding(.top, 12)

                // A name is required, so say so rather than letting the button
                // silently do nothing.
                Text(canEnter ? " " : "Enter a first name to continue.")
                    .font(.caption)
                    .foregroundStyle(Color.flagSoft)
                    .padding(.top, 6)

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
            NavWrap(title: "Friends", me: me, showInvite: $showInvite) { FriendsView(me: me) }
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
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
    @State private var showScoring = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paper.ignoresSafeArea()
                VStack(spacing: 0) {
                    CourseHeader(eyebrow: "Saturday is a group project",
                                 title: "Foursome",
                                 subtitle: title) {
                        HStack(spacing: 8) {
                            headerButton("slider.horizontal.3", label: "Scoring settings") {
                                showScoring = true
                            }
                            headerButton("square.and.arrow.up", label: "Invite friends") {
                                showInvite = true
                            }
                        }
                    }
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showScoring) { ScoringSettingsView(me: me) }
    }

    private func headerButton(_ symbol: String, label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(9)
                .background(.white.opacity(0.15), in: Circle())
        }
        .accessibilityLabel(label)
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
