//
//  StatsRow.swift
//  Pillie
//

import SwiftUI

struct StatsRow: View {
    @Environment(PillStore.self) var store
    private let valueChangeAnimation = Animation.easeInOut(duration: 0.28)

    private var isBlockingOn: Bool {
        AppBlockingManager.shared.blockingEnabled && AppBlockingManager.shared.hasAppsSelected
    }

    private var blockingStatusText: String {
        isBlockingOn ? "On" : "Off"
    }

    private var blockingSubtitle: String {
        isBlockingOn ? "Blocking" : "No Blocks"
    }

    var body: some View {
        let currentStreak = store.currentStreak
        HStack(spacing: 12) {
            // Streak card
            VStack(spacing: 6) {
                Text("\u{1F525}")
                    .font(.system(size: 24))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                Text("\(currentStreak)")
                    .font(.pillie(24, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(valueChangeAnimation, value: currentStreak)

                Text("Day Streak")
                    .font(.pillieCaption())
                    .foregroundStyle(PillieTheme.coral)
                    .textCase(.uppercase)
                    .tracking(1)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(PillieTheme.coralLight)
            .clipShape(RoundedRectangle(cornerRadius: PillieTheme.buttonRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.buttonRadius)
                    .stroke(PillieTheme.coralFaded, lineWidth: 1)
            )

            // Blocking card
            VStack(spacing: 6) {
                Text("\u{1F6E1}\u{FE0F}")
                    .font(.system(size: 24))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                Text(blockingStatusText)
                    .font(.pillie(24, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .contentTransition(.opacity)
                    .animation(valueChangeAnimation, value: blockingStatusText)

                Text(blockingSubtitle)
                    .font(.pillieCaption())
                    .foregroundStyle(PillieTheme.textMuted)
                    .textCase(.uppercase)
                    .tracking(1)
                    .contentTransition(.opacity)
                    .animation(valueChangeAnimation, value: blockingSubtitle)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(PillieTheme.cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: PillieTheme.buttonRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.buttonRadius)
                    .stroke(PillieTheme.sageHalf, lineWidth: 1)
            )
            .shadow(color: PillieTheme.cardShadow, radius: 8, y: 4)
        }
    }
}

#Preview {
    StatsRow()
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
