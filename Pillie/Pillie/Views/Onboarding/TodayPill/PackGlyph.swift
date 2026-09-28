//
//  PackGlyph.swift
//  Pillie
//

import SwiftUI

struct PackGlyph: View {
    enum Size {
        case compact
        case tile

        fileprivate var dot: CGFloat {
            switch self {
            case .compact: 3.6
            case .tile: 8.9
            }
        }

        fileprivate var gap: CGFloat {
            switch self {
            case .compact: 1.4
            case .tile: 3.6
            }
        }

        fileprivate var noPillStroke: StrokeStyle {
            switch self {
            case .compact: StrokeStyle(lineWidth: 0.8)
            case .tile: StrokeStyle(lineWidth: 1.4, dash: [2.2, 1.95])
            }
        }
    }

    let regimen: PackRegimen
    var size: Size = .compact

    var body: some View {
        VStack(alignment: .leading, spacing: size.gap) {
            ForEach(0..<regimen.weekCount, id: \.self) { week in
                HStack(spacing: size.gap) {
                    ForEach(week * 7..<min(week * 7 + 7, regimen.totalDays), id: \.self) { index in
                        dot(regimen.day(atIndex: index).kind)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dot(_ kind: PackDay.Kind) -> some View {
        switch kind {
        case .active:
            Circle().fill(GlyphColor.active).frame(width: size.dot, height: size.dot)
        case .sugarPill:
            Circle().fill(GlyphColor.sugar).frame(width: size.dot, height: size.dot)
        case .noPill:
            Circle().strokeBorder(GlyphColor.noPill, style: size.noPillStroke).frame(width: size.dot, height: size.dot)
        }
    }

    private enum GlyphColor {
        static let active = Color(hex: "F4A6A0")
        static let sugar = Color(hex: "C3D3C0")
        static let noPill = Color(hex: "CFCBC7")
    }
}
