//
//  AppBlockingSetupView.swift
//  Pillie
//
//  Issue #82 — Native App Selection And Blocker Config Save (design Option B).
//
//  The post-authorization wrapper for the native Screen Time picker. There is no
//  separate primer: the pill-time CTA requests Screen Time authorization
//  inline (if needed) and goes straight into the system FamilyActivityPicker.
//  A denial stays on this screen with an explicit retry route. An honest
//  reminder-only path remains available, a valid selection saves the blocker config
//  and fires `blocker_config_saved`, and the summary is privacy-safe — Pillie only
//  ever knows the count (see BlockerSelectionState).
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
    let trialDisclosure: String

    // Empty state
    let emptyTitle: String
    let emptyDetail: String
    let categoryHints: [CategoryHint]
    let chooseAppsCTA: String

    // Authorization recovery
    let authorizationDeniedTitle: String
    let authorizationDeniedDetail: String
    let retryAuthorizationCTA: String

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
            badge, titleLead, titleAccent, subtitle, trialDisclosure,
            emptyTitle, emptyDetail,
            authorizationDeniedTitle, authorizationDeniedDetail, retryAuthorizationCTA
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

    static var `default`: AppBlockingSetupContent { localized() }

    static func localized(locale: Locale = .current) -> AppBlockingSetupContent {
        AppBlockingSetupContent(
        badge: "Pillie Plus",
        titleLead: PillieLocalization.string("onboarding.blocking_setup.title", locale: locale),
        titleAccent: "",
        subtitle: PillieLocalization.string("onboarding.blocking_setup.subtitle", locale: locale),
        trialDisclosure: PillieLocalization.string("onboarding.blocking_setup.plus_locked", locale: locale),
        emptyTitle: PillieLocalization.string("onboarding.blocking_setup.title", locale: locale),
        emptyDetail: PillieLocalization.string("onboarding.blocking_setup.subtitle", locale: locale),
        categoryHints: [
            CategoryHint(name: PillieLocalization.string("onboarding.personalise.distraction.social", locale: locale), symbol: "bubble.left.and.bubble.right.fill"),
            CategoryHint(name: PillieLocalization.string("onboarding.personalise.distraction.video", locale: locale), symbol: "play.rectangle.fill"),
            CategoryHint(name: PillieLocalization.string("onboarding.personalise.distraction.games", locale: locale), symbol: "gamecontroller.fill"),
            CategoryHint(name: PillieLocalization.string("onboarding.personalise.distraction.other", locale: locale), symbol: "bag.fill")
        ],
        chooseAppsCTA: PillieLocalization.string("onboarding.blocking_setup.title", locale: locale),
        authorizationDeniedTitle: PillieLocalization.string("onboarding.permission.title", locale: locale),
        authorizationDeniedDetail: PillieLocalization.string("onboarding.permission.body", locale: locale),
        retryAuthorizationCTA: PillieLocalization.string("global.action.retry", locale: locale),
        selectedSummaryLabel: PillieLocalization.string("onboarding.blocking_setup.subtitle", locale: locale),
        selectedPrivacyNote: PillieLocalization.string("onboarding.plan.disclaimer", locale: locale),
        changeSelectionCTA: PillieLocalization.string("global.action.edit", locale: locale),
        privacyNote: PillieLocalization.string("onboarding.plan.disclaimer", locale: locale),
        finishCTA: PillieLocalization.string("global.action.continue", locale: locale),
        skipCTA: PillieLocalization.string("global.action.continue", locale: locale),
        lockedTitle: PillieLocalization.string("onboarding.blocking_setup.plus_locked", locale: locale),
        lockedSubtitle: PillieLocalization.string("onboarding.blocking_setup.plus_locked", locale: locale),
        lockedDetail: PillieLocalization.string("onboarding.demo.free_body", locale: locale)
        )
    }
}

/// Observable permission-request behavior kept separate from the opaque Screen Time
/// authorization API so denial, retry, and picker presentation stay deterministic.
struct AppBlockingSetupPermissionState: Equatable {
    enum Phase: Equatable {
        case ready
        case requesting
        case recovery
    }

    enum Resolution: Equatable {
        case openPicker
        case showRecovery
    }

    private(set) var phase: Phase = .ready

    var isRequesting: Bool { phase == .requesting }
    var isRecoveryVisible: Bool { phase == .recovery }

    /// The initial CTA and recovery retry each begin an explicit Apple request.
    /// Repeated taps while a request is already in flight are ignored.
    mutating func beginRequest() -> Bool {
        guard !isRequesting else { return false }
        phase = .requesting
        return true
    }

