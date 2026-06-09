// xcode: set sdk=iOS

//
//  HomeView.swift
//  Pillie
//

import SwiftUI

struct HomeView: View {
    @Environment(PillStore.self) var store
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var appeared = false
    @State private var hasAnimatedIn = false
    @State private var showRefillConfirmation = false
    @State private var showShakeConfirm = false
    private let homeFeedback = HomeActionInteractionFeedback()

    private var unifiedStateTransition: Animation {
        PillieMotion.animation(
            for: .standard,
            accessibilityReduceMotion: accessibilityReduceMotion
        )
    }

    private var ctaStateTransition: AnyTransition {
        if accessibilityReduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .scale(scale: 0.97).combined(with: .opacity),
            removal: .opacity
        )
    }

    private var todayActionState: TodayActionState {
        TodayActionState.resolve(
            TodayActionState.Input(
                isRefillDue: store.isRefillDue,
                isTodayTaken: store.isTodayTaken,
                todayDueAction: store.todayDueAction,
                isPlus: SubscriptionManager.shared.isPlus,
                reduceMotionEnabled: accessibilityReduceMotion
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
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
            }
        }
        .alert(store.refillBannerTitle, isPresented: $showRefillConfirmation) {
            Button(store.refillCTALabel) {
                startNewPackOrCycle()
                ProductAnalyticsTelemetry.live.newPackOrCycleStarted()
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
                        completeTodayAction()
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
                .transition(ctaStateTransition)
            case .completed:
                Button {
                    let feedbackResponse = homeFeedback.undoTodayAction(
                        accessibilityReduceMotion: accessibilityReduceMotion
                    )
                    withAnimation(feedbackResponse.motionProfile.animation) {
                        store.unmarkTodayAsTaken()
                    }
                    ProductAnalyticsTelemetry.live.todayActionUndone()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Completed (Tap to undo)")
                    }
                }
                .buttonStyle(PillieTakenButtonStyle())
                .transition(ctaStateTransition)
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
                .transition(ctaStateTransition)
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
                .transition(ctaStateTransition)
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

    private func completeTodayAction() {
        let feedbackResponse = homeFeedback.commitTodayAction(
            accessibilityReduceMotion: accessibilityReduceMotion
        )
        withAnimation(feedbackResponse.motionProfile.animation) {
            store.markTodayAsTaken()
        }
        ProductAnalyticsTelemetry.live.todayActionCompleted()
    }

    private func startNewPackOrCycle() {
        let feedbackResponse = homeFeedback.commitNewPackOrCycle(
            accessibilityReduceMotion: accessibilityReduceMotion
        )
        withAnimation(feedbackResponse.motionProfile.animation) {
            store.startNewPack()
        }
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
