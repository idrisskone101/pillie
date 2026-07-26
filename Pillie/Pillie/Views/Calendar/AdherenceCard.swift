//
//  AdherenceCard.swift
//  Pillie
//

import SwiftUI

struct AdherenceCard: View {
    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale
    let displayedMonth: Date
    let animatesValueChanges: Bool
    private let valueChangeAnimation = Animation.spring(response: 0.24, dampingFraction: 0.78)
    private let valuePopTransition = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.92).combined(with: .opacity),
        removal: .scale(scale: 1.06).combined(with: .opacity)
    )

    private var stats: (completed: Int, due: Int, percentage: Int) {
        store.monthAdherence(for: displayedMonth)
    }

    private var summary: HistoryPresentation.MonthSummary {
        HistoryPresentation.monthSummary(
            completed: stats.completed,
            percentage: stats.percentage,
            displayedMonth: displayedMonth,
            locale: locale
        )
    }

    private var monthAnimationKey: String {
        let components = Calendar.current.dateComponents([.year, .month], from: displayedMonth)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return "\(year)-\(month)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
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
            }

            // Large number
            if animatesValueChanges {
                Text(summary.completedCount)
                    .id("checkins-\(monthAnimationKey)")
                    .font(.pillieHuge())
                    .foregroundStyle(PillieTheme.textPrimary)
                    .transition(valuePopTransition)
            } else {
                Text(summary.completedCount)
                    .font(.pillieHuge())
                    .foregroundStyle(PillieTheme.textPrimary)
            }

            // Subtitle
            Text(summary.completedBody)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)

            // Consistency row
            HStack(spacing: 8) {
                Text(summary.percentage)
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.coral)
                    .contentTransition(.opacity)
                    .animation(animatesValueChanges ? valueChangeAnimation : nil, value: displayedMonth)

                Text(stats.due > 0 ? "\(stats.completed)/\(stats.due)" : "")
                    .font(.pillieHandwriting())
                    .foregroundStyle(PillieTheme.textMuted)
                    .rotationEffect(.degrees(-5))
                    .contentTransition(.opacity)
                    .animation(animatesValueChanges ? valueChangeAnimation : nil, value: displayedMonth)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PillieTheme.sage)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(PillieTheme.coral)
                        .frame(width: geo.size.width * CGFloat(stats.percentage) / 100, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .background(PillieTheme.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
        .animation(animatesValueChanges ? valueChangeAnimation : nil, value: monthAnimationKey)
    }
}

#Preview {
    AdherenceCard(displayedMonth: Date(), animatesValueChanges: true)
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
