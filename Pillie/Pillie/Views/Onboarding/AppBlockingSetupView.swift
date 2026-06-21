//
//  AppBlockingSetupView.swift
//  Pillie
//
//  Issue #82 — Native App Selection And Blocker Config Save (design Option B).
//
//  The post-authorization wrapper for the native Screen Time picker. There is no
//  separate primer: "Choose apps to block" requests Screen Time authorization
//  inline (if needed) and goes straight into the system FamilyActivityPicker.
//  An honest empty state keeps the skip / reminder-only path, a valid selection
//  saves the blocker config and fires `blocker_config_saved`, and the summary is
//  privacy-safe — Pillie only ever knows the count (see BlockerSelectionState).
//

import SwiftUI
import FamilyControls

struct AppBlockingSetupContent {
    /// A generic category hint shown in the empty state — illustrative only, never
    /// the user's real selection (which is opaque tokens Pillie cannot read).
    struct CategoryHint: Equatable {
        let name: String
        let symbol: String
    }

    // Hero
    let badge: String
    let titleLead: String
    let titleAccent: String
    let subtitle: String

    // Empty state
    let emptyTitle: String
    let emptyDetail: String
    let categoryHints: [CategoryHint]
    let chooseAppsCTA: String

    // Selected state
    let selectedSummaryLabel: String
    let selectedPrivacyNote: String
    let changeSelectionCTA: String

    // Shared privacy + footer
    let privacyNote: String
    let finishCTA: String
    let skipCTA: String

    // Locked fallback (reached only if entitlement drops underneath the screen)
    let lockedTitle: String
    let lockedSubtitle: String
    let lockedDetail: String

    var visibleCopy: [String] {
        [
            badge, titleLead, titleAccent, subtitle,
            emptyTitle, emptyDetail
        ]
        + categoryHints.map(\.name)
        + [
            chooseAppsCTA, selectedSummaryLabel, selectedPrivacyNote, changeSelectionCTA,
            privacyNote, finishCTA, skipCTA, lockedTitle, lockedSubtitle, lockedDetail
        ]
    }

    /// One combined VoiceOver label for the empty permission card, so it reads as
    /// a single coherent element (title → what happens → privacy) rather than a
    /// run of separate Text + category-chip fragments.
    var emptyStateAccessibilityLabel: String {
        "\(emptyTitle). \(emptyDetail) \(privacyNote)"
    }

    /// One combined VoiceOver label for the locked (entitlement-dropped) fallback
    /// card, mirroring the empty/selected cards' single-element treatment.
    var lockedAccessibilityLabel: String {
        "\(lockedTitle). \(lockedDetail)"
    }

    static let `default` = AppBlockingSetupContent(
        badge: "Pillie Plus",
        titleLead: "Block the apps",
        titleAccent: "that pull you in.",
        subtitle: "Pick the categories Pillie should pause right after your reminder.",
        emptyTitle: "Nothing paused yet",
        emptyDetail: "You'll choose real apps in the Screen Time picker. We only ever store the count.",
        categoryHints: [
            CategoryHint(name: "Social", symbol: "bubble.left.and.bubble.right.fill"),
            CategoryHint(name: "Entertainment", symbol: "play.rectangle.fill"),
            CategoryHint(name: "Games", symbol: "gamecontroller.fill"),
            CategoryHint(name: "Shopping", symbol: "bag.fill")
        ],
        chooseAppsCTA: "Choose apps to block",
        selectedSummaryLabel: "apps & categories blocked",
        selectedPrivacyNote: "Pillie stores only the count — never which apps.",
        changeSelectionCTA: "Change selection",
        privacyNote: "Your choices stay on this device.",
        finishCTA: "Finish Setup",
        skipCTA: "Skip for now",
        lockedTitle: "Included with Pillie Plus",
        lockedSubtitle: "App blocking is a Pillie Plus tool you can set up after upgrading.",
        lockedDetail: "Your free plan still includes daily reminders and cycle tracking. You can upgrade from Settings when you want app blocking."
    )
}

struct AppBlockingSetupView: View {
    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(OnboardingFlow.selectedFreePlanStorageKey) private var onboardingSelectedFreePlan = false

    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    @State private var showPicker = false
    @State private var isRequestingAuth = false
    private let performanceTier = PerformanceTier.current
    private let onboardingTelemetry = OnboardingTelemetry()
    private let content = AppBlockingSetupContent.default

    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    private var blockingManager: AppBlockingManager { .shared }

    private var canSetUpBlocking: Bool {
        SubscriptionManager.shared.isPlus && !onboardingSelectedFreePlan
    }

