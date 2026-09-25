import SwiftUI

struct TrialDeclineFeedbackOptionalDetail: View {
    @FocusState private var isFocused: Bool

    let title: String
    let placeholder: String
    let privacyGuidance: String
    let doneTitle: String
    let characterCount: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(PillieTheme.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextEditor(text: $text)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 112)
                    .focused($isFocused)
                    // PostHog globally masks every text input. Mark this field
                    // sensitive as an additional field-level replay/screenshot boundary.
                    .privacySensitive()
                    .accessibilityLabel(title)
                    .accessibilityHint(privacyGuidance)
                    .accessibilityValue(characterCount)
                    .accessibilityIdentifier("trialDeclineFeedbackOptionalDetail")
            }
            .padding(10)
            .background(PillieTheme.bg, in: RoundedRectangle(cornerRadius: 16))

            TrialDeclineFeedbackPrivacyFooter(
                privacyGuidance: privacyGuidance,
                visibleCharacterCount: text.count,
                accessibilityCharacterCount: characterCount
            )
        }
        .padding(20)
        .background(
            PillieTheme.cardWhite,
            in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(doneTitle) {
                    isFocused = false
                }
                .accessibilityIdentifier("trialDeclineFeedbackKeyboardDone")
            }
        }
    }
}

struct TrialDeclineFeedbackPrivacyFooter: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let privacyGuidance: String
    let visibleCharacterCount: Int
    let accessibilityCharacterCount: String

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                guidance
                count
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                guidance
                Spacer(minLength: 8)
                count
            }
        }
    }

    private var guidance: some View {
        Label(privacyGuidance, systemImage: "hand.raised.fill")
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            .foregroundStyle(PillieTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("trialDeclineFeedbackPrivacyGuidance")
    }

    private var count: some View {
        Text(verbatim: "\(visibleCharacterCount)/\(TrialDeclineFeedbackQuestionnaire.maximumOptionalDetailLength)")
            .font(.system(.footnote, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(PillieTheme.textMuted)
            .accessibilityLabel(accessibilityCharacterCount)
            .accessibilityIdentifier("trialDeclineFeedbackCharacterCount")
    }
}

struct TrialDeclineFeedbackReasonList: View {
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

struct TrialDeclineFeedbackReasonRow: View {
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

struct TrialDeclineFeedbackActions: View {
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

struct TrialDeclineFeedbackHeader: View {
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
