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
    let progress: CGFloat
    let badge: String
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

            GeometryReader { geo in
                Capsule()
                    .fill(PillieTheme.sage.opacity(0.65))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(PillieTheme.coral)
                            .frame(width: geo.size.width * min(max(progress, 0), 1))
                    }
            }
            .frame(height: 7)

            Text(badge)
                .font(.pillie(14, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PillieTheme.coral)
                .frame(minWidth: 72, alignment: .trailing)
        }
    }
}

enum PersonalizationOnboardingProgress {
    static let totalSteps: CGFloat = 10

    static func fraction(for step: CGFloat) -> CGFloat {
        step / totalSteps
    }

    static func badge(for step: Int) -> String {
        "STEP \(step)/\(Int(totalSteps))"
    }
}
