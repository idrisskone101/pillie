//
//  ProtectionPlanDraftBlockedAppsView.swift
//  Pillie
//
//  Draft Blocked Apps — the fifth plan-builder question (issue #76, Superdesign
//  drafts f1c3b77e + ed2e2ec4). Multi-select grouped chips: broad distraction
//  categories, specific apps, and an Other catch-all. This is a DRAFT intent only —
//  the footnote makes clear the real apps are chosen later via Apple's Screen Time
//  picker. The committed answer lives in the testable onboarding value core, so
//  back navigation restores it; only a coarse funnel event is sent — never the
//  chosen apps, app tokens, or an exact count.
//

import SwiftUI

struct ProtectionPlanDraftBlockedAppsView: View {
    let model: ProtectionPlanOnboardingModel
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: () -> Void

    private let content = ProtectionPlanDraftBlockedAppsContent.default

    @State private var selected: Set<DraftBlockedAppChoice> = []
    @State private var appeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let performanceTier = PerformanceTier.current

    private var animationsEnabled: Bool {
        performanceTier == .standard && !reduceMotion
    }

    var body: some View {
        ProtectionPlanScaffold(
            progress: progress,
            onBack: onBack,
            primaryTitle: content.primaryCTA,
            primaryIcon: "checkmark.shield.fill",
            animatesPrimaryIcon: false,
            isPrimaryEnabled: !selected.isEmpty,
            onPrimary: commit
        ) {
            VStack(alignment: .leading, spacing: 24) {
                compactHeader
                    .opacity(appeared ? 1 : 0)
                    .offset(y: revealOffset)
                    .animation(reveal(delay: PillieTheme.stagger1), value: appeared)

                section(header: content.categoriesHeader, choices: content.categories)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: revealOffset)
                    .animation(reveal(delay: PillieTheme.stagger2), value: appeared)

                section(header: content.appsHeader, choices: content.apps + [content.other])
                    .opacity(appeared ? 1 : 0)
                    .offset(y: revealOffset)
                    .animation(reveal(delay: PillieTheme.stagger3), value: appeared)

                ProtectionPlanDraftThreadSummary(
                    selected: selected,
                    orderedChoices: content.categories + content.apps + [content.other],
                    animationsEnabled: animationsEnabled
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: revealOffset)
                .animation(reveal(delay: PillieTheme.stagger4), value: appeared)

                Text(content.footnote)
                    .font(.pillie(13, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                    .opacity(appeared ? 1 : 0)
                    .animation(reveal(delay: PillieTheme.stagger5), value: appeared)
            }
        }
        .onAppear {
            // Restore the committed answer so back navigation re-seeds the screen.
            selected = model.draftBlockedApps
            appeared = true
        }
    }

    // A local, compact header (not the shared 42pt ProtectionPlanQuestionHeader):
    // at 30pt the long title lands on two lines, reclaiming the top so the chips and
    // the draft-plan summary become the screen's center of gravity.
    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(content.title)
                .font(.pillie(30, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(content.subtitle)
                .font(.pillie(15, weight: .regular))
                .foregroundStyle(PillieTheme.textMuted)
                .lineSpacing(3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func section(header: String, choices: [DraftBlockedAppChoice]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(header.uppercased())
                .font(.pillie(12, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(PillieTheme.textMuted)

            ProtectionPlanFlowLayout(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(choices) { choice in
                    ProtectionPlanSelectableChip(
                        title: choice.title,
                        isSelected: selected.contains(choice)
                    ) {
                        toggle(choice)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ choice: DraftBlockedAppChoice) {
        if selected.contains(choice) {
            selected.remove(choice)
        } else {
            selected.insert(choice)
        }
    }

    private func commit() {
        model.recordDraftBlockedApps(selected)
        onContinue()
    }

    private var revealOffset: CGFloat {
        guard animationsEnabled else { return 0 }
        return appeared ? 0 : 14
    }

    private func reveal(delay: Double) -> Animation? {
        animationsEnabled ? PillieTheme.fadeInUpCurve.delay(delay) : .easeOut(duration: 0.25)
    }
}

#Preview {
    ProtectionPlanDraftBlockedAppsView(
        model: ProtectionPlanOnboardingModel(),
        progress: ProtectionPlanProgress(index: 9, total: 10),
        onBack: {},
        onContinue: {}
    )
}
