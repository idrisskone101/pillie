//
//  ProtectionPlanAnalyticsConsentView.swift
//  Pillie
//
//  Analytics Consent screen, shown immediately after Welcome (Superdesign draft
//  6911713d). Accept or decline; declining never blocks onboarding. Product
//  Analytics Telemetry stays consent-gated upstream in `AnalyticsManager`.
//

import SwiftUI

struct ProtectionPlanAnalyticsConsentView: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onAllow: () -> Void
    let onDecline: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let content = ProtectionPlanAnalyticsConsentContent.default
    private let performanceTier = PerformanceTier.current
    @State private var appeared = false

    private var animationsEnabled: Bool {
        performanceTier == .standard && !reduceMotion
    }

    var body: some View {
        ProtectionPlanScaffold(
            progress: progress,
            onBack: onBack,
            primaryTitle: content.allowCTA,
            primaryIcon: nil,
            onPrimary: onAllow,
            secondaryTitle: content.declineCTA,
            onSecondary: onDecline
        ) {
            VStack(spacing: 12) {
                icon
                    .padding(.top, 0)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger1), value: appeared)

                VStack(spacing: 10) {
                    Text(content.title)
                        .font(.pillieTitle())
                        .foregroundStyle(PillieTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(content.body)
                        .font(.pillieBody())
                        .foregroundStyle(PillieTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(PillieTheme.fadeInUpCurve.delay(PillieTheme.stagger2), value: appeared)

                VStack(spacing: 10) {
                    ForEach(Array(content.points.enumerated()), id: \.element.id) { index, point in
                        pointRow(point)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: cardOffset)
                            .animation(cardRevealAnimation(index: index), value: appeared)
                    }
                }
            }
        }
        .onAppear {
            appeared = true
        }
    }

    private var icon: some View {
        ZStack {
            // Soft halo, then a vibrant coral coin with a crisp white chart.
            Circle()
                .fill(PillieTheme.coral.opacity(0.18))
                .frame(width: 72, height: 72)

            Circle()
                .fill(PillieTheme.coral)
                .frame(width: 54, height: 54)
                .overlay {
                    // Subtle top sheen for a soft, glossy coin (no dark tones).
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
                .shadow(color: PillieTheme.coral.opacity(0.5), radius: 8, y: 4)
                .overlay {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(.white)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PillieTheme.verifiedGreen)
                        .padding(4)
                        .background(.white, in: Circle())
                        .offset(x: 7, y: -5)
                }
        }
        .accessibilityHidden(true)
    }

    /// Cards start lowered only when motion is allowed; otherwise they fade in place.
    private var cardOffset: CGFloat {
        guard animationsEnabled else { return 0 }
        return appeared ? 0 : 18
    }

    /// Staggered spring per card; a plain fade when motion is reduced.
    private func cardRevealAnimation(index: Int) -> Animation? {
        guard animationsEnabled else { return .easeOut(duration: 0.3) }
        return .spring(response: 0.5, dampingFraction: 0.82).delay(0.2 + Double(index) * 0.1)
    }

    private func pointRow(_ point: ProtectionPlanAnalyticsConsentContent.Point) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: point.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PillieTheme.coral)
                .frame(width: 34, height: 34)
                .background(PillieTheme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 2) {
                Text(point.title)
                    .font(.pillie(15, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                Text(point.detail)
                    .font(.pillie(13, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
        }
    }
}

#Preview {
    ProtectionPlanAnalyticsConsentView(
        progress: ProtectionPlanProgress(index: 2, total: 10),
        onBack: {},
        onAllow: {},
        onDecline: {}
    )
}
