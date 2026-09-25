import SwiftUI

/// Shared left-aligned title + subtitle for the plan-builder question screens.
struct ProtectionPlanQuestionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.pillieTitle())
                .foregroundStyle(PillieTheme.textPrimary)
                // The 42pt title fits short questions on one or two lines; a long
                // question (including longer localized variants) can use a third
                // line before scaling down, avoiding clipped Italian copy.
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.pillie(17, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
