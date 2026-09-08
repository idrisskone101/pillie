//
//  AppBlockingSetupView.swift
//  Pillie
//

import SwiftUI
import FamilyControls

struct AppBlockingSetupContent {
    struct CategoryHint: Equatable {
        let name: String
        let symbol: String
    }

    let badge: String
    let titleLead: String
    let titleAccent: String
    let subtitle: String
    let trialDisclosure: String

    let emptyTitle: String
    let emptyUnlockFormat: String
    let emptyDetail: String
    let categoryHints: [CategoryHint]
    let chooseAppsCTA: String

    let authorizationDeniedTitle: String
    let authorizationDeniedDetail: String
    let retryAuthorizationCTA: String

    let selectedSummaryLabel: String
    let selectedPrivacyNote: String
    let changeSelectionCTA: String

    let privacyNote: String
    let finishCTA: String
    let skipCTA: String

    let lockedTitle: String
    let lockedSubtitle: String
    let lockedDetail: String
    let lockedCTA: String

    var visibleCopy: [String] {
        [
            badge, titleLead, titleAccent, subtitle, trialDisclosure,
            emptyTitle, emptyUnlockFormat, emptyDetail,
            authorizationDeniedTitle, authorizationDeniedDetail, retryAuthorizationCTA
        ]
        + categoryHints.map(\.name)
        + [
            chooseAppsCTA, selectedSummaryLabel, selectedPrivacyNote, changeSelectionCTA,
            privacyNote, finishCTA, skipCTA, lockedTitle, lockedSubtitle, lockedDetail, lockedCTA
        ]
    }

    func emptyStateAccessibilityLabel(unlockHint: String) -> String {
        "\(emptyTitle). \(unlockHint) \(privacyNote)"
    }

    var lockedAccessibilityLabel: String {
        let separator = lockedTitle.last.map { ".!?…".contains($0) } == true ? " " : ". "
        return "\(lockedTitle)\(separator)\(lockedDetail)"
    }

    static var `default`: AppBlockingSetupContent { localized() }

    static func localized(
        locale: Locale = .current,
        trialEndTerms: TrialEndAccessTerms = .legacy,
        isPaidSubscriber: Bool = false
    ) -> AppBlockingSetupContent {
        AppBlockingSetupContent(
        badge: "Pillie Plus",
        titleLead: PillieLocalization.string("onboarding.blocking_setup.title", locale: locale),
        titleAccent: "",
        subtitle: PillieLocalization.string("onboarding.blocking_setup.subtitle", locale: locale),
        trialDisclosure: PillieLocalization.string(
            isPaidSubscriber
                ? "onboarding.blocking_setup.subscriber_disclosure"
                : trialEndTerms == .hardPaywall
                    ? "trial.granted.disclosure.hard_paywall"
                    : "trial.granted.disclosure",
            table: "Commerce",
            locale: locale
        ),
        emptyTitle: PillieLocalization.string("onboarding.blocking_setup.paused_app", locale: locale),
        emptyUnlockFormat: PillieLocalization.string("onboarding.blocking_setup.unlock_hint", locale: locale),
        emptyDetail: PillieLocalization.string(
            "onboarding.blocking_setup.empty_detail",
            locale: locale
        ),
        categoryHints: [
            CategoryHint(name: PillieLocalization.string("onboarding.personalise.distraction.social", locale: locale), symbol: "bubble.left.and.bubble.right.fill"),
            CategoryHint(name: PillieLocalization.string("onboarding.personalise.distraction.video", locale: locale), symbol: "play.rectangle.fill"),
            CategoryHint(name: PillieLocalization.string("onboarding.personalise.distraction.games", locale: locale), symbol: "gamecontroller.fill"),
            CategoryHint(name: PillieLocalization.string("onboarding.personalise.distraction.other", locale: locale), symbol: "bag.fill")
        ],
        chooseAppsCTA: PillieLocalization.string("onboarding.blocking_setup.allow_pausing", locale: locale),
        authorizationDeniedTitle: PillieLocalization.string("error.screen_time.title", locale: locale),
        authorizationDeniedDetail: PillieLocalization.string("error.screen_time.body", locale: locale),
        retryAuthorizationCTA: PillieLocalization.string("global.action.retry", locale: locale),
        selectedSummaryLabel: PillieLocalization.string(
            "onboarding.blocking_setup.selected_summary",
            locale: locale
        ),
        selectedPrivacyNote: PillieLocalization.string(
            "onboarding.blocking_setup.privacy",
            locale: locale
        ),
        changeSelectionCTA: PillieLocalization.string("global.action.edit", locale: locale),
        privacyNote: PillieLocalization.string("onboarding.blocking_setup.privacy", locale: locale),
        finishCTA: PillieLocalization.string("global.action.continue", locale: locale),
        skipCTA: PillieLocalization.string("onboarding.blocking_setup.skip", locale: locale),
        lockedTitle: PillieLocalization.string("onboarding.blocking_setup.plus_locked", locale: locale),
        lockedSubtitle: PillieLocalization.string("onboarding.blocking_setup.plus_locked", locale: locale),
        lockedDetail: PillieLocalization.string(
            trialEndTerms == .hardPaywall
                ? "onboarding.blocking_setup.hard_paywall_locked_detail"
                : "onboarding.demo.free_body",
            table: "Commerce",
            locale: locale
        ),
        lockedCTA: PillieLocalization.string(
            trialEndTerms == .hardPaywall
                ? "paywall.action.upgrade"
                : "global.action.continue",
            table: trialEndTerms == .hardPaywall ? "Commerce" : nil,
            locale: locale
        )
        )
    }

