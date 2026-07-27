import SwiftUI

// MARK: - Palette
//
// Sampled off an actual course rather than off a UI palette. The rule: every
// color has to name something you'd walk past between the first tee and the
// clubhouse. Greens lean warm and olive because chlorophyll does — the old
// emerald ramp was a blue-leaning jewel tone that read "premium app," not
// "turf." Neutrals are bunker sand and warm scorecard stock, not grey.

extension Color {
    init(hex: UInt32) {
        self.init(red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >>  8) & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255)
    }

    // Turf, dark to light
    static let rough      = Color(hex: 0x16301F)  // treeline shadow, deepest surface
    static let fairway    = Color(hex: 0x1F4A2C)  // fairway in shade
    static let fairwayLit = Color(hex: 0x2E6B3A)  // the sunlit half of a mown stripe
    static let putting    = Color(hex: 0x5C8A4A)  // green complex, warm and fine
    static let dew        = Color(hex: 0xE8F0DC)  // palest turf tint, for fills

    // Sand and paper
    static let sand       = Color(hex: 0xDFCFA6)  // bunker face
    static let paper      = Color(hex: 0xF7F5EA)  // scorecard stock
    static let card       = Color(hex: 0xFFFDF6)  // a fresh card laid on the stock
    static let paper100   = Color(hex: 0xF0ECDC)
    static let paper200   = Color(hex: 0xDFD9C2)  // pencil rule on a scorecard

    // Ink — warm, like pencil on card, never neutral grey
    static let ink        = Color(hex: 0x2A2820)
    static let inkSoft    = Color(hex: 0x6E6A58)

    // Course furniture
    static let flag       = Color(hex: 0xC0392B)  // flagstick red
    static let flagSoft   = Color(hex: 0xE07A5F)
    static let water      = Color(hex: 0x3D6B7D)  // hazard
    static let overPar    = Color(hex: 0xA8342A)

    // Compatibility aliases so existing views retheme without edits.
    // fairway700 maps to fairwayLit, not putting: it's used for small text on
    // cream, and putting only reaches ~3.9:1 there. fairwayLit clears AA.
    static let fairway800 = Color.fairway
    static let fairway700 = Color.fairwayLit
    static let fairway50  = Color.dew
}

// MARK: - Mown stripes
//
// The signature of a maintained course: a mower running one way then the other,
// laying the blades in opposite directions so alternating bands catch the light.
// Overlay it on any turf-colored surface. Purely decorative, so it never takes
// touches.

struct FairwayStripes: View {
    var bandWidth: CGFloat = 30
    var angle: Angle = .degrees(-22)
    var strength: Double = 0.055

    var body: some View {
        GeometryReader { geo in
            let span = (geo.size.width + geo.size.height) * 1.4
            let count = Int(span / bandWidth) + 2
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i.isMultiple(of: 2) ? strength : 0))
                        .frame(width: bandWidth)
                }
            }
            .frame(width: span, height: span)
            .rotationEffect(angle)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .allowsHitTesting(false)
        .clipped()
    }
}

/// A turf panel: deep green, mown, with the light falling from the top.
struct TurfBackground: View {
    var body: some View {
        LinearGradient(colors: [.fairwayLit, .fairway, .rough],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(FairwayStripes())
    }
}

// MARK: - Masthead

struct CourseHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background bleeds under the status bar; content below stays clear of it.
            TurfBackground().ignoresSafeArea(edges: .top)
            HStack(alignment: .top, spacing: 14) {
                Flagstick()
                trailing
            }
            .padding(.trailing, 20)
            .padding(.top, 16)
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.system(.caption2, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))
                Text(title)
                    .font(.system(size: 40, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 26)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension CourseHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Pin and flag, with the cup shadow on the green.
struct Flagstick: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(.white.opacity(0.85)).frame(width: 1.5, height: 46)
                Triangle().fill(Color.flag)
                    .frame(width: 20, height: 14)
                    .offset(x: 1.5)
            }
            Ellipse().fill(.black.opacity(0.18)).frame(width: 22, height: 5)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height / 2))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
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
        case .eagle, .birdie: return .dew
        case .doublePlus: return Color.overPar.opacity(0.08)
        default: return .card
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
            .background(Color.card)
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
