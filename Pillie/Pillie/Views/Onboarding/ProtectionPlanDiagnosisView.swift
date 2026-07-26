//
//  ProtectionPlanDiagnosisView.swift
//  Pillie
//
//  Personalized Diagnosis — the Draft Pill Protection Plan reveal (issue #78).
//  Replaces the legacy "Reminder Plan" form summary in the `.reminderPlan` slot.
//
//  Visual direction: "Coral Canopy" (Claude Design "Poppier Takes", option 2) — a
//  color-block coral header with a big headline, a white shield medallion that
//  overlaps the header edge, then a "how it protects you" card, two stat tiles, a
//  handwritten accent, and the CTA. The reveal keeps the loved two-beat motion: an
//  ANALYZING scan (the plan_reveal Lottie + the signals we detected, as chips), then
//  it resolves into the verified Coral Canopy plan.
//
//  Derivation + copy live in the pure `ProtectionPlanDiagnosis` value core. The plan
//  is enriched with the real answers we collect across onboarding: the primary
//  distraction, Due Action Time (+ time-of-day), the regimen/cycle, risk window,
//  failure frequency, how missing feels, habits, method, and protected apps. Under
//  Reduce Motion / VoiceOver the analyze beat is skipped and the verified plan is
//  placed immediately; the reveal still plays on constrained / thermally-throttled
//  devices (only the looping background blob is suppressed there).
//

import Lottie
import SwiftUI

struct ProtectionPlanDiagnosisView: View {
    let model: ProtectionPlanOnboardingModel
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var blobPhase: CGFloat = 0
    /// false = analyzing beat, true = verified Coral Canopy plan revealed.
    @State private var verified = false
    /// Drives the verified plan's entrance — the coral header slides down and the
    /// elements pop in, once the analyzing beat resolves.
    @State private var canopyIn = false
    /// Fades the detected-signal chips in during the analyzing beat.
    @State private var analyzeShown = false
    /// Flips the pre-warmed reveal Lottie from paused to playing once, on entrance.
    @State private var revealPlayed = false
    /// Parsed once on appear so the decode never lands mid-animation.
    @State private var revealAnimation: LottieAnimation?
    /// Draws the medallion checkmark on once the plan is verified.
    @State private var checkProgress: CGFloat = 0

    private let content = ProtectionPlanDiagnosisContent.default
    private let performanceTier = PerformanceTier.current

    private var interactionFeedback: OnboardingInteractionFeedback {
        OnboardingInteractionFeedback(performanceTier: performanceTier)
    }

    private var animateReveal: Bool {
        // The "building your plan" reveal is a meaningful one-time moment, NOT
        // ambient looping decoration — so it plays even on a thermally-throttled or
        // Low Power Mode device (where it was previously skipped). We only skip it
        // for accessibility (Reduce Motion / VoiceOver) or once it has already
        // played this session. The looping background blob stays performance-gated
        // on its own in `onAppear`.
        !reduceMotion && !voiceOverEnabled && !model.hasRevealedDiagnosisPlan
    }

    private var diagnosis: ProtectionPlanDiagnosis {
        let selection = ReminderTimeConverter.toTwelveHour(
            hour24: store.reminderHour,
            minute: store.reminderMinute
        )
        let timeText = ProtectionPlanRoutineSummary.clockText(
            hour12: selection.hour,
            minute: selection.minute,
            isPM: selection.period == 1
        )
        return ProtectionPlanDiagnosis(
            primaryDistraction: ProtectionPlanDiagnosisEngine.primaryDistraction(
                distractionChoices: model.distractionChoices,
                draftBlockedApps: model.draftBlockedApps
            ),
            protectedApps: ProtectionPlanDiagnosisEngine.protectedApps(
                distractionChoices: model.distractionChoices,
                draftBlockedApps: model.draftBlockedApps
            ),
            method: store.contraceptiveMethod,
            dueActionTimeText: timeText,
            riskWindow: model.riskWindow,
            distractionChoices: model.distractionChoices,
            delayConsequence: model.delayConsequence,
            missFrequency: store.missFrequency
        )
    }

