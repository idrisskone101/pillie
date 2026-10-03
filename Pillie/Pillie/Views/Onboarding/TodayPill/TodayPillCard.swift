//
//  TodayPillCard.swift
//  Pillie
//

import SwiftUI

/// The pill pack the user taps to say which pill they are on today, then the
/// "taken yet?" question. Onboarding and the Settings schedule editor both host it.
struct TodayPillCard: View {
    @Binding var selection: TodayPillSelection
    let showsLoggedRow: Bool
    var onReveal: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isCascading = false
    @State private var revealTask: Task<Void, Never>?
    @State private var cascadeTicks = 0
    @State private var showsPackSheet = false

    private let feedback = OnboardingInteractionFeedback()

    private static let questionDelay: Duration = .milliseconds(600)
    private static let cascadeTickEvery = 3

    private var showsQuestion: Bool {
        selection.asksQuestion && !isCascading
    }

    private var dayOneWeekday: Int? {
        guard let dayIndex = selection.dayIndex else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: PillieClock.now)
        let dayOne = calendar.date(byAdding: .day, value: -dayIndex, to: today) ?? today
        return calendar.component(.weekday, from: dayOne)
    }

    private var tappedDay: PackDay? {
        selection.dayIndex.map { selection.packRegimen.day(atIndex: $0) }
    }

    private var marks: [Int: PackTileMark] {
        guard let dayIndex = selection.dayIndex, selection.answer == .taken else { return [:] }
        return [dayIndex: .taken]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PackCard(
                regimen: selection.packRegimen,
                dayOneWeekday: dayOneWeekday,
                todayIndex: selection.dayIndex,
                marks: marks,
                onSelectDay: tap
            ) {
                TodayPillPackHeader(pack: selection.pack) { showsPackSheet = true }
            }

            if showsQuestion, let tappedDay {
                TodayPillQuestion(
                    pillNumber: tappedDay.pillNumber ?? tappedDay.number,
                    answer: selection.answer,
                    showsLoggedRow: showsLoggedRow && (selection.pick?.logsADose ?? false),
                    onAnswer: record
                )
                .padding(.top, 22)
                .transition(.offset(y: 12).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.15), value: showsQuestion)
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: selection.answer)
        .onChange(of: showsQuestion) { onReveal() }
        .onChange(of: selection.answer) { onReveal() }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: cascadeTicks)
        .sheet(isPresented: $showsPackSheet) {
            PackTypeSheet(current: selection.pack, onPick: changePack)
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }

    private func tap(_ index: Int) {
        let previous = selection.dayIndex
        guard index != previous else { return }
        let wasShowing = showsQuestion
        selection.tap(index)
        feedback.selectChoice(accessibilityReduceMotion: reduceMotion)
        revealTask?.cancel()
        guard selection.asksQuestion, !wasShowing else {
            isCascading = false
            return
        }
        isCascading = true
        // Only the tapped pill's page cascades; the card pops earlier pages at once.
        let pageStart = index / PackCardLayout.daysPerPage * PackCardLayout.daysPerPage
        let popped = index - max(previous ?? 0, pageStart)
        let tickGap = PackPopSequence.stagger(pops: popped) * Self.cascadeTickEvery
        revealTask = Task { @MainActor in
            if !reduceMotion {
                for _ in stride(from: Self.cascadeTickEvery, through: popped, by: Self.cascadeTickEvery) {
                    try? await Task.sleep(for: tickGap)
                    guard !Task.isCancelled else { return }
                    cascadeTicks += 1
                }
                let elapsed = tickGap * max(0, popped / Self.cascadeTickEvery)
                if elapsed < Self.questionDelay {
                    try? await Task.sleep(for: Self.questionDelay - elapsed)
                }
            }
            guard !Task.isCancelled else { return }
            isCascading = false
        }
    }

    private func record(_ answer: TodayPillPick.Answer) {
        guard selection.answer != answer else { return }
        selection.record(answer)
        if answer == .taken { feedback.markDueActionTaken(accessibilityReduceMotion: reduceMotion) }
    }

    private func changePack(_ pack: PackChoice) {
        selection.changePack(pack)
        revealTask?.cancel()
        isCascading = false
    }
}

private struct TodayPillPackHeader: View {
    let pack: PackChoice
    let onChange: () -> Void

    // A glyph wider than five weeks would overflow the 44 pt box.
    private static let glyphMaxDays = 35

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if pack.regimen.totalDays <= Self.glyphMaxDays {
                    PackGlyph(regimen: pack.regimen)
                } else {
                    SlidersIcon()
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PillieTheme.coralLight))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(pack.displayName())
                    .font(.pillie(17, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(pack.scheduleSummary())
                    .font(.pillie(13, weight: .regular))
                    .foregroundStyle(PillieTheme.textMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(action: onChange) {
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
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityIdentifier("todayPillChangeButton")
        }
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
        TodayPillQuestionTemplate.split(template)
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
