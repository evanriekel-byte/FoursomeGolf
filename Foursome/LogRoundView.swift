import SwiftUI
import SwiftData

struct LogRoundView: View {
    let me: Player
    @Environment(\.modelContext) private var context

    @State private var courseID = Course.all.first!.id
    @State private var strokesText = ""
    @State private var showConfirm = false

    private var par: Int { Course.by(courseID)?.par ?? 72 }
    private var strokes: Int? { Int(strokesText) }
    private var valid: Bool { if let s = strokes { return s >= 50 && s <= 160 }; return false }
    private var diff: Int? { strokes.map { $0 - par } }

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

                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TO PAR").font(.system(.caption2, design: .monospaced)).foregroundStyle(Color.inkSoft)
                            Text(diff.map(toParText) ?? "—")
                                .font(.system(.title, design: .monospaced).weight(.semibold))
                                .foregroundStyle((diff ?? 0) < 0 ? Color.fairway700 : Color.ink)
                        }
                        Spacer()
                        if valid, let s = strokes { ScoreBadge(strokes: s, par: par, large: true) }
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

    private func save() {
        guard let s = strokes, valid else { return }
        context.insert(Round(playerID: me.id, courseID: courseID, strokes: s, par: par))
        strokesText = ""
        withAnimation { showConfirm = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showConfirm = false }
        }
    }
}
