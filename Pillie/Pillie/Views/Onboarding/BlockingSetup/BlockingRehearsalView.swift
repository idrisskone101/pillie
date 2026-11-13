//
//  BlockingRehearsalView.swift
//  Pillie
//
//  The open blocking step. A thin shell around `BlockingRehearsalState`: it
//  draws the state, forwards what she does as events, and carries out effects.
//

import FamilyControls
import SwiftUI

struct BlockingRehearsalView: View {
    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var state = BlockingRehearsalState()
    @State private var showPicker = false
    @State private var pauseCardNudges = 0
    @State private var shakeDetector = ShakeDetectionManager(requiredShakes: 1)
    @State private var appeared = false
    @AppStorage(BlockingRehearsalView.demoSeenKey) private var demoSeen = false
    #if DEBUG
    @AppStorage(BlockingRehearsalDebugSeed.storageKey) private var debugSeedLink = ""
    #endif

    let distractionChoices: Set<DistractionChoice>
    let onBack: () -> Void
    let onContinue: () -> Void
    let onRemindersOnly: () -> Void

    private let telemetry = BlockingRehearsalTelemetry()
    private let actions = BlockingSetupActions()

    static let demoSeenKey = "onboarding_blocking_rehearsal_seen"

    private var blockingManager: AppBlockingManager { .shared }

    private var script: BlockingRehearsalScript {
        let script = BlockingRehearsalScript(
            distractionChoices: distractionChoices,
            method: store.contraceptiveMethod,
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute
        )
        #if DEBUG
        if let featuredApp = BlockingRehearsalDebugSeed(link: debugSeedLink)?.featuredApp {
            return BlockingRehearsalScript(
                featuredApp: featuredApp,
                method: script.method,
                reminderHour: script.reminderHour,
                reminderMinute: script.reminderMinute
            )
        }
        #endif
        return script
    }

    private var content: BlockingRehearsalContent {
        BlockingRehearsalContent.localized(
            script: script,
            locale: locale,
            trialClock: SubscriptionManager.shared.plusAccessState.trialClock
        )
    }

    private func chrome(for stage: BlockingRehearsalStage) -> BlockingRehearsalChrome {
        content.chrome(
            for: stage,
            refusal: state.refusal,
            isAuthorized: state.isAuthorized,
            hasEntitlement: SubscriptionManager.shared.hasEntitlement
        )
    }

    /// The coral covers the screen through the shake beat, and starts
    /// spreading while "Open Pillie" is still pressed in.
    private var coverIsUp: Bool {
        state.stage == .shake || (state.stage == .paused && state.resolvedBy != nil)
    }

    private var coverAnimation: Animation {
        guard !reduceMotion else { return .easeInOut(duration: 0.3) }
        let pressTime = state.resolvedBy == .demo ? 0.3 : 0.1
        return .easeInOut(duration: 0.4).delay(coverIsUp ? pressTime : 0)
    }

