//
//  HomeView.swift
//  Pillie
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct HomeView: View {
    @Environment(PillStore.self) var store
    @State private var appeared = false
    @State private var hasAnimatedIn = false
    #if os(iOS)
    @State private var markTakenHaptic = UIImpactFeedbackGenerator(style: .medium)
    @State private var undoHaptic = UIImpactFeedbackGenerator(style: .light)
    #endif
    @State private var showRefillConfirmation = false
    @State private var showShakeConfirm = false
    private let unifiedStateTransition = Animation.easeInOut(duration: 0.28)

    private var todayActionState: TodayActionState {
        #if os(iOS)
        let reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        #else
        let reduceMotionEnabled = true
        #endif

        return TodayActionState.resolve(
            TodayActionState.Input(
                isRefillDue: store.isRefillDue,
                isTodayTaken: store.isTodayTaken,
                todayDueAction: store.todayDueAction,
                isPlus: SubscriptionManager.shared.isPlus,
                reduceMotionEnabled: reduceMotionEnabled
            )
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    PrimaryTitleAnchor(
                        title: "Today",
                        titleFont: .pillieHeadline().weight(.bold),
                        showsAccessorySlot: true,
                        accessory: {
                            AnyView(
                                HStack {
                                    Text(dateString)
                                        .font(.pillieDate())
                                        .foregroundStyle(PillieTheme.textMuted)

                                    Spacer()

                                    HomeAvatarLogoBadge()
                                }
                            )
                        }
                    )
                        .modifier(FadeInUp(appeared: appeared, delay: 0))

                    StatusCard()
                        .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                    if store.isRefillDue {
                        RefillBannerCard(onRefill: {
                            showRefillConfirmation = true
                            ProductAnalyticsTelemetry.live.newPackOrCyclePrompted()
                        })
                        .modifier(FadeInUp(appeared: appeared, delay: 0.15))
                    }

                    PillPackCard()
                        .modifier(FadeInUp(appeared: appeared, delay: 0.2))
                        .animation(unifiedStateTransition, value: store.isTodayTaken)

                    StatsRow()
                        .modifier(FadeInUp(appeared: appeared, delay: 0.3))
                        .animation(unifiedStateTransition, value: store.isTodayTaken)

                    // Handwriting motivation
                    Text("Keep it up, you're doing great!")
                        .font(.pillieHandwriting())
                        .foregroundStyle(PillieTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .rotationEffect(.degrees(-2))
                        .padding(.top, 8)
                        .modifier(FadeInUp(appeared: appeared, delay: 0.3))
                        .animation(unifiedStateTransition, value: store.isTodayTaken)
                }
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.top, PillieTheme.scrollTopPadding)
                .padding(.bottom, PillieTheme.scrollBottomPaddingWithCTA)
            }

            // Floating button
            floatingButton
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .onAppear {
            guard !hasAnimatedIn else { return }
            hasAnimatedIn = true
            prepareHaptics()
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
            }
        }
        .alert(store.refillBannerTitle, isPresented: $showRefillConfirmation) {
            Button(store.refillCTALabel) {
                store.startNewPack()
                ProductAnalyticsTelemetry.live.newPackOrCycleStarted()
                #if os(iOS)
                markTakenHaptic.impactOccurred()
                #endif
            }
            Button("Not Yet", role: .cancel) {}
        } message: {
            Text("This will start a new \(store.pack.method == .pill ? "pack" : "cycle") from today. Your previous history will be preserved.")
        }
        .fullScreenCover(isPresented: $showShakeConfirm) {
            if let action = store.todayDueAction {
                ShakeConfirmView(
                    action: action,
                    onConfirm: {
                        store.markTodayAsTaken()
                        ProductAnalyticsTelemetry.live.todayActionCompleted()
                        fireMarkTakenHaptic()
                        showShakeConfirm = false
                    },
                    onDismiss: {
                        showShakeConfirm = false
                    }
                )
            }
        }
    }

    // MARK: - Floating Button

    @ViewBuilder
    private var floatingButton: some View {
        let state = todayActionState
        Group {
            switch state {
            case .refillDue:
                Button {
                    showRefillConfirmation = true
                    ProductAnalyticsTelemetry.live.newPackOrCyclePrompted()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                        Text(store.refillCTALabel)
                    }
                }
                .buttonStyle(.pillieDark)
                .transition(.opacity)
            case .completed:
                Button {
                    store.unmarkTodayAsTaken()
                    ProductAnalyticsTelemetry.live.todayActionUndone()
                    fireUndoHaptic()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Completed (Tap to undo)")
                    }
                }
                .buttonStyle(PillieTakenButtonStyle())
                .transition(.opacity)
            case .noActionDue:
                Button {
                    // No due action for today.
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                        Text("No Action Due Today")
                    }
                }
                .buttonStyle(PillieTakenButtonStyle())
                .allowsHitTesting(false)
                .transition(.opacity)
            case .dueAction(let action, let requiresShakeConfirm):
                Button {
                    ProductAnalyticsTelemetry.live.todayActionStarted()
                    if requiresShakeConfirm {
                        showShakeConfirm = true
                    } else {
                        completeTodayAction()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            )
                        Text(action.ctaLabel)
                    }
                }
                .buttonStyle(.pillieDark)
                .transition(.opacity)
            }
        }
        .animation(unifiedStateTransition, value: store.isTodayTaken)
        .animation(unifiedStateTransition, value: store.isRefillDue)
        .animation(unifiedStateTransition, value: store.todayDueAction == nil)
    }

    // MARK: - Helpers

    private var dateString: String {
        PillieDateFormatters.homeHeader.string(from: Date())
    }

    private func prepareHaptics() {
        #if os(iOS)
        markTakenHaptic.prepare()
        undoHaptic.prepare()
        #endif
    }

    private func fireMarkTakenHaptic() {
        #if os(iOS)
        markTakenHaptic.impactOccurred()
        markTakenHaptic.prepare()
        #endif
    }

    private func fireUndoHaptic() {
        #if os(iOS)
        undoHaptic.impactOccurred()
        undoHaptic.prepare()
        #endif
    }

    private func completeTodayAction() {
        store.markTodayAsTaken()
        ProductAnalyticsTelemetry.live.todayActionCompleted()
        fireMarkTakenHaptic()
    }
}

// MARK: - Taken Button Style

private struct PillieTakenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pillie(18, weight: .semibold))
            .foregroundStyle(PillieTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: PillieTheme.ctaHeight)
            .background(PillieTheme.sage)
            .clipShape(Capsule())
    }
}

#Preview {
    HomeView()
        .environment(PillStore.previewStore())
}
