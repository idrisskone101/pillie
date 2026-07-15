//
//  PersonalizationOnboardingTests.swift
//  PillieTests
//

import XCTest

@testable import Pillie

@MainActor
final class PersonalizationOnboardingTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testCombinedIntentScreenCoversEverySelectionAndRestoresCommittedAnswer() {
        for distraction in DistractionChoice.allCases {
            for outcome in DelayConsequence.allCases {
                var selection = ProtectionPlanIntentSelection()
                selection.toggle(distraction)
                selection.selectOutcome(outcome)

                XCTAssertTrue(selection.canContinue)
                XCTAssertEqual(selection.distractionChoices, [distraction])
                XCTAssertEqual(selection.desiredOutcome, outcome)

                let restored = ProtectionPlanIntentSelection(
                    distractionChoices: selection.distractionChoices,
                    desiredOutcome: selection.desiredOutcome
                )
                XCTAssertEqual(restored, selection)
            }
        }
    }

    func testCombinedTimingScreenCoversEverySelectionAndRestoresCommittedAnswer() {
        for frequency in MissFrequency.allCases {
            for riskWindow in RiskWindow.allCases {
                var selection = ProtectionPlanTimingSelection()
                selection.selectFrequency(frequency)
                selection.selectRiskWindow(riskWindow)

                XCTAssertTrue(selection.canContinue)
                XCTAssertEqual(selection.missFrequency, frequency)
                XCTAssertEqual(selection.riskWindow, riskWindow)

                let restored = ProtectionPlanTimingSelection(
                    missFrequency: selection.missFrequency,
                    riskWindow: selection.riskWindow
                )
                XCTAssertEqual(restored, selection)
            }
        }
    }

    func testAcquisitionSourcePersistsAsCoarseLocalValue() throws {
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.fixedDate("2026-06-03")
        )

        fixture.store.acquisitionSource = .appStoreSearch

        let reloadedStore = PillStore(modelContext: fixture.context)
        XCTAssertEqual(reloadedStore.acquisitionSource, .appStoreSearch)
    }

    func testRealSetupPreservesPillPatchAndRingScheduleBehavior() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-06-03")

        let pillFixture = try InMemoryStoreFactory.makeStore(now: today)
        pillFixture.store.startNewProtocol(
            method: .pill,
            regimen: .twentyFourFour,
            customActiveDays: nil,
            customBreakDays: nil,
            cycleDay: 12,
            preserveHistory: false
        )
        let pillAction = try XCTUnwrap(DoseScheduleEngine.dueAction(on: today, pack: pillFixture.store.pack))
        XCTAssertEqual(pillAction.method, .pill)
        XCTAssertEqual(pillAction.type, .pillActive)
        XCTAssertEqual(pillAction.cycleDay, 12)
        XCTAssertEqual(pillFixture.store.pack.pillRegimen, .twentyFourFour)

        let patchFixture = try InMemoryStoreFactory.makeStore(now: today)
        patchFixture.store.startNewProtocol(
            method: .patch,
            regimen: .twentyOneSeven,
            customActiveDays: nil,
            customBreakDays: nil,
            cycleDay: 8,
            preserveHistory: false
        )
        let patchAction = try XCTUnwrap(DoseScheduleEngine.dueAction(on: today, pack: patchFixture.store.pack))
        XCTAssertEqual(patchAction.method, .patch)
        XCTAssertEqual(patchAction.type, .patchChange)
        XCTAssertEqual(patchAction.cycleDay, 8)
        XCTAssertNil(patchFixture.store.pack.customActiveDays)
        XCTAssertNil(patchFixture.store.pack.customBreakDays)

        let ringFixture = try InMemoryStoreFactory.makeStore(now: today)
        ringFixture.store.startNewProtocol(
            method: .ring,
            regimen: .twentyOneSeven,
            customActiveDays: nil,
            customBreakDays: nil,
            cycleDay: 22,
            preserveHistory: false
        )
        let ringAction = try XCTUnwrap(DoseScheduleEngine.dueAction(on: today, pack: ringFixture.store.pack))
        XCTAssertEqual(ringAction.method, .ring)
        XCTAssertEqual(ringAction.type, .ringRemove)
        XCTAssertEqual(ringAction.cycleDay, 22)
        XCTAssertNil(ringFixture.store.pack.customActiveDays)
        XCTAssertNil(ringFixture.store.pack.customBreakDays)
    }

    func testMidCycleOnboardingBackfillKeepsStreakAtZeroUntilUserLogsDueAction() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-06-03")
        let fixture = try InMemoryStoreFactory.makeStore(now: today)
        let store = fixture.store

        store.startNewProtocol(
            method: .pill,
            regimen: .twentyFourFour,
            customActiveDays: nil,
            customBreakDays: nil,
            cycleDay: 12,
            preserveHistory: false
        )

        let action = try XCTUnwrap(DoseScheduleEngine.dueAction(on: today, pack: store.pack))
        XCTAssertEqual(action.cycleDay, 12)

        let startDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -11, to: today))
        XCTAssertEqual(store.scheduleSnapshot(for: startDate)?.status, .taken)
        XCTAssertEqual(store.currentStreak, 0)
        XCTAssertEqual(store.streakResetDate, PillieClock.today)

        store.markActionAsTaken(on: today)

        XCTAssertEqual(store.currentStreak, 1)
    }

    func testReminderPlanSummaryReflectsStoredSetupWithNeutralSupportCopy() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-06-03")
        let fixture = try InMemoryStoreFactory.makeStore(now: today)
        fixture.store.personalGoal = .stayProtected
        fixture.store.missFrequency = .sometimes
        fixture.store.reminderHour = 21
        fixture.store.reminderMinute = 30
        fixture.store.startNewProtocol(
            method: .pill,
            regimen: .twentyFourFour,
            customActiveDays: nil,
            customBreakDays: nil,
            cycleDay: 12,
            preserveHistory: false
        )

        let summary = ReminderPlanSummary(store: fixture.store)

        XCTAssertEqual(summary.methodValue, "The Pill")
        XCTAssertEqual(summary.methodDetail, "24 active / 4 break days")
        XCTAssertEqual(summary.cyclePositionValue, "Day 12 of 28")
        XCTAssertEqual(summary.cyclePositionDetail, "Current routine position")
        XCTAssertEqual(summary.reminderTimeValue, "Daily at 9:30 PM")
        XCTAssertEqual(summary.reminderTimeDetail, "Evening consistency anchor")
        XCTAssertEqual(summary.supportFocusTitle, "Routine reinforcement")
        XCTAssertEqual(summary.supportFocusValue, "Weekly check-ins for steadier follow-through")

        let visibleCopy = summary.visibleCopy.joined(separator: " ").lowercased()
        XCTAssertFalse(visibleCopy.contains("health plan"))
        XCTAssertFalse(visibleCopy.contains("protection"))
        XCTAssertFalse(visibleCopy.contains("hormone"))
        XCTAssertFalse(visibleCopy.contains("medical"))
        XCTAssertFalse(visibleCopy.contains("risk"))
    }
}
