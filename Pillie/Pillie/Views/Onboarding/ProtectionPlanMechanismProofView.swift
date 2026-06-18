//
//  ProtectionPlanMechanismProofView.swift
//  Pillie
//
//  Mechanism Proof (issue #78, Superdesign drafts c3e8eb96 / 6f6cedb8 / f1c2c9b9).
//  Proves the app-blocking loop before the paywall and the Screen Time permission
//  moment: the reminder rings, the user's distracting apps lock behind a frosted
//  pane, and marking the dose taken unlocks them. The demo auto-plays once and is
//  replayable, so the cause and effect are unmistakable.
//
//  Reduce Motion or VoiceOver get a fully readable static state: the locked scene
//  plus the three written beats and a one-line summary, with Continue available
//  immediately (the proof is never a gate). Copy is method-aware via
//  `ProtectionPlanMechanismProofContent` so a Patch or Ring user never sees pill
//  wording.
//

import SwiftUI

struct ProtectionPlanMechanismProofView: View {
    let model: ProtectionPlanOnboardingModel
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private enum Phase { case ringing, locked, unlocked }

    @State private var appeared = false
    @State private var blobPhase: CGFloat = 0
    @State private var phase: Phase = .ringing
    /// Bumped by Replay so the play `.task` re-runs (and cancels the previous one).
    @State private var playToken = 0
    /// A subtle ring pulse on the reminder bell while it's ringing.
    @State private var bellPulse = false

    private let performanceTier = PerformanceTier.current

    private var content: ProtectionPlanMechanismProofContent {
        ProtectionPlanMechanismProofContent(method: store.contraceptiveMethod)
    }

    /// The app tiles to lock. Drawn from the user's own answers; a neutral
    /// placeholder trio stands in when they only chose categories / behaviours.
    private var apps: [DistractionApp] {
        ProtectionPlanDiagnosisEngine.protectedApps(
            distractionChoices: model.distractionChoices,
            draftBlockedApps: model.draftBlockedApps
        )
    }

    private var animationsEnabled: Bool {
        performanceTier == .standard && !reduceMotion
    }

    /// Reduce Motion or VoiceOver: skip the animated loop, present the locked scene +
    /// written beats statically.
    private var prefersStaticProof: Bool {
        reduceMotion || voiceOverEnabled
    }

    /// Which step is currently emphasised in the live demo.
    private var activeStepIndex: Int {
        switch phase {
        case .ringing: return 0
        case .locked: return 1
        case .unlocked: return 2
        }
    }

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                ProtectionPlanBackBar(onBack: onBack)
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                            .modifier(FadeInUp(appeared: appeared, delay: PillieTheme.stagger1))

                        scene
                            .modifier(FadeInUp(appeared: appeared, delay: PillieTheme.stagger2))

                        stepList
                            .modifier(FadeInUp(appeared: appeared, delay: PillieTheme.stagger3))

