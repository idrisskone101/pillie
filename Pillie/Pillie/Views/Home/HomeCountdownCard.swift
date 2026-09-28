//
//  HomeCountdownCard.swift
//  Pillie
//

import SwiftUI

/// Home's patch and ring card. Logging happens on Home's own button; the card follows the store.
struct HomeCountdownCard: View {
    let method: RoutineDialMethod
    /// A log made while Home is covered or in the background waits here, so the logged state lands in view.
    let holdsTodayLog: Bool

    @Environment(PillStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var heldTaken: Bool?
    @State private var showsNewCycleConfirmation = false
    private let homeFeedback = HomeActionInteractionFeedback()

    var body: some View {
        let _ = store.protocolChangeVersion
        let _ = store.dayRecordsRevision
        let _ = store.civilDay
        let today = store.today
        let cycleDay = store.pack.elapsedCycleDays(on: today) + 1
        let progress = HomeCountdownProgress(
            method: method,
            cycleDay: cycleDay,
            isTodayTaken: heldTaken ?? store.isTodayTaken,
            standing: store.doseStanding(on: today),
            missedTaskDays: missedTaskDays(before: cycleDay, today: today),
            reminderHour: store.reminderHour,
            reminderMinute: store.reminderMinute,
            today: today,
            now: PillieClock.now,
            calendar: .current
        )
        CountdownCard(
            progress: progress,
            reminderTime: SettingsPresentation.time(
                hour: store.reminderHour,
                minute: store.reminderMinute,
                locale: locale
            )
        ) {
            Menu {
                Button {
                    showsNewCycleConfirmation = true
                } label: {
                    Label(
                        PillieLocalization.string("today.pack.start_new.confirm", locale: locale),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
            } label: {
                CountdownMenuLabel()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PillieLocalization.string("home.countdown.options", locale: locale))
            .accessibilityIdentifier("homeCountdownOptions")
        }
        .onChange(of: holdsTodayLog || scenePhase != .active, initial: true) { _, holds in
            heldTaken = holds ? store.isTodayTaken : nil
        }
        .alert(startNewConfirmation.title, isPresented: $showsNewCycleConfirmation) {
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
    }

    /// Cycle days before today whose task the store reads as missed.
    private func missedTaskDays(before cycleDay: Int, today: Date) -> Set<Int> {
        let calendar = Calendar.current
        let taskDays = HomeCountdownProgress.taskDays(for: method).filter { $0 < cycleDay }
        return Set(taskDays.filter { day in
            guard let date = calendar.date(byAdding: .day, value: day - cycleDay, to: today) else { return false }
            return store.statusForDate(date) == .missed
        })
    }

    private var startNewConfirmation: CycleNounPresentation.StartNewConfirmation {
        CycleNounPresentation.startNewConfirmation(for: method.contraceptiveMethod, locale: locale)
    }
}
