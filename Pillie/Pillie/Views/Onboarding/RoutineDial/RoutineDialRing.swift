//
//  RoutineDialRing.swift
//  Pillie
//

import SwiftUI

struct RoutineDialRing: View {
    struct Metrics {
        let size: CGFloat
        let radius: CGFloat
        let gapDegrees: Double

        static let patch = Metrics(size: 224, radius: 96, gapDegrees: 2)
        static let ring = Metrics(size: 244, radius: 106, gapDegrees: 0.8)
    }

    struct SegmentColors {
        let fill: Color
        let track: Color
    }

    struct Knob {
        let halo: Color
        let dot: Color
    }

    let metrics: Metrics
    let segments: [SegmentColors]
    let position: Int
    let knob: Knob
    let animatesKnob: Bool
    let onSelect: (Int) -> Void
    @Binding var isScrubbing: Bool

    @State private var dragDegrees: Double?

    private static let lineWidth: CGFloat = 14
    private static let knobRadius: CGFloat = 15
    private static let dotRadius: CGFloat = 5
    private static let knobStroke: CGFloat = 3

    private var count: Int { segments.count }
    private var knobDegrees: Double { dragDegrees ?? Double(position) * segmentDegrees }
    private var segmentDegrees: Double { 360 / Double(count) }

    var body: some View {
        ZStack {
            ForEach(segments.indices, id: \.self) { index in
                let start = Double(index) * segmentDegrees + metrics.gapDegrees
                let end = Double(index + 1) * segmentDegrees - metrics.gapDegrees
                RingSegment(start: start, end: end, fill: end, radius: metrics.radius)
                    .stroke(segments[index].track, lineWidth: Self.lineWidth)
                RingSegment(start: start, end: end, fill: knobDegrees, radius: metrics.radius)
                    .stroke(segments[index].fill, lineWidth: Self.lineWidth)
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
            .modifier(OrbitEffect(degrees: knobDegrees, radius: metrics.radius))
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
                let touch = angle(of: value.location)
                guard let current = dragDegrees else {
                    #if DEBUG || PILLIE_FRAME_PROBE
                    TabSwitchFrameProbe.shared.monitor("scrub", duration: 1.2, settle: 0)
                    #endif
                    isScrubbing = true
                    withAnimation(animatesKnob ? .spring(duration: 0.25, bounce: 0) : nil) {
                        dragDegrees = touch
                    }
                    selectDay(at: touch)
                    return
                }
                // Unwrapped, so crossing twelve o'clock pins the knob instead of jumping ends.
                let next = min(max(current + remainder(touch - current, 360), 0), 360)
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) {
                    dragDegrees = next
                    selectDay(at: next)
                }
            }
            .onEnded { _ in
                isScrubbing = false
                withAnimation(animatesKnob ? .spring(duration: 0.5, bounce: 0.4) : nil) {
                    dragDegrees = nil
                }
            }
    }

    private func angle(of location: CGPoint) -> Double {
        let center = metrics.size / 2
        let degrees = atan2(location.x - center, center - location.y) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    private func selectDay(at degrees: Double) {
        let day = min(max(Int((degrees / segmentDegrees).rounded(.up)), 1), count)
        guard day != position else { return }
        onSelect(day)
    }
}

/// One segment's arc, drawn up to `fill` degrees so the fill tracks the knob.
private struct RingSegment: Shape {
    let start: Double
    let end: Double
    var fill: Double
    let radius: CGFloat

    var animatableData: Double {
        get { fill }
        set { fill = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let stop = min(end, fill)
        guard stop > start else { return path }
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(start - 90),
            endAngle: .degrees(stop - 90),
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
