import SwiftUI

struct LaunchSplashView: View {
    let iconScale: CGFloat

    var body: some View {
        ZStack {
            PillieTheme.coral
                .ignoresSafeArea()

            Image("SplashIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 20, y: 8)
                .scaleEffect(iconScale)
        }
        .transition(.opacity)
        .zIndex(1)
        .allowsHitTesting(false)
    }
}
