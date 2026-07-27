import SwiftUI
import SwiftData

struct LogRoundView: View {
    let me: Player
    @Environment(\.modelContext) private var context

    private enum Mode: String, CaseIterable, Identifiable {
        case scorecard, total
        var id: String { rawValue }
        var label: String { self == .scorecard ? "Hole by hole" : "Just the total" }
    }

    @State private var courseID = Course.all.first!.id
    @State private var mode: Mode = .scorecard
    @State private var holeScores: [Int] = []
    @State private var strokesText = ""
    @State private var showConfirm = false

    @Query private var allRounds: [Round]

    private var course: Course? { Course.by(courseID) }
    private var holePars: [Int] { course?.holePars ?? Array(repeating: 4, count: 18) }
    private var par: Int { course?.par ?? 72 }

    private var scoring: ScoringContext {
        guard let course else {
            return ScoringContext(holePars: holePars, netPars: holePars, caption: "vs par", index: nil)
        }
        return .make(player: me, course: course, rounds: allRounds)
    }

    /// Par plus my strokes, for reading the round total net.
    private var referenceTotal: Int {
        let nets = scoring.netPars
        return nets.isEmpty ? par : nets.reduce(0, +)
    }

    private var strokes: Int? {
        switch mode {
        case .scorecard: return holeScores.isEmpty ? nil : holeScores.reduce(0, +)
        case .total:     return Int(strokesText)
        }
    }

    private var valid: Bool {
        guard let s = strokes else { return false }
        return s >= 18 && s <= 200
    }
    private var diff: Int? { strokes.map { $0 - par } }
    private var netDiff: Int? { strokes.map { $0 - referenceTotal } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow("New score")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Course").font(.subheadline.weight(.medium)).foregroundStyle(Color.inkSoft)
                    Picker("Course", selection: $courseID) {
                        ForEach(Course.all) { c in
                            Text("\(c.name) — \(c.city) (par \(c.par))").tag(c.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.fairway800)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
                }

                Picker("How", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                if mode == .scorecard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tap a hole to adjust")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.inkSoft)
                        ScorecardEditor(holeScores: $holeScores, context: scoring)
                            .padding(14)
                            .background(Color.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total strokes").font(.subheadline.weight(.medium)).foregroundStyle(Color.inkSoft)
                        TextField("e.g. 82", text: $strokesText)
                            .keyboardType(.numberPad)
                            .font(.system(.title3, design: .monospaced))
                            .padding(14)
                            .background(Color.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.paper200, lineWidth: 1))
                    }
                }

                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scoring.index == nil ? "TO PAR" : "TO YOUR NUMBER")
                                .font(.system(.caption2, design: .monospaced)).foregroundStyle(Color.inkSoft)
                            Text(netDiff.map(toParText) ?? "—")
                                .font(.system(.title, design: .monospaced).weight(.semibold))
                                .foregroundStyle((netDiff ?? 0) < 0 ? Color.fairway700 : Color.ink)
                            if scoring.index != nil, let d = diff {
                                Text("\(toParText(d)) to par")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Color.inkSoft.opacity(0.8))
                            }
                        }
                        Spacer()
                        if valid, let s = strokes {
                            ScoreBadge(strokes: s, par: par, large: true, reference: referenceTotal)
                        }
                    }
                }

                Button(action: save) {
                    Text("Post round")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(valid ? Color.fairway800 : Color.paper200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!valid)
            }
            .padding(16)
        }
        .onAppear(perform: resetCardIfNeeded)
        // Re-seed to the new course's pars, but only while the card is still
        // untouched — switching courses mid-entry shouldn't wipe real scores.
        .onChange(of: courseID) { _, _ in
            if holeScores == previousPars || holeScores.isEmpty { resetCard() }
            previousPars = holePars
        }
        .overlay(alignment: .bottom) {
            if showConfirm {
                Label("Round posted", systemImage: "checkmark.circle.fill")
                    .font(.subheadline).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.fairway).clipShape(Capsule())
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @State private var previousPars: [Int] = []

    private func resetCardIfNeeded() {
        if holeScores.count != 18 { resetCard() }
        previousPars = holePars
    }

    /// Start every hole at par: a level round is zero taps.
    private func resetCard() {
        holeScores = holePars
    }

    private func save() {
        guard let s = strokes, valid else { return }

        let round: Round
        switch mode {
        case .scorecard:
            round = Round(playerID: me.id, courseID: courseID, holeScores: holeScores, par: par)
        case .total:
            round = Round(playerID: me.id, courseID: courseID, strokes: s, par: par)
        }
        context.insert(round)

        strokesText = ""
        resetCard()
        withAnimation { showConfirm = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showConfirm = false }
        }
    }
}
