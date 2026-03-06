//
//  ConfettiView.swift
//  Pillie
//

import SwiftUI

struct ConfettiView: View {
    let isActive: Bool

    private let particleCount = PerformanceTier.current == .constrained ? 30 : 60
    private let colors: [Color] = [
        PillieTheme.coral,
        Color(hex: "B8D8B8"), // sage-ish green
        Color(hex: "C4B8E0"), // lavender
        PillieTheme.amber,
        .white
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            Canvas { context, size in
                guard isActive else { return }
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<particleCount {
                    let seed = Double(i)
                    let x = fmod((seed * 137.508 + elapsed * (30 + seed * 3)), size.width)
                    let baseY = fmod((seed * 97.3 + elapsed * (80 + seed * 5)), size.height * 1.4) - size.height * 0.2
                    let wobble = sin(elapsed * 3 + seed) * 8
                    let rotation = Angle.degrees(elapsed * (60 + seed * 10))
                    let colorIndex = Int(seed) % colors.count
                    let particleSize = 6 + fmod(seed * 3.7, 6)

                    var transform = CGAffineTransform.identity
                    transform = transform.translatedBy(x: x + wobble, y: baseY)
                    transform = transform.rotated(by: rotation.radians)

                    let rect = CGRect(
                        x: -particleSize / 2,
                        y: -particleSize / 2,
                        width: particleSize,
                        height: particleSize * 0.5
                    )
                    let path = Path(roundedRect: rect, cornerRadius: 1)
                    context.opacity = 0.9
                    context.fill(
                        path.applying(transform),
                        with: .color(colors[colorIndex])
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
