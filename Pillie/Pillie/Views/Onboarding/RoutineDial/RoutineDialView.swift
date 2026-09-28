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
    @State private var moves = 0
    @State private var appeared = false

    private let feedback = OnboardingInteractionFeedback()

    private var animationsEnabled: Bool {
        PerformanceTier.current == .standard && !reduceMotion
    }

    private var copy: RoutineDialCopy {
        RoutineDialCopy(selection: selection)
    }

    private var showsQuestion: Bool {
        selection.asksQuestion && !isScrubbing
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

                    card(copy)
                        .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger2)


                    Color.clear
                        .frame(height: Self.bottomGap)
                        .id(Self.bottomAnchor)
                }
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.15), value: showsQuestion)
                .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: selection.answer)
                .onChange(of: showsQuestion) { if showsQuestion { reveal(in: scroll) } }
                .onChange(of: selection.answer) { if selection.answer != nil { reveal(in: scroll) } }
            }
        }
        .sensoryFeedback(.selection, trigger: moves)
        .onAppear {
            seed()
            appeared = true
        }
    }

    private static let bottomAnchor = "routineDialBottom"
    private static let bottomGap: CGFloat = 16

    private func card(_ copy: RoutineDialCopy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if method == .patch {
                RoutineDialSegments(
                    titles: copy.segmentTitles,
                    selected: selection.patchSegment,
                    onSelect: selectSegment
                )
            }

            dial(copy)
                .frame(maxWidth: .infinity)

            if method == .ring {
                RoutineDialLegend()
            }

            ZStack {
                RoutineDialQuestion(
                    question: copy.sizingQuestion,
                    yesTitle: copy.yesTitle,
                    notYetTitle: copy.notYetTitle,
                    answer: nil,
                    status: .logged(copy.sizingStatus),
                    statusDot: .clear,
                    onAnswer: { _ in }
                )
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                if showsQuestion, let question = copy.question {
                    RoutineDialQuestion(
                        question: question,
                        yesTitle: copy.yesTitle,
                        notYetTitle: copy.notYetTitle,
                        answer: selection.answer,
                        status: copy.status,
                        statusDot: palette.accent,
                        onAnswer: record
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.offset(y: 12).combined(with: .opacity))
                } else if let row = copy.resultRow {
                    VStack(spacing: 14) {
                        RoutineDialResultRow(row: row, dot: palette.accent)
                        Text(copy.hint)
                            .font(.pillie(13, weight: .regular))
                            .foregroundStyle(PillieTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous)
                .strokeBorder(PillieTheme.textPrimary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: PillieTheme.textMuted.opacity(0.1), radius: 15, y: 10)
    }

    private func dial(_ copy: RoutineDialCopy) -> some View {
        let metrics: RoutineDialRing.Metrics = method == .patch ? .patch : .ring
        return ZStack(alignment: .top) {
            RoutineDialRing(
                metrics: metrics,
                segmentColors: palette.segments(count: selection.dialCount, position: selection.dialDay),
                position: selection.dialDay,
                knob: palette.knob(answer: selection.answer),
                animatesKnob: animationsEnabled,
                onSelect: selectDialDay,
                isScrubbing: $isScrubbing
            )
            .accessibilityElement()
            .accessibilityLabel(copy.accessibilityLabel)
            .accessibilityValue(copy.dayLabel)
            .accessibilityHint(copy.accessibilityHint)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: selectDialDay(selection.dialDay + 1)
                case .decrement: selectDialDay(selection.dialDay - 1)
                @unknown default: break
                }
            }
            .accessibilityIdentifier("routineDial")

            VStack(spacing: 4) {
                Image(method.contraceptiveMethod.iconImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: method == .patch ? 74 : 84, height: method == .patch ? 74 : 84)
                    .opacity(selection.day.phase == .free ? 0.4 : 1)
                    .accessibilityHidden(true)
                Text(copy.dayLabel)
                    .font(.pillie(30, weight: .extraBold))
                    .tracking(-0.9)
                    .foregroundStyle(PillieTheme.textPrimary)
                    .contentTransition(.numericText())
                Text(copy.centerSubtitle)
                    .font(.pillie(13, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: metrics.radius * 1.2)
            }
            .frame(width: metrics.radius * 2 - 40)
            .padding(.top, method == .patch ? 40 : 52)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("routineDialDayLabel")
        }
        .frame(width: metrics.size, height: metrics.size)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selection.cycleDay)
    }

    private var palette: RoutineDialPalette {
        RoutineDialPalette(method: method, phase: selection.day.phase)
    }

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

    private func selectSegment(_ segment: Int) {
        let before = selection.cycleDay
        selection.selectSegment(segment)
        if selection.cycleDay != before { moves += 1 }
    }

    private func selectDialDay(_ day: Int) {
        let before = selection.cycleDay
        selection.selectDialDay(day)
        if selection.cycleDay != before { moves += 1 }
    }

    private func record(_ answer: TodayPillPick.Answer) {
        guard selection.answer != answer else { return }
        selection.record(answer)
        if answer == .taken { feedback.markDueActionTaken(accessibilityReduceMotion: reduceMotion) }
    }
}

private struct RoutineDialPalette {
    let method: RoutineDialMethod
    let phase: RoutineDialDay.Phase

