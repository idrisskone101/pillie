//
//  ProtectionPlanWelcomeView.swift
//  Pillie
//
//  First screen of Protection Plan Onboarding. Leads with Pillie's app-blocking
//  differentiator (Superdesign draft e19e4ffd) using the existing premium brand
//  language rather than copying the reference photography.
//
//  The hero is a single "moment" panel — a reminder that flows into a distracting
//  app snapping shut — so the cause-and-effect reads as one cohesive scene.
//

import SwiftUI

struct ProtectionPlanWelcomeView: View {
    let onBuildPlan: () -> Void
    var splashActive: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var isLocked = false
    @State private var didStartEntrance = false

    private let content = ProtectionPlanWelcomeContent.default
    private let performanceTier = PerformanceTier.current

    /// Heavy, looping motion only runs on a capable device with motion allowed.
    private var animationsEnabled: Bool {
        PillieMotion.decorativeMotionEnabled(
            accessibilityReduceMotion: reduceMotion,
            performanceTier: performanceTier
        )
    }

    /// A single-element array holds the dot static; two phases make it breathe.
    private var dotPulsePhases: [CGFloat] {
        animationsEnabled ? [1.0, 1.5] : [1.0]
    }

    var body: some View {
        ProtectionPlanScaffold(
            primaryTitle: content.primaryCTA,
            onPrimary: onBuildPlan
        ) {
            VStack(spacing: 0) {
                brandLockup
                    .padding(.top, 4)

                Spacer(minLength: 30)

                momentPanel
                    .scaleEffect(appeared ? 1 : 0.96)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.08), value: appeared)

                Spacer(minLength: 36)

                headline

                Spacer(minLength: 20)
            }
            .containerRelativeFrame(.vertical)
        }
        // Hold the entrance until the launch splash has cleared, otherwise the
        // lock-snap beat plays underneath the splash and is never seen.
        .onAppear {
            if !splashActive { startEntranceOnce() }
        }
        .onChange(of: splashActive) { _, active in
            if !active { startEntranceOnce() }
        }
    }

    // MARK: - Entrance

    private func startEntranceOnce() {
        guard !didStartEntrance else { return }
        didStartEntrance = true
        runEntrance()
    }

    private func runEntrance() {
        appeared = true

        guard animationsEnabled else {
            // Reduce Motion / constrained: present the locked end state, no beat.
            isLocked = true
            return
        }

        // Signature beat: a moment after the panel lands, the app snaps shut.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
                isLocked = true
            }
            InteractionFeedback.live.perform(.lowRiskTap)
        }
    }

    // MARK: - Brand

    private var brandLockup: some View {
        HStack(spacing: 10) {
            HomeAvatarLogoBadge(size: 38)
                .shadow(color: Color.black.opacity(0.14), radius: 8, y: 4)
            Text("Pillie")
                .font(.pillie(22, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(PillieTheme.fadeInUpCurve, value: appeared)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pillie")
    }

    // MARK: - Hero "moment" panel

    private var momentPanel: some View {
        VStack(spacing: 0) {
            reminderRow
            connector
            lockedAppRow
        }
        .padding(18)
        .frame(maxWidth: 332)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 32))
        .overlay {
            RoundedRectangle(cornerRadius: 32)
                .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.07), radius: 22, y: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.eyebrow)
    }

    private var reminderRow: some View {
        HStack(spacing: 14) {
            iconTile(symbol: "alarm.fill", fill: PillieTheme.coral)

            VStack(alignment: .leading, spacing: 3) {
                Text("Afternoon dose")
                    .font(.pillie(17, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                Text("Reminder · 2:00 PM")
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
            }

            Spacer(minLength: 8)

            Circle()
                .fill(PillieTheme.coral)
                .frame(width: 11, height: 11)
                .shadow(color: PillieTheme.coral.opacity(0.7), radius: 5)
                .phaseAnimator(dotPulsePhases) { dot, scale in
                    dot.scaleEffect(scale)
                } animation: { _ in
                    .easeInOut(duration: 1.15)
                }
        }
        .padding(.horizontal, 4)
    }

    private var connector: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(PillieTheme.dark, in: Circle())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    private var lockedAppRow: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [PillieTheme.lavender, PillieTheme.coral.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isLocked)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Distracting apps")
                    .font(.pillie(17, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                // The locked copy is longer and wraps, so the row grows as it
                // locks — an intentional "expanding" beat on the panel.
                Text(isLocked ? "Locked until you check in" : "Tempting to open…")
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(isLocked ? PillieTheme.textMuted : PillieTheme.coral)
                    .contentTransition(.opacity)
            }

            Spacer(minLength: 8)

            Image(systemName: isLocked ? "lock.fill" : "lock.open")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isLocked ? PillieTheme.coral : PillieTheme.textMuted.opacity(0.5))
                .frame(width: 32, height: 32)
                .background(
                    isLocked ? PillieTheme.coral.opacity(0.14) : PillieTheme.sage.opacity(0.4),
                    in: Circle()
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(10)
        .background(
            isLocked ? PillieTheme.coralLight.opacity(0.85) : Color.clear,
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(PillieTheme.coral.opacity(isLocked ? 0.3 : 0), lineWidth: 1)
        }
    }

    private func iconTile(symbol: String, fill: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(fill, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Headline + reassurance

    private var headline: some View {
        VStack(spacing: 14) {
            Text(content.title)
                .font(.pillieTitle())
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)
                .scaleEffect(appeared ? 1 : 0.92)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.18), value: appeared)

            Text(content.subtitle)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger3), value: appeared)
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    ProtectionPlanWelcomeView(onBuildPlan: {})
}
