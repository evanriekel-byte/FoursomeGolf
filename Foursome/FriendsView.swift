import SwiftUI
import SwiftData

/// Add friends, answer requests, and keep groups. Until this existed the friend
/// graph could only be populated by seed data, which made every friend-based
/// audience unusable for anyone who signed up for real.
struct FriendsView: View {
    let me: Player
    @Environment(\.modelContext) private var context

    @Query private var players: [Player]
    @Query private var friendships: [Friendship]
    @Query(sort: \PlayerGroup.createdAt, order: .reverse) private var groups: [PlayerGroup]

    @State private var search = ""
    @State private var showNewGroup = false

    private var graph: SocialGraph {
        SocialGraph(friendships: friendships, groups: groups, players: players)
    }

    private var myFriends: [Player] {
        let ids = graph.friends(of: me.id)
        return players.filter { ids.contains($0.id) }.sorted { $0.name < $1.name }
    }

    private var incoming: [Friendship] { graph.pendingRequests(for: me.id) }
    private var outgoingIDs: Set<UUID> {
        Set(graph.sentRequests(from: me.id).map(\.addresseeID))
    }

    /// Everyone who isn't me and isn't already a friend, filtered by search.
    private var addable: [Player] {
        let friendIDs = graph.friends(of: me.id)
        let incomingIDs = Set(incoming.map(\.requesterID))
        let term = search.trimmingCharacters(in: .whitespaces).lowercased()

        return players
            .filter { $0.id != me.id && !friendIDs.contains($0.id) && !incomingIDs.contains($0.id) }
            .filter { term.isEmpty || $0.name.lowercased().contains(term) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !incoming.isEmpty { requestsSection }
                friendsSection
                groupsSection
                addSection
            }
            .padding(16)
        }
        .sheet(isPresented: $showNewGroup) {
            NewGroupSheet(me: me, friends: myFriends)
        }
    }

    // MARK: - Sections

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Wants to be friends")
            ForEach(incoming, id: \.id) { request in
                if let requester = players.first(where: { $0.id == request.requesterID }) {
                    Card {
                        HStack(spacing: 12) {
                            Avatar(name: requester.name)
                            Text(requester.name).font(.headline)
                            Spacer()
                            Button(action: { decline(request) }) {
                                Image(systemName: "xmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.inkSoft)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(Color.paper200, lineWidth: 1))
                            }
                            Button(action: { accept(request) }) {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Color.fairway800)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
            }
        }
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Your friends (\(myFriends.count))")
            if myFriends.isEmpty {
                Text("No friends yet. Add someone below and your feed fills up.")
                    .font(.subheadline).foregroundStyle(Color.inkSoft)
                    .padding(.vertical, 4)
            } else {
                ForEach(myFriends) { friend in
                    Card {
                        HStack(spacing: 12) {
                            Avatar(name: friend.name)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(friend.name).font(.headline)
                                if let index = friend.handicapIndex {
                                    Text("index \(ScoringContext.formatted(index))")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(Color.inkSoft)
                                }
                            }
                            Spacer()
                            Menu {
                                Button("Remove friend", role: .destructive) { remove(friend) }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundStyle(Color.inkSoft)
                                    .frame(width: 34, height: 34)
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow("Groups")
                Spacer()
                Button(action: { showNewGroup = true }) {
                    Label("New", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.fairway800)
                }
            }

            if groups.isEmpty {
                Text("Groups let you invite the same people without picking them one by one.")
                    .font(.subheadline).foregroundStyle(Color.inkSoft)
            } else {
                ForEach(groups) { group in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(group.name).font(.headline)
                                Spacer()
                                Text("\(group.memberIDs.count)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Color.inkSoft)
                            }
                            FlexWrap(items: group.memberIDs.compactMap { idString in
                                players.first { $0.id.uuidString == idString }?.name
                            })
                        }
                    }
                }
            }
        }
    }

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Add someone")

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.inkSoft)
                TextField("Search by name", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))

            if addable.isEmpty {
                Text(search.isEmpty ? "Everyone here is already a friend."
                                    : "Nobody matches \"\(search)\".")
                    .font(.subheadline).foregroundStyle(Color.inkSoft)
                    .padding(.top, 2)
            } else {
                ForEach(addable) { person in
                    let requested = outgoingIDs.contains(person.id)
                    Card {
                        HStack(spacing: 12) {
                            Avatar(name: person.name)
                            Text(person.name).font(.headline)
                            Spacer()
                            Button(action: { request(person) }) {
                                Text(requested ? "Requested" : "Add")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(requested ? Color.inkSoft : .white)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(requested ? Color.paper100 : Color.fairway800)
                                    .clipShape(Capsule())
                            }
                            .disabled(requested)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func request(_ person: Player) {
        // An edge either way already covers this pair.
        guard graph.edge(between: me.id, and: person.id) == nil else { return }
        context.insert(Friendship(requesterID: me.id, addresseeID: person.id))
    }

    private func accept(_ friendship: Friendship) {
        friendship.accepted = true
    }

    private func decline(_ friendship: Friendship) {
        context.delete(friendship)
    }

    private func remove(_ friend: Player) {
        guard let edge = graph.edge(between: me.id, and: friend.id) else { return }
        context.delete(edge)
    }
}

// MARK: - New group

struct NewGroupSheet: View {
    let me: Player
    let friends: [Player]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selected: Set<UUID> = []

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selected.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow("Group name")
                            TextField("Saturday regulars", text: $name)
                                .padding(14)
                                .background(Color.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("Members")
                            if friends.isEmpty {
                                Text("Add a friend first — groups are built from people you've added.")
                                    .font(.subheadline).foregroundStyle(Color.inkSoft)
                            } else {
                                ForEach(friends) { friend in
                                    Button { toggle(friend.id) } label: {
                                        HStack(spacing: 12) {
                                            Avatar(name: friend.name)
                                            Text(friend.name).font(.subheadline.weight(.medium))
                                                .foregroundStyle(Color.ink)
                                            Spacer()
                                            Image(systemName: selected.contains(friend.id)
                                                  ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selected.contains(friend.id)
                                                                 ? Color.fairway800 : Color.paper200)
                                        }
                                        .padding(12)
                                        .background(Color.card)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { create() }
                        .fontWeight(.semibold)
                        .disabled(!valid)
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func create() {
        guard valid else { return }
        let group = PlayerGroup(name: name.trimmingCharacters(in: .whitespaces),
                                ownerID: me.id,
                                memberIDs: Array(selected))
        context.insert(group)
        dismiss()
    }
}