    var body: some View {
        let plan = diagnosis

        ZStack(alignment: .bottom) {
            PillieTheme.bg.ignoresSafeArea()

            if verified {
                verifiedCanopy(plan)
                    .transition(.identity)
            } else {
                analyzeBeat(plan)
                    .transition(.opacity)
            }

            // The CTA only appears once the plan is built — there's nothing to act on
            // while the analyzing beat is still playing.
            if verified {
                ctaBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            revealAnimation = LottieAnimation.named("plan_reveal")
            // Warm RevenueCat + offerings now (a couple of screens before the
            // paywall) so the paywall renders its prices/CTA instantly instead of
            // doing a cold network fetch while the user waits on a spinner.
            SubscriptionManager.shared.prefetchOfferings()
            guard animateReveal else {
                verified = true
                canopyIn = true
                analyzeShown = true
                checkProgress = 1
                blobPhase = 0
                model.hasRevealedDiagnosisPlan = true
                return
            }
            revealPlayed = true
            withAnimation(.easeOut(duration: 0.4).delay(0.25)) { analyzeShown = true }
            // Only the looping background blob is performance-gated — it's the
            // expensive ambient piece. The reveal itself plays regardless.
            if PillieMotion.decorativeMotionEnabled(
                accessibilityReduceMotion: reduceMotion,
                performanceTier: performanceTier
            ) {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { blobPhase = 1 }
            } else {
                blobPhase = 0
            }
        }
        .task {
            guard animateReveal else { return }
            // Hold the "building your plan" loading beat until BOTH the minimum
            // animation time has played AND RevenueCat offerings are preloaded, so
            // the paywall that follows renders instantly. Capped so a slow network
            // can never strand the user on the loading screen.
            await waitForRevealReady()
            guard !Task.isCancelled else { return }
            let resolved = interactionFeedback.markDueActionTaken(accessibilityReduceMotion: reduceMotion)
            withAnimation(resolved.motionProfile.animation) { verified = true }
            withAnimation(.easeInOut(duration: 0.5).delay(0.3)) { checkProgress = 1 }
            // NB: the "revealed" flag is set when leaving via the CTA (so Back from the
            // paywall skips the reveal). It must NOT be set here — doing so flips
            // `animateReveal` to false mid-reveal and cancels the canopy entrance.
        }
    }

    // MARK: - Reveal timing

    /// The shortest the loading beat ever runs (the original animation length), so
    /// the reveal is never abrupt even if offerings are already cached.
    private static let minimumRevealSeconds: Double = 2.6
    /// The longest the loading beat waits on RevenueCat before revealing anyway, so a
    /// slow/failed offerings fetch can never strand the user on the loading screen.
    private static let offeringsWaitCapSeconds: Double = 5

    /// Completes once the loading beat may end: after both the minimum animation
    /// time and the (capped) RevenueCat offerings preload. Running them concurrently
    /// means the reveal fires at whichever is longer.
    private func waitForRevealReady() async {
        async let minimumBeat: Void = quietSleep(seconds: Self.minimumRevealSeconds)
        async let offeringsWarm: Void = waitForOfferings(maxSeconds: Self.offeringsWaitCapSeconds)
        _ = await (minimumBeat, offeringsWarm)
    }

    private func quietSleep(seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Awaits the offerings fetch (coalesced with the onAppear prefetch by
    /// RevenueCat), but never longer than `maxSeconds`.
    private func waitForOfferings(maxSeconds: Double) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { _ = try? await SubscriptionManager.shared.fetchOfferings() }
            group.addTask { try? await Task.sleep(for: .seconds(maxSeconds)) }
            _ = await group.next()   // return as soon as offerings load OR the cap elapses
            group.cancelAll()
        }
    }

    // MARK: - Analyzing beat

    private func analyzeBeat(_ plan: ProtectionPlanDiagnosis) -> some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)
            VStack(spacing: 0) {
                ProtectionPlanBackBar(onBack: onBack)
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, 8)

                Spacer(minLength: 0)

