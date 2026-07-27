import SwiftUI
import SwiftData

/// Write a post and choose who sees it.
struct PostComposer: View {
    let me: Player

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var players: [Player]
    @Query(sort: \PlayerGroup.createdAt, order: .reverse) private var groups: [PlayerGroup]
    @Query private var friendships: [Friendship]

    @State private var text = ""
    @State private var audience: PostAudience = .friends
    @State private var pickedPlayers: Set<UUID> = []
    @State private var pickedGroups: Set<UUID> = []

    private var graph: SocialGraph {
        SocialGraph(friendships: friendships, groups: groups, players: players)
    }

    private var myFriends: [Player] {
        let ids = graph.friends(of: me.id)
        return players.filter { ids.contains($0.id) }.sorted { $0.name < $1.name }
    }

    private var valid: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard audience == .selected else { return hasText }
        // "Specific people" with nobody picked would post to an audience of one.
        return hasText && !(pickedPlayers.isEmpty && pickedGroups.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Anyone free Saturday morning?", text: $text, axis: .vertical)
                            .lineLimit(3...8)
                            .padding(14)
                            .background(Color.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))

                        audiencePicker

                        if audience == .selected { recipientPicker }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") { post() }.fontWeight(.semibold).disabled(!valid)
                }
            }
        }
    }

    private var audiencePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Who can see this")
            VStack(spacing: 0) {
                ForEach(Array(PostAudience.options(for: me).enumerated()), id: \.element.id) { i, option in
                    if i > 0 { Divider() }
                    Button { audience = option } label: {
                        HStack(spacing: 12) {
                            Image(systemName: option.systemImage)
                                .foregroundStyle(audience == option ? Color.fairway800 : Color.inkSoft)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.label).font(.subheadline.weight(.medium)).foregroundStyle(Color.ink)
                                Text(option.detail).font(.caption).foregroundStyle(Color.inkSoft)
                            }
                            Spacer()
                            if audience == option {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
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
    }

    private var recipientPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !groups.isEmpty {
                Eyebrow("Groups")
                ForEach(groups) { group in
                    row(title: group.name,
                        subtitle: "\(group.memberIDs.count) people",
                        selected: pickedGroups.contains(group.id)) {
                        toggle(group.id, in: &pickedGroups)
                    }
                }
            }

            Eyebrow("People")
            if myFriends.isEmpty {
                Text("Add a friend first — there's nobody to pick yet.")
                    .font(.subheadline).foregroundStyle(Color.inkSoft)
            } else {
                ForEach(myFriends) { friend in
                    row(title: friend.name, subtitle: nil,
                        selected: pickedPlayers.contains(friend.id)) {
                        toggle(friend.id, in: &pickedPlayers)
                    }
                }
            }
        }
    }

    private func row(title: String, subtitle: String?, selected: Bool,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Avatar(name: title)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Color.ink)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(Color.inkSoft)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.fairway800 : Color.paper200)
            }
            .padding(12)
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
        }
    }

    private func toggle(_ id: UUID, in set: inout Set<UUID>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    private func post() {
        guard valid else { return }
        let new = Post(authorID: me.id,
                       text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                       audience: audience,
                       invitedPlayerIDs: Array(pickedPlayers),
                       invitedGroupIDs: Array(pickedGroups))
        context.insert(new)
        dismiss()
    }
}
