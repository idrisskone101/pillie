//
//  PlusSetupStrip.swift
//  Pillie
//
//  ENG-135: the Today strip under the status card during the Reverse Trial.
//  A progress ring plus one line of what is left; tapping opens the setup sheet.
//

import SwiftUI

struct PlusSetupStrip: View {
    let progress: PlusSetupProgress
    let onTap: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                PlusSetupRing(
                    completed: progress.completedCount,
                    total: progress.total,
                    label: PillieLocalization.formatted(
                        "plus_setup.strip.progress",
                        locale: locale,
                        arguments: Int64(progress.completedCount),
                        Int64(progress.total)
                    )
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(PillieLocalization.string("plus_setup.strip.title", locale: locale))
                        .font(.pillieBodySemibold())
                        .foregroundStyle(PillieTheme.textPrimary)
                    Text(PillieLocalization.string("plus_setup.strip.subtitle", locale: locale))
                        .font(.pillie(13, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                PillieTheme.cardWhite,
                in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .stroke(PillieTheme.sageHalf, lineWidth: 1)
            )
            .shadow(
                color: PillieTheme.cardShadow,
                radius: PillieTheme.cardShadowRadius,
                y: PillieTheme.cardShadowY
            )
            .contentShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PillieLocalization.formatted(
            "plus_setup.strip.accessibility",
            locale: locale,
            arguments: Int64(progress.completedCount),
            Int64(progress.total)
        ))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("plusSetupStrip")
    }
}

private struct PlusSetupRing: View {
    let completed: Int
    let total: Int
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(PillieTheme.coralLight, lineWidth: 5)
            Circle()
                .trim(from: 0, to: total > 0 ? CGFloat(completed) / CGFloat(total) : 0)
                .stroke(PillieTheme.coral, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: completed)
            Text(label)
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.textPrimary)
                .monospacedDigit()
        }
        .padding(3)
        .frame(width: 44, height: 44)
    }
}

#Preview {
    PlusSetupStrip(progress: PlusSetupProgress(completed: [.reminders]), onTap: {})
        .padding()
        .background(PillieTheme.bg)
}
