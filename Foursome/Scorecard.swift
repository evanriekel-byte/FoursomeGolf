import SwiftUI

// MARK: - Hole notation
//
// Real scorecard marking, which is why per-hole scores are worth storing at
// all: a bare number tells you nothing at a glance, but the shapes do.
//   eagle or better — double circle
//   birdie          — circle
//   par             — bare number
//   bogey           — square
//   double or worse — double square

struct HoleScoreMark: View {
    let strokes: Int
    /// What this hole is measured against — par under scratch scoring, par plus
    /// strokes received under personal scoring.
    let reference: Int
    var size: CGFloat = 26

    private var kind: ScoreKind { scoreKind(toPar: strokes - reference) }

    private var tint: Color {
        switch kind {
        case .eagle, .birdie: return .fairwayLit
        case .par:            return .ink
        case .bogey:          return .inkSoft
        case .doublePlus:     return .overPar
        }
    }

    var body: some View {
        Text("\(strokes)")
            .font(.system(size: size * 0.52, weight: .medium, design: .monospaced))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .overlay { shape }
    }

    @ViewBuilder private var shape: some View {
        switch kind {
        case .eagle:
            ZStack {
                Circle().stroke(tint, lineWidth: 1.2)
                Circle().stroke(tint, lineWidth: 1.2).padding(2.5)
            }
        case .birdie:
            Circle().stroke(tint, lineWidth: 1.4)
        case .par:
            EmptyView()
        case .bogey:
            RoundedRectangle(cornerRadius: 3).stroke(tint, lineWidth: 1.4)
        case .doublePlus:
            ZStack {
                RoundedRectangle(cornerRadius: 3).stroke(tint, lineWidth: 1.2)
                RoundedRectangle(cornerRadius: 2).stroke(tint, lineWidth: 1.2).padding(2.5)
            }
        }
    }
}

// MARK: - Read-only card (feed)

/// Front nine and back nine as two banded rows, the way a paper card reads.
struct ScorecardTable: View {
    let holeScores: [Int]
    let context: ScoringContext

    private var references: [Int] { context.netPars }

    var body: some View {
        VStack(spacing: 6) {
            nine(range: 0..<9, label: "OUT")
            nine(range: 9..<18, label: "IN")
            HStack {
                Text(context.caption)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.inkSoft.opacity(0.8))
                Spacer()
            }
            .padding(.top, 2)
        }
        .padding(10)
        .background(Color.paper100)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func nine(range: Range<Int>, label: String) -> some View {
        let scores = range.compactMap { holeScores.indices.contains($0) ? holeScores[$0] : nil }
        let total = scores.reduce(0, +)

        return VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(range, id: \.self) { i in
                    Text("\(i + 1)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.inkSoft.opacity(0.8))
                        .frame(maxWidth: .infinity)
                }
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.inkSoft)
                    .frame(width: 34)
            }
            HStack(spacing: 0) {
                ForEach(range, id: \.self) { i in
                    Group {
                        if holeScores.indices.contains(i), references.indices.contains(i) {
                            HoleScoreMark(strokes: holeScores[i], reference: references[i], size: 24)
                        } else {
                            Text("–").font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color.inkSoft.opacity(0.5))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                Text("\(total)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.ink)
                    .frame(width: 34)
            }
        }
    }
}

// MARK: - Entry grid (logging)

/// Eighteen holes, six to a row, each pre-filled with par so a level round is
/// zero taps and most rounds are only a few. Starting from par rather than
/// from zero is the whole ergonomic trick here.
struct ScorecardEditor: View {
    @Binding var holeScores: [Int]
    let context: ScoringContext

    private var holePars: [Int] { context.holePars }
    private var references: [Int] { context.netPars }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<18, id: \.self) { i in
                cell(i)
            }
        }
    }

    private func cell(_ i: Int) -> some View {
        let par = holePars.indices.contains(i) ? holePars[i] : 4
        let reference = references.indices.contains(i) ? references[i] : par
        let score = holeScores.indices.contains(i) ? holeScores[i] : par

        return VStack(spacing: 3) {
            Text("\(i + 1)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.inkSoft.opacity(0.8))

            HoleScoreMark(strokes: score, reference: reference, size: 28)

            HStack(spacing: 2) {
                stepButton("minus") { adjust(i, by: -1) }
                stepButton("plus") { adjust(i, by: 1) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hole \(i + 1), par \(par)")
        .accessibilityValue("\(score)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(i, by: 1)
            case .decrement: adjust(i, by: -1)
            @unknown default: break
            }
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.inkSoft)
                .frame(width: 20, height: 18)
                .background(Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.paper200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Clamped to 1...15 — a 15 is already a bad day, and it keeps a stray
    /// long-press from producing a nonsense card.
    private func adjust(_ i: Int, by delta: Int) {
        guard holeScores.indices.contains(i) else { return }
        holeScores[i] = min(15, max(1, holeScores[i] + delta))
    }
}
