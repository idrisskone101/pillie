//
//  RoutineDialView.swift
//  Pillie
//

import SwiftUI

struct RoutineDialView: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: (RoutineDialPick) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Seeded before the first frame. Seeding in onAppear rendered a patch dial first and
    // cross-faded it into the ring during the reveal.
    @State private var selection: RoutineDialSelection
    @State private var isScrubbing = false
    @State private var appeared = false

    init(
        method: RoutineDialMethod,
        store: PillStore,
        progress: ProtectionPlanProgress,
        onBack: @escaping () -> Void,
        onContinue: @escaping (RoutineDialPick) -> Void
    ) {
        self.progress = progress
        self.onBack = onBack
        self.onContinue = onContinue
        _selection = State(initialValue: Self.seed(method: method, store: store))
    }

    private var animationsEnabled: Bool {
        PerformanceTier.current == .standard && !reduceMotion
    }

    private var copy: RoutineDialCopy {
        RoutineDialCopy(selection: selection)
    }

    var body: some View {
        let copy = copy
        ProtectionPlanScaffold(
            progress: progress,
            onBack: onBack,
            primaryTitle: PillieLocalization.string("global.action.continue"),
            isPrimaryEnabled: selection.pick != nil && !isScrubbing,
            onPrimary: {
                guard let pick = selection.pick else { return }
                onContinue(pick)
            }
        ) {
            ScrollViewReader { scroll in
                VStack(alignment: .leading, spacing: 0) {
                    ProtectionPlanQuestionHeader(title: copy.title, subtitle: copy.subtitle)
                        .padding(.top, 4)
                        .padding(.bottom, 16)
                        .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger1)

                    RoutineDialCard(selection: $selection, isScrubbing: $isScrubbing, onReveal: { reveal(in: scroll) })
                        .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger2)

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

    private static let bottomAnchor = "routineDialBottom"
    private static let bottomGap: CGFloat = 16

    private func reveal(in scroll: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.1)) {
            scroll.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }

    private static func seed(method: RoutineDialMethod, store: PillStore) -> RoutineDialSelection {
        if let draft = RoutineDialPick.load(), draft.method == method {
            return RoutineDialSelection(restoring: draft)
        }
        let pack = store.pack
        let cycleDay = RoutineDialMethod(pack.method) == method ? pack.cycleDayIndex(on: store.today) + 1 : 1
        return RoutineDialSelection(method: method, cycleDay: cycleDay)
    }
}

#Preview("Patch") {
    RoutineDialView(
        method: .patch,
        store: PillStore.previewStore(),
        progress: ProtectionPlanProgressIndex.progress(for: .schedule),
        onBack: {},
        onContinue: { _ in }
    )
}

#Preview("Ring") {
    RoutineDialView(
        method: .ring,
        store: PillStore.previewStore(),
        progress: ProtectionPlanProgressIndex.progress(for: .schedule),
        onBack: {},
        onContinue: { _ in }
    )
}
