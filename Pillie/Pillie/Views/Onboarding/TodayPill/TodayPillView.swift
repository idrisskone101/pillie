import SwiftUI

struct TodayPillView: View {
    let progress: ProtectionPlanProgress
    let onBack: () -> Void
    let onContinue: (TodayPillPick) -> Void

    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Seeded in onAppear, not a custom init, so the SDK 27 @State macro stays well-behaved.
    @State private var selection = TodayPillSelection(regimen: .twentyOneSeven)
    @State private var showsQuestion = false
    @State private var revealTask: Task<Void, Never>?
    @State private var cascadeTicks = 0
    @State private var appeared = false

    private let feedback = OnboardingInteractionFeedback()

    private static let questionDelay: Duration = .milliseconds(600)

    private var animationsEnabled: Bool {
        PerformanceTier.current == .standard && !reduceMotion
    }

    private var dayOneWeekday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: PillieClock.now)
        let dayOne = calendar.date(byAdding: .day, value: -(selection.pillIndex ?? 0), to: today) ?? today
        return calendar.component(.weekday, from: dayOne)
    }

    private var tappedDay: PackDay? {
        selection.pillIndex.map { selection.packRegimen.day(atIndex: $0) }
    }

    private var marks: [Int: PackTileMark] {
        guard let pillIndex = selection.pillIndex, selection.answer == .taken else { return [:] }
        return [pillIndex: .taken]
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
            VStack(alignment: .leading, spacing: 0) {
                ProtectionPlanQuestionHeader(
                    title: PillieLocalization.string("onboarding.today_pill.title"),
                    subtitle: PillieLocalization.string("onboarding.today_pill.subtitle")
                )
                .padding(.top, 4)
                .padding(.bottom, 20)
                .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger1)

                PackCard(
                    regimen: selection.packRegimen,
                    dayOneWeekday: dayOneWeekday,
                    todayIndex: selection.pillIndex,
                    marks: marks,
                    onSelectDay: tap
                ) {
                    TodayPillPackHeader(regimen: selection.regimen, onChange: changeRegimen)
                }
                .planBuilderReveal(appeared, animationsEnabled, delay: PillieTheme.stagger2)

                if showsQuestion, let tappedDay {
                    TodayPillQuestion(
                        pillNumber: tappedDay.pillNumber ?? tappedDay.number,
                        answer: selection.answer,
                        showsLoggedRow: selection.answer == .taken && tappedDay.kind == .active,
                        onAnswer: record
                    )
                    .padding(.top, 22)
                    .transition(.offset(y: 12).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.15), value: showsQuestion)
            .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: selection.answer)
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: cascadeTicks)
        .onAppear {
            seed()
            appeared = true
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }

    private func seed() {
        if let draft = TodayPillPick.load() {
            selection = TodayPillSelection(restoring: draft)
            showsQuestion = selection.asksQuestion
            return
        }
        let pack = store.pack
        let storedRegimen = pack.method == .pill ? pack.pillRegimen : .twentyOneSeven
        selection = TodayPillSelection(regimen: storedRegimen == .custom ? .twentyOneSeven : storedRegimen)
    }

    private func tap(_ index: Int) {
        let previous = selection.pillIndex
        guard index != previous else { return }
        selection.tap(index)
        feedback.selectChoice(accessibilityReduceMotion: reduceMotion)
        revealTask?.cancel()
        guard selection.asksQuestion else {
            showsQuestion = false
            return
        }
        guard !showsQuestion else { return }
        let popped = index - (previous ?? 0)
        revealTask = Task { @MainActor in
            if !reduceMotion {
                for _ in stride(from: 3, through: popped, by: 3) {
                    try? await Task.sleep(for: PackPopSequence.popStagger * 3)
                    guard !Task.isCancelled else { return }
                    cascadeTicks += 1
                }
                let elapsed = PackPopSequence.popStagger * 3 * max(0, popped / 3)
                if elapsed < Self.questionDelay {
                    try? await Task.sleep(for: Self.questionDelay - elapsed)
                }
            }
            guard !Task.isCancelled else { return }
            showsQuestion = true
        }
    }

    private func record(_ answer: TodayPillPick.Answer) {
        guard selection.answer != answer else { return }
        selection.record(answer)
        if answer == .taken { feedback.markDueActionTaken(accessibilityReduceMotion: reduceMotion) }
    }

    private func changeRegimen(_ regimen: PillPack.PillRegimenPreset) {
        selection.changeRegimen(regimen)
        revealTask?.cancel()
        showsQuestion = selection.asksQuestion
    }
}

private struct TodayPillPackHeader: View {
    let regimen: PillPack.PillRegimenPreset
    let onChange: (PillPack.PillRegimenPreset) -> Void

    private static let presets = (RoutineRegimenCatalog.common + RoutineRegimenCatalog.more).filter { $0 != .custom }

