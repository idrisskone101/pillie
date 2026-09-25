import SwiftUI

// MARK: - Headline (badge + title + subtitle)

struct TrialGrantedHeadline: View {
    let badge: String
    let title: String
    let titleAccent: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text(badge.uppercased())
                    .font(.pillie(10, weight: .black))
                    .tracking(1.5)
            }
            .foregroundStyle(PillieTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(PillieTheme.coral, in: Capsule())

            (Text("\(title)\n")
                .foregroundStyle(PillieTheme.textPrimary)
             + Text(titleAccent)
                .foregroundStyle(PillieTheme.coral))
            .font(.pillie(32, weight: .black))
            .tracking(-0.5)
            .lineSpacing(1)
            .lineLimit(2)
            .minimumScaleFactor(0.85)

            Text(subtitle)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Timeline card (Today glow → Day 12 → Day 14)

struct TrialGrantedTimelineCard: View {
    let today: TrialGrantedMomentContent.Today
    let laterDays: [TrialGrantedMomentContent.TimelineDay]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrialGrantedTodayHighlight(today: today)

            ForEach(Array(laterDays.enumerated()), id: \.offset) { index, day in
                TrialGrantedTimelineRow(day: day, showsConnector: index < laterDays.count - 1)
                    .padding(.horizontal, 14)
                    .padding(.top, index == 0 ? 14 : 0)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        }
        .shadow(
            color: PillieTheme.cardShadow,
            radius: PillieTheme.cardShadowRadius,
            y: PillieTheme.cardShadowY
        )
    }
}

struct TrialGrantedTodayHighlight: View {
    let today: TrialGrantedMomentContent.Today

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(PillieTheme.coral)
                    .frame(width: 34, height: 34)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(PillieTheme.textPrimary)
            }
            .background(
                // The design's soft coral glow ring around today's marker.
                Circle()
                    .fill(PillieTheme.coral.opacity(0.25))
                    .frame(width: 44, height: 44)
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(today.label.uppercased())
                    .font(.pillie(10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(PillieTheme.patchChangeRose)

                Text(today.title)
                    .font(.pillie(15, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)

                TrialGrantedPerkChips(perks: today.perks)
                    .padding(.top, 5)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(PillieTheme.coralLight)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(PillieTheme.coral.opacity(0.35), lineWidth: 1)
        }
    }
}

struct TrialGrantedPerkChips: View {
    let perks: [TrialGrantedMomentContent.Perk]

    var body: some View {
        // A wrapping flow so each chip keeps its label on one line (e.g. "Smart
        // Reminders" never breaks) and wraps to the next row only when the full
        // chip would overflow the card.
        ProtectionPlanFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(perks, id: \.title) { perk in
                chip(perk)
            }
        }
    }

    private func chip(_ perk: TrialGrantedMomentContent.Perk) -> some View {
        HStack(spacing: 5) {
            Image(systemName: perk.symbolName)
                .font(.system(size: 10, weight: .semibold))
            Text(perk.title)
                .font(.pillie(12, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(PillieTheme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(PillieTheme.cardWhite, in: Capsule())
    }
}

struct TrialGrantedTimelineRow: View {
    let day: TrialGrantedMomentContent.TimelineDay
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(day.circleBackground)
                        .frame(width: 34, height: 34)
                    Image(systemName: day.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(day.symbolColor)
                }
                .accessibilityHidden(true)

                if showsConnector {
                    Rectangle()
                        .fill(PillieTheme.sage.opacity(0.9))
                        .frame(width: 2)
                        .padding(.vertical, 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(day.label.uppercased())
                    .font(.pillie(10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(PillieTheme.textMuted)

                Text(day.title)
                    .font(.pillie(14, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)

                Text(day.detail)
                    .font(.pillie(13, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, showsConnector ? 14 : 0)

            Spacer(minLength: 0)
        }
    }
}
