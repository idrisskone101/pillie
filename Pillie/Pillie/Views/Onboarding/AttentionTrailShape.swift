import SwiftUI

/// An animatable quadratic curve from the reminder (leading) to the app tile
/// (trailing); `bow` dips the control point downward toward the distraction.
struct AttentionTrailShape: Shape {
    var bow: CGFloat

    var animatableData: CGFloat {
        get { bow }
        set { bow = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX, y: rect.midY)
        let end = CGPoint(x: rect.maxX, y: rect.midY)
        let control = CGPoint(x: rect.midX, y: rect.midY + bow * rect.height * 0.34)
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}
