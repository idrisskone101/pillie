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
    @State private var held: Held?
    @State private var showsNewCycleConfirmation = false
    private let homeFeedback = HomeActionInteractionFeedback()

    var body: some View {
        let _ = store.protocolChangeVersion
        let _ = store.dayRecordsRevision
        let _ = store.civilDay
        let today = store.today
        let cycleDay = store.pack.elapsedCycleDays(on: today) + 1
        let live = held ?? Held(taken: store.isTodayTaken, misses: misses(before: cycleDay, today: today))
        let progress = HomeCountdownProgress(
            method: method,
            cycleDay: cycleDay,
            isTodayTaken: live.taken,
            standing: store.doseStanding(on: today),
            misses: live.misses,
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
            let cycleDay = store.pack.elapsedCycleDays(on: store.today) + 1
            held = holds ? Held(taken: store.isTodayTaken, misses: misses(before: cycleDay, today: store.today)) : nil
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

    /// Tasks before today that the store reads as missed, and whether each was logged late.
    private func misses(before cycleDay: Int, today: Date) -> [Int: HomeCountdownProgress.Miss] {
        let calendar = Calendar.current
        var misses: [Int: HomeCountdownProgress.Miss] = [:]
        for day in HomeCountdownProgress.taskDays(for: method) where day < cycleDay {
            guard let date = calendar.date(byAdding: .day, value: day - cycleDay, to: today),
                  store.statusForDate(date) == .missed else { continue }
            misses[day] = store.caughtUpAt(on: date).map { .caughtUp(onLiveDay: store.isOnLiveDay($0)) } ?? .pending
        }
        return misses
    }

    private var startNewConfirmation: CycleNounPresentation.StartNewConfirmation {
        CycleNounPresentation.startNewConfirmation(for: method.contraceptiveMethod, locale: locale)
    }
}

/// What the card shows while a log waits behind the Shake cover or the background.
private struct Held: Equatable {
    let taken: Bool
    let misses: [Int: HomeCountdownProgress.Miss]
}