    /// Count-only view of the live selection — the deep, testable core.
    private var selection: BlockerSelectionState {
        BlockerSelectionState(
            applicationCount: blockingManager.activitySelection.applicationTokens.count,
            categoryCount: blockingManager.activitySelection.categoryTokens.count
        )
    }

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, 28)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        heroSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        if canSetUpBlocking {
                            Group {
                                if selection.isEmpty {
                                    emptyStateCard
                                } else {
                                    selectedStateCard
                                }
                            }
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                        } else {
                            lockedSection
                                .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                        }
                    }
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, 18)
                    .padding(.bottom, 16)
                }

                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.bottom, PillieTheme.onboardingCTABottomPadding)
            }
        }
        .familyActivityPicker(
            isPresented: $showPicker,
            selection: Bindable(blockingManager).activitySelection
        )
        .onAppear {
            animateIn = true
            // The looping background blob is purely decorative — suppress it for
            // Reduce Motion users and on constrained devices (shared gate).
            guard PillieMotion.decorativeMotionEnabled(
                accessibilityReduceMotion: reduceMotion,
                performanceTier: performanceTier
            ) else {
                blobPhase = 0
                return
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        let progress = ProtectionPlanProgressIndex.progress(for: .appBlocking)
        return PersonalizationOnboardingHeader(
            appeared: animateIn,
            progress: progress.fraction,
            badge: progress.badge,
            onBack: onBack
        )
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(content.badge)
                .font(.pillie(10, weight: .black))
                .foregroundStyle(PillieTheme.textMuted)
                .tracking(1.4)
                .textCase(.uppercase)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(PillieTheme.coralLight, in: Capsule())
                .overlay {
                    Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1)
                }

            (Text(content.titleLead + "\n").foregroundColor(PillieTheme.textPrimary)
                + Text(content.titleAccent).foregroundColor(PillieTheme.coral))
                .font(.pillie(34, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(canSetUpBlocking ? content.subtitle : content.lockedSubtitle)
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(PillieTheme.coral, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .frame(width: 60, height: 60)
                Image(systemName: "pause.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
            }

            Text(content.emptyTitle)
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)

            Text(content.emptyDetail)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)

            ProtectionPlanFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(content.categoryHints, id: \.name) { hint in
                    hintChip(hint)
                }
            }
            .padding(.top, 2)

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                Text(content.privacyNote)
                    .font(.pillie(13, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .modifier(BlockerCardSurface())
        // Read the card as one coherent element; the category chips are
        // illustrative decoration, so they fold into the combined label.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.emptyStateAccessibilityLabel)
    }

    private func hintChip(_ hint: AppBlockingSetupContent.CategoryHint) -> some View {
        HStack(spacing: 6) {
            Image(systemName: hint.symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(hint.name)
                .font(.pillie(12, weight: .semibold))
        }
        .foregroundStyle(PillieTheme.textMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(PillieTheme.bg, in: Capsule())
        .overlay { Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1) }
    }

    // MARK: - Selected State

    private var selectedStateCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Count-only summary — no category icons/names, just how many are
            // blocked. Pillie never learns which apps (AC5).
            HStack(spacing: 16) {
                Text(selection.countText)
                    .font(.pillie(40, weight: .bold))
                    .foregroundStyle(PillieTheme.coral)
                    .monospacedDigit()

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.selectedSummaryLabel)
                        .font(.pillieBodySemibold())
                        .foregroundStyle(PillieTheme.textPrimary)
                    Text(content.selectedPrivacyNote)
                        .font(.pillie(13, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(selection.accessibilitySummary). \(content.selectedPrivacyNote)")

            Button(action: chooseApps) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                    Text(content.changeSelectionCTA)
                        .font(.pillieBodySemibold())
                }
                .foregroundStyle(PillieTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(PillieTheme.lavender, in: RoundedRectangle(cornerRadius: PillieTheme.buttonRadius))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(BlockerCardSurface())
    }

    // MARK: - Locked fallback

    private var lockedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)

            Text(content.lockedTitle)
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)

            Text(content.lockedDetail)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .modifier(BlockerCardSurface())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.lockedAccessibilityLabel)
    }

    // MARK: - Footer
    //
    // A single bottom-anchored primary CTA at the shared onboarding baseline. It
    // morphs "Choose apps to block" → "Finish Setup" once a selection exists, so
    // the dark CTA never competes with a second dark button (the in-card action is
    // the lavender "Change selection"). "Skip for now" keeps the reminder-only path.

    private var footer: some View {
        VStack(spacing: 12) {
            if canSetUpBlocking {
                primaryCTA
                skipButton
            } else {
                Button(action: onContinue) {
                    Text(content.finishCTA)
                }
                .buttonStyle(.pillieDark)
            }
        }
    }

    private var primaryCTA: some View {
        // No primer: when empty, the CTA requests Screen Time authorization inline
        // and opens the system picker; once apps are chosen it saves and continues.
        Button(action: selection.hasSelection ? finishSetup : chooseApps) {
            HStack(spacing: 8) {
                if isRequestingAuth {
                    ProgressView().tint(.white)
                } else if !selection.hasSelection {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(selection.hasSelection ? content.finishCTA : content.chooseAppsCTA)
            }
        }
        .buttonStyle(.pillieDark)
        .disabled(isRequestingAuth)
    }

    private var skipButton: some View {
        Button(action: onSkip) {
            Text(content.skipCTA)
                .font(.pillie(16, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func chooseApps() {
        Task {
            if !blockingManager.isAuthorized {
                isRequestingAuth = true
                onboardingTelemetry.screenTimePermissionRequested()
                await blockingManager.requestAuthorization()
                onboardingTelemetry.screenTimePermissionCompleted(isAuthorized: blockingManager.isAuthorized)
                isRequestingAuth = false
            }
            if blockingManager.isAuthorized {
                showPicker = true
            }
        }
    }

    private func finishSetup() {
        // AC2: never save an empty configuration (the CTA is also disabled when empty).
        guard selection.canSaveBlockerConfig else { return }
        blockingManager.saveSelectionAndReconcile(routine: appBlockingRoutine)
        ProductAnalyticsTelemetry.live.onboardingBlockerConfigSaved(
            hasSelection: blockingManager.hasAppsSelected
        )
        onContinue()
    }

    private var appBlockingRoutine: AppBlockingManager.RoutineState {
        AppBlockingManager.RoutineState(
            isTodayHandled: store.isTodayHandled,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            method: store.pack.method
        )
    }
}

// MARK: - Card surface

private struct BlockerCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .fill(PillieTheme.cardWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(
                color: PillieTheme.cardShadow,
                radius: PillieTheme.cardShadowRadius,
                y: PillieTheme.cardShadowY
            )
    }
}

// MARK: - Preview

#Preview {
    AppBlockingSetupView(
        onBack: {},
        onContinue: {},
        onSkip: {}
    )
    .environment(PillStore.previewStore())
}
