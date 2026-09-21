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
                        .accessibilityLabel(content.close)
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

                    if questionnaire.showsOptionalDetail {
                        TrialDeclineFeedbackOptionalDetail(
                            title: content.optionalDetailTitle,
                            placeholder: content.optionalDetailPlaceholder,
                            privacyGuidance: content.optionalDetailPrivacyGuidance,
                            doneTitle: content.done,
                            characterCount: content.optionalDetailCharacterCount(
                                questionnaire.optionalDetail.count
                            ),
                            text: Binding(
                                get: { questionnaire.optionalDetail },
                                set: { questionnaire.updateOptionalDetail($0) }
                            )
                        )
                    }

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
            .scrollDismissesKeyboard(.interactively)
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
        ProductAnalyticsTelemetry.live.trialDeclineFeedbackSubmitted(submission)
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
