//
//  ShakeHalftoneField.swift
//  Pillie
//

import SwiftUI

/// Pop-art Ben-Day dots around the blister. `intensity` runs 0...3 with the
/// shake stage: each step pushes the dots bigger and further out.
struct ShakeHalftoneField: View, Animatable {
    var intensity: Double
    let motionLineCount: Int

    var animatableData: Double {
        get { intensity }
        set { intensity = newValue }
    }

    private let spacing: CGFloat = 12
    private let innerRadius: CGFloat = 128

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            drawDots(in: &context, size: size, center: center)
            drawMotionLines(in: &context, center: center)
        }
        .accessibilityHidden(true)
    }

    private func drawDots(in context: inout GraphicsContext, size: CGSize, center: CGPoint) {
        let reach = 60 + 45 * intensity
        let maxRadius = 2.2 + 0.7 * intensity
        let rowHeight = spacing * 0.866
        let rows = Int(size.height / rowHeight) + 2
        let columns = Int(size.width / spacing) + 2
        var dots = Path()

        for row in 0..<rows {
            let y = CGFloat(row) * rowHeight
            let rowShift = row.isMultiple(of: 2) ? 0 : spacing / 2
            for column in 0..<columns {
                let x = CGFloat(column) * spacing + rowShift
                let distance = hypot(x - center.x, y - center.y)
                guard distance > innerRadius else { continue }
                let falloff = 1 - (distance - innerRadius - 7) / reach
                guard falloff > 0 else { continue }
                let radius = maxRadius * min(1, falloff)
                guard radius > 0.35 else { continue }
                dots.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            }
        }
        context.fill(dots, with: .color(.white.opacity(0.9)))
    }

    private func drawMotionLines(in context: inout GraphicsContext, center: CGPoint) {
        guard motionLineCount > 0 else { return }
        var lines = Path()
        for index in 0..<motionLineCount {
            let angle = 2 * Double.pi * Double(index) / Double(motionLineCount) + 0.2
            let inner: CGFloat = 172
            let outer: CGFloat = index.isMultiple(of: 2) ? 200 : 208
            lines.move(to: CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle)))
            lines.addLine(to: CGPoint(x: center.x + outer * cos(angle), y: center.y + outer * sin(angle)))
        }
        context.stroke(lines, with: .color(.white), style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }
}