    static func formattedEmptyUnlock(
        format: String,
        reminderHour: Int,
        reminderMinute: Int,
        locale: Locale = .current
    ) -> String {
        let twelve = ReminderTimeConverter.toTwelveHour(hour24: reminderHour, minute: reminderMinute)
        let time = ProtectionPlanRoutineSummary.clockText(
            hour12: twelve.hour,
            minute: twelve.minute,
            isPM: twelve.period == 1,
            locale: locale
        )
        return String(format: format, locale: locale, arguments: [time as CVarArg])
    }
}

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

enum AppBlockingSetupPrimaryAction: Equatable {
    case requestAuthorization
    case finishSetup

    static func resolve(hasSelection: Bool, isAuthorized: Bool) -> Self {
        hasSelection && isAuthorized ? .finishSetup : .requestAuthorization
    }
}

enum AppBlockingSetupEmptyCardAction: Equatable {
    case chooseApps

    static func resolve(hasSelection: Bool, isRequesting: Bool) -> Self? {
        guard !hasSelection, !isRequesting else { return nil }
        return .chooseApps
    }
}

struct AppBlockingSetupView: View {
    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    private var content: AppBlockingSetupContent {
        AppBlockingSetupContent.localized(
            locale: locale,
            trialEndTerms: trialEndTerms,
            isPaidSubscriber: isPaidSubscriber
        )
    }

    let trialEndTerms: TrialEndAccessTerms
    let isPaidSubscriber: Bool
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    init(
        trialEndTerms: TrialEndAccessTerms = .legacy,
        isPaidSubscriber: Bool = false,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.trialEndTerms = trialEndTerms
        self.isPaidSubscriber = isPaidSubscriber
        self.onBack = onBack
        self.onContinue = onContinue
        self.onSkip = onSkip
    }

    private var blockingManager: AppBlockingManager { .shared }

    private var canSetUpBlocking: Bool {
        SubscriptionManager.shared.hasPlusAccess && !onboardingSelectedFreePlan
    }

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
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.68)
                .allowsTightening(true)

            Text(canSetUpBlocking ? content.subtitle : content.lockedSubtitle)
                .font(.pillieBodyLarge())
                .foregroundStyle(PillieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            TrialUnlockDisclosure(text: content.trialDisclosure)
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

    private var markCompleteDecorLabel: String {
        PillieLocalization.string("today.action.mark_complete", locale: locale)
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        phonePauseIllustration
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(content.emptyStateAccessibilityLabel(unlockHint: emptyUnlockText))
            .accessibilityIdentifier("appBlockingEmptyStateCard")
    }

    private var phonePauseIllustration: some View {
        ZStack {
            Ellipse()
                .fill(PillieTheme.coral.opacity(0.16))
                .frame(width: 292, height: 236)

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(PillieTheme.bg)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1.5)
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 48, height: 5)
                        .padding(.top, 9)
                }
                .overlay {
                    VStack(spacing: 10) {
                        genericPausedAppTile

                        Text(content.emptyTitle)
                            .font(.pillieBodyBold())
                            .foregroundStyle(PillieTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.75)
                            .allowsTightening(true)

                        Text(emptyUnlockText)
                            .font(.pillie(13, weight: .medium))
                            .foregroundStyle(PillieTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(markCompleteDecorLabel)
                            .font(.pillie(13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(PillieTheme.coral, in: Capsule())
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 18)
                }
                .frame(width: 196, height: 228)
        }
        .frame(height: 236)
    }

    private var genericPausedAppTile: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PillieTheme.lavender)
                .frame(width: 64, height: 64)
                .overlay {
                    LazyVGrid(
                        columns: [GridItem(.fixed(14), spacing: 4), GridItem(.fixed(14), spacing: 4)],
                        spacing: 4
                    ) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.black.opacity(0.08))
                                .frame(width: 14, height: 14)
                        }
                    }
                }

            ZStack {
                Circle()
                    .fill(PillieTheme.coral)
                    .frame(width: 28, height: 28)
                Image(systemName: "pause.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(x: 6, y: 6)
        }
        .accessibilityHidden(true)
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

    // MARK: - Selected State

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

    private var footer: some View {
        VStack(spacing: 12) {
            if canSetUpBlocking {
                if showsEmptyCoachLine {
                    emptyCoachLine
                }
                primaryCTA
                skipButton
            } else {
                Button(action: onContinue) {
                    Text(content.lockedCTA)
                }
                .buttonStyle(.pillieDark)
            }
        }
    }

    private var showsEmptyCoachLine: Bool {
        selection.isEmpty && !permissionState.isRecoveryVisible
    }

    private var emptyCoachLine: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted)
                .padding(.top, 2)
            Text(content.emptyDetail)
                .font(.pillie(13, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var primaryCTA: some View {
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
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.72)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 42)
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
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            method: store.pack.method,
            blockingSchedule: store.blockingScheduleMirror
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
