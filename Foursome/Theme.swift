import SwiftUI

// MARK: - Palette (grounded in a scorecard: fairway greens, paper stone, an amber flag)

extension Color {
    static let fairway   = Color(red: 6/255,   green: 78/255,  blue: 59/255)   // emerald-900
    static let fairway800 = Color(red: 6/255,  green: 95/255,  blue: 70/255)   // emerald-800
    static let fairway700 = Color(red: 4/255,  green: 120/255, blue: 87/255)   // emerald-700
    static let fairway50 = Color(red: 236/255, green: 253/255, blue: 245/255)  // emerald-50
    static let paper     = Color(red: 250/255, green: 250/255, blue: 249/255)  // stone-50
    static let paper100  = Color(red: 245/255, green: 245/255, blue: 244/255)  // stone-100
    static let paper200  = Color(red: 231/255, green: 229/255, blue: 228/255)  // stone-200
    static let ink       = Color(red: 41/255,  green: 37/255,  blue: 36/255)   // stone-800
    static let inkSoft   = Color(red: 120/255, green: 113/255, blue: 108/255)  // stone-500
    static let flag      = Color(red: 251/255, green: 191/255, blue: 36/255)   // amber-400
    static let flagSoft  = Color(red: 252/255, green: 211/255, blue: 77/255)   // amber-300
    static let overPar   = Color(red: 190/255, green: 18/255,  blue: 60/255)   // rose-700
}

// MARK: - Eyebrow label (uppercase mono kicker, a scorecard tell)

struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption2, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(Color.fairway700.opacity(0.8))
    }
}

// MARK: - Score badge with real scorecard notation (birdie in a circle, bogey in a square)

struct ScoreBadge: View {
    let strokes: Int
    let par: Int
    var large: Bool = false

    private var diff: Int { strokes - par }
    private var kind: ScoreKind { scoreKind(toPar: diff) }
    private var isCircle: Bool { diff <= -1 }

    private var stroke: Color {
        switch kind {
        case .eagle, .birdie: return .fairway700
        case .par: return Color.paper200
        case .bogey: return Color.inkSoft
        case .doublePlus: return Color.overPar
        }
    }
    private var fill: Color {
        switch kind {
        case .eagle, .birdie: return .fairway50
        case .doublePlus: return Color.overPar.opacity(0.08)
        default: return .white
        }
    }
    private var textColor: Color {
        switch kind {
        case .eagle, .birdie: return .fairway700
        case .doublePlus: return .overPar
        default: return .ink
        }
    }

    var body: some View {
        let size: CGFloat = large ? 44 : 36
        Text("\(strokes)")
            .font(.system(large ? .title3 : .subheadline, design: .monospaced).weight(.semibold))
            .foregroundStyle(textColor)
            .frame(width: size, height: size)
            .background(fill)
            .overlay(
                Group {
                    if isCircle {
                        Circle().stroke(stroke, lineWidth: kind == .eagle ? 2.5 : 2)
                    } else {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(stroke, lineWidth: kind == .doublePlus ? 2.5 : 1.5)
                    }
                }
            )
            .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 7)))
    }
}

// MARK: - Avatar (initial in a fairway chip)

struct Avatar: View {
    let name: String
    var large: Bool = false
    var body: some View {
        let size: CGFloat = large ? 48 : 36
        Text(String(name.prefix(1)).uppercased())
            .font(.system(large ? .headline : .footnote).weight(.bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.fairway800)
            .clipShape(Circle())
    }
}

// MARK: - Card container

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.paper200, lineWidth: 1))
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let systemImage: String
    let title: String
    let body: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(Color.fairway700)
                .frame(width: 56, height: 56)
                .background(Color.fairway50)
                .clipShape(Circle())
            Text(title).font(.system(.headline, design: .serif))
            Text(self.body)
                .font(.subheadline)
                .foregroundStyle(Color.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }
}
