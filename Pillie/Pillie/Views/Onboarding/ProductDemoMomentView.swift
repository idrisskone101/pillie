//
//  ProductDemoMomentView.swift
//  Pillie
//

import SwiftUI
#if os(iOS)
  import UIKit
#endif

struct ProductDemoMomentView: View {
  @State private var animateIn = false
  @State private var blobPhase: CGFloat = 0
  @State private var demoPhase = 0
  @State private var shakeManager = ShakeDetectionManager(requiredShakes: 3)
  @State private var phoneTilt: Double = 0
  @State private var shakeComplete = false
  private let performanceTier = PerformanceTier.current

  let onContinue: () -> Void

  var body: some View {
    ZStack {
      OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

      VStack(spacing: 0) {
        Spacer(minLength: 24)

        ScrollView(showsIndicators: false) {
          VStack(spacing: 16) {
            titleSection
              .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))

            routineLoopCard
              .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

            plusPreviewCard
              .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

            Text("Reminders and history stay free. App blocking is a Plus boost.")
              .font(.pillie(11, weight: .medium))
              .foregroundStyle(PillieTheme.textMuted)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, 12)
              .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
          }
          .padding(.horizontal, 28)
          .padding(.top, 30)
          .padding(.bottom, 118)
        }

        Button(action: onContinue) {
          Text("Continue")
        }
        .buttonStyle(.pillieDark)
        .accessibilityIdentifier("productDemoContinueButton")
        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
        .padding(.horizontal, 28)
        .padding(.bottom, 34)
      }
    }
    .accessibilityIdentifier("productDemoMomentView")
    .onAppear {
      animateIn = true
      shakeManager.startDetecting()
      guard performanceTier == .standard else {
        blobPhase = 0
        return
      }
      withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
        blobPhase = 1
      }
    }
    .onDisappear {
      shakeManager.stopDetecting()
      shakeComplete = false
    }
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1.35))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
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

  private var titleSection: some View {
    VStack(spacing: 10) {
      Text("Your Daily Flow")
        .font(.pillie(11, weight: .black))
        .foregroundStyle(PillieTheme.textMuted)
        .textCase(.uppercase)

      Text("Take your dose.\nUnlock your day.")
        .font(.pillie(28, weight: .bold))
        .foregroundStyle(PillieTheme.textPrimary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: 300)

      Text("Pillie reminds you, you check in, and your apps open back up.")
        .font(.pillie(15, weight: .medium))
        .foregroundStyle(PillieTheme.textMuted)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var routineLoopCard: some View {
    HStack(spacing: 8) {
      demoStep(index: 0, icon: "bell.fill", title: "Reminder")
      flowArrow
      demoStep(index: 1, icon: "iphone.radiowaves.left.and.right", title: "Shake")
      flowArrow
      demoStep(index: 2, icon: "lock.open.fill", title: "Unlock")
    }
    .padding(18)
    .background(RoundedRectangle(cornerRadius: PillieTheme.cardRadius).fill(PillieTheme.cardWhite))
    .shadow(
      color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius,
      y: PillieTheme.cardShadowY)
  }

  private var flowArrow: some View {
    Image(systemName: "arrow.right")
      .font(.system(size: 13, weight: .bold))
      .foregroundStyle(PillieTheme.textMuted.opacity(0.36))
      .frame(width: 16)
      .accessibilityHidden(true)
  }

  private func demoStep(index: Int, icon: String, title: String) -> some View {
    let isActive = demoPhase == index

    return VStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(isActive ? .white : PillieTheme.coral)
        .frame(width: 52, height: 52)
        .background(
          isActive ? PillieTheme.dark : PillieTheme.coral.opacity(0.14),
          in: RoundedRectangle(cornerRadius: 16))

      Text(title)
        .font(.pillie(13, weight: .bold))
        .foregroundStyle(isActive ? PillieTheme.textPrimary : PillieTheme.textMuted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(
      isActive ? PillieTheme.sage.opacity(0.55) : PillieTheme.bg,
      in: RoundedRectangle(cornerRadius: 18)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .strokeBorder(isActive ? PillieTheme.coral.opacity(0.35) : Color.clear, lineWidth: 1)
    )
    .scaleEffect(isActive ? 1.015 : 1)
    .accessibilityElement(children: .combine)
  }

  private var plusPreviewCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Pillie Plus")
            .font(.pillie(14, weight: .black))
            .foregroundStyle(PillieTheme.textPrimary)

          Text("Keep distracting apps paused until you confirm your dose. One quick shake brings them back.")
            .font(.pillie(12, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        Text("Plus")
          .font(.pillie(10, weight: .black))
          .foregroundStyle(PillieTheme.textPrimary)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(PillieTheme.coral, in: Capsule())
      }

      HStack(alignment: .center, spacing: 14) {
        ZStack {
          RoundedRectangle(cornerRadius: 16)
            .fill(PillieTheme.cardWhite)
            .frame(width: 54, height: 54)
            .shadow(color: PillieTheme.cardShadow, radius: 10, y: 5)

          Image(systemName: "iphone")
            .font(.system(size: 23, weight: .semibold))
            .foregroundStyle(PillieTheme.textMuted)
        }
        .rotationEffect(.degrees(phoneTilt))

        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline) {
            Text("\(shakeManager.shakeCount) of \(shakeManager.requiredShakes) shakes")
              .font(.pillie(14, weight: .bold))
              .foregroundStyle(shakeComplete ? PillieTheme.coral : PillieTheme.textPrimary)
              .contentTransition(.numericText())

            Spacer(minLength: 8)
          }

          ProgressView(value: shakeManager.progress)
            .tint(PillieTheme.coral)
            .frame(maxWidth: .infinity)

          Text(shakeComplete ? "Nice. You are unlocked." : "Shake three times to confirm.")
            .font(.pillie(11, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted)
            .lineLimit(2)
            .minimumScaleFactor(0.86)
            .contentTransition(.opacity)
        }
      }
    }
    .padding(16)
    .background(RoundedRectangle(cornerRadius: 26).fill(PillieTheme.lavender))
    .overlay(
      RoundedRectangle(cornerRadius: 26)
        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
    )
    .accessibilityIdentifier("pilliePlusPreviewShakeCard")
  }
}

#Preview {
  ProductDemoMomentView(onContinue: {})
}
