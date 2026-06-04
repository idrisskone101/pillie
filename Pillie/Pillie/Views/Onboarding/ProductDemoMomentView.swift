//
//  ProductDemoMomentView.swift
//  Pillie
//

import SwiftUI

struct ProductDemoMomentView: View {
  @State private var animateIn = false
  @State private var demoPhase = 0

  let onContinue: () -> Void

  var body: some View {
    ZStack {
      PillieTheme.bg.ignoresSafeArea()

      VStack(spacing: 0) {
        Spacer(minLength: 24)

        ScrollView(showsIndicators: false) {
          VStack(spacing: 16) {
            titleSection
              .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))

            routineLoopCard
              .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

            historyPreviewCard
              .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

            Text("Daily reminders, logging, and history are part of the free plan.")
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
  }

  private var titleSection: some View {
    VStack(spacing: 10) {
      Text("Your Daily Flow")
        .font(.pillie(11, weight: .black))
        .foregroundStyle(PillieTheme.textMuted)
        .textCase(.uppercase)

      Text("Get reminded.\nLog your dose.")
        .font(.pillie(28, weight: .bold))
        .foregroundStyle(PillieTheme.textPrimary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: 300)

      Text("Pillie helps you check in and keeps your history easy to review.")
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
      demoStep(index: 1, icon: "checkmark.circle.fill", title: "Log")
      flowArrow
      demoStep(index: 2, icon: "calendar.badge.checkmark", title: "History")
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
      isActive ? PillieTheme.coralLight : PillieTheme.bg,
      in: RoundedRectangle(cornerRadius: 18)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .strokeBorder(isActive ? PillieTheme.coral.opacity(0.35) : Color.clear, lineWidth: 1)
    )
    .scaleEffect(isActive ? 1.015 : 1)
    .accessibilityElement(children: .combine)
  }

  private var historyPreviewCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Your history builds automatically")
            .font(.pillie(14, weight: .black))
            .foregroundStyle(PillieTheme.textPrimary)

          Text("Every check-in updates your streak and cycle timeline so you can see what happened later.")
            .font(.pillie(12, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        Text("Free")
          .font(.pillie(10, weight: .black))
          .foregroundStyle(PillieTheme.textPrimary)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(PillieTheme.coral, in: Capsule())
      }

      VStack(spacing: 8) {
        historyRow(day: "MON", status: "Taken", tint: PillieTheme.coral, icon: "checkmark")
        historyRow(day: "TUE", status: "Taken", tint: PillieTheme.coral, icon: "checkmark")
        historyRow(day: "WED", status: "Reminder set", tint: PillieTheme.coral, icon: "bell.fill")
      }
    }
    .padding(16)
    .background(RoundedRectangle(cornerRadius: 26).fill(PillieTheme.coralLight))
    .overlay(
      RoundedRectangle(cornerRadius: 26)
        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
    )
    .accessibilityIdentifier("pillieHistoryPreviewCard")
  }

  private func historyRow(day: String, status: String, tint: Color, icon: String) -> some View {
    HStack(spacing: 12) {
      Text(day)
        .font(.pillie(10, weight: .black))
        .foregroundStyle(PillieTheme.textMuted)
        .frame(width: 34, alignment: .leading)

      Image(systemName: icon)
        .font(.system(size: 12, weight: .black))
        .foregroundStyle(tint)
        .frame(width: 28, height: 28)
        .background(.white.opacity(0.8), in: Circle())

      Text(status)
        .font(.pillie(12, weight: .bold))
        .foregroundStyle(PillieTheme.textPrimary)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
  }
}

#Preview {
  ProductDemoMomentView(onContinue: {})
}
