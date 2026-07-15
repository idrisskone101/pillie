//
//  PersonalizationOnboardingLayout.swift
//  Pillie
//
//  Shared chrome for the legacy personalization onboarding screens that are still
//  in the flow (method, schedule, reminder time, paywall, etc.): the back +
//  progress header and the step-progress helper. The selectable row and footer that
//  used to live here were removed once the calibration question screens migrated to
//  the Protection Plan plan-builder components (ProtectionPlanScaffold /
//  ProtectionPlanSelectableRow / ProtectionPlanSelectableChip).
//

import SwiftUI

struct PersonalizationOnboardingHeader: View {
    let appeared: Bool
    let progress: ProtectionPlanProgress
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(width: 56, height: 56)
                    .background(.white, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 7) {
                Text(progress.title)
                    .font(.pillie(13, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .accessibilityHidden(true)

                GeometryReader { geo in
                    Capsule()
                        .fill(PillieTheme.sage.opacity(0.65))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(PillieTheme.coral)
                                .frame(
                                    width: appeared
                                        ? geo.size.width * min(max(progress.fraction, 0), 1)
                                        : 0
                                )
                                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)
                        }
                }
                .frame(height: 7)
                .accessibilityElement()
                .accessibilityLabel(Text(progress.accessibilityLabel))
            }
        }
    }
}
