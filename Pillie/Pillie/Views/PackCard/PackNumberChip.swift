//
//  PackNumberChip.swift
//  Pillie
//

import SwiftUI

/// The black numbered capsule shared by the pack card's flag (`PackFlag`) and the
/// onboarding "have you taken pill N" question line (`TodayPillQuestionLine`). The
/// two spots render it at different sizes.
struct PackNumberChip: View {
    enum Size {
        case flag
        case question

        var side: CGFloat {
            switch self {
            case .flag: return 24
            case .question: return 26
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .flag: return 9
            case .question: return 10
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .flag: return 13
            case .question: return 14
            }
        }
    }

    let number: Int
    let size: Size

    var body: some View {
        Text(verbatim: "\(number)")
            .font(.pillie(size.fontSize, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, size.horizontalPadding)
            .frame(minWidth: size.side)
            .frame(height: size.side)
            .background(Capsule().fill(PillieTheme.textPrimary))
            .contentTransition(.numericText())
    }
}
