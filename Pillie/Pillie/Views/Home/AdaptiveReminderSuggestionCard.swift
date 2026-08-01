//
//  AdaptiveReminderSuggestionCard.swift
//  Pillie
//
//  The Adaptive Reminder Time Suggestion surface on Home (#126). It appears only when
//  `AdaptiveReminderTimeAnalyzer` returns a confident suggestion (for Pillie Plus users,
//  outside the dismissal cooldown) and invites the user to shift their primary reminder
//  toward when they actually log. Accepting routes through the normal reminder-time path
//  (`ScheduleCriticalSettingChange`), which reschedules all reminders; Pillie never
//  changes the reminder time silently. Copy + gating live in
//  `AdaptiveReminderSuggestionCardContent` (value-type tested).
//

import SwiftUI

struct AdaptiveReminderSuggestionCard: View {
    let content: AdaptiveReminderSuggestionCardContent
    let onAccept: () -> Void
    let onDismiss: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                iconBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.headline)
                        .font(.pillieBodyBold())
                        .foregroundStyle(PillieTheme.textPrimary)
                        .pillieAdaptiveLineLimit(minimumScaleFactor: 0.72)

                    Text(content.body)
                        .font(.pillie(13, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                dismissButton
            }

            acceptButton
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .stroke(PillieTheme.sageHalf, lineWidth: 1)
        )
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeAdaptiveReminderCard")
    }

    private var iconBadge: some View {
        Image(systemName: "clock.badge.checkmark")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(PillieTheme.coral)
            .frame(width: 42, height: 42)
            .background(PillieTheme.coralLight, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PillieTheme.textMuted)
                .frame(width: 26, height: 26)
                .background(PillieTheme.bg, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PillieLocalization.string("global.action.close", locale: locale))
        .accessibilityIdentifier("homeAdaptiveReminderCardDismiss")
    }

    private var acceptButton: some View {
        Button(action: onAccept) {
            HStack(spacing: 8) {
                Text(content.acceptTitle)
                    .font(.pillieBodySemibold())
                    .pillieAdaptiveLineLimit(minimumScaleFactor: 0.72)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(PillieTheme.textPrimary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("homeAdaptiveReminderCardAccept")
    }
}

#Preview {
    AdaptiveReminderSuggestionCard(
        content: AdaptiveReminderSuggestionCardContent.make(
            suggestion: AdaptiveReminderTimeAnalyzer.Suggestion(hour: 8, minute: 40, deltaMinutes: 40),
            isPlus: true
        )!,
        onAccept: {},
        onDismiss: {}
    )
    .padding(20)
    .background(PillieTheme.bg)
}
