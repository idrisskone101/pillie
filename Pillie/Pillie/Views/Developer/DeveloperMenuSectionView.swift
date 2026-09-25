#if DEBUG
import SwiftUI

struct DeveloperMenuSectionView: View {
    let section: DebugQASection
    let onSelect: (DebugQAScenario) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: section.title.uppercased())
                .font(.pillieCaptionMedium())
                .foregroundStyle(PillieTheme.textMuted)
                .tracking(2)

            VStack(spacing: 0) {
                ForEach(
                    Array(DebugQAScenario.scenarios(in: section).enumerated()),
                    id: \.element.id
                ) { index, scenario in
                    if index > 0 {
                        Rectangle()
                            .fill(PillieTheme.sageHalf)
                            .frame(height: 1)
                    }
                    Button {
                        onSelect(scenario)
                    } label: {
                        DeveloperMenuRowView(scenario: scenario)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(PillieTheme.cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: PillieTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                    .stroke(PillieTheme.sageHalf, lineWidth: 1)
            )
        }
    }
}
#endif
