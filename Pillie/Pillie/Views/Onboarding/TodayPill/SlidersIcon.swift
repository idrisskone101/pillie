//
//  SlidersIcon.swift
//  Pillie
//

import SwiftUI

/// The Custom pack icon from Paper: two slider tracks with knobs, drawn in a 24 pt box
/// and scaled to the frame it is given.
struct SlidersIcon: View {
    var color: Color = PillieTheme.textMuted

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width, proxy.size.height) / 24
            SlidersShape()
                .stroke(color, style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct SlidersShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        for (from, to) in [((4.0, 7.0), (14.0, 7.0)), ((18, 7), (20, 7)), ((4, 17), (8, 17)), ((12, 17), (20, 17))] {
            path.move(to: CGPoint(x: from.0, y: from.1))
            path.addLine(to: CGPoint(x: to.0, y: to.1))
        }
        for center in [CGPoint(x: 16, y: 7), CGPoint(x: 10, y: 17)] {
            path.addEllipse(in: CGRect(x: center.x - 2.2, y: center.y - 2.2, width: 4.4, height: 4.4))
        }
        return path.applying(CGAffineTransform(scaleX: scale, y: scale).concatenating(
            CGAffineTransform(translationX: rect.minX, y: rect.minY)
        ))
    }
}
