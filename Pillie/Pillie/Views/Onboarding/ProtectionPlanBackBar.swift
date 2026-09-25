import SwiftUI

/// A standalone back chevron for the analyzing beat (the verified beat puts its own
/// chevron in the coral header).
struct ProtectionPlanBackBar: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(width: 52, height: 52)
                    .background(.white, in: Circle())
                    .overlay { Circle().stroke(Color.black.opacity(0.08), lineWidth: 1) }
                    .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PillieLocalization.string("global.action.back"))
            .accessibilityIdentifier("protectionPlanBackButton")

            Spacer()
        }
    }
}