                        footer
                            .modifier(FadeInUp(appeared: appeared, delay: PillieTheme.stagger4))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, PillieTheme.screenHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 130)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            VStack {
                Spacer()
                ctaBar
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .onAppear {
            withAnimation(PillieTheme.fadeInUpCurve) { appeared = true }
            guard animationsEnabled else {
                blobPhase = 0
                return
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                bellPulse = true
            }
        }
        // Auto-play the loop once (and on each Replay). No-op under static proof.
        .task(id: playToken) {
            guard !prefersStaticProof else { return }
            phase = .ringing
            try? await Task.sleep(for: .seconds(1.3))
            guard !Task.isCancelled, phase == .ringing else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                phase = .locked
            }
            InteractionFeedback.live.perform(.meaningfulCommit)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW IT WORKS")
                .font(.pillie(12, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(PillieTheme.coral)

            Text(content.headline)
                .font(.pillie(26, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Proof scene

    private var isLockedState: Bool {
        prefersStaticProof ? true : (phase == .locked)
    }

    private var isUnlockedState: Bool {
        !prefersStaticProof && phase == .unlocked
    }

    private var scene: some View {
        VStack(spacing: 16) {
            sceneDepiction
            // The mark-taken / replay controls drive the animated demo only. Under
            // Reduce Motion or VoiceOver the loop is presented statically (the locked
            // depiction + the written step list + the summary carry the narrative),
            // so there are no orphaned, no-op controls to confuse assistive tech.
            if !prefersStaticProof {
                if phase == .locked {
                    markTakenButton
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if phase == .unlocked {
                    unlockedConfirmation
                        .transition(.opacity)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
    }

    /// The decorative depiction (reminder banner + app tiles). Exposed to VoiceOver
    /// as one readable summary of the whole loop. The interactive controls live
    /// OUTSIDE this element so assistive technologies (VoiceOver, Switch Control,
    /// Full Keyboard Access) can always reach them in the animated path.
    private var sceneDepiction: some View {
        VStack(spacing: 16) {
            reminderBanner
            appGrid
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilitySummary)
    }

    private var reminderBanner: some View {
        let ringing = !prefersStaticProof && phase == .ringing
        return HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(PillieTheme.coral, in: Circle())
                .scaleEffect(ringing && bellPulse ? 1.08 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pillie")
                    .font(.pillie(11, weight: .bold))
                    .foregroundStyle(PillieTheme.textMuted)
                Text(store.contraceptiveMethod.blockingReasonText)
                    .font(.pillie(14, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(PillieTheme.coralLight, in: RoundedRectangle(cornerRadius: 16))
        .opacity(isUnlockedState ? 0.5 : 1)
    }

    private var appGrid: some View {
        HStack(spacing: 12) {
            ForEach(Array(tileSpecs.enumerated()), id: \.offset) { _, spec in
                proofTile(spec)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay {
            if isLockedState {
                lockedOverlay
                    .transition(.opacity)
            }
        }
    }

    /// Either the user's named apps, or a neutral placeholder trio.
    private var tileSpecs: [TileSpec] {
        if apps.isEmpty {
            return [
                TileSpec(symbol: "play.rectangle.fill", name: nil),
                TileSpec(symbol: "rectangle.stack.fill", name: nil),
                TileSpec(symbol: "bubble.left.and.bubble.right.fill", name: nil),
            ]
        }
        return apps.map { TileSpec(symbol: $0.symbolName, name: $0.displayName) }
    }

    private struct TileSpec {
        let symbol: String
        let name: String?
    }

    private func proofTile(_ spec: TileSpec) -> some View {
        VStack(spacing: 6) {
            Image(systemName: spec.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(PillieTheme.bg, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                )
            if let name = spec.name {
                Text(name)
                    .font(.pillie(10, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var lockedOverlay: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .fill(PillieTheme.textPrimary.opacity(0.04))
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(PillieTheme.coral)
                    Text(content.lockedLabel)
                        .font(.pillie(13, weight: .bold))
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(PillieTheme.textPrimary)
                }
            }
            .padding(-6)
    }

    private var markTakenButton: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                phase = .unlocked
            }
            InteractionFeedback.live.perform(.success)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(content.markTakenCTA)
            }
            .font(.pillie(15, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(PillieTheme.coral, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mechanismProofMarkTaken")
        .accessibilityLabel(content.markTakenCTA)
    }

    private var unlockedConfirmation: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "7DA37B"))
            Text("Unlocked — your apps are back.")
                .font(.pillie(14, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
            Spacer(minLength: 0)

            Button(action: replay) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(content.replayCTA)
                }
                .font(.pillie(13, weight: .bold))
                .foregroundStyle(PillieTheme.coral)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mechanismProofReplay")
            .accessibilityLabel(content.replayCTA)
            .accessibilityHint("Plays the lock and unlock demonstration again.")
        }
        .padding(.vertical, 6)
    }

    // MARK: - Step list

    private var stepList: some View {
        VStack(spacing: 10) {
            ForEach(Array(content.steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step, isActive: !prefersStaticProof && index == activeStepIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stepListAccessibilityLabel)
    }

    private func stepRow(_ step: ProtectionPlanMechanismProofContent.Step, isActive: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: step.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isActive ? .white : PillieTheme.coral)
                .frame(width: 44, height: 44)
                .background(isActive ? PillieTheme.coral : PillieTheme.coralLight, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(step.phase)
                    .font(.pillie(10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(PillieTheme.coral.opacity(0.9))
                Text(step.title)
                    .font(.pillie(15, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(step.detail)
                    .font(.pillie(12, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(PillieTheme.cardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(isActive ? PillieTheme.coral.opacity(0.4) : Color.black.opacity(0.03), lineWidth: isActive ? 1.5 : 1)
        )
        .shadow(color: PillieTheme.cardShadow, radius: 10, y: 5)
    }

    private var stepListAccessibilityLabel: String {
        content.steps.map { "\($0.phase): \($0.title). \($0.detail)" }.joined(separator: " ")
    }

    private var footer: some View {
        Text(content.footer)
            .font(.pillie(12, weight: .semibold))
            .foregroundStyle(PillieTheme.textMuted.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - CTA

    private var ctaBar: some View {
        Button(action: onContinue) {
            HStack(spacing: 10) {
                Text(content.continueCTA)
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(.pillieDark)
        .accessibilityIdentifier("protectionPlanPrimaryCTA")
        .padding(.horizontal, PillieTheme.screenHorizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 34)
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

    private func replay() {
        InteractionFeedback.live.perform(.lowRiskTap)
        playToken += 1
    }
}

#Preview {
    ProtectionPlanMechanismProofView(
        model: ProtectionPlanOnboardingModel(),
        onBack: {},
        onContinue: {}
    )
    .environment(PillStore.previewStore())
}
