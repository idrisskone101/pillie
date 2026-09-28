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

    @State private var dragDegrees: Double?

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
            .modifier(OrbitEffect(degrees: dragDegrees ?? Double(position) * segmentDegrees, radius: metrics.radius))
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