                sealHero
                Text(content.eyebrow)
                    .font(.pillie(12, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(PillieTheme.coral)
                    .padding(.top, 8)
                Text("\(content.analyzingTitle)\u{2026}")
                    .font(.pillie(26, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .padding(.horizontal, 28)
                Text(content.analyzingSubtitle)
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .padding(.top, 8)

                ProtectionPlanFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(Array(plan.detectedSignals.enumerated()), id: \.offset) { index, signal in
                        signalChip(signal)
                            .opacity(analyzeShown ? 1 : 0)
                            .offset(y: analyzeShown ? 0 : 8)
                            .animation(
                                animateReveal ? .easeOut(duration: 0.32).delay(0.25 + Double(index) * 0.13) : nil,
                                value: analyzeShown
                            )
                    }
                }
                .padding(.top, 18)
                .padding(.horizontal, 24)

                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 120)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(content.analyzingTitle). Detected: \(plan.detectedSignals.joined(separator: ", ")).")
    }

    private var sealHero: some View {
        LottieView(animation: revealAnimation)
            .configuration(LottieConfiguration(renderingEngine: .coreAnimation))
            .playbackMode(
                revealPlayed
                    ? .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
                    : .paused(at: .progress(0))
            )
            .frame(width: 220, height: 220)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func signalChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(PillieTheme.coral).frame(width: 6, height: 6)
            Text(text)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary.opacity(0.82))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(PillieTheme.cardWhite))
        .overlay(Capsule().strokeBorder(PillieTheme.coral.opacity(0.28), lineWidth: 1))
        .shadow(color: PillieTheme.cardShadow, radius: 6, y: 3)
    }

    // MARK: - Verified beat (Coral Canopy)

    private func verifiedCanopy(_ plan: ProtectionPlanDiagnosis) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // The coral top bar slides down into place.
                coralHeader(plan)
                    .offset(y: canopyIn ? 0 : -320)
                    .opacity(canopyIn ? 1 : 0)
                    .animation(canopyAnimation(delay: 0), value: canopyIn)

                // The medallion pops in, overlapping the header edge.
                ShieldMedallion(checkProgress: checkProgress)
                    .scaleEffect(canopyIn ? 1 : 0.3, anchor: .center)
                    .opacity(canopyIn ? 1 : 0)
                    .animation(canopyAnimation(delay: 0.26), value: canopyIn)
                    .padding(.top, -55)
                    .zIndex(1)

                VStack(spacing: 14) {
                    strategyCard(plan)
                        .modifier(CanopyReveal(shown: canopyIn, animated: animateReveal, delay: 0.36))
                    statTiles(plan)
                        .modifier(CanopyReveal(shown: canopyIn, animated: animateReveal, delay: 0.44))
                    appLockCard(plan)
                        .modifier(CanopyReveal(shown: canopyIn, animated: animateReveal, delay: 0.52))
                    handNote
                        .modifier(CanopyReveal(shown: canopyIn, animated: animateReveal, delay: 0.6))
                    disclaimer(plan)
                        .modifier(CanopyReveal(shown: canopyIn, animated: animateReveal, delay: 0.66))
                }
                .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 130)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            // Trigger the entrance once the canopy mounts (after the analyzing beat).
            canopyIn = true
        }
    }

    /// Spring for the header / medallion entrance, or `nil` (instant) when motion is
    /// reduced.
    private func canopyAnimation(delay: Double) -> Animation? {
        animateReveal ? .spring(response: 0.55, dampingFraction: 0.8).delay(delay) : nil
    }

    private func coralHeader(_ plan: ProtectionPlanDiagnosis) -> some View {
        VStack(spacing: 0) {
            // Same back button used throughout the onboarding flow (stays top-left).
            ProtectionPlanBackBar(onBack: onBack)

            // Centered headline, matching the Coral Canopy reference.
            Text(plan.headline)
                .foregroundStyle(PillieTheme.textPrimary)
                .font(.pillie(40, weight: .black))
                .multilineTextAlignment(.center)
                .lineSpacing(-9)
                .minimumScaleFactor(0.85)
                .shadow(color: PillieTheme.coral.opacity(0.35), radius: 10, y: 2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .accessibilityLabel("\(plan.headline). \(plan.leadLine)")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 64)
        .padding(.bottom, 72)
        .background(
            LinearGradient(
                colors: [Color(hex: "FFD0CD"), PillieTheme.coral, Color(hex: "FFAEAA")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        )
        .overlay(alignment: .topTrailing) {
            Circle().fill(.white.opacity(0.16)).frame(width: 170, height: 170)
                .blur(radius: 8).offset(x: 40, y: -50).allowsHitTesting(false)
        }
        .clipShape(BottomRoundedRectangle(radius: 44))
    }

    private func strategyCard(_ plan: ProtectionPlanDiagnosis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(content.strategyHeader)
                .font(.pillie(11, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(PillieTheme.textMuted.opacity(0.7))

            ForEach(Array(plan.strategyPoints.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .center, spacing: 13) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(PillieTheme.coral, in: Circle())
                        .accessibilityHidden(true)
                    Text(point)
                        .font(.pillie(16, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(planCardBackground)
    }

    private func statTiles(_ plan: ProtectionPlanDiagnosis) -> some View {
        let cycle = cycleStat()
        return HStack(spacing: 12) {
            statTile(
                icon: "alarm.fill",
                tint: PillieTheme.coral,
                background: PillieTheme.coralLight,
                value: plan.windowValue,
                label: reminderLabel(hour: store.reminderHour)
            )
            statTile(
                icon: cycle.icon,
                tint: Color(hex: "8B83A8"),
                background: PillieTheme.lavender,
                value: cycle.value,
                label: cycle.label
            )
        }
    }

    private func statTile(icon: String, tint: Color, background: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.pillie(21, weight: .black))
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.pillie(10, weight: .bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(PillieTheme.textMuted)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    /// Represents the lock mechanism generically — a small cluster of stand-in app
    /// tiles sealed under one lock — so it reads the same whether or not the user ever
    /// named specific apps. The copy is method-aware ("…until you take your pill").
    private func appLockCard(_ plan: ProtectionPlanDiagnosis) -> some View {
        HStack(spacing: 16) {
            lockedAppsCluster

            VStack(alignment: .leading, spacing: 4) {
                Text(content.protectedAppsHeader)
                    .font(.pillie(11, weight: .bold))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
                Text(plan.lockMechanismSummary)
                    .font(.pillie(15, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(planCardBackground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(content.protectedAppsHeader). \(plan.lockMechanismSummary)")
    }

    /// A few generic, faded app stand-ins fanned behind a single coral lock badge.
    private var lockedAppsCluster: some View {
        ZStack {
            genericAppTile(tint: PillieTheme.lavender, rotation: -11, offset: CGSize(width: -17, height: 3))
            genericAppTile(tint: PillieTheme.sage, rotation: 11, offset: CGSize(width: 17, height: 3))
            genericAppTile(tint: PillieTheme.coralLight, rotation: 0, offset: .zero)

            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(PillieTheme.coral, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: PillieTheme.coral.opacity(0.4), radius: 6, y: 3)
        }
        .frame(width: 86, height: 60)
        .accessibilityHidden(true)
    }

    private func genericAppTile(tint: Color, rotation: Double, offset: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 13)
            .fill(tint)
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.3))
            )
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white, lineWidth: 1.5))
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .shadow(color: PillieTheme.cardShadow, radius: 4, y: 2)
    }

    private var handNote: some View {
        Text(content.handNote)
            .font(.pillieHandwriting(size: 26))
            .foregroundStyle(PillieTheme.coral)
            .rotationEffect(.degrees(-3))
            .padding(.top, 4)
            .accessibilityHidden(true)
    }

    private func disclaimer(_ plan: ProtectionPlanDiagnosis) -> some View {
        Text(plan.disclaimer)
            .font(.pillie(11, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted.opacity(0.66))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }

    private var planCardBackground: some View {
        RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
            .fill(PillieTheme.cardWhite)
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .strokeBorder(Color.black.opacity(0.03), lineWidth: 1)
            )
            .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
    }

    private var ctaBar: some View {
        Button(action: onContinue) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                Text(content.primaryCTA)
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(.pillieDark)
        .accessibilityIdentifier("protectionPlanPrimaryCTA")
        .padding(.horizontal, PillieTheme.screenHorizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, PillieTheme.onboardingCTABottomPadding)
        .background(
            LinearGradient(
                colors: [PillieTheme.bg.opacity(0), PillieTheme.bg, PillieTheme.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.top, -24)
            .ignoresSafeArea(.all, edges: .bottom)
        )
    }

    // MARK: - Real-data stat helpers

    private func reminderLabel(hour: Int) -> String {
        switch hour {
        case 5..<12: return PillieLocalization.string("onboarding.reminder_time.morning")
        case 17..<22: return PillieLocalization.string("onboarding.reminder_time.evening")
        default: return PillieLocalization.string("onboarding.demo.step.reminder")
        }
    }

    private func cycleStat() -> (icon: String, value: String, label: String) {
        switch store.contraceptiveMethod {
        case .pill:
            let pack = store.pack
            return (
                "pills.fill",
                pack.pillRegimen.localizedScheduleSummary(),
                PillieLocalization.string("onboarding.plan.current_cycle")
            )
        case .patch:
            return ("bandage.fill", store.contraceptiveMethod.routineDescriptor, PillieLocalization.string("onboarding.plan.current_cycle"))
        case .ring:
            return ("circle.circle", store.contraceptiveMethod.routineDescriptor, PillieLocalization.string("onboarding.plan.current_cycle"))
        }
    }
}

/// A soft crest shield (matching the Coral Canopy / Lottie shield silhouette).
private struct CrestShield: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + x / 96 * r.width, y: r.minY + y / 104 * r.height)
        }
        var path = Path()
        path.move(to: p(48, 4))
        path.addLine(to: p(88, 20))
        path.addLine(to: p(88, 52))
        path.addCurve(to: p(48, 100), control1: p(88, 78), control2: p(70, 94))
        path.addCurve(to: p(8, 52), control1: p(26, 94), control2: p(8, 78))
        path.addLine(to: p(8, 20))
        path.closeSubpath()
        return path
    }
}

private struct CrestCheck: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + x / 96 * r.width, y: r.minY + y / 104 * r.height)
        }
        var path = Path()
        path.move(to: p(31, 53))
        path.addLine(to: p(43, 65))
        path.addLine(to: p(66, 39))
        return path
    }
}

