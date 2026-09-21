import SwiftUI

struct UpdateTrialPerkGrid: View {
    let perks: [UpdateTrialAnnouncementContent.Perk]

    private let columns = [GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(perks, id: \.title) { perk in
                HStack(spacing: 10) {
                    Image(systemName: perk.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PillieTheme.coral)
                    Text(perk.title)
                        .font(.pillie(13, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .pillieAdaptiveLineLimit(minimumScaleFactor: 0.75)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PillieTheme.sage.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
