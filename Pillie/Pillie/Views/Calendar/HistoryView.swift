//
//  HistoryView.swift
//  Pillie
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var appeared = false
    @State private var hasAnimatedIn = false
    @State private var correctionTarget: HistoryEditableDay?
    @AppStorage(HistoryDiscoveryAnnouncement.storageKey) private var discoveryDismissed = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                PrimaryTitleAnchor(
                    title: PillieLocalization.string("history.navigation.title", locale: locale),
                    titleFont: .pillieExtraBold(36),
                    showsAccessorySlot: true,
                    accessory: nil
                )
                .modifier(FadeInUp(appeared: appeared, delay: 0))

                Text(PillieLocalization.string("history.title", locale: locale))
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                if !discoveryDismissed {
                    HistoryDiscoveryBanner {
                        withAnimation(PillieMotion.animation(for: .quick)) {
                            discoveryDismissed = true
                        }
                    }
                    .transition(.opacity)
                    .modifier(FadeInUp(appeared: appeared, delay: 0.05))
                }

                VStack(alignment: .leading, spacing: 6) {
                    primaryLegend
                    if store.pack.method == .patch {
                        HStack(spacing: 16) {
                            legendItem(
                                color: PillieTheme.patchChangeRose,
                                label: legendLabels.active
                            )
                        }
                    }
                    if store.pack.method == .ring {
                        HStack(spacing: 16) {
                            legendItem(
                                color: PillieTheme.ringReinsertCoral,
                                label: legendLabels.active
                            )
                        }
                    }
                }
                .padding(.top, 4)
                .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                HistoryMonthSlideHost(
                    onEditableDayActivate: { correctionTarget = $0 }
                )
                .modifier(FadeInUp(appeared: appeared, delay: 0.2))
            }
            .padding(.horizontal, PillieTheme.screenHorizontalPadding)
            .padding(.top, PillieTheme.scrollTopPadding)
            .padding(.bottom, PillieTheme.scrollBottomPaddingDefault)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .onAppear {
            guard !hasAnimatedIn else { return }
            hasAnimatedIn = true
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
            }
        }
        .sheet(item: $correctionTarget) { target in
            HistoryDayCorrectionSheet(day: target) { outcome in
                applyCorrection(outcome, to: target)
            }
        }
    }

    private var legendLabels: (active: String, missed: String, rest: String) {
        (
            PillieLocalization.string("history.legend.completed", locale: locale),
            PillieLocalization.string("history.legend.unlogged", locale: locale),
            PillieLocalization.string("history.legend.break", locale: locale)
        )
    }

    private func applyCorrection(_ outcome: DayCorrectionOutcome, to day: HistoryEditableDay) {
        guard store.correctPastDay(on: day.date, to: outcome) else { return }
        InteractionFeedback.live.perform(.meaningfulCommit)
        discoveryDismissed = true
    }

    @ViewBuilder
    private var primaryLegend: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                legendItem(color: PillieTheme.sage, label: legendLabels.active)
                legendItem(color: PillieTheme.amber, label: legendLabels.missed)
                legendItem(color: PillieTheme.lavender, label: legendLabels.rest)
            }
        } else {
            HStack(spacing: 16) {
                legendItem(color: PillieTheme.sage, label: legendLabels.active)
                legendItem(color: PillieTheme.amber, label: legendLabels.missed)
                legendItem(color: PillieTheme.lavender, label: legendLabels.rest)
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    HistoryView()
        .environment(PillStore.previewStore())
        .modelContainer(PillStore.previewContainer)
}
