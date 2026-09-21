import SwiftUI

struct ReminderPlanPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pillie(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(Color(hex: "FF8C86"), in: Capsule())
            .shadow(color: Color(hex: "FF8C86").opacity(0.42), radius: 14, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