    var body: some View {
        HStack(spacing: 12) {
            PackGlyph(regimen: regimen.resolvedRegimen(custom: nil))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(regimen.localizedRoutineDisplayName())
                    .font(.pillie(17, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(regimen.localizedScheduleSummary())
                    .font(.pillie(13, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Menu {
                ForEach(Self.presets, id: \.self) { preset in
                    Button {
                        onChange(preset)
                    } label: {
                        if preset == regimen {
                            Label(preset.localizedRoutineDisplayName(), systemImage: "checkmark")
                        } else {
                            Text(preset.localizedRoutineDisplayName())
                        }
                        Text(preset.localizedScheduleSummary())
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(PillieLocalization.string("onboarding.today_pill.change"))
                        .font(.pillie(13, weight: .bold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(PillieTheme.textPrimary)
                .padding(.leading, 14)
                .padding(.trailing, 12)
                .frame(height: 36)
                .background(Capsule().fill(PillieTheme.coralLight))
                .overlay(Capsule().strokeBorder(PillieTheme.coral, lineWidth: 1.5))
                .contentShape(Capsule())
            }
            .fixedSize()
            .accessibilityIdentifier("todayPillChangeButton")
        }
    }
}

private struct PackGlyph: View {
    let regimen: PackRegimen

    private static let dot: CGFloat = 3.6
    private static let gap: CGFloat = 1.4

    var body: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            ForEach(0..<regimen.weekCount, id: \.self) { week in
                HStack(spacing: Self.gap) {
                    ForEach(week * 7..<min(week * 7 + 7, regimen.totalDays), id: \.self) { index in
                        dot(regimen.day(atIndex: index).kind)
                    }
                }
            }
        }
        .frame(width: 44, height: 44)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PillieTheme.coralLight))
    }

    @ViewBuilder
    private func dot(_ kind: PackDay.Kind) -> some View {
        switch kind {
        case .active:
            Circle().fill(GlyphColor.active).frame(width: Self.dot, height: Self.dot)
        case .sugarPill:
            Circle().fill(GlyphColor.sugar).frame(width: Self.dot, height: Self.dot)
        case .noPill:
            Circle().strokeBorder(GlyphColor.sugar, lineWidth: 0.8).frame(width: Self.dot, height: Self.dot)
        }
    }

    private enum GlyphColor {
        static let active = Color(hex: "F4A6A0")
        static let sugar = Color(hex: "C3D3C0")
    }
}

private struct TodayPillQuestion: View {
    let pillNumber: Int
    let answer: TodayPillPick.Answer?
    let showsLoggedRow: Bool
    let onAnswer: (TodayPillPick.Answer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TodayPillQuestionLine(pillNumber: pillNumber)

            HStack(spacing: 10) {
                answerButton(.taken, title: PillieLocalization.string("onboarding.today_pill.yes"))
                    .accessibilityIdentifier("todayPillYes")
                answerButton(.notYet, title: PillieLocalization.string("onboarding.today_pill.not_yet"))
                    .accessibilityIdentifier("todayPillNotYet")
            }

            if showsLoggedRow {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PillieTheme.verifiedGreen)
                    Text(PillieLocalization.string("onboarding.today_pill.logged"))
                        .font(.pillie(15, weight: .semibold))
                        .foregroundStyle(PillieTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("todayPillLogged")
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func answerButton(_ value: TodayPillPick.Answer, title: String) -> some View {
        let isSelected = answer == value
        let fill: Color = isSelected && value == .taken ? PillieTheme.sage : .white
        let border: Color = switch (isSelected, value) {
        case (true, .taken): PillieTheme.verifiedGreen
        case (true, .notYet): PillieTheme.textPrimary
        case (false, _): Color.black.opacity(0.06)
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
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(border, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 5)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct TodayPillQuestionLine: View {
    let pillNumber: Int

    private var template: String {
        PillieLocalization.string("onboarding.today_pill.question")
    }

    private var parts: (prefix: String, prefixSpaced: Bool, suffix: String, suffixSpaced: Bool) {
        let pieces = template.components(separatedBy: "%@")
        guard pieces.count == 2 else { return (template, true, "", false) }
        return (
            pieces[0].trimmingCharacters(in: .whitespaces),
            pieces[0].last?.isWhitespace ?? false,
            pieces[1].trimmingCharacters(in: .whitespaces),
            pieces[1].first?.isWhitespace ?? false
        )
    }

    var body: some View {
        let parts = parts
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                if !parts.prefix.isEmpty {
                    Text(parts.prefix).padding(.trailing, parts.prefixSpaced ? 6 : 2)
                }
                chip
                if !parts.suffix.isEmpty {
                    Text(parts.suffix).padding(.leading, parts.suffixSpaced ? 6 : 2)
                }
            }
            .fixedSize()

            Text(fallback)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.pillie(18, weight: .bold))
        .foregroundStyle(PillieTheme.textPrimary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PillieLocalization.formatted("onboarding.today_pill.question", arguments: "\(pillNumber)"))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("todayPillQuestion")
    }

    private var chip: some View {
        PackNumberChip(number: pillNumber, size: .question)
            .animation(.snappy, value: pillNumber)
    }

    private var fallback: AttributedString {
        let parts = parts
        var number = AttributedString("\(pillNumber)")
        number.font = .pillie(18, weight: .black)
        return AttributedString(parts.prefix + (parts.prefixSpaced ? " " : ""))
            + number
            + AttributedString((parts.suffixSpaced ? " " : "") + parts.suffix)
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
