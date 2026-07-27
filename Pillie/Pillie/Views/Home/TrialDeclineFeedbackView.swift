//
//  TrialDeclineFeedbackView.swift
//  Pillie
//
//  Optional closed-reason decline-feedback surface for issues #243–244.
//

import SwiftUI

struct TrialDeclineFeedbackView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var hasLoggedView = false
    @State private var hasResolved = false
    @State private var questionnaire = TrialDeclineFeedbackQuestionnaire()

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
                        Button(action: resolveSkipped) {
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

                    TrialDeclineFeedbackReasonList(
                        reasons: TrialDeclineFeedbackQuestionnaire.availableReasons,
                        selectedReason: questionnaire.selectedReason,
                        label: content.label(for:),
                        onSelect: select
                    )

                    TrialDeclineFeedbackActions(
                        submitTitle: content.submit,
                        skipTitle: content.skip,
                        canSubmit: questionnaire.canSubmit,
                        onSubmit: submit,
                        onSkip: resolveSkipped
                    )
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

    private func select(_ reason: TrialDeclineFeedbackReason) {
        guard questionnaire.selectedReason != reason else { return }
        questionnaire.select(reason)
        ProductAnalyticsTelemetry.live.trialDeclineFeedbackReasonSelected(reason)
    }

    private func submit() {
        guard !hasResolved, let submission = questionnaire.submit() else { return }
        hasResolved = true
        ProductAnalyticsTelemetry.live.trialDeclineFeedbackSubmitted(submission.reason)
        onResolve()
    }

    private func resolveSkipped() {
        guard !hasResolved else { return }
        hasResolved = true
        ProductAnalyticsTelemetry.live.trialDeclineFeedbackSkipped()
        ProductAnalyticsTelemetry.live.trialDeclineFeedbackCompleted(outcome: .skipped)
        onResolve()
    }
}

private struct TrialDeclineFeedbackReasonList: View {
    let reasons: [TrialDeclineFeedbackReason]
    let selectedReason: TrialDeclineFeedbackReason?
    let label: (TrialDeclineFeedbackReason) -> String
    let onSelect: (TrialDeclineFeedbackReason) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(reasons, id: \.rawValue) { reason in
                TrialDeclineFeedbackReasonRow(
                    title: label(reason),
                    analyticsValue: reason.analyticsValue,
                    isSelected: selectedReason == reason,
                    action: { onSelect(reason) }
                )
            }
        }
    }
}

private struct TrialDeclineFeedbackReasonRow: View {
    let title: String
    let analyticsValue: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(isSelected ? PillieTheme.dark : PillieTheme.textMuted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? PillieTheme.sage : PillieTheme.cardWhite,
                in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .strokeBorder(
                        isSelected ? PillieTheme.dark.opacity(0.35) : Color.clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("trialDeclineFeedbackReason_\(analyticsValue)")
    }
}

private struct TrialDeclineFeedbackActions: View {
    let submitTitle: String
    let skipTitle: String
    let canSubmit: Bool
    let onSubmit: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onSubmit) {
                Text(submitTitle)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: PillieTheme.ctaHeight)
                    .background(PillieTheme.dark, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.42)
            .accessibilityIdentifier("trialDeclineFeedbackSubmit")

            Button(action: onSkip) {
                Text(skipTitle)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("trialDeclineFeedbackSkip")
        }
        .padding(.top, 8)
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
