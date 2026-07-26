//
//  ProtectionPlanProgressHeader.swift
//  Pillie
//
//  Bespoke progress header for the Protection Plan flow: a back button, a
//  section title and progress capsule. Kept separate from the legacy personalization header
//  so the plan-builder chrome can evolve independently.
//

import SwiftUI

struct ProtectionPlanProgressHeader: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            backButton
            VStack(alignment: .leading, spacing: 7) {
                Text(progress.title)
                    .font(.pillie(13, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .accessibilityHidden(true)
                progressBar
            }
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
        .accessibilityLabel(PillieLocalization.string("global.action.back"))
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
        .accessibilityLabel(progress.accessibilityLabel)
    }
}

#Preview {
    ProtectionPlanProgressHeader(
        progress: ProtectionPlanProgressIndex.progress(for: .painPoints),
        onBack: {}
    )
    .padding()
    .background(PillieTheme.bg)
}