    var body: some View {
        ZStack {
            PillieTheme.bg.ignoresSafeArea()

            if let stage = state.stage {
                // The ask waits under the cover, so pulling the coral back
                // reveals it instead of the beat she just left.
                page(stage == .shake ? .ask : stage, isLive: stage != .shake)
                    .accessibilityHidden(stage == .shake)

                if coverIsUp {
                    PillieTheme.coral
                        .ignoresSafeArea()
                        .transition(reduceMotion ? .opacity : .coralSpread)
                        .zIndex(1)
                }

                if stage == .shake {
                    BlockingRehearsalShakeBeat(
                        clip: script.shakeClip,
                        chrome: chrome(for: .shake),
                        playsClip: state.playsShakeClip,
                        onBack: onBack,
                        send: send
                    )
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
                    .zIndex(2)
                }
            }
        }
        .animation(coverAnimation, value: coverIsUp)
        .familyActivityPicker(
            isPresented: $showPicker,
            selection: Bindable(blockingManager).activitySelection
        )
        .onAppear {
            appeared = true
            var opening = BlockingRehearsalOpening(
                demoSeen: demoSeen,
                hasSelection: blockingManager.selectionState.hasSelection,
                isAuthorized: blockingManager.isAuthorized,
                voiceOverRunning: voiceOverEnabled
            )
            #if DEBUG
            opening.debugSeed = BlockingRehearsalDebugSeed(link: debugSeedLink)
            #endif
            send(.appeared(opening))
        }
        #if DEBUG
        .onChange(of: debugSeedLink) { _, link in
            if let seed = BlockingRehearsalDebugSeed(link: link) {
                send(.debugSeeded(seed))
            }
        }
        #endif
        .onDisappear {
            shakeDetector.stopDetecting()
        }
        .task(id: state.timer) {
            guard let timer = state.timer else { return }
            do {
                try await Task.sleep(for: timer.duration)
            } catch {
                return
            }
            send(.timerFired(timer))
        }
        .onChange(of: state.listensForShake, initial: true) { _, listens in
            if listens {
                shakeDetector.startDetecting()
            } else {
                shakeDetector.stopDetecting()
            }
        }
        .onChange(of: shakeDetector.shakeCount) { _, count in
            if count > 0 { send(.shaken) }
        }
        .onChange(of: blockingManager.selectionState.hasSelection) { _, hasSelection in
            send(.selectionChanged(hasSelection: hasSelection))
        }
        .onChange(of: blockingManager.isAuthorized) { _, isAuthorized in
            send(.authorizationChanged(isAuthorized: isAuthorized))
        }
        .onChange(of: voiceOverEnabled) { _, isRunning in
            send(.voiceOverChanged(isRunning: isRunning))
        }
        .onChange(of: scenePhase) { _, phase in
            send(.sceneActivityChanged(isActive: phase == .active))
        }
    }

    // MARK: - Page