/// The white medallion that overlaps the coral header, holding the gradient shield
/// and a checkmark that draws on once the plan is verified.
private struct ShieldMedallion: View {
    let checkProgress: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 97, height: 97)
                .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 6))
                .shadow(color: Color.black.opacity(0.16), radius: 13, y: 12)

            // Brand-dark shield with a coral check — mirrors the Pillie logo (dark
            // tile + coral mark) so the medallion isn't all pink.
            CrestShield()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "3A3531"), PillieTheme.dark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 53, height: 57)
                .overlay {
                    CrestCheck()
                        .trim(from: 0, to: checkProgress)
                        .stroke(PillieTheme.coral, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        .frame(width: 53, height: 57)
                }
                .shadow(color: PillieTheme.dark.opacity(0.3), radius: 6, y: 4)
        }
        .accessibilityHidden(true)
    }
}

/// A rectangle with only its bottom corners rounded — the coral header shape.
private struct BottomRoundedRectangle: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Pops a plan element into place (fade + rise), delayed by its position so the
/// verified plan assembles itself. A no-op (placed immediately) when motion is reduced.
private struct CanopyReveal: ViewModifier {
    let shown: Bool
    let animated: Bool
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 26)
            .animation(
                animated ? .spring(response: 0.5, dampingFraction: 0.82).delay(delay) : nil,
                value: shown
            )
    }
}

/// A standalone back chevron for the analyzing beat (the verified beat puts its own
/// chevron in the coral header).
struct ProtectionPlanBackBar: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(width: 52, height: 52)
                    .background(.white, in: Circle())
                    .overlay { Circle().stroke(Color.black.opacity(0.08), lineWidth: 1) }
                    .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PillieLocalization.string("global.action.back"))
            .accessibilityIdentifier("protectionPlanBackButton")

            Spacer()
        }
    }
}

#Preview {
    ProtectionPlanDiagnosisView(
        model: ProtectionPlanOnboardingModel(),
        onBack: {},
        onContinue: {}
    )
    .environment(PillStore.previewStore())
}
