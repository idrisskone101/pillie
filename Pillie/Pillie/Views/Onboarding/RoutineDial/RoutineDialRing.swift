import SwiftUI

struct RoutineDialRing: View {
    struct Metrics {
        let size: CGFloat
        let radius: CGFloat
        let gapDegrees: Double

        static let patch = Metrics(size: 236, radius: 96, gapDegrees: 2)
        static let ring = Metrics(size: 256, radius: 106, gapDegrees: 0.8)
    }

    struct Knob {
        let halo: Color
        let dot: Color
    }

    let metrics: Metrics
    let segmentColors: [Color]
    let position: Int
    let knob: Knob
    let animatesKnob: Bool
    let onSelect: (Int) -> Void
    @Binding var isScrubbing: Bool

    private static let lineWidth: CGFloat = 14
    private static let knobRadius: CGFloat = 15
    private static let dotRadius: CGFloat = 5
    private static let knobStroke: CGFloat = 3

    private var count: Int { segmentColors.count }
    private var segmentDegrees: Double { 360 / Double(count) }

    var body: some View {
        ZStack {
            ForEach(segmentColors.indices, id: \.self) { index in
                RingSegment(
                    start: Double(index) * segmentDegrees + metrics.gapDegrees,
                    end: Double(index + 1) * segmentDegrees - metrics.gapDegrees,
                    radius: metrics.radius
                )
                .stroke(segmentColors[index], lineWidth: Self.lineWidth)
            }

            ZStack {
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(knob.halo, lineWidth: Self.knobStroke))
                    .frame(width: Self.knobRadius * 2 + Self.knobStroke, height: Self.knobRadius * 2 + Self.knobStroke)
                Circle()
                    .fill(knob.dot)
                    .frame(width: Self.dotRadius * 2, height: Self.dotRadius * 2)
            }
            .modifier(OrbitEffect(degrees: Double(position) * segmentDegrees, radius: metrics.radius))
            .animation(animatesKnob ? .spring(duration: 0.3, bounce: 0.15) : nil, value: position)
        }
        .frame(width: metrics.size, height: metrics.size)
        .contentShape(
            RingBand(inner: metrics.radius - 34, outer: metrics.radius + 26),
            eoFill: true
        )
        .gesture(scrub)
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isScrubbing { isScrubbing = true }
                select(at: value.location, continuing: value.translation != .zero)
            }
            .onEnded { value in
                select(at: value.location, continuing: true)
                isScrubbing = false
            }
    }

    private func select(at location: CGPoint, continuing: Bool) {
        let center = metrics.size / 2
        let dx = location.x - center
        let dy = location.y - center
        var degrees = atan2(dx, -dy) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        var day = min(max(Int((degrees / segmentDegrees).rounded(.up)), 1), count)
        if continuing {
            let quarter = max(1, count / 4)
            if position > count - quarter && day <= quarter { day = count }
            if position <= quarter && day > count - quarter { day = 1 }
        }
        guard day != position else { return }
        onSelect(day)
    }
}

private struct RingSegment: Shape {
    let start: Double
    let end: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(start - 90),
            endAngle: .degrees(end - 90),
            clockwise: false
        )
        return path
    }
}

private struct RingBand: Shape {
    let inner: CGFloat
    let outer: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2))
        path.addEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2))
        return path
    }
}

private struct OrbitEffect: GeometryEffect {
    var degrees: Double
    let radius: CGFloat

    var animatableData: Double {
        get { degrees }
        set { degrees = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let radians = degrees * .pi / 180
        return ProjectionTransform(
            CGAffineTransform(translationX: radius * sin(radians), y: -radius * cos(radians))
        )
    }
}
