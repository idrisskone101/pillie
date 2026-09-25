import SwiftUI

/// A soft crest shield (matching the Coral Canopy / Lottie shield silhouette).
struct CrestShield: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + x / 96 * r.width, y: r.minY + y / 104 * r.height)
        }
        var path = Path()
        path.move(to: p(48, 4))
        path.addLine(to: p(88, 20))
        path.addLine(to: p(88, 52))
        path.addCurve(to: p(48, 100), control1: p(88, 78), control2: p(70, 94))
        path.addCurve(to: p(8, 52), control1: p(26, 94), control2: p(8, 78))
        path.addLine(to: p(8, 20))
        path.closeSubpath()
        return path
    }
}

struct CrestCheck: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + x / 96 * r.width, y: r.minY + y / 104 * r.height)
        }
        var path = Path()
        path.move(to: p(31, 53))
        path.addLine(to: p(43, 65))
        path.addLine(to: p(66, 39))
        return path
    }
}

/// The white medallion that overlaps the coral header, holding the gradient shield
/// and a checkmark that draws on once the plan is verified.
struct ShieldMedallion: View {
    let checkProgress: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 97, height: 97)
                .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 6))
                .shadow(color: Color.black.opacity(0.16), radius: 13, y: 12)

            // Brand-dark shield with a coral check — mirrors the Pillie logo (dark
            // tile + coral mark) so the medallion isn't all pink.
            CrestShield()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "3A3531"), PillieTheme.dark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 53, height: 57)
                .overlay {
                    CrestCheck()
                        .trim(from: 0, to: checkProgress)
                        .stroke(PillieTheme.coral, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        .frame(width: 53, height: 57)
                }
                .shadow(color: PillieTheme.dark.opacity(0.3), radius: 6, y: 4)
        }
        .accessibilityHidden(true)
    }
}

/// A rectangle with only its bottom corners rounded — the coral header shape.
struct BottomRoundedRectangle: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Pops a plan element into place (fade + rise), delayed by its position so the
/// verified plan assembles itself. A no-op (placed immediately) when motion is reduced.
struct CanopyReveal: ViewModifier {
    let shown: Bool
    let animated: Bool
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 26)
            .animation(
                animated ? .spring(response: 0.5, dampingFraction: 0.82).delay(delay) : nil,
                value: shown
            )
    }
}
