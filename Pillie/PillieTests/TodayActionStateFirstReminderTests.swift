import Foundation
import Testing

@testable import Pillie

struct TodayActionStateFirstReminderTests {
    private let action = DoseScheduleAction(
        date: Date(timeIntervalSince1970: 1_779_840_000),
        type: .pillActive,
        method: .pill,
        cycleDay: 1,
        cycleLength: 28
    )

    private func input(
        isRefillDue: Bool = false,
        isTodayTaken: Bool = false,
        todayDueAction: DoseScheduleAction? = nil,
        isPlus: Bool = false,
        reduceMotionEnabled: Bool = false,
        catchUp: DoseScheduleAction? = nil,
        awaitsFirstReminder: Bool
    ) -> TodayActionState.Input {
        TodayActionState.Input(
            isRefillDue: isRefillDue,
            isTodayTaken: isTodayTaken,
            todayDueAction: todayDueAction,
            isPlus: isPlus,
            reduceMotionEnabled: reduceMotionEnabled,
            catchUp: catchUp,
            awaitsFirstReminder: awaitsFirstReminder
        )
    }

    @Test func aDueDoseBeforeTheFirstReminderIsOfferedQuietly() {
        let state = TodayActionState.resolve(input(todayDueAction: action, awaitsFirstReminder: true))
        #expect(state == .dueActionAwaitingFirstReminder(action, requiresShakeConfirm: false))
        #expect(state.localizedPrimaryLabel(locale: Locale(identifier: "en")) == "Took it")
    }

    @Test func plusKeepsTheShakeConfirmOnTheQuietButton() {
        let state = TodayActionState.resolve(
            input(todayDueAction: action, isPlus: true, awaitsFirstReminder: true)
        )
        #expect(state == .dueActionAwaitingFirstReminder(action, requiresShakeConfirm: true))
    }

    @Test func withoutTheHandoffTheDueActionKeepsTheTakeButton() {
        let state = TodayActionState.resolve(input(todayDueAction: action, awaitsFirstReminder: false))
        #expect(state == .dueAction(action, requiresShakeConfirm: false))
        #expect(state.localizedPrimaryLabel(locale: Locale(identifier: "en")) == "Take pill")
    }

    @Test func aLoggedDayAndARefillOutrankTheHandoff() {
        #expect(TodayActionState.resolve(
            input(isTodayTaken: true, todayDueAction: action, awaitsFirstReminder: true)
        ) == .completed)
        #expect(TodayActionState.resolve(
            input(isRefillDue: true, todayDueAction: action, awaitsFirstReminder: true)
        ) == .refillDue)
    }

    @Test func aCatchUpTaskIsNotSoftened() {
        let state = TodayActionState.resolve(input(catchUp: action, awaitsFirstReminder: true))
        #expect(state == .dueAction(action, requiresShakeConfirm: false))
    }

    @Test func nothingDueStaysNothingDue() {
        #expect(TodayActionState.resolve(input(awaitsFirstReminder: true)) == .noActionDue)
    }
}
