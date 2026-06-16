//
//  ProtectionPlanEarlyValueProofView.swift
//  Pillie
//
//  Early Value Proof — "Catch the Drift" (issue #74, Superdesign element set
//  a4208394). Instead of a static card, the user redirects their own attention
//  with their thumb: a coral focus dot drifts along an Attention Trail toward the
//  "Endless scroll" app; at a checkpoint Pillie's frosted Social Guard pane snaps
//  over the app and holds it; the user's "I took my pill" tap melts the guard,
//  straightens the trail to green, and releases the app — the save is something
//  the hand earns, not a slideshow.
//
//  Reduce Motion or VoiceOver get a fully-revealed, non-animated, non-trapping
//  equivalent: the resolved moment plus the written three-beat trail, with the
//  Continue action available immediately (the drag is delight, never a gate).
//

import Lottie
import SwiftUI
import UIKit

struct ProtectionPlanEarlyValueProofView: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var appeared = false
    /// 0 = attention rests on the reminder, 1 = fully drifted onto the app tile.
    /// The drag tracks this both directions, so the catch is fully reversible.
    @State private var beadProgress: CGFloat = 0
    /// How far the trail bows down toward the distraction (0 = straight/calm).
    @State private var trailBow: CGFloat = 0
    /// Whether Pillie is currently holding the app (the Social Guard is sealed).
    /// Driven live off `beadProgress` with hysteresis, so dragging back un-seals it.
    @State private var isLatched = false
    /// The committed end state — only set by tapping the check-in CTA.
    @State private var hasResolved = false
    /// The verifiedGreen "melt" ring sweep on resolve.
    @State private var ringFill: CGFloat = 0
    @State private var horizontalLocked = false
    /// Parsed once when the screen appears so the decode never lands on the
    /// resolve tap (where it would drop a frame).
    @State private var unlockAnimation: LottieAnimation?
    /// The drag is relative to wherever the dot is resting, so a fresh drag picks
    /// it up from its current position rather than snapping back to the start.
    @State private var dragStartProgress: CGFloat = 0
    /// Per-shake tilt kick and the idle "waiting for a shake" wiggle on the comet.
    @State private var cometTilt: Double = 0
    @State private var cometWiggle = false
    /// One-shot horizontal bounce when the user taps the CTA at rest (a "drag me"
    /// hint) — tapping never skips the demo, it points them at the dot.
    @State private var cometNudgeX: CGFloat = 0
    /// Light "ratchet" haptic per trail dash as the dot is dragged. A dedicated
    /// prepared generator keeps the rapid ticks crisp; the latch tick is heavier
    /// (`.meaningfulCommit`) so the end of the drag feels more significant.
    @State private var lastDashIndex = 0
    @State private var dashTick = UIImpactFeedbackGenerator(style: .light)
    /// The real check-in mechanic: shake the phone (3×). CoreMotion is unavailable
    /// on the simulator, so the CTA tap is the fallback there (and for a11y).
    @State private var shakeManager = ShakeDetectionManager(requiredShakes: 3)

    private let content = ProtectionPlanEarlyValueProofContent.default
    private let performanceTier = PerformanceTier.current

    // Tuning. Hysteresis (latch high, release low) keeps the seal from flickering
    // when the finger hovers around the threshold.
    private let pullDistance: CGFloat = 190
    private let latchThreshold: CGFloat = 0.72
    private let unlatchThreshold: CGFloat = 0.60
    private let heldRest: CGFloat = 0.85
    private let maxBow: CGFloat = 1.0
    /// Roughly one tick per visible trail dash across the lane (dash period ~10pt).
    private let dashTickCount = 14

    /// Heavy / looping motion only on a capable device with motion allowed.
    private var animationsEnabled: Bool {
        performanceTier == .standard && !reduceMotion
    }

    /// Reduce Motion or VoiceOver: skip the interactive layer, present the resolved
    /// state + written narrative, Continue ready immediately.
    private var prefersStaticProof: Bool {
        reduceMotion || voiceOverEnabled
    }

    private var isResolved: Bool { hasResolved || prefersStaticProof }
    /// The frosted "Locked" pane is visible only while actively holding.
    private var showsGuard: Bool { isLatched && !isResolved }
    /// The interactive shake step (ring + idle wiggle) only exists in the locked,
    /// unresolved, motion-allowed path.
    private var showsShakeStep: Bool { isLatched && !hasResolved && !prefersStaticProof }

    /// At rest (idle, interactive), gently rock the dot to invite the drag.
    private var showsRestNudge: Bool {
        !isLatched && !hasResolved && !prefersStaticProof && beadProgress < 0.05
    }
    private var restNudgePhases: [CGFloat] {
        showsRestNudge && animationsEnabled ? [0, 9] : [0]
    }

    private var resolveAnimation: Animation {
        animationsEnabled
            ? .spring(response: 0.55, dampingFraction: 0.7)
            : .easeInOut(duration: 0.2)
    }

    var body: some View {
        ProtectionPlanScaffold(
            progress: progress,
            onBack: onBack,
            primaryTitle: isResolved ? content.continueCTA : (isLatched ? content.shakeToTakeCTA : content.dragCTA),
            primaryIcon: isResolved ? "arrow.right" : (isLatched ? "iphone.radiowaves.left.and.right" : "hand.draw.fill"),
            onPrimary: handlePrimary
        ) {
            VStack(spacing: 16) {
                header
                // Live guidance sits ABOVE the interactive card so the user's thumb
                // (dragging the lane) never covers it. Fixed height so the card
                // doesn't shift as the caption text changes mid-drag.
                if !prefersStaticProof {
                    captionStack
                }
                momentCard
                // The written 3-beat narrative is only for the static / VoiceOver
                // path (no thumb interaction), so it stays below the card.
                if prefersStaticProof {
                    beatTrail
                }
                reassurance
            }
            .padding(.top, 4)
        }
        .accessibilityIdentifier("protectionPlanEarlyValueProofView")
        .onAppear {
            withAnimation(PillieTheme.fadeInUpCurve) { appeared = true }
            // Warm the Lottie during the calm entrance, not at the resolve tap.
            if unlockAnimation == nil {
                unlockAnimation = LottieAnimation.named("unlock_success")
            }
            dashTick.prepare()
        }
        // Shake detection is bound to the latch (off during drift/rest), so a shake
        // only ever counts toward unlocking once the apps are actually locked.
        .onChange(of: isLatched) { _, latched in
            guard !prefersStaticProof else { return }
            if latched {
                shakeManager.startDetecting()
                guard animationsEnabled else { return }
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    cometWiggle = true
                }
            } else {
                shakeManager.stopDetecting()
                shakeManager.reset()
                cometWiggle = false
            }
        }
        .onChange(of: shakeManager.shakeCount) { oldValue, newValue in
            guard newValue > oldValue, isLatched, !hasResolved else { return }
            animateCometShake()
            // Per-shake escalation; performCheckIn owns the single success haptic.
            InteractionFeedback.live.perform(
                newValue >= shakeManager.requiredShakes ? .meaningfulCommit : .lowRiskTap
            )
            if shakeManager.isComplete { performCheckIn() }
        }
        .onDisappear {
            shakeManager.stopDetecting()
            cometWiggle = false
        }
    }

    // MARK: - Actions

    private func handlePrimary() {
        if isResolved {
            onContinue()
            return
        }
        // Once locked, a single CTA tap is the fallback for taking the pill (the
        // simulator has no CoreMotion, and not everyone can shake): fill the ring
        // to full, then resolve.
        if isLatched {
            shakeManager.fillToComplete()
            performCheckIn()
            return
        }
        // At rest the CTA does NOT skip the demo — it points the user at the dot.
        nudgeComet()
    }

    /// A one-shot "drag me" bounce on the dot when the user taps the rest CTA.
    private func nudgeComet() {
        InteractionFeedback.live.perform(.lowRiskTap)
        guard animationsEnabled else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { cometNudgeX = 16 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { cometNudgeX = 0 }
        }
    }

    private func performCheckIn() {
        guard !hasResolved else { return }   // idempotent: a final shake + tap can't double-fire
        shakeManager.stopDetecting()
        cometWiggle = false
        InteractionFeedback.live.perform(.success)
        withAnimation(resolveAnimation) {
            hasResolved = true
            trailBow = 0
        }
        withAnimation(.easeInOut(duration: 0.5)) { ringFill = 1 }
    }

    /// A per-shake spring kick on the comet (additive to its latched scale).
    private func animateCometShake() {
        guard animationsEnabled else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.35)) {
            cometTilt = cometTilt == 0 ? -9 : 9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { cometTilt = 0 }
        }
    }

    /// Updates the seal state from the live drag position with hysteresis, firing
    /// haptics on each crossing. Reversible: dragging back below the release
    /// threshold un-seals the app.
    private func updateLatch(for progress: CGFloat) {
        if !isLatched, progress >= latchThreshold {
            withAnimation(.snappy(duration: 0.35)) { isLatched = true }
            InteractionFeedback.live.perform(.meaningfulCommit)
        } else if isLatched, progress <= unlatchThreshold {
            withAnimation(.snappy(duration: 0.35)) { isLatched = false }
            InteractionFeedback.live.perform(.lowRiskTap)
        }
    }

    /// Horizontal, direction-locked drag — the proven HistoryView contract so it
    /// coexists with the scaffold's vertical ScrollView (vertical pans fall through).
    /// Tracks both directions so the catch can be pulled back even after sealing.
    private var beadDragGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                guard !hasResolved else { return }   // only the committed state is frozen
                let tx = value.translation.width
                let ty = value.translation.height
                if !horizontalLocked {
                    guard abs(tx) > abs(ty) * 1.2 else { return }
                    horizontalLocked = true
                    dragStartProgress = beadProgress   // pick the dot up where it rests
                }
                let p = min(max(dragStartProgress + tx / pullDistance, 0), 1)
                beadProgress = p
                trailBow = p * maxBow
                // Light ratchet: one tick each time the dot crosses a dash, only on
                // the approach (before the latch). The latch fires its own, heavier
                // tick — see updateLatch.
                let idx = Int(p * CGFloat(dashTickCount))
                if idx != lastDashIndex {
                    lastDashIndex = idx
                    if !isLatched && p < latchThreshold { fireDashTick() }
                }
                updateLatch(for: p)
            }
            .onEnded { _ in
                horizontalLocked = false
                guard !hasResolved else { return }
                // Settle onto the checkpoint if still sealed, otherwise spring back
                // to the reminder — both fully repeatable, no nagging.
                let rest: CGFloat = isLatched ? heldRest : 0
                // Bouncier so the spring-back visibly rebounds off the alarm box
                // (the leftward overshoot is absorbed by the puckX clamp).
                withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) {
                    beadProgress = rest
                    trailBow = rest * maxBow
                }
                lastDashIndex = Int(rest * CGFloat(dashTickCount))
            }
    }

    /// A crisp, light per-dash tick; re-prepares for the next one.
    private func fireDashTick() {
        dashTick.impactOccurred(intensity: 0.6)
        dashTick.prepare()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Text(content.eyebrow.uppercased())
                .font(.pillie(12, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(PillieTheme.coral)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(PillieTheme.coral.opacity(0.14), in: Capsule())

            Text(content.title)
                .font(.pillieTitle())
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger1), value: appeared)
    }

    // MARK: - Hero "moment" card (the Attention Lane)

    private var momentCard: some View {
        attentionLane
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 340)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 36))
            .overlay {
                RoundedRectangle(cornerRadius: 36)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 26, y: 16)
            .scaleEffect(appeared ? 1 : 0.96)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)
            // The written trail carries the narrative for VoiceOver in the static
            // path, so the decorative lane is one ignored element there.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(content.accessibilitySummary)
            .accessibilityHidden(prefersStaticProof)
    }

    @ViewBuilder private var attentionLane: some View {
        if prefersStaticProof {
            laneContent
        } else {
            laneContent.gesture(beadDragGesture)
        }
    }

    private var laneContent: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let baseline = h * 0.46
            let bellCenter = CGPoint(x: 34, y: baseline)
            let tileCenter = CGPoint(x: w - 44, y: baseline)
            // The trail lives strictly between the reminder and the app tile. p0 is
            // set so the dot's rest position clears the alarm tile (54pt wide,
            // centered at bellCenter) — it's the wall the dot bounces off, never
            // sliding under it.
            let p0 = CGPoint(x: bellCenter.x + 42, y: baseline)
            let p1 = CGPoint(x: tileCenter.x - 44, y: baseline)
            let control = CGPoint(x: (p0.x + p1.x) / 2, y: baseline + trailBow * h * 0.30)
            let puck = quadPoint(beadProgress, p0, control, p1)
            // Clamp so spring overshoot / float never carries the dot left of its
            // rest (= the alarm box edge); it bounces off instead of going under.
            let puckX = max(puck.x, p0.x)
            let trailWidth = max(p1.x - p0.x, 1)

            ZStack {
                trail
                    .frame(width: trailWidth, height: h)
                    .position(x: (p0.x + p1.x) / 2, y: baseline)
                appFeedTile.position(tileCenter)
                if showsGuard { guardPane.position(tileCenter) }
                focusComet.position(x: puckX, y: puck.y)
                reminderTile.position(bellCenter)
                // The celebratory Lottie burst is PRE-MOUNTED during the calm
                // entrance (paused at frame 0, invisible) so lottie-ios builds the
                // CALayer tree + first-frame CAAnimations ahead of the tap instead
                // of synchronously on the resolve frame. It plays once when the user
                // resolves. Never built in the static / VoiceOver path.
                if !prefersStaticProof {
                    lottieBurst
                        .position(tileCenter)
                        .opacity(hasResolved ? 1 : 0)
                        .allowsHitTesting(false)
                }

                Text("2:00 PM")
                    .font(.pillie(11, weight: .bold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .position(x: bellCenter.x, y: baseline + 47)
                Text("Your apps")
                    .font(.pillie(11, weight: .bold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .fixedSize()
                    .position(x: tileCenter.x, y: baseline + 52)
            }
        }
        .frame(height: 156)
        .contentShape(Rectangle())
    }

    /// Two crossfaded strokes of the same animatable curve: coral while drifting,
    /// verifiedGreen once the save lands.
    private var trail: some View {
        ZStack {
            AttentionTrailShape(bow: trailBow)
                .stroke(
                    LinearGradient(
                        colors: [PillieTheme.coral, PillieTheme.coral.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 9])
                )
                .opacity(isResolved ? 0 : 1)

            AttentionTrailShape(bow: trailBow)
                .stroke(
                    LinearGradient(
                        colors: [PillieTheme.verifiedGreen, PillieTheme.verifiedGreen.opacity(0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .opacity(isResolved ? 1 : 0)
        }
    }

    /// A live reminder: a soft coralLight tile with a bell, a halo glow, and a
    /// breathing notification dot.
    private var reminderTile: some View {
        // Cools from coral to verifiedGreen once the dose is taken (resolved),
        // matching the trail + app tile so the whole moment reads "done".
        let tint = isResolved ? PillieTheme.verifiedGreen : PillieTheme.coral
        return ZStack {
            Circle()
                .fill(tint)
                .frame(width: 64, height: 64)
                .blur(radius: 16)
                .opacity(0.22)
            RoundedRectangle(cornerRadius: 16)
                .fill(isResolved ? PillieTheme.verifiedGreen.opacity(0.16) : PillieTheme.coralLight)
                .frame(width: 54, height: 54)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(tint.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
            Image(systemName: "alarm.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: isResolved)
        }
    }

    /// The "attention" comet that rides the trail: a glowing coral orb with a
    /// white core and a soft trailing tail; grows as it drifts, fades on resolve.
    private var focusComet: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, PillieTheme.coral.opacity(0.45)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 34, height: 10)
                .blur(radius: 2)
                .offset(x: -20)
            Circle()
                .fill(PillieTheme.coral)
                .frame(width: 22, height: 22)
                .shadow(color: PillieTheme.coral.opacity(0.6), radius: 10)
                .overlay { Circle().fill(.white).frame(width: 8, height: 8) }
        }
        // Per-shake kick + a gentle idle "waiting for a shake" wiggle (both zero
        // unless latched on a motion-allowed device).
        .rotationEffect(.degrees(cometTilt + (cometWiggle ? 3 : 0)))
        // The shake-progress ring (the ShakeConfirmView idiom) hugs the comet and
        // fills in thirds as you shake; it stays upright while the orb wiggles.
        .overlay {
            if showsShakeStep {
                ZStack {
                    Circle()
                        .stroke(PillieTheme.coral.opacity(0.18), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(shakeManager.progress))
                        .stroke(PillieTheme.coral, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(resolveAnimation, value: shakeManager.progress)
                }
                .frame(width: 46, height: 46)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .scaleEffect(isLatched ? 1.05 : (0.9 + beadProgress * 0.22))
        // Tap-the-CTA bounce + a gentle idle rock that says "drag me" at rest.
        .offset(x: cometNudgeX)
        .phaseAnimator(restNudgePhases) { view, dx in
            view.offset(x: dx)
        } animation: { _ in
            .easeInOut(duration: 0.85)
        }
        .opacity(isResolved ? 0 : 1)
    }

    /// The distracting app as a believable mini "feed" card — a thumbnail with a
    /// play glyph over shimmer caption bars; cools to green and a check on resolve.
    private var appFeedTile: some View {
        VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 8)
                .fill(isResolved ? PillieTheme.verifiedGreen.opacity(0.20) : PillieTheme.lavender)
                .frame(height: 28)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.85))
                }
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(white: 0.92))
                .frame(height: 6)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(white: 0.92))
                .frame(width: 34, height: 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(9)
        .frame(width: 72, height: 72)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        }
        .overlay {
            if isResolved {
                RoundedRectangle(cornerRadius: 20).fill(PillieTheme.verifiedGreen.opacity(0.10))
            }
        }
        .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
        // The verifiedGreen "melt" ring sweeps as the save lands.
        .overlay {
            Circle()
                .trim(from: 0, to: ringFill)
                .stroke(PillieTheme.verifiedGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 86, height: 86)
                .opacity(ringFill > 0 && ringFill < 1 ? 1 : 0)
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: isResolved ? "checkmark.seal.fill" : "lock.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isResolved ? PillieTheme.verifiedGreen : PillieTheme.coral)
                .padding(3)
                .background(.white, in: Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: isResolved)
                .offset(x: 5, y: 5)
        }
    }

    /// A calm, premium "unlock success" celebration (expanding rings + sparkles),
    /// authored as a transparent Lottie and played once on resolve.
    private var lottieBurst: some View {
        LottieView(animation: unlockAnimation)
            // Keep the configuration STABLE (never state-dependent): changing it
            // rebuilds the layer tree, which would reintroduce the hitch at the tap.
            .configuration(LottieConfiguration(renderingEngine: .coreAnimation))
            // Declarative playback driven off the @State Bool. Paused at frame 0
            // pre-warms the layers + first display() during the calm entrance; the
            // value change to .playing on resolve fires exactly one 0->1 play.
            .playbackMode(
                hasResolved
                    ? .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
                    : .paused(at: .progress(0))
            )
            .frame(width: 150, height: 150)
            .allowsHitTesting(false)
    }

    /// The premium frosted Intercept Shield — Pillie holding the app at the
    /// checkpoint, with a "Social Guard" mark and a "HELD" badge.
    private var guardPane: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(.ultraThinMaterial)
            .frame(width: 84, height: 84)
            .overlay { RoundedRectangle(cornerRadius: 22).fill(Color.white.opacity(0.35)) }
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
            }
            .overlay {
                VStack(spacing: 5) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.55)).frame(width: 34, height: 34)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(PillieTheme.coral)
                            .symbolEffect(.bounce, value: showsGuard)
                    }
                    Text("Locked")
                        .font(.pillie(11, weight: .bold))
                        .foregroundStyle(PillieTheme.textPrimary)
                }
            }
            .shadow(color: PillieTheme.coral.opacity(0.25), radius: 12, y: 4)
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }

    // MARK: - Narration

    /// Live, single-line narration that tracks the moment: a drag invitation at
    /// rest, then drift → checkpoint → resolution copy as the user acts.
    private var captionStack: some View {
        // One slot, one voice: a single centered line that morphs across rest →
        // drift → locked → resolved, with the shake count beneath it while locked.
        VStack(spacing: 6) {
            Text(captionText)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                // Crossfade EVERY caption change — incl. rest→drift, which the drag
                // sets outside withAnimation (that's why it used to pop).
                .animation(.easeInOut(duration: 0.3), value: captionText)
                .padding(.horizontal, 8)

            // At-a-glance shake count while locked (parity with the Plus demo).
            if showsShakeStep {
                Text("\(shakeManager.shakeCount) of \(shakeManager.requiredShakes) shakes")
                    .font(.pillieCaptionMedium())
                    .foregroundStyle(PillieTheme.coral)
                    .contentTransition(.numericText())
                    .animation(resolveAnimation, value: shakeManager.shakeCount)
            }
        }
        // Reserve a fixed height for the tallest state (2-line cue + count) so the
        // card below never moves while the caption changes during a drag.
        .frame(maxWidth: .infinity, minHeight: 72, maxHeight: 72)
        // Breathing room above/below the live copy.
        .padding(.vertical, 10)
    }

    private var showsHint: Bool {
        !isLatched && !isResolved && beadProgress < 0.05
    }

    private var captionText: String {
        if isResolved { return content.resolved.detail }
        if isLatched { return content.shakeCue }
        if showsHint { return content.restCue }   // idle: value + drag invite
        return content.drift.detail                // mid-drag: the temptation
    }

    /// The written three-beat narrative for the static / VoiceOver equivalent.
    private var beatTrail: some View {
        VStack(spacing: 10) {
            ForEach(content.beats) { beat in
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: beat.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PillieTheme.coral)
                        .frame(width: 34, height: 34)
                        .background(PillieTheme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(beat.title)
                            .font(.pillie(15, weight: .bold))
                            .foregroundStyle(PillieTheme.textPrimary)
                        Text(beat.detail)
                            .font(.pillie(13, weight: .regular))
                            .foregroundStyle(PillieTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var reassurance: some View {
        Text(content.reassurance)
            .font(.pillieCaptionMedium())
            .foregroundStyle(PillieTheme.textMuted)
            .multilineTextAlignment(.center)
            .padding(.top, 2)
    }

    // MARK: - Geometry

    /// Point on a quadratic Bézier at parameter `t` (De Casteljau).
    private func quadPoint(_ t: CGFloat, _ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint) -> CGPoint {
        let mt = 1 - t
        return CGPoint(
            x: mt * mt * p0.x + 2 * mt * t * c.x + t * t * p1.x,
            y: mt * mt * p0.y + 2 * mt * t * c.y + t * t * p1.y
        )
    }
}

/// An animatable quadratic curve from the reminder (leading) to the app tile
/// (trailing); `bow` dips the control point downward toward the distraction.
private struct AttentionTrailShape: Shape {
    var bow: CGFloat

    var animatableData: CGFloat {
        get { bow }
        set { bow = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX, y: rect.midY)
        let end = CGPoint(x: rect.maxX, y: rect.midY)
        let control = CGPoint(x: rect.midX, y: rect.midY + bow * rect.height * 0.34)
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

#Preview {
    ProtectionPlanEarlyValueProofView(
        progress: ProtectionPlanProgress(index: 3, total: 10),
        onBack: {},
        onContinue: {}
    )
}