    mutating func completeRequest(isAuthorized: Bool) -> Resolution {
        if isAuthorized {
            phase = .ready
            return .openPicker
        }

        phase = .recovery
        return .showRecovery
    }

    /// Simulator FamilyControls authorization is always approved, so DEBUG UI QA
    /// needs a way to render the exact recovery state a real denial reaches.
    mutating func showRecoveryForDebug() {
        phase = .recovery
    }
}

/// The primary CTA may save only when Screen Time is currently authorized.
/// Keeping this decision value-based prevents a retained selection from skipping
/// the authorization recovery path.
enum AppBlockingSetupPrimaryAction: Equatable {
    case requestAuthorization
    case finishSetup

    static func resolve(hasSelection: Bool, isAuthorized: Bool) -> Self {
        hasSelection && isAuthorized ? .finishSetup : .requestAuthorization
    }
}

struct AppBlockingSetupView: View {
    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(OnboardingFlow.selectedFreePlanStorageKey) private var onboardingSelectedFreePlan = false

    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    @State private var showPicker = false
    @State private var permissionState = AppBlockingSetupPermissionState()
    #if DEBUG
    @AppStorage("pillie_debug_app_blocking_authorization_recovery")
    private var debugAuthorizationRecovery = false
    #endif
    private let performanceTier = PerformanceTier.current
    private let onboardingTelemetry = OnboardingTelemetry()
    private let content = AppBlockingSetupContent.default

    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    private var blockingManager: AppBlockingManager { .shared }

    private var canSetUpBlocking: Bool {
        SubscriptionManager.shared.hasPlusAccess && !onboardingSelectedFreePlan
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
                                if permissionState.isRecoveryVisible {
                                    authorizationRecoveryCard
                                } else if selection.isEmpty {
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
            #if DEBUG
            if debugAuthorizationRecovery {
                permissionState.showRecoveryForDebug()
            }
            #endif
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
        #if DEBUG
        .onChange(of: debugAuthorizationRecovery) { _, isRecoveryVisible in
            if isRecoveryVisible {
                permissionState.showRecoveryForDebug()
            }
        }
        #endif
    }

    // MARK: - Header

    private var header: some View {
        let progress = ProtectionPlanProgressIndex.progress(for: .appBlocking)
        return PersonalizationOnboardingHeader(
            appeared: animateIn,
            progress: progress,
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

            (Text(content.titleLead + (content.titleAccent.isEmpty ? "" : "\n"))
                .foregroundColor(PillieTheme.textPrimary)
                + Text(content.titleAccent).foregroundColor(PillieTheme.coral))
                .font(.pillie(34, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(canSetUpBlocking ? content.subtitle : content.lockedSubtitle)
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            TrialUnlockDisclosure(text: content.trialDisclosure)
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

    private var authorizationRecoveryCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)

            Text(content.authorizationDeniedTitle)
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)

            Text(content.authorizationDeniedDetail)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .modifier(BlockerCardSurface())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appBlockingAuthorizationRecovery")
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
    // morphs the pill-time CTA → "Finish Setup" once a selection exists, so
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
        Button(action: performPrimaryAction) {
            HStack(spacing: 8) {
                if permissionState.isRequesting {
                    ProgressView().tint(.white)
                } else if !selection.hasSelection {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(primaryActionTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
        }
        .buttonStyle(.pillieDark)
        .disabled(permissionState.isRequesting)
    }

    private var primaryActionTitle: String {
        if primaryAction == .finishSetup { return content.finishCTA }
        if permissionState.isRecoveryVisible { return content.retryAuthorizationCTA }
        return content.chooseAppsCTA
    }

    private var primaryAction: AppBlockingSetupPrimaryAction {
        AppBlockingSetupPrimaryAction.resolve(
            hasSelection: selection.hasSelection,
            isAuthorized: blockingManager.isAuthorized
        )
    }

    private func performPrimaryAction() {
        switch primaryAction {
        case .requestAuthorization:
            chooseApps()
        case .finishSetup:
            finishSetup()
        }
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
                guard permissionState.beginRequest() else { return }
                onboardingTelemetry.screenTimePermissionRequested()
                await blockingManager.requestAuthorization()
                onboardingTelemetry.screenTimePermissionCompleted(isAuthorized: blockingManager.isAuthorized)
                let resolution = permissionState.completeRequest(
                    isAuthorized: blockingManager.isAuthorized
                )
                if resolution == .openPicker {
                    showPicker = true
                }
            } else {
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

private struct TrialUnlockDisclosure: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.seal.fill")
                .font(.pillie(15, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)

            Text(text)
                .font(.pillie(14, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PillieTheme.coralLight, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appBlockingTrialDisclosure")
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
