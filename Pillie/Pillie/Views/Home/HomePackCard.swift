//
//  HomePackCard.swift
//  Pillie
//

import SwiftUI

/// Home's pill pack. Logging today flips its mark, and PackCard pops the tile, wherever the log came from.
struct HomePackCard: View {
    /// A log made while Home is covered or in the background waits here, so its pop plays once Home is seen.
    let holdsTodayLog: Bool

    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsNewPackConfirmation = false
    @State private var showsPackSheet = false
    @State private var pickedPack: PackChoice?
    @State private var showsResetConfirmation = false
    @State private var heldTaken: Bool?
    @State private var correctionTarget: HistoryEditableDay?
    @State private var explainer: DoseWindowExplainer?
    private let homeFeedback = HomeActionInteractionFeedback()

    var body: some View {
        let _ = store.protocolChangeVersion
        let _ = store.dayRecordsRevision
        let _ = store.civilDay
        let pack = store.pack
        let today = store.today
        let elapsedDays = pack.elapsedCycleDays(on: today)
        let progress = HomePackProgress(
            regimen: pack.regimen,
            elapsedDays: elapsedDays,
            isTodayTaken: heldTaken ?? store.isTodayTaken,
            missedDays: missedDays(elapsedDays: elapsedDays, totalDays: pack.regimen.totalDays, today: today),
            lateUntil: lateUntil(today: today),
            today: today,
            now: PillieClock.now,
            calendar: .current
        )
        let lateExplainer: DoseWindowExplainer? = if case .late = progress.status {
            DoseWindowExplainer(
                subject: .pill(number: pack.regimen.day(atIndex: elapsedDays).number),
                day: today,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute,
                calendar: .current
            )
        } else {
            nil
        }
        PackCard(
            regimen: progress.regimen,
            dayOneWeekday: progress.dayOneWeekday,
            todayIndex: progress.todayIndex,
            marks: progress.marks,
            onSelectMissedDay: { index in
                correctionTarget = editableDay(atIndex: index, elapsedDays: elapsedDays, today: today)
            }
        ) {
            HomePackHeader(
                title: progress.title(locale: locale),
                subtitle: progress.subtitle(
                    reminderTime: SettingsPresentation.time(
                        hour: store.reminderHour,
                        minute: store.reminderMinute,
                        locale: locale
                    ),
                    locale: locale
                ),
                subtitleColor: subtitleColor(for: progress.status),
                onExplainLate: lateExplainer.map { built in { explainer = built } },
                onChangeType: { showsPackSheet = true },
                onStartNew: { showsNewPackConfirmation = true }
            )
        }
        .sheet(isPresented: $showsPackSheet, onDismiss: {
            showsResetConfirmation = pickedPack != nil
        }) {
            PackTypeSheet(current: PackChoice(pack.regimen)) { pickedPack = $0 }
        }
        .sheet(item: $explainer) { DoseWindowExplainerSheet(explainer: $0) }
        .sheet(item: $correctionTarget) { target in
            HistoryDayCorrectionSheet(day: target) { outcome in
                guard store.correctPastDay(on: target.date, to: outcome) else { return }
                InteractionFeedback.live.perform(.meaningfulCommit)
            }
        }
        .onChange(of: holdsTodayLog || scenePhase != .active, initial: true) { _, holds in
            heldTaken = holds ? store.isTodayTaken : nil
        }
        .alert(startNewConfirmation.title, isPresented: $showsNewPackConfirmation) {
            Button(PillieLocalization.string("today.pack.start_new.confirm", locale: locale)) {
                let feedbackResponse = homeFeedback.commitNewPackOrCycle(
                    accessibilityReduceMotion: accessibilityReduceMotion
                )
                withAnimation(feedbackResponse.motionProfile.animation) {
                    store.startNewPack()
                }
            }
            Button(PillieLocalization.string("global.action.cancel", locale: locale), role: .cancel) {}
        } message: {
            Text(startNewConfirmation.body)
        }
        .alert(resetConfirmation.title, isPresented: $showsResetConfirmation) {
            Button(resetConfirmation.cancelTitle, role: .cancel) { pickedPack = nil }
            Button(resetConfirmation.confirmTitle, role: .destructive) { startOver() }
        } message: {
            Text(resetConfirmation.body)
        }
    }

