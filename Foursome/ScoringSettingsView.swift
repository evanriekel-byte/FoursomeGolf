import SwiftUI
import SwiftData

/// Where a player sets what their scores get measured against.
struct ScoringSettingsView: View {
    let me: Player
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var rounds: [Round]

    @AppStorage("meID") private var meID: String = ""
    @AppStorage("didSeed") private var didSeed: Bool = false

    @State private var indexText = ""
    @State private var mode: ScoringMode = .personal

    /// What we'd work out on our own, ignoring anything entered by hand.
    private var computed: Double? {
        Handicap.index(differentials: Handicap.differentials(for: me.id, rounds: rounds))
    }
    private var roundCount: Int { rounds.filter { $0.playerID == me.id }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        modePicker
                        if mode == .personal {
                            indexField
                            baselineSummary
                        }
                        ghinNote
                        resetSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Scoring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() }.fontWeight(.semibold) }
            }
            .onAppear {
                mode = me.scoringMode
                indexText = me.handicapIndex.map { ScoringContext.formatted($0) } ?? ""
            }
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Measure my holes against")
            VStack(spacing: 0) {
                ForEach(Array(ScoringMode.allCases.enumerated()), id: \.element.id) { i, option in
                    if i > 0 { Divider() }
                    Button { mode = option } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label).font(.subheadline.weight(.medium)).foregroundStyle(Color.ink)
                                Text(option.detail).font(.caption).foregroundStyle(Color.inkSoft)
                            }
                            Spacer()
                            if mode == option {
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

    private var indexField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Handicap index")
            TextField(computed.map { "Leave blank to use \(ScoringContext.formatted($0))" } ?? "e.g. 18.4",
                      text: $indexText)
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .monospaced))
                .padding(14)
                .background(Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
            Text("Blank means we work it out from your rounds.")
                .font(.caption).foregroundStyle(Color.inkSoft)
        }
    }

    private var baselineSummary: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("From your rounds")
                if let computed {
                    Text(ScoringContext.formatted(computed))
                        .font(.system(.title, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Text("Based on your \(roundCount) logged round\(roundCount == 1 ? "" : "s").")
                        .font(.caption).foregroundStyle(Color.inkSoft)
                } else {
                    Text("Not enough rounds yet")
                        .font(.system(.headline, design: .serif)).foregroundStyle(Color.ink)
                    Text("Log \(max(0, 3 - roundCount)) more and we can work out a baseline. Until then holes are marked against par.")
                        .font(.caption).foregroundStyle(Color.inkSoft)
                }
            }
        }
    }

    private var ghinNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("About GHIN")
            Text("We can't pull your GHIN index automatically. The USGA only opens that data to licensed partners, so there's no key to plug in. Type your index above and it'll behave the same.")
                .font(.caption).foregroundStyle(Color.inkSoft)
            Text("This number is a baseline for reading your own scorecards. It isn't an official handicap and can't be used for competition.")
                .font(.caption).foregroundStyle(Color.inkSoft)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.paper100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Temporary, while the app is still being shaken out. Failed sign-in
    /// attempts can leave stray players behind, and there's otherwise no way to
    /// clear them or get the demo clubhouse back without deleting the app.
    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Start over")
            Text("Deletes everything on this phone and rebuilds the demo clubhouse, then returns you to the sign-in screen.")
                .font(.caption).foregroundStyle(Color.inkSoft)
            Button(role: .destructive, action: resetEverything) {
                Text("Reset all data")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.overPar)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.overPar.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.overPar.opacity(0.4), lineWidth: 1))
            }
            .padding(.top, 4)
        }
    }

    private func resetEverything() {
        DemoData.wipe(context)
        didSeed = false
        meID = ""          // RootView watches this and signs out
        dismiss()
    }

    private func save() {
        me.scoringMode = mode
        let clean = indexText.trimmingCharacters(in: .whitespaces)
        // Accept "+2.1" for a plus handicap, which is better than scratch.
        if clean.isEmpty {
            me.handicapIndex = nil
        } else if let value = Double(clean.replacingOccurrences(of: "+", with: "-")) {
            me.handicapIndex = min(54, max(-10, value))
        }
        dismiss()
    }
}