    static let patchEmpty = Color(hex: "EFEBE6")
    static let ringEmpty = Color(hex: "F6E3DC")
    static let ringOutEmpty = Color(hex: "DCE8DA")
    static let freeHalo = Color(hex: "C3D3C0")

    var methodColor: Color {
        method == .patch ? PillieTheme.patchChangeRose : PillieTheme.ringReinsertCoral
    }

    var accent: Color {
        phase == .free ? PillieTheme.verifiedGreen : methodColor
    }

    func segments(count: Int, position: Int) -> [Color] {
        (1...count).map { segment in
            let filled = segment <= position
            switch method {
            case .patch where phase == .free:
                return filled ? PillieTheme.verifiedGreen : PillieTheme.sage
            case .patch:
                return filled ? methodColor : Self.patchEmpty
            case .ring where segment <= RoutineDialDay.wearingDays:
                return filled ? methodColor : Self.ringEmpty
            case .ring:
                return filled ? PillieTheme.verifiedGreen : Self.ringOutEmpty
            }
        }
    }

    func knob(answer: TodayPillPick.Answer?) -> RoutineDialRing.Knob {
        if answer == .taken {
            return RoutineDialRing.Knob(halo: PillieTheme.verifiedGreen, dot: PillieTheme.verifiedGreen)
        }
        if phase == .free {
            return RoutineDialRing.Knob(halo: Self.freeHalo, dot: PillieTheme.verifiedGreen)
        }
        return RoutineDialRing.Knob(halo: PillieTheme.coral, dot: methodColor)
    }
}

private struct RoutineDialSegments: View {
    let titles: [String]
    let selected: Int
    let onSelect: (Int) -> Void

    private static let track = Color(hex: "F0EEEB")

    var body: some View {
        HStack(spacing: 4) {
            ForEach(titles.indices, id: \.self) { index in
                let isSelected = index == selected
                Button {
                    onSelect(index)
                } label: {
                    Text(titles[index])
                        .font(.pillie(14, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? PillieTheme.textPrimary : PillieTheme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("routineDialSegment.\(index + 1)")
            }
        }
        .padding(4)
        .background(Self.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.snappy(duration: 0.25), value: selected)
    }
}

private struct RoutineDialLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            item(PillieLocalization.string("onboarding.dial.ring.legend_in")) {
                RoundedRectangle(cornerRadius: 3).fill(PillieTheme.ringReinsertCoral)
            }
            item(PillieLocalization.string("onboarding.dial.ring.legend_out")) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(RoutineDialPalette.ringOutEmpty)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(PillieTheme.verifiedGreen, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func item(_ title: String, @ViewBuilder swatch: () -> some View) -> some View {
        HStack(spacing: 6) {
            swatch()
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(title)
                .font(.pillie(13, weight: .semibold))
                .foregroundStyle(PillieTheme.textMuted)
        }
    }
}

private struct RoutineDialResultRow: View {
    let row: RoutineDialCopy.ResultRow
    let dot: Color

    private static let surface = Color(hex: "FAF8F6")

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dot)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                ViewThatFits(in: .horizontal) {
                    title(row.title)
                    title(row.compactTitle)
                        .minimumScaleFactor(0.8)
                }
                Text(row.detail)
                    .font(.pillie(13, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Self.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("routineDialResult")
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.pillie(15, weight: .bold))
            .foregroundStyle(PillieTheme.textPrimary)
            .lineLimit(1)
    }
}

private struct RoutineDialQuestion: View {
    let question: String
    let yesTitle: String
    let notYetTitle: String
    let answer: TodayPillPick.Answer?
    let status: RoutineDialCopy.Status?
    let statusDot: Color
    let onAnswer: (TodayPillPick.Answer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question)
                .font(.pillie(18, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("routineDialQuestion")

            HStack(spacing: 10) {
                answerButton(.taken, title: yesTitle)
                    .accessibilityIdentifier("routineDialYes")
                answerButton(.notYet, title: notYetTitle)
                    .accessibilityIdentifier("routineDialNotYet")
            }

            if let status {
                statusLine(status)
                    .padding(.leading, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("routineDialStatus")
                    .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statusLine(_ status: RoutineDialCopy.Status) -> some View {
        HStack(spacing: 8) {
            switch status {
            case .logged(let text):
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(PillieTheme.verifiedGreen)
                    .frame(width: 14, height: 14)
                statusText(text)
            case .notYet(let text):
                Circle()
                    .fill(statusDot)
                    .frame(width: 8, height: 8)
                statusText(text)
            }
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.pillie(14, weight: .semibold))
            .foregroundStyle(PillieTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func answerButton(_ value: TodayPillPick.Answer, title: String) -> some View {
        let isSelected = answer == value
        let (fill, border): (Color, Color) = switch (isSelected, value) {
        case (true, .taken): (PillieTheme.sage, PillieTheme.verifiedGreen)
        case (true, .notYet): (PillieTheme.coralLight, PillieTheme.coral)
        case (false, _): (.white, Color.black.opacity(0.06))
        }
        return Button {
            onAnswer(value)
        } label: {
            Text(title)
                .font(.pillie(16, weight: .bold))
                .foregroundStyle(PillieTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(border, lineWidth: 1.5))
                .shadow(color: .black.opacity(isSelected ? 0 : 0.05), radius: 5, y: 5)
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