    private func lateUntil(today: Date) -> Date? {
        guard case .late(let until)? = store.doseStanding(on: today) else { return nil }
        return until
    }

    private func date(ofIndex index: Int, elapsedDays: Int, today: Date) -> Date? {
        Calendar.current.date(byAdding: .day, value: index - elapsedDays, to: today)
    }

    private func missedDays(elapsedDays: Int, totalDays: Int, today: Date) -> Set<Int> {
        let pastDays = min(elapsedDays, totalDays)
        guard pastDays > 0, var day = date(ofIndex: 0, elapsedDays: elapsedDays, today: today) else { return [] }
        var missed: Set<Int> = []
        for index in 0..<pastDays {
            if store.statusForDate(day) == .missed { missed.insert(index) }
            day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return missed
    }

    private func editableDay(atIndex index: Int, elapsedDays: Int, today: Date) -> HistoryEditableDay? {
        guard let day = date(ofIndex: index, elapsedDays: elapsedDays, today: today),
              let snapshot = store.scheduleSnapshot(for: day) else { return nil }
        return HistoryEditableDay(snapshot: snapshot, relation: .past)
    }

    private func subtitleColor(for status: HomePackProgress.Status) -> Color {
        switch status {
        case .taken: PillieTheme.verifiedGreen
        case .late, .missedYesterday: PillieTheme.amberText
        default: PillieTheme.textMuted
        }
    }

    /// The same reset Settings runs when the schedule changes: history clears and the new pack starts at pill 1 today.
    private var resetConfirmation: ScheduleCriticalSettingChange.Confirmation {
        ScheduleCriticalSettingChange.confirmation(cycleDay: 1, locale: locale)
    }

    private func startOver() {
        guard let choice = pickedPack else { return }
        pickedPack = nil
        let feedbackResponse = homeFeedback.commitNewPackOrCycle(
            accessibilityReduceMotion: accessibilityReduceMotion
        )
        withAnimation(feedbackResponse.motionProfile.animation) {
            store.resetAndStartFresh(
                method: .pill,
                regimen: choice.preset,
                customRegimen: choice.preset == .custom ? choice.regimen : nil,
                cycleDay: 1,
                anchorDay: store.anchorDay(for: nil)
            )
        }
        ProductAnalyticsTelemetry.live.protocolChangeSaved()
        StreakChangeReport.record(store, reason: .packChange)
    }

    private var startNewConfirmation: CycleNounPresentation.StartNewConfirmation {
        CycleNounPresentation.startNewConfirmation(for: store.pack.method, locale: locale)
    }
}

private struct HomePackHeader: View {
    let title: String
    let subtitle: String
    let subtitleColor: Color
    let onExplainLate: (() -> Void)?
    let onChangeType: () -> Void
    let onStartNew: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.pillie(17, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.pillie(13))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    if let onExplainLate {
                        LateInfoButton(id: "homePackLateInfo", action: onExplainLate)
                    }
                }
            }
            .contentTransition(.opacity)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)

            Menu {
                Button(action: onChangeType) {
                    Label(
                        PillieLocalization.string("home.pack.change_type", locale: locale),
                        systemImage: "pills"
                    )
                }
                .accessibilityIdentifier("homePackChangeType")
                Button(action: onStartNew) {
                    Label(
                        PillieLocalization.string("today.pack.start_new.confirm", locale: locale),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PillieTheme.textMuted)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Self.menuFill))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PillieLocalization.string("home.pack.options", locale: locale))
            .accessibilityIdentifier("homePackOptions")
        }
    }

    private static let menuFill = Color(hex: "F5F5F4")
}

#Preview {
    HomePackCard(holdsTodayLog: false)
        .padding()
        .background(PillieTheme.bg)
        .environment(PillStore.previewStore())
}
