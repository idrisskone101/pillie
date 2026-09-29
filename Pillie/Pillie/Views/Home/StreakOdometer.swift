//
//  StreakOdometer.swift
//  Pillie
//

import SwiftUI

/// Flip-counter streak: each changing wheel rolls from the old digit toward the
/// new one as `progress` goes from 0 to 1.
struct StreakOdometer: View {
    enum Size {
        case compact
        case hero

        var cell: CGSize {
            switch self {
            case .compact: CGSize(width: 48, height: 64)
            case .hero: CGSize(width: 104, height: 140)
            }
        }

        var cellRadius: CGFloat { self == .compact ? 12 : 24 }
        var digitSize: CGFloat { self == .compact ? 44 : 100 }
        var wheelSpacing: CGFloat { self == .compact ? 6 : 10 }
    }

    let digits: StreakOdometerDigits
    let progress: Double
    let size: Size

    var body: some View {
        HStack(spacing: size.wheelSpacing) {
            ForEach(Array(digits.wheels.enumerated()), id: \.offset) { _, wheel in
                wheelView(wheel)
            }
        }
    }

    private func wheelView(_ wheel: StreakOdometerDigits.Wheel) -> some View {
        let cell = size.cell
        return VStack(spacing: 0) {
            digitFace(wheel.from, isNew: false)
            digitFace(wheel.to, isNew: wheel.rolls)
        }
        .offset(y: wheel.rolls ? -cell.height * progress : -cell.height)
        .frame(width: cell.width, height: cell.height, alignment: .top)
        .background(PillieTheme.dark, in: RoundedRectangle(cornerRadius: size.cellRadius))
        .clipShape(RoundedRectangle(cornerRadius: size.cellRadius))
    }

    private func digitFace(_ digit: Character?, isNew: Bool) -> some View {
        Text(digit.map { String($0) } ?? " ")
            .font(.pillie(size.digitSize, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(isNew ? PillieTheme.coral : .white)
            .frame(width: size.cell.width, height: size.cell.height)
    }
}