    private func page(_ stage: BlockingRehearsalStage, isLive: Bool) -> some View {
        let chrome = chrome(for: stage)
        return GeometryReader { proxy in
            let isCompact = proxy.size.height < 700
            VStack(spacing: 0) {
                ProtectionPlanProgressHeader(
                    progress: ProtectionPlanProgressIndex.progress(for: .appBlocking)
                        .titled(chrome.header ?? ""),
                    onBack: onBack
                )
                .modifier(FadeInUp(appeared: appeared, delay: 0))
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)

                copy(chrome, isCompact: isCompact)
                    .id(stage)
                    .transition(.opacity)
                    .modifier(FadeInUp(appeared: appeared, delay: 0))
                    .padding(.horizontal, 24)
                    .padding(.top, isCompact ? 16 : 34)

                card(stage, isLive: isLive)
                    .modifier(FadeInUp(appeared: appeared, delay: PillieTheme.stagger3))
                    .padding(.top, isCompact ? 16 : 26)
                    .layoutPriority(-1)

                footer(chrome, isLive: isLive)
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, isCompact ? 16 : 26)
                    .padding(.bottom, PillieTheme.onboardingCTABottomPadding)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.3), value: stage)
    }

    private func copy(_ chrome: BlockingRehearsalChrome, isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(chrome.title)
                .font(.pillie(isCompact ? 32 : 38, weight: .extraBold))
                .tracking(isCompact ? -0.96 : -1.14)
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let body = chrome.body {
                Text(body)
                    .font(.pillie(17, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineSpacing(3)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func card(_ stage: BlockingRehearsalStage, isLive: Bool) -> some View {
        switch stage {
        case .reminder, .paused, .shake, .ask:
            BlockingRehearsalPhoneCard(
                stage: stage,
                resolvedBy: state.resolvedBy,
                isLive: isLive,
                script: script,
                content: content,
                nudges: pauseCardNudges,
                send: send
            )
            .padding(.horizontal, 24)
            .transition(.opacity)
        case .picks:
            ScrollView(showsIndicators: false) {
                BlockingRehearsalPicksCard(
                    grid: BlockingRehearsalPickGrid(picks: picks),
                    content: content,
                    onChange: { send(.chooseTapped) }
                )
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .transition(.opacity)
        case .refused:
            Group {
                if BlockingRehearsalContent.showsPromptPreview(for: state.refusal) {
                    BlockingRehearsalRefusedCard(content: content)
                        .padding(.horizontal, 24)
                } else {
                    Color.clear
                }
            }
            .transition(.opacity)
        }
    }

    private var picks: [BlockingRehearsalPick] {
        #if DEBUG
        if let count = blockingManager.debugSelectionCountOverride, count > 0 {
            return BlockingRehearsalSamplePick.tiles(count: count)
        }
        #endif
        return BlockingRehearsalPick.picks(in: blockingManager.activitySelection)
    }

    // MARK: - Footer

    private func footer(_ chrome: BlockingRehearsalChrome, isLive: Bool) -> some View {
        let shown = appeared && isLive
        return VStack(spacing: 0) {
            if !chrome.footnotes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(chrome.footnotes.enumerated()), id: \.offset) { index, footnote in
                        footnoteLine(footnote)
                            .modifier(FadeInUp(appeared: shown, delay: Double(index) * 0.05))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 16)
            }

            if let primary = chrome.primary {
                Button {
                    send(primary.event)
                } label: {
                    HStack(spacing: 10) {
                        if state.isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Text(primary.title)
                            if primary.leadsOn {
                                Image(systemName: "arrow.right")
                            }
                        }
                    }
                }
                .buttonStyle(.pillieDark)
                .disabled(state.isRequesting)
                .modifier(FadeInUp(appeared: shown, delay: Double(chrome.footnotes.count) * 0.05))
                .accessibilityIdentifier("blockingRehearsalPrimary")
            }

            if let quietTitle = chrome.quietTitle {
                Button(quietTitle) {
                    send(.remindersOnlyTapped)
                }
                .buttonStyle(.pillieQuiet)
                .disabled(state.isRequesting)
                .padding(.top, 6)
                .accessibilityIdentifier("blockingRehearsalRemindersOnly")
            }
        }
    }

    @ViewBuilder
    private func footnoteLine(_ footnote: BlockingRehearsalChrome.Footnote) -> some View {
        switch footnote {
        case .trial(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PillieTheme.coral)
                Text(text)
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("appBlockingTrialLine")
        case .apple(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                Text(text)
                    .font(.pillie(13, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Events and effects

    private func send(_ event: BlockingRehearsalEvent) {
        for effect in state.handle(event) {
            perform(effect)
        }
    }

    private func perform(_ effect: BlockingRehearsalEffect) {
        switch effect {
        case .nudgePauseCard:
            pauseCardNudges += 1
            InteractionFeedback.live.perform(.lowRiskTap)
        case .persistDemoSeen:
            demoSeen = true
        case .authorize:
            Task {
                send(.authorizationResolved(await actions.authorize()))
            }
        case .presentPicker:
            showPicker = true
        case .saveAndContinue:
            if actions.saveSelection(store: store) {
                onContinue()
            }
        case .useRemindersOnly:
            onRemindersOnly()
        case .report(let signal):
            telemetry.record(signal)
        }
    }
}

private extension AnyTransition {
    /// Coral spreads from where "Open Pillie" sits until it covers the screen,
    /// and pulls back the same way.
    static var coralSpread: AnyTransition {
        .modifier(active: CoralSpread(progress: 0), identity: CoralSpread(progress: 1))
    }
}

private struct CoralSpread: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.clipShape(SpreadingCircle(progress: progress))
    }
}

private struct SpreadingCircle: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.86)
        let reach = hypot(rect.width / 2, max(center.y - rect.minY, rect.maxY - center.y))
        let radius = reach * progress
        return Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

#Preview {
    BlockingRehearsalView(
        distractionChoices: [.instagram],
        onBack: {},
        onContinue: {},
        onRemindersOnly: {}
    )
    .environment(PillStore.previewStore())
}
