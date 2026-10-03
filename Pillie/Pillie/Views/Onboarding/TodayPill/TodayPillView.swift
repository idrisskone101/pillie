//
//  TodayPillView.swift
//  Pillie
//

import SwiftUI

struct TodayPillView: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: (TodayPillPick) -> Void

    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Seeded in onAppear, not a custom init, so the SDK 27 @State macro stays well-behaved.
    @State private var selection = TodayPillSelection(pack: PackChoice(preset: .twentyOneSeven))
    @State private var appeared = false

    private var animationsEnabled: Bool {
        PerformanceTier.current == .standard && !reduceMotion
    }

    var body: some View {
        ProtectionPlanScaffold(
            progress: progress,
            onBack: onBack,
            primaryTitle: PillieLocalization.string("global.action.continue"),
            isPrimaryEnabled: selection.pick != nil,
            onPrimary: {
                guard let pick = selection.pick else { return }
                onContinue(pick)
            }
        ) {
            ScrollViewReader { scroll in
                VStack(alignment: .leading, spacing: 0) {
                    ProtectionPlanQuestionHeader(
                        title: PillieLocalization.string("onboarding.today_pill.title"),
                        subtitle: PillieLocalization.string("onboarding.today_pill.subtitle")
                    )
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                    .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger1)

                    TodayPillCard(selection: $selection, showsLoggedRow: true, onReveal: { reveal(in: scroll) })
                        .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger2)

                    // Scrolled to when the question or the logged row appears, so the last
                    // line keeps this gap above the CTA on screens the step overflows.
                    Color.clear
                        .frame(height: Self.bottomGap)
                        .id(Self.bottomAnchor)
                }
            }
        }
        .onAppear {
            seed()
            appeared = true
        }
    }

    private static let bottomAnchor = "todayPillBottom"
    private static let bottomGap: CGFloat = 24

    private func reveal(in scroll: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.1)) {
            scroll.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }

    private func seed() {
        if let draft = TodayPillPick.load() {
            selection = TodayPillSelection(restoring: draft)
            return
        }
        let pack = store.pack
        selection = TodayPillSelection(pack: pack.method == .pill ? PackChoice(pack.regimen) : PackChoice(preset: .twentyOneSeven))
    }
}

#Preview {
    TodayPillView(
        progress: ProtectionPlanProgressIndex.progress(for: .schedule),
        onBack: {},
        onContinue: { _ in }
    )
    .environment(PillStore.previewStore())
}
