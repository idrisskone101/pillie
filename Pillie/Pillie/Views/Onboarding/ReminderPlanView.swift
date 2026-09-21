//
//  ReminderPlanView.swift
//  Pillie
//

import SwiftUI

struct ReminderPlanView: View {
    @Environment(PillStore.self) private var store
    @State private var animateIn = false
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    let onBack: () -> Void
    let onContinue: () -> Void

    private var summary: ReminderPlanSummary {
        ReminderPlanSummary(store: store)
    }

    var body: some View {
        ZStack {
            OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)

            VStack(spacing: 0) {
                header
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger1))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        titleSection
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger2))

                        VStack(spacing: 10) {
                            ForEach(summary.items) { item in
                                summaryCard(item)
                            }
                        }
                        .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))

                        noteText
                            .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger3))
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 14)
                    .padding(.bottom, 104)
                }
            }

            VStack {
                Spacer()
                footer
                    .modifier(FadeInUp(appeared: animateIn, delay: PillieTheme.stagger4))
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .background(
                        LinearGradient(
                            colors: [PillieTheme.bg.opacity(0), PillieTheme.bg, PillieTheme.bg],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .padding(.top, -20)
                        .ignoresSafeArea(.all, edges: .bottom)
                    )
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
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

    private var header: some View {
        PersonalizationOnboardingHeader(
            appeared: animateIn,
            progress: ProtectionPlanProgressIndex.progress(for: .reminderPlan),
            onBack: onBack
        )
    }

    private var titleSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)
                .frame(width: 48, height: 48)
                .background(PillieTheme.coralLight, in: Circle())
                .shadow(color: PillieTheme.cardShadow, radius: 10, y: 4)
                .accessibilityHidden(true)

            Text("Your Personalized\nReminder Plan")
                .font(.pillie(27, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(0)

            Text("Built specifically for your routine.")
                .font(.pillie(14, weight: .medium))
                .foregroundStyle(PillieTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private func summaryCard(_ item: ReminderPlanSummary.Item) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbolName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(item.color)
                .frame(width: 44, height: 44)
                .background(item.background, in: RoundedRectangle(cornerRadius: 15))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.pillie(10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.68))
                    .textCase(.uppercase)

                Text(item.value)
                    .font(.pillie(14, weight: .black))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.detail)
                    .font(.pillie(11, weight: .medium))
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .fill(PillieTheme.cardWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius)
                .strokeBorder(Color.black.opacity(0.03), lineWidth: 1)
        )
        .shadow(
            color: PillieTheme.cardShadow,
            radius: PillieTheme.cardShadowRadius,
            y: PillieTheme.cardShadowY
        )
    }

    private var noteText: some View {
        Text("This is a reminder setup based on your inputs. You can edit it later in Settings.")
            .font(.pillie(10, weight: .medium))
            .foregroundStyle(PillieTheme.textMuted.opacity(0.68))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 8)
    }

    private var footer: some View {
        Button {
            onContinue()
        } label: {
            HStack(spacing: 8) {
                Text("See Recommendation")
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(ReminderPlanPrimaryButtonStyle())
    }
}

#Preview {
    ReminderPlanView(onBack: {}, onContinue: {})
        .environment(PillStore.previewStore())
}
