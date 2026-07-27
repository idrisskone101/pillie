//
//  TrialDeclineFeedbackView.swift
//  Pillie
//
//  Minimal optional decline-feedback surface for issue #243. Structured
//  reasons arrive in later slices; this tracer intentionally offers only
//  dismiss and Skip.
//

import SwiftUI

struct TrialDeclineFeedbackView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var hasLoggedView = false
    @State private var hasResolved = false

    let content: TrialDeclineFeedbackContent
    let onResolve: () -> Void

    var body: some View {
        ZStack {
            PillieTheme.bg.ignoresSafeArea()

            Circle()
                .fill(PillieTheme.lavender.opacity(0.75))
                .frame(width: 260, height: 260)
                .blur(radius: 55)
                .offset(x: 120, y: -100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        Button(action: resolve) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PillieTheme.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(PillieTheme.sage, in: Circle())
                        }
                        .accessibilityLabel("global.action.close")
                        .accessibilityIdentifier("trialDeclineFeedbackClose")
                    }

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(PillieTheme.dark)
                        .frame(width: 72, height: 72)
                        .background(PillieTheme.coral, in: Circle())
                        .accessibilityHidden(true)

                    TrialDeclineFeedbackHeader(
                        title: content.title,
                        prompt: content.prompt
                    )

                    Text(content.optionalNote)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(PillieTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PillieTheme.cardWhite, in: RoundedRectangle(
                            cornerRadius: PillieTheme.cardRadius
                        ))
                        .accessibilityIdentifier("trialDeclineFeedbackOptionalNote")

                    Button(action: resolve) {
                        Text(content.skip)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: PillieTheme.ctaHeight)
                            .background(PillieTheme.dark, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("trialDeclineFeedbackSkip")
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .animation(
            accessibilityReduceMotion ? nil : PillieTheme.fadeInUpCurve,
            value: hasResolved
        )
        .onAppear {
            guard !hasLoggedView else { return }
            hasLoggedView = true
            ProductAnalyticsTelemetry.live.trialDeclineFeedbackViewed()
        }
    }

    private func resolve() {
        guard !hasResolved else { return }
        hasResolved = true
        ProductAnalyticsTelemetry.live.trialDeclineFeedbackSkipped()
        ProductAnalyticsTelemetry.live.trialDeclineFeedbackCompleted(outcome: .skipped)
        onResolve()
    }
}

private struct TrialDeclineFeedbackHeader: View {
    let title: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(prompt)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trialDeclineFeedbackPrompt")
    }
}
