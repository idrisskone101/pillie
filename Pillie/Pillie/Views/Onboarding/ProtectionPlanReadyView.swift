//
//  ProtectionPlanReadyView.swift
//  Pillie
//
//  Issue #83 — Pill Protection Plan Ready. The terminal activation screen, shown
//  only to activated users (saved blocker config + Screen Time authorization) after
//  a valid blocker config save. Faithful to the Claude Design "You're In — Options"
//  variant 1 ("Protection pulse"): a live radar pulse around the Pillie mark, the
//  "You're protected." handoff, a live reminder chip, and a single primary CTA into
//  the app. The screen carries the reminder time but never which apps — or how many —
//  were blocked.
//

import SwiftUI

/// Copy for the Pill Protection Plan Ready screen. Only `statusLabel` is data-driven
/// (the live reminder time); the rest is the fixed warm handoff. Kept as a value type
/// so the reminder-time formatting and the generic (name/count-free) summary are
/// testable without driving the SwiftUI view.
struct ProtectionPlanReadyContent {
    let title: String
    let titleAccent: String
    let subtitle: String
    let statusLabel: String
    let handNote: String
    let primaryCTA: String

    var visibleCopy: [String] {
        [title, titleAccent, subtitle, statusLabel, handNote, primaryCTA]
    }

    /// Builds the ready copy for a reminder configured at `reminderHour`:`reminderMinute`
    /// (24-hour). The reminder time is the only personalized value — nothing about which
    /// apps, or how many, were blocked is ever included.
    static func make(reminderHour: Int, reminderMinute: Int) -> ProtectionPlanReadyContent {
        let twelve = ReminderTimeConverter.toTwelveHour(hour24: reminderHour, minute: reminderMinute)
        let time = ProtectionPlanRoutineSummary.clockText(
            hour12: twelve.hour,
            minute: twelve.minute,
            isPM: twelve.period == 1
        )
        return ProtectionPlanReadyContent(
            title: "You're",
            titleAccent: "protected.",
            subtitle: "Pillie's watching the clock so you don't have to. It all just runs, quietly.",
            statusLabel: "Active from \(time) daily",
            handNote: "we've got you",
            primaryCTA: "Start Using Pillie"
        )
    }
}

struct ProtectionPlanReadyView: View {
    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    @State private var pulse = false

    private let performanceTier = PerformanceTier.current

    let onContinue: () -> Void

    private var content: ProtectionPlanReadyContent {
        ProtectionPlanReadyContent.make(
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute
        )
    }

    private var motionEnabled: Bool {
        !accessibilityReduceMotion && performanceTier == .standard
    }

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                VStack(spacing: 26) {
                    hero
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))

                    titleSection
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                    statusChip
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                    handNote
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 16)

                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger5))
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        guard motionEnabled else {
            blobPhase = 0
            pulse = false
            animateIn = true
            return
        }
        // The whole page composes in via the staggered FadeInUp below; kick it off.
        animateIn = true
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            blobPhase = 1
        }
        // The lone continuing loop: the live "Active from …" status dot.
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    // MARK: - Hero (the brand mark, settling in with the page)

    private var hero: some View {
        logoTile
            // A gentle settle that rides the same staggered curve as the rest of the
            // page, so the mark and the copy read as one smooth render.
            .scaleEffect(motionEnabled ? (animateIn ? 1 : 0.9) : 1)
            .animation(motionEnabled ? PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger1) : nil, value: animateIn)
            .accessibilityHidden(true)
    }

    private var logoTile: some View {
        Image("HomeAvatarLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 82, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .frame(width: 124, height: 124)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 38, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .stroke(Color.white.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 20, y: 14)
    }

    // MARK: - Copy

    private var titleSection: some View {
        VStack(spacing: 14) {
            (Text("\(content.title) ").foregroundStyle(PillieTheme.textPrimary)
                + Text(content.titleAccent).foregroundStyle(PillieTheme.coral))
                .font(.pillieTitle())
                .tracking(-0.5)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(content.subtitle)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
        }
    }

    private var statusChip: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(PillieTheme.verifiedGreen)
                .frame(width: 9, height: 9)
                .scaleEffect((pulse && motionEnabled) ? 1.4 : 1)
                .opacity((pulse && motionEnabled) ? 0.6 : 1)

            Text(content.statusLabel)
                .font(.pillie(14, weight: .semibold))
                .foregroundStyle(PillieTheme.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Capsule().fill(PillieTheme.cardWhite))
        .overlay(Capsule().stroke(PillieTheme.sageHalf, lineWidth: 1))
        .shadow(color: PillieTheme.cardShadow, radius: 6, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.statusLabel)
    }

    private var handNote: some View {
        Text(content.handNote)
            .font(.pillieHandwriting(size: 27))
            .foregroundStyle(PillieTheme.textMuted)
            .rotationEffect(.degrees(-3))
    }

    private var footer: some View {
        Button(action: onContinue) {
            HStack(spacing: 8) {
                Text(content.primaryCTA)
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(.pillieDark)
        .accessibilityIdentifier("protectionPlanReadyStartButton")
    }
}

#Preview {
    ProtectionPlanReadyView(onContinue: {})
        .environment(PillStore.previewStore())
}
