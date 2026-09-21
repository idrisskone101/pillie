//
//  AppBlockingSetupView.swift
//  Pillie
//

import SwiftUI
import FamilyControls

struct AppBlockingSetupView: View {
    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(OnboardingFlow.selectedFreePlanStorageKey) private var onboardingSelectedFreePlan = false

    @State private var animateIn = false
    @State private var showPicker = false
    @State private var permissionState = AppBlockingSetupPermissionState()
    #if DEBUG
    @AppStorage("pillie_debug_app_blocking_authorization_recovery")
    private var debugAuthorizationRecovery = false
    #endif
    private let onboardingTelemetry = OnboardingTelemetry()
    private var content: AppBlockingSetupContent {
        AppBlockingSetupContent.localized(
            locale: locale,
            trialEndTerms: trialEndTerms
        )
    }

    let trialEndTerms: TrialEndAccessTerms
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    init(
        trialEndTerms: TrialEndAccessTerms = .legacy,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.trialEndTerms = trialEndTerms
        self.onBack = onBack
        self.onContinue = onContinue
        self.onSkip = onSkip
    }

    private var blockingManager: AppBlockingManager { .shared }

    private var canSetUpBlocking: Bool {
        SubscriptionManager.shared.hasPlusAccess && !onboardingSelectedFreePlan
    }

    private var selection: BlockerSelectionState {
        blockingManager.selectionState
    }

    private var phase: AppBlockingSetupPhase {
        AppBlockingSetupPhase.resolve(
            canSetUpBlocking: canSetUpBlocking,
            isEmpty: selection.isEmpty,
            isRecoveryVisible: permissionState.isRecoveryVisible
        )
    }

    var body: some View {
        ZStack {
            PillieTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                heroSection
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, 22)

                if phase == .empty {
                    emptyStateCard
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                } else {
                    ScrollView(showsIndicators: false) {
                        phaseCard
                            .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                            .padding(.top, 18)
                            .padding(.bottom, 16)
                    }
                }

                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, 16)
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
        ProtectionPlanProgressHeader(
            progress: ProtectionPlanProgressIndex.progress(for: .appBlocking),
            onBack: onBack
        )
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(content.titleLead)
                .font(.pillie(34, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .tracking(-0.85)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(phase == .locked ? content.lockedSubtitle : content.subtitle)
                .font(.pillie(15, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyUnlockText: String {
        AppBlockingSetupContent.formattedEmptyUnlock(
            format: content.emptyUnlockFormat,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            locale: locale
        )
    }

    // MARK: - Phase cards

    private var emptyStateCard: some View {
        PausedPhoneIllustration(
            title: content.emptyTitle,
            unlockHint: emptyUnlockText,
            markTaken: content.emptyMarkTaken
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.emptyStateAccessibilityLabel(unlockHint: emptyUnlockText))
        .accessibilityIdentifier("appBlockingEmptyStateCard")
    }

    @ViewBuilder
    private var phaseCard: some View {
        switch phase {
        case .empty:
            EmptyView()
        case .recovery:
            authorizationRecoveryCard
        case .selected:
            selectedStateCard
        case .locked:
            lockedSection
        }
    }

    private var authorizationRecoveryCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)

            Text(content.authorizationDeniedTitle)
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.72)
                .allowsTightening(true)

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

    private var selectedStateCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Text(selection.countText)
                    .font(.pillie(40, weight: .bold))
                    .foregroundStyle(PillieTheme.coral)
                    .monospacedDigit()

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.selectedSummaryLabel)
                        .font(.pillieBodySemibold())
                        .foregroundStyle(PillieTheme.textPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.75)
                        .allowsTightening(true)
                    Text(content.selectedPrivacyNote)
                        .font(.pillie(13, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(selection.localizedAccessibilitySummary(locale: locale)). \(content.selectedPrivacyNote)"
            )

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

    private var footer: some View {
        VStack(spacing: 12) {
            if phase == .locked {
                Button(action: onContinue) {
                    Text(content.lockedCTA)
                }
                .buttonStyle(.pillieDark)
            } else {
                if phase == .empty {
                    emptyCoachLine
                }
                primaryCTA
                skipButton
            }
        }
    }

    private var emptyCoachLine: some View {
        HStack(alignment: .center, spacing: 5) {
            Image(systemName: "lock")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .frame(width: 14, height: 16)
            Text(content.emptyDetail)
                .font(.pillie(13, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var primaryCTA: some View {
        Button(action: performPrimaryAction) {
            Group {
                if permissionState.isRequesting {
                    ProgressView().tint(.white)
                } else {
                    Text(primaryActionTitle)
                }
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
                .font(.pillie(15, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.72)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
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
            liveDay: store.today,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            method: store.pack.method,
            blockingSchedule: store.blockingScheduleMirror
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
