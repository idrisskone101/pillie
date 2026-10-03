//
//  TodayPillView.swift
//  Pillie
//

import SwiftUI

struct TodayPillView: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: (TodayPillPick) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Seeded before the first frame, so a saved pack never cross-fades in from 21/7.
    @State private var selection: TodayPillSelection
    @State private var appeared = false

    init(
        store: PillStore,
        progress: ProtectionPlanProgress,
        onBack: @escaping () -> Void,
        onContinue: @escaping (TodayPillPick) -> Void
    ) {
        self.progress = progress
        self.onBack = onBack
        self.onContinue = onContinue
        _selection = State(initialValue: Self.seed(store: store))
    }

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

    private static func seed(store: PillStore) -> TodayPillSelection {
        if let draft = TodayPillPick.load() {
            return TodayPillSelection(restoring: draft)
        }
        let pack = store.pack
        return TodayPillSelection(pack: pack.method == .pill ? PackChoice(pack.regimen) : PackChoice(preset: .twentyOneSeven))
    }
}

#Preview {
    TodayPillView(
        store: PillStore.previewStore(),
        progress: ProtectionPlanProgressIndex.progress(for: .schedule),
        onBack: {},
        onContinue: { _ in }
    )
}
