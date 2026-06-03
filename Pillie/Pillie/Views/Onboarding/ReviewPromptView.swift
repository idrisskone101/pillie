//
//  ReviewPromptView.swift
//  Pillie
//

import StoreKit
import SwiftUI

struct ReviewPromptView: View {
  @Environment(\.requestReview) private var requestReview
  @State private var animateIn = false
  @State private var blobPhase: CGFloat = 0
  private let performanceTier = PerformanceTier.current

  let onContinue: () -> Void

  var body: some View {
    ZStack {
      OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

      VStack(spacing: 0) {
        Spacer()

        VStack(spacing: 26) {
          starRow

          VStack(spacing: 14) {
            Text("Does this feel useful so far?")
              .font(.pillieHeadline())
              .foregroundStyle(PillieTheme.textPrimary)
              .multilineTextAlignment(.center)

            Text("A quick rating helps more people find Pillie.")
              .font(.pillieBody())
              .foregroundStyle(PillieTheme.textMuted)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }

          VStack(spacing: 12) {
            Button {
              requestReview()
              onContinue()
            } label: {
              Text("Rate Pillie")
            }
            .buttonStyle(.pillieDark)
            .accessibilityIdentifier("ratePillieButton")

            Button(action: onContinue) {
              Text("Not now")
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .accessibilityIdentifier("skipReviewPromptButton")
          }
        }
        .padding(30)
        .background(RoundedRectangle(cornerRadius: 34).fill(PillieTheme.cardWhite))
        .shadow(color: PillieTheme.cardShadow, radius: 24, y: 14)
        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
        .padding(.horizontal, 28)
        Spacer()
      }
    }
    .accessibilityIdentifier("reviewPromptView")
    .onAppear {
      animateIn = true
      guard performanceTier == .standard else {
        blobPhase = 0
        return
      }
      withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
        blobPhase = 1
      }
    }
  }

  private var starRow: some View {
    HStack(spacing: 6) {
      ForEach(0..<5, id: \.self) { index in
        Image(systemName: "star.fill")
          .font(.system(size: 26, weight: .semibold))
          .foregroundStyle(PillieTheme.coral)
          .scaleEffect(animateIn ? 1 : 0.55)
          .opacity(animateIn ? 1 : 0)
          .animation(
            .spring(response: 0.42, dampingFraction: 0.58).delay(Double(index) * 0.07),
            value: animateIn)
      }
    }
    .accessibilityHidden(true)
  }
}

#Preview {
  ReviewPromptView(onContinue: {})
}
