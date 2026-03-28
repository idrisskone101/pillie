//
//  WelcomeView.swift
//  Pillie
//

import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void
    @State private var animateIn = false
    @State private var floatingOffset: CGFloat = 0
    @State private var floatDelayedOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var blobPhase: CGFloat = 0
    private let performanceTier = PerformanceTier.current

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        heroArea
                            .padding(.top, 60)
                            .offset(y: animateIn ? 0 : 12)
                            .opacity(animateIn ? 1 : 0)
                            .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger1), value: animateIn)

                        titleSection
                            .offset(y: animateIn ? 0 : 12)
                            .opacity(animateIn ? 1 : 0)
                            .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger2), value: animateIn)

                        subtitleSection
                            .offset(y: animateIn ? 0 : 12)
                            .opacity(animateIn ? 1 : 0)
                            .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger3), value: animateIn)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }

                buttonSection
                    .offset(y: animateIn ? 0 : 12)
                    .opacity(animateIn ? 1 : 0)
                    .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger4), value: animateIn)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 34)
            }
        }
        .onAppear {
            animateIn = true

            guard performanceTier == .standard else {
                floatingOffset = 0
                floatDelayedOffset = 0
                pulseScale = 1
                blobPhase = 0
                return
            }

            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                floatingOffset = -10
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                    floatDelayedOffset = -8
                }
            }

            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.02
            }

            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        OnboardingBackground(blobPhase: blobPhase, tier: performanceTier)
    }

    // MARK: - Hero Area

    private var heroArea: some View {
        ZStack(alignment: .topLeading) {
            // Handwriting annotation above grid
            Text("your new bestie ->")
                .font(.pillieHandwriting())
                .foregroundStyle(PillieTheme.textMuted)
                .rotationEffect(.degrees(-12))
                .offset(x: -16, y: -10)

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Card 1: Alarm — coral glassmorphic
                    bentoCard(
                        gradient: LinearGradient(
                            colors: [PillieTheme.coral.opacity(0.6), PillieTheme.coral.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        glowOpacities: (0.2, 0.6),
                        shadowColor: PillieTheme.coral.opacity(0.4)
                    ) {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(PillieTheme.coral)
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(8))
                            .overlay(
                                Image(systemName: "alarm.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color.white)
                                    .rotationEffect(.degrees(8))
                            )
                            .scaleEffect(pulseScale)
                    }
                    .frame(height: 140)
                    .offset(y: floatingOffset)

                    // Card 2: Pill — lavender glassmorphic
                    bentoCard(
                        gradient: LinearGradient(
                            colors: [PillieTheme.lavender.opacity(0.8), PillieTheme.lavender.opacity(0.2)],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        ),
                        glowOpacities: (0.3, 0.7),
                        shadowColor: PillieTheme.lavender.opacity(0.5)
                    ) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(-6))
                            .overlay(
                                Text("\u{1F48A}")
                                    .font(.system(size: 32))
                                    .rotationEffect(.degrees(-6))
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 8)
                    }
                    .frame(height: 140)
                    .offset(y: floatDelayedOffset)
                }

                // Card 3: Time bar — sage glassmorphic, full width
                bentoCard(
                    gradient: LinearGradient(
                        colors: [PillieTheme.sage.opacity(0.7), PillieTheme.sage.opacity(0.3), PillieTheme.sage.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    glowOpacities: (0.5, 0.0),
                    glowDirection: (.top, .bottom),
                    shadowColor: PillieTheme.sage.opacity(0.4)
                ) {
                    HStack {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "bell")
                                        .font(.system(size: 20))
                                        .foregroundStyle(PillieTheme.textMuted)
                                )
                                .rotationEffect(.degrees(4))

                            Text("Next dose")
                                .font(.pillie(16, weight: .medium))
                                .foregroundStyle(PillieTheme.textMuted)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Circle()
                                .fill(PillieTheme.coral)
                                .frame(width: 10, height: 10)
                                .shadow(color: PillieTheme.coral.opacity(0.8), radius: 4)
                                .scaleEffect(pulseScale)

                            Text("8:00 AM")
                                .font(.pillie(16, weight: .bold))
                                .foregroundStyle(PillieTheme.textPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                        .rotationEffect(.degrees(-2))
                    }
                    .padding(.horizontal, 24)
                }
                .frame(height: 84)
                .offset(y: floatingOffset * 0.5)
            }
            .padding(.top, 24)
        }
        .frame(width: 300)
        .offset(y: floatingOffset)
    }

    // MARK: - Bento Card

    private func bentoCard<Content: View>(
        gradient: LinearGradient,
        glowOpacities: (CGFloat, CGFloat),
        glowDirection: (UnitPoint, UnitPoint) = (.topTrailing, .bottomLeading),
        shadowColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(gradient)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(glowOpacities.0), Color.white.opacity(glowOpacities.1)],
                        startPoint: glowDirection.0,
                        endPoint: glowDirection.1
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: shadowColor, radius: 16, y: 8)

            content()
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 0) {
            Text("The alarm clock")
                .font(.pillieTitle())
                .foregroundStyle(PillieTheme.textPrimary)
            Text("for your pill.")
                .font(.pillieTitle())
                .foregroundStyle(PillieTheme.coral)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Subtitle

    private var subtitleSection: some View {
        Text("No more swiping away notifications.\nPillie makes building your habit feel natural and effortless.")
            .font(.pillieBody())
            .foregroundStyle(PillieTheme.textMuted)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        Button(action: onGetStarted) {
            HStack(spacing: 8) {
                Text("Get Started")
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(.pillieDark)
        .shadow(color: PillieTheme.dark.opacity(0.4), radius: 15, y: 15)
    }
}

#Preview {
    WelcomeView(onGetStarted: {})
}
