//
//  RoutineDialPickTests.swift
//  PillieTests
//

// Value types only, so the Xcode 27 beta @MainActor deinit crash cannot fire.

import XCTest

@testable import Pillie

@MainActor
final class RoutineDialPickTests: XCTestCase {
    private func defaults(_ name: String) throws -> UserDefaults {
        let suite = "RoutineDialPickTests.\(name)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testPatchTasksFallOnChangeDaysAndTheRemoveDay() {
        let tasks = (1...28).compactMap { day -> String? in
            RoutineDialDay.day(day, method: .patch).task.map { "\(day):\($0)" }
        }
        XCTAssertEqual(tasks, ["1:putOn", "8:putOn", "15:putOn", "22:takeOff"])
    }

    func testRingTasksFallOnInsertAndRemoveDays() {
        let tasks = (1...28).compactMap { day -> String? in
            RoutineDialDay.day(day, method: .ring).task.map { "\(day):\($0)" }
        }
        XCTAssertEqual(tasks, ["1:putOn", "22:takeOff"])
    }

    func testPatchNumbersCoverThreeWeeksThenTheOffWeekHasNone() {
        XCTAssertEqual(RoutineDialDay.day(1, method: .patch).patchNumber, 1)
        XCTAssertEqual(RoutineDialDay.day(7, method: .patch).patchNumber, 1)
        XCTAssertEqual(RoutineDialDay.day(8, method: .patch).patchNumber, 2)
        XCTAssertEqual(RoutineDialDay.day(21, method: .patch).patchNumber, 3)
        XCTAssertNil(RoutineDialDay.day(22, method: .patch).patchNumber)
        XCTAssertNil(RoutineDialDay.day(10, method: .ring).patchNumber)
    }

    func testTheFreeWeekStartsOnTheRemoveDay() {
        XCTAssertEqual(RoutineDialDay.day(21, method: .ring).phase, .wearing)
        XCTAssertEqual(RoutineDialDay.day(22, method: .ring).phase, .free)
        XCTAssertEqual(RoutineDialDay.day(28, method: .patch).phase, .free)
    }

    func testPickAsksForAnAnswerExactlyOnTaskDays() {
        XCTAssertNotNil(RoutineDialPick(method: .patch, cycleDay: 8, answer: .taken))
        XCTAssertNotNil(RoutineDialPick(method: .patch, cycleDay: 22, answer: .notYet))
        XCTAssertNotNil(RoutineDialPick(method: .patch, cycleDay: 3, answer: nil))
        XCTAssertNotNil(RoutineDialPick(method: .ring, cycleDay: 25, answer: nil))
        XCTAssertNil(RoutineDialPick(method: .patch, cycleDay: 8, answer: nil))
        XCTAssertNil(RoutineDialPick(method: .ring, cycleDay: 22, answer: nil))
        XCTAssertNil(RoutineDialPick(method: .patch, cycleDay: 3, answer: .taken))
        XCTAssertNil(RoutineDialPick(method: .ring, cycleDay: 8, answer: .notYet))
    }

    func testPickRefusesDaysOutsideTheCycle() {
        XCTAssertNil(RoutineDialPick(method: .ring, cycleDay: 0, answer: nil))
        XCTAssertNil(RoutineDialPick(method: .patch, cycleDay: 29, answer: nil))
    }

    func testOnlyATakenAnswerLogs() {
        XCTAssertEqual(RoutineDialPick(method: .ring, cycleDay: 1, answer: .taken)?.logsAnAction, true)
        XCTAssertEqual(RoutineDialPick(method: .ring, cycleDay: 1, answer: .notYet)?.logsAnAction, false)
        XCTAssertEqual(RoutineDialPick(method: .ring, cycleDay: 10, answer: nil)?.logsAnAction, false)
    }

    func testDraftRoundTripsThroughDefaultsAndClears() throws {
        let defaults = try defaults("draft")
        let pick = try XCTUnwrap(RoutineDialPick(method: .patch, cycleDay: 15, answer: .notYet))

        XCTAssertNil(RoutineDialPick.load(from: defaults))
        pick.save(to: defaults)
        XCTAssertEqual(RoutineDialPick.load(from: defaults), RoutineDialPick(method: .patch, cycleDay: 15, answer: .notYet))

        RoutineDialPick.clear(from: defaults)
        XCTAssertNil(RoutineDialPick.load(from: defaults))
    }

    func testDraftThatBreaksTheTaskRuleLoadsAsNil() throws {
        let defaults = try defaults("corrupt")
        defaults.set(Data(#"{"method":"ring","cycleDay":10,"answer":"taken"}"#.utf8), forKey: RoutineDialPick.storageKey)

        XCTAssertNil(RoutineDialPick.load(from: defaults))
    }

    func testOnboardingPickLoadsOnlyTheDraftForTheChosenMethod() throws {
        let defaults = try defaults("method")
        let pickedAt = InMemoryStoreFactory.localDate("2026-09-27", hour: 12, minute: 24)
        let dial = try XCTUnwrap(RoutineDialPick(method: .patch, cycleDay: 3, answer: nil))
        let pill = try XCTUnwrap(TodayPillPick(pack: PackChoice(preset: .twentyOneSeven), dayIndex: 4, answer: .taken))
        dial.save(to: defaults, at: pickedAt)
        pill.save(to: defaults, at: pickedAt)

        XCTAssertEqual(OnboardingTodayPick.load(method: .patch, from: defaults), .dial(OnboardingDraft(pick: dial, pickedAt: pickedAt)))
        XCTAssertNil(OnboardingTodayPick.load(method: .ring, from: defaults))
        XCTAssertEqual(OnboardingTodayPick.load(method: .pill, from: defaults), .pill(OnboardingDraft(pick: pill, pickedAt: pickedAt)))
    }

    func testPatchSegmentKeepsTheDialDayAndClearsTheAnswer() {
        var selection = RoutineDialSelection(method: .patch, cycleDay: 8)
        selection.record(.taken)
        XCTAssertEqual(selection.pick, RoutineDialPick(method: .patch, cycleDay: 8, answer: .taken))

        selection.selectSegment(3)
        XCTAssertEqual(selection.cycleDay, 22)
        XCTAssertEqual(selection.dialDay, 1)
        XCTAssertNil(selection.answer)
        XCTAssertNil(selection.pick, "the remove day waits for an answer")

        selection.selectDialDay(3)
        XCTAssertEqual(selection.cycleDay, 24)
        XCTAssertEqual(selection.pick, RoutineDialPick(method: .patch, cycleDay: 24, answer: nil))
    }

    func testRingDialDayIsTheCycleDayAndIgnoresAnswersOffTaskDays() {
        var selection = RoutineDialSelection(method: .ring, cycleDay: 10)
        selection.record(.taken)
        XCTAssertNil(selection.answer)
        XCTAssertEqual(selection.dialDay, 10)

        selection.selectDialDay(22)
        selection.record(.notYet)
        XCTAssertEqual(selection.pick, RoutineDialPick(method: .ring, cycleDay: 22, answer: .notYet))

        selection.selectSegment(1)
        XCTAssertEqual(selection.cycleDay, 22, "rings have no segments")
    }
}
