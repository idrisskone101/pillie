//
//  PlusBlockingDemoView.swift
//  Pillie
//

import SwiftUI
#if os(iOS)
  import UIKit
#endif

struct PlusBlockingDemoView: View {
  @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
  @State private var animateIn = false
  @State private var demoPhase = 0
  @State private var shakeManager = ShakeDetectionManager(requiredShakes: 3)
  @State private var phoneTilt: Double = 0
  @State private var shakeIconWiggle = false
  @State private var shakeComplete = false
  private let performanceTier = PerformanceTier.current
  private let onboardingFeedback = OnboardingInteractionFeedback(performanceTier: PerformanceTier.current)

  let onContinue: () -> Void

  var body: some View {
    ZStack {
      PillieTheme.bg.ignoresSafeArea()

      VStack(spacing: 0) {
        Spacer(minLength: 22)

        ScrollView(showsIndicators: false) {
          VStack(spacing: 14) {
            titleSection
              .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))

            blockingStoryboardCard
              .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

            shakeTryCard
              .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
          }
          .padding(.horizontal, 28)
          .padding(.top, 22)
          .padding(.bottom, 28)
        }

        Button(action: onContinue) {
          Text("Continue")
        }
        .buttonStyle(.pillieDark)
        .accessibilityIdentifier("plusBlockingDemoContinueButton")
        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
        .padding(.horizontal, 28)
        .padding(.bottom, PillieTheme.onboardingCTABottomPadding)
      }
    }
    .accessibilityIdentifier("plusBlockingDemoView")
    .onAppear {
      animateIn = true
      shakeManager.startDetecting()
      guard !accessibilityReduceMotion, performanceTier == .standard else { return }
      withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
        shakeIconWiggle = true
      }
    }
    .onDisappear {
      shakeManager.stopDetecting()
      shakeComplete = false
    }
    .task {
      guard !accessibilityReduceMotion, performanceTier == .standard else { return }
      let response = onboardingFeedback.ambientLoop(accessibilityReduceMotion: accessibilityReduceMotion)
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1.45))
        guard !Task.isCancelled else { return }
        withAnimation(response.motionProfile.animation) {
          demoPhase = (demoPhase + 1) % 3
        }
      }
    }
    .onChange(of: shakeManager.shakeCount) { oldValue, newValue in
      guard newValue > oldValue else { return }
      animatePhoneShake()
      fireShakeHaptic(count: newValue)

      if shakeManager.isComplete {
        completeShakeDemo()
      }
    }
  }

  private var titleSection: some View {
    VStack(spacing: 9) {
      Text("Pillie Plus")
        .font(.pillie(11, weight: .black))
        .foregroundStyle(PillieTheme.textPrimary)
        .textCase(.uppercase)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(PillieTheme.coral, in: Capsule())

      Text("Block distractions\nuntil you check in.")
        .font(.pillie(27, weight: .bold))
        .foregroundStyle(PillieTheme.textPrimary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: 320)

      Text("Pillie Plus can pause selected apps when your reminder fires, then unlock them after you confirm your dose.")
        .font(.pillie(14, weight: .medium))
        .foregroundStyle(PillieTheme.textMuted)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var blockingStoryboardCard: some View {
    VStack(spacing: 9) {
      storyboardRow(
        index: 0,
        icon: "bell.badge.fill",
        title: "Reminder fires",
        detail: "Your daily dose nudge arrives.",
        tint: PillieTheme.coral
      )

      appBlockingRow

      appsUnlockRow
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: PillieTheme.cardRadius).fill(PillieTheme.cardWhite))
    .shadow(
      color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius,
      y: PillieTheme.cardShadowY)
  }

  private func storyboardRow(
    index: Int,
    icon: String,
    title: String,
    detail: String,
    tint: Color
  ) -> some View {
    let isActive = demoPhase == index

    return HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(isActive ? PillieTheme.textPrimary : tint)
        .frame(width: 40, height: 40)
        .background(
          isActive ? PillieTheme.coral : PillieTheme.cardWhite,
          in: RoundedRectangle(cornerRadius: 14)
        )

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(title)
            .font(.pillie(12, weight: .black))
            .foregroundStyle(PillieTheme.textPrimary)
        }

        Text(detail)
          .font(.pillie(10, weight: .medium))
          .foregroundStyle(PillieTheme.textMuted)
          .lineLimit(2)
          .minimumScaleFactor(0.88)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      isActive ? PillieTheme.coralLight : PillieTheme.cardWhite,
      in: RoundedRectangle(cornerRadius: 18)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .strokeBorder(isActive ? PillieTheme.coral.opacity(0.36) : Color.black.opacity(0.04), lineWidth: 1)
    )
    .scaleEffect(isActive ? 1.01 : 1)
    .accessibilityElement(children: .combine)
  }

  private var appBlockingRow: some View {
    let isActive = demoPhase == 1

    return HStack(spacing: 12) {
      Image(systemName: "lock.fill")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(PillieTheme.coral)
        .frame(width: 40, height: 40)
        .background(PillieTheme.cardWhite, in: RoundedRectangle(cornerRadius: 14))

      VStack(alignment: .leading, spacing: 3) {
        Text("Apps stay blocked")
          .font(.pillie(12, weight: .black))
          .foregroundStyle(PillieTheme.textPrimary)

        Text("Instagram, Safari, and other selected apps wait until you confirm.")
          .font(.pillie(10, weight: .medium))
          .foregroundStyle(PillieTheme.textMuted)
          .lineLimit(2)
          .minimumScaleFactor(0.88)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(isActive ? PillieTheme.coralLight : PillieTheme.cardWhite, in: RoundedRectangle(cornerRadius: 18))
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .strokeBorder(isActive ? PillieTheme.coral.opacity(0.42) : Color.black.opacity(0.04), lineWidth: 1)
    )
    .scaleEffect(isActive ? 1.01 : 1)
    .accessibilityElement(children: .combine)
  }

  private var appsUnlockRow: some View {
    let isActive = demoPhase == 2

    return HStack(spacing: 12) {
      Image(systemName: "lock.open.fill")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(PillieTheme.coral)
        .frame(width: 40, height: 40)
        .background(PillieTheme.cardWhite, in: RoundedRectangle(cornerRadius: 14))

      VStack(alignment: .leading, spacing: 3) {
        Text("Apps unlock")
          .font(.pillie(12, weight: .black))
          .foregroundStyle(PillieTheme.textPrimary)

        Text("Dose handled. Your day opens back up.")
          .font(.pillie(10, weight: .medium))
          .foregroundStyle(PillieTheme.textMuted)
          .lineLimit(1)
          .minimumScaleFactor(0.88)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(isActive ? PillieTheme.coralLight : PillieTheme.cardWhite, in: RoundedRectangle(cornerRadius: 18))
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .strokeBorder(isActive ? PillieTheme.coral.opacity(0.36) : Color.black.opacity(0.04), lineWidth: 1)
    )
    .scaleEffect(isActive ? 1.01 : 1)
    .accessibilityElement(children: .combine)
  }

  private var shakeTryCard: some View {
    Button {
      shakeManager.simulateShake()
    } label: {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .center, spacing: 12) {
          ZStack {
            RoundedRectangle(cornerRadius: 16)
              .fill(PillieTheme.cardWhite)
              .frame(width: 54, height: 54)
              .shadow(color: PillieTheme.cardShadow, radius: 10, y: 5)

            Image(systemName: "iphone.radiowaves.left.and.right")
              .font(.system(size: 23, weight: .semibold))
              .foregroundStyle(PillieTheme.coral)
          }
          .rotationEffect(.degrees(phoneTilt == 0 ? (shakeIconWiggle ? -3 : 3) : phoneTilt))

          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
              Text("Try shake-to-unlock")
                .font(.pillie(14, weight: .black))
                .foregroundStyle(PillieTheme.textPrimary)
            }

            Text("Shake your phone now, or tap this card in Simulator.")
              .font(.pillie(11, weight: .medium))
              .foregroundStyle(PillieTheme.textMuted)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 0)
        }

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("\(shakeManager.shakeCount) of \(shakeManager.requiredShakes) shakes")
              .font(.pillie(13, weight: .bold))
              .foregroundStyle(shakeComplete ? PillieTheme.coral : PillieTheme.textPrimary)

            Spacer()

            Text(shakeComplete ? "Unlocked" : "Demo")
              .font(.pillie(10, weight: .black))
              .foregroundStyle(PillieTheme.textMuted)
          }

          ProgressView(value: shakeManager.progress)
            .tint(PillieTheme.coral)

          Text(shakeComplete ? "Nice. Apps would unlock now." : "Three quick shakes confirms your dose.")
            .font(.pillie(11, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted)
        }
        .transaction { transaction in
          transaction.animation = nil
        }
        .padding(13)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18))
      }
      .padding(15)
      .background(RoundedRectangle(cornerRadius: 24).fill(PillieTheme.coralLight))
      .overlay(
        RoundedRectangle(cornerRadius: 24)
          .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("plusBlockingShakeTryCard")
  }

  private func animatePhoneShake() {
    withAnimation(.spring(response: 0.22, dampingFraction: 0.35)) {
      phoneTilt = phoneTilt == 0 ? -9 : 9
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
      withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
        phoneTilt = 0
      }
    }
  }

  private func fireShakeHaptic(count: Int) {
    #if os(iOS)
      let style: UIImpactFeedbackGenerator.FeedbackStyle
      switch count {
      case 1: style = .light
      case 2: style = .medium
      default: style = .heavy
      }
      UIImpactFeedbackGenerator(style: style).impactOccurred()
    #endif
  }

  private func completeShakeDemo() {
    guard !shakeComplete else { return }
    shakeManager.stopDetecting()

    #if os(iOS)
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    #endif

    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
      shakeComplete = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
      withAnimation(.easeOut(duration: 0.25)) {
        shakeComplete = false
      }
      shakeManager.reset()
      shakeManager.startDetecting()
    }
  }
}

#Preview {
  PlusBlockingDemoView(onContinue: {})
}
