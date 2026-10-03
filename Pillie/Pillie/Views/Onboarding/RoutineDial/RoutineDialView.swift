//
//  RoutineDialView.swift
//  Pillie
//

import SwiftUI

struct RoutineDialView: View {
    let method: RoutineDialMethod
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: (RoutineDialPick) -> Void

    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Seeded in onAppear, not a custom init, so the SDK 27 @State macro stays well-behaved.
    @State private var selection = RoutineDialSelection(method: .patch)
    @State private var isScrubbing = false
    @State private var appeared = false

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
            seed()
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

    private func seed() {
        if let draft = RoutineDialPick.load(), draft.method == method {
            selection = RoutineDialSelection(restoring: draft)
            return
        }
        let pack = store.pack
        let cycleDay = RoutineDialMethod(pack.method) == method ? pack.cycleDayIndex(on: store.today) + 1 : 1
        selection = RoutineDialSelection(method: method, cycleDay: cycleDay)
    }
}

#Preview("Patch") {
    RoutineDialView(
        method: .patch,
        progress: ProtectionPlanProgressIndex.progress(for: .schedule),
        onBack: {},
        onContinue: { _ in }
    )
    .environment(PillStore.previewStore())
}

#Preview("Ring") {
    RoutineDialView(
        method: .ring,
        progress: ProtectionPlanProgressIndex.progress(for: .schedule),
        onBack: {},
        onContinue: { _ in }
    )
    .environment(PillStore.previewStore())
}
