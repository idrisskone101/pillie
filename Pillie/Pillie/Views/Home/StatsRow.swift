//
//  StatsRow.swift
//  Pillie
//

import SwiftUI

struct StatsRow: View {
    @Environment(PillStore.self) var store
    @State private var showUpsell = false
    private let valueChangeAnimation = Animation.easeInOut(duration: 0.28)

    private var isPlus: Bool { SubscriptionManager.shared.isPlus }

    private var blockingStatusText: String {
        let mgr = AppBlockingManager.shared
        if !mgr.blockingEnabled { return "Off" }
        if !mgr.hasAppsSelected { return "Off" }
        return mgr.blockingActive ? "Active" : "On"
    }

    private var blockingSubtitle: String {
        AppBlockingManager.shared.isEffectivelyOn ? "Blocking" : "No Blocks"
    }

    var body: some View {
        let _ = store.protocolChangeVersion
        let currentStreak = store.currentStreak
        HStack(spacing: 12) {
            // Streak card
            VStack(spacing: 6) {
                statIcon("flame.fill", tint: PillieTheme.coral)

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
            if isPlus {
                blockingCardContent
                    .modifier(StatsCardStyle())
            } else {
                Button {
                    showUpsell = true
                } label: {
                    lockedBlockingCardContent
                        .modifier(StatsCardStyle())
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showUpsell) {
            PlusUpsellSheet.appBlocking()
                .presentationDetents([.height(PlusUpsellSheet.compactPresentationHeight)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(PillieTheme.bg)
        }
    }

    private var blockingCardContent: some View {
        VStack(spacing: 6) {
            statIcon("lock.shield.fill", tint: PillieTheme.sage)

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
    }

    private var lockedBlockingCardContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .foregroundStyle(PillieTheme.textMuted)

            Text("Pillie+")
                .font(.pillie(24, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)

            Text("Blocking")
                .font(.pillieCaption())
                .foregroundStyle(PillieTheme.textMuted)
                .textCase(.uppercase)
                .tracking(1)
        }
    }

    private func statIcon(_ symbolName: String, tint: Color) -> some View {
        Image(systemName: symbolName)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .contentTransition(.opacity)
    }
}

private struct StatsCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
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

#Preview {
    StatsRow()
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
