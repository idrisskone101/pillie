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
    let emptyMarkTaken: String
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
            emptyTitle, emptyUnlockFormat, emptyMarkTaken, emptyDetail,
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
        emptyMarkTaken: PillieLocalization.string("onboarding.blocking_setup.mark_taken", locale: locale),
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
    @AppStorage(OnboardingFlow.selectedFreePlanStorageKey) private var onboardingSelectedFreePlan = false

    @State private var animateIn = false
    @State private var showPicker = false
    @State private var permissionState = AppBlockingSetupPermissionState()
    #if DEBUG
    @AppStorage("pillie_debug_app_blocking_authorization_recovery")
    private var debugAuthorizationRecovery = false
    #endif
    private let onboardingTelemetry = OnboardingTelemetry()
    private let a10Gutter: CGFloat = 24
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
        #if DEBUG
        if let count = blockingManager.debugSelectionCountOverride, count > 0 {
            return BlockerSelectionState(applicationCount: count, categoryCount: 0)
        }
        #endif
        return BlockerSelectionState(
            applicationCount: blockingManager.activitySelection.applicationTokens.count,
            categoryCount: blockingManager.activitySelection.categoryTokens.count
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
                    .padding(.horizontal, a10Gutter)
                    .padding(.top, 22)

                if showsA10EmptyLayout {
                    emptyStateCard
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                } else {
                    ScrollView(showsIndicators: false) {
                        Group {
                            if canSetUpBlocking {
                                if permissionState.isRecoveryVisible {
                                    authorizationRecoveryCard
                                } else {
                                    selectedStateCard
                                }
                            } else {
                                lockedSection
                            }
                        }
                        .padding(.horizontal, a10Gutter)
                        .padding(.top, 18)
                        .padding(.bottom, 16)
                    }
                }

                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, a10Gutter)
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

    private var showsA10EmptyLayout: Bool {
        canSetUpBlocking && selection.isEmpty && !permissionState.isRecoveryVisible
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

            Text(canSetUpBlocking ? content.subtitle : content.lockedSubtitle)
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

    // MARK: - Empty State

    private var emptyStateCard: some View {
        AppBlockingA10EmptyStage(
            title: content.emptyTitle,
            unlockHint: emptyUnlockText,
            markTaken: content.emptyMarkTaken
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.emptyStateAccessibilityLabel(unlockHint: emptyUnlockText))
        .accessibilityIdentifier("appBlockingEmptyStateCard")
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
            .font(.pillie(17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(PillieTheme.dark, in: Capsule())
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(Color(hex: "A8A29E"))
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
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            method: store.pack.method,
            blockingSchedule: store.blockingScheduleMirror
        )
    }
}

// MARK: - A10 empty stage

/// Paper A10 middle stage is 390×442: a 310 circle at y=30 and a 232×300
/// phone sitting on the footer. Scale that canvas to the live hole so the
/// halo stays high behind the phone instead of hugging its bottom edge.
struct A10PhoneStageLayout: Equatable {
    static let designCanvas = CGSize(width: 390, height: 442)
    static let designCircle: CGFloat = 310
    static let designCircleTop: CGFloat = 30
    static let designPhone = CGSize(width: 232, height: 300)

    static var designCircleBottomInset: CGFloat {
        designCanvas.height - (designCircleTop + designCircle)
    }

    let scale: CGFloat

    static func fitted(in size: CGSize) -> Self {
        guard size.width > 0, size.height > 0 else { return Self(scale: 1) }
        return Self(
            scale: min(
                size.width / designCanvas.width,
                size.height / designCanvas.height
            )
        )
    }
}

private struct AppBlockingA10EmptyStage: View {
    let title: String
    let unlockHint: String
    let markTaken: String

    var body: some View {
        GeometryReader { geo in
            let layout = A10PhoneStageLayout.fitted(in: geo.size)
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(PillieTheme.coralLight)
                    .frame(
                        width: A10PhoneStageLayout.designCircle,
                        height: A10PhoneStageLayout.designCircle
                    )
                    .offset(y: -A10PhoneStageLayout.designCircleBottomInset)

                AppBlockingPausedPhoneMock(
                    title: title,
                    unlockHint: unlockHint,
                    markTaken: markTaken
                )
            }
            .frame(
                width: A10PhoneStageLayout.designCanvas.width,
                height: A10PhoneStageLayout.designCanvas.height,
                alignment: .bottom
            )
            .scaleEffect(layout.scale, anchor: .bottom)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private struct AppBlockingPausedPhoneMock: View {
    let title: String
    let unlockHint: String
    let markTaken: String

    private var phoneBezel: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 36,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 36,
            style: .continuous
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            genericPausedAppTile

            Text(title)
                .font(.pillie(18, weight: .bold))
                .tracking(-0.18)
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(unlockHint)
                .font(.pillie(13, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(markTaken)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(PillieTheme.dark, in: Capsule())
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 44)
        .frame(
            width: A10PhoneStageLayout.designPhone.width,
            height: A10PhoneStageLayout.designPhone.height,
            alignment: .top
        )
        .background(Color.white)
        .clipShape(phoneBezel)
        .overlay {
            phoneBezel.stroke(PillieTheme.dark, lineWidth: 6)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(PillieTheme.dark)
                .frame(width: 70, height: 20)
                .padding(.top, 12)
        }
        .shadow(color: PillieTheme.dark.opacity(0.1), radius: 20, y: -6)
    }

    private var genericPausedAppTile: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PillieTheme.lavender)
                .frame(width: 58, height: 58)
                .overlay {
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            appGlyph(opacity: 0.35)
                            appGlyph(opacity: 0.18)
                        }
                        HStack(spacing: 3) {
                            appGlyph(opacity: 0.18)
                            appGlyph(opacity: 0.35)
                        }
                    }
                }

            ZStack {
                Circle()
                    .fill(PillieTheme.coral)
                    .frame(width: 22, height: 22)
                HStack(spacing: 2.5) {
                    Capsule()
                        .fill(PillieTheme.dark)
                        .frame(width: 2.5, height: 8)
                    Capsule()
                        .fill(PillieTheme.dark)
                        .frame(width: 2.5, height: 8)
                }
            }
            .offset(x: 6, y: 6)
        }
        .accessibilityHidden(true)
    }

    private func appGlyph(opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(PillieTheme.dark.opacity(opacity))
            .frame(width: 8, height: 8)
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
