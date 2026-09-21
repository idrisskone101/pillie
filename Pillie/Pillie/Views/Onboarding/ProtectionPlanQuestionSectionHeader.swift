import SwiftUI

/// Secondary heading inside a consolidated question screen. It preserves the
/// primary screen title's hierarchy while keeping both sections easy to scan.
struct ProtectionPlanQuestionSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.pillie(24, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.pillie(15, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
