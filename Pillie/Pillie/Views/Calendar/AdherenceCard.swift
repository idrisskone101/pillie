//
//  AdherenceCard.swift
//  Pillie
//

import SwiftUI

struct AdherenceCard: View, Equatable {
    @Environment(\.locale) private var locale
    let displayedMonth: Date
    let completed: Int
    let due: Int
    let percentage: Int

    static func == (lhs: AdherenceCard, rhs: AdherenceCard) -> Bool {
        lhs.completed == rhs.completed
            && lhs.due == rhs.due
            && lhs.percentage == rhs.percentage
            && MonthCursor.identity(for: lhs.displayedMonth) == MonthCursor.identity(for: rhs.displayedMonth)
    }

    private var summary: HistoryPresentation.MonthSummary {
        HistoryPresentation.monthSummary(
            completed: completed,
            percentage: percentage,
            displayedMonth: displayedMonth,
            locale: locale
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(summary.title)
                    .font(.pillieBodyBold())
                    .foregroundStyle(PillieTheme.textPrimary)

                Spacer()

                Text(summary.month)
                    .font(.pillieCaptionMedium())
                    .foregroundStyle(PillieTheme.coral)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(PillieTheme.coralLight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentTransition(.opacity)
            }

            Text(summary.completedCount)
                .font(.pillieHuge())
                .foregroundStyle(PillieTheme.textPrimary)
                .contentTransition(.opacity)

            Text(summary.completedBody)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)

            HStack(spacing: 8) {
                Text(summary.percentage)
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.coral)
                    .contentTransition(.opacity)

                Text(due > 0 ? "\(completed)/\(due)" : "")
                    .font(.pillieHandwriting())
                    .foregroundStyle(PillieTheme.textMuted)
                    .rotationEffect(.degrees(-5))
                    .contentTransition(.opacity)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PillieTheme.sage)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(PillieTheme.coral)
                        .frame(width: geo.size.width * CGFloat(percentage) / 100, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .background(PillieTheme.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
    }
}

#Preview {
    AdherenceCard(displayedMonth: Date(), completed: 0, due: 0, percentage: 0)
        .padding()
        .background(PillieTheme.bg)
}
