//
//  TodayActionStateTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class TodayActionStateTests: XCTestCase {
    func testRefillDueTakesPriorityOverOtherTodayActionStates() {
        XCTAssertEqual(
            TodayActionState.resolve(
                input(
                    isRefillDue: true,
                    isTodayTaken: true,
                    todayDueAction: dueAction(),
                    isPlus: true,
                    reduceMotionEnabled: false
                )
            ),
            .refillDue
        )
    }

    func testCompletedStateComesBeforeDueAction() {
        XCTAssertEqual(
            TodayActionState.resolve(
                input(isTodayTaken: true, todayDueAction: dueAction())
            ),
            .completed
        )
    }

    func testNoActionDueWhenThereIsNoDueAction() {
        XCTAssertEqual(
            TodayActionState.resolve(input(todayDueAction: nil)),
            .noActionDue
        )
    }

    func testPlusUserGetsShakeConfirmWhenReduceMotionIsOff() {
        XCTAssertEqual(
            TodayActionState.resolve(
                input(
                    todayDueAction: dueAction(),
                    isPlus: true,
                    reduceMotionEnabled: false
                )
            ),
            .dueAction(dueAction(), requiresShakeConfirm: true)
        )
    }

    func testFreeOrReduceMotionUserCompletesDirectly() {
        XCTAssertEqual(
            TodayActionState.resolve(
                input(
                    todayDueAction: dueAction(),
                    isPlus: false,
                    reduceMotionEnabled: false
                )
            ),
            .dueAction(dueAction(), requiresShakeConfirm: false)
        )
        XCTAssertEqual(
            TodayActionState.resolve(
                input(
                    todayDueAction: dueAction(),
                    isPlus: true,
                    reduceMotionEnabled: true
                )
            ),
            .dueAction(dueAction(), requiresShakeConfirm: false)
        )
    }

    private func input(
        isRefillDue: Bool = false,
        isTodayTaken: Bool = false,
        todayDueAction: DoseScheduleAction? = nil,
        isPlus: Bool = false,
        reduceMotionEnabled: Bool = false
    ) -> TodayActionState.Input {
        TodayActionState.Input(
            isRefillDue: isRefillDue,
            isTodayTaken: isTodayTaken,
            todayDueAction: todayDueAction,
            isPlus: isPlus,
            reduceMotionEnabled: reduceMotionEnabled
        )
    }

    private func dueAction() -> DoseScheduleAction {
        DoseScheduleAction(
            date: Date(timeIntervalSince1970: 1_779_840_000),
            type: .pillActive,
            method: .pill,
            cycleDay: 1,
            cycleLength: 28
        )
    }
}
