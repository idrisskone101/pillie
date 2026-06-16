//
//  ProtectionPlanProgressHeader.swift
//  Pillie
//
//  Bespoke progress header for the Protection Plan flow: a back button, a
//  segmented progress capsule whose fill springs in with a glowing leading edge,
//  and the "STEP n/N" badge. Kept separate from the legacy personalization header
//  so the plan-builder chrome can evolve independently.
//

import SwiftUI

struct ProtectionPlanProgressHeader: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            backButton
            progressBar
            Text(progress.badge)
                .font(.pillie(13, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(PillieTheme.coral)
                .frame(minWidth: 64, alignment: .trailing)
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted)
                .frame(width: 52, height: 52)
                .background(.white, in: Circle())
                .overlay { Circle().stroke(Color.black.opacity(0.07), lineWidth: 1) }
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let fillWidth = trackWidth * min(max(progress.fraction, 0), 1)

            Capsule()
                .fill(PillieTheme.sage.opacity(0.55))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(PillieTheme.coral)
                        .frame(width: fillWidth)
                }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel(progress.badge)
    }
}

#Preview {
    ProtectionPlanProgressHeader(
        progress: ProtectionPlanProgress(index: 2, total: 10),
        onBack: {}
    )
    .padding()
    .background(PillieTheme.bg)
}
