#if DEBUG
import SwiftUI

struct DeveloperMenuRowView: View {
    let scenario: DebugQAScenario

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: scenario.title)
                    .font(.pillieSubtitleBold())
                    .foregroundStyle(PillieTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(verbatim: scenario.detail)
                    .font(.pillie(14, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted.opacity(0.4))
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityIdentifier("developerScenario.\(scenario.rawValue)")
    }
}
#endif
