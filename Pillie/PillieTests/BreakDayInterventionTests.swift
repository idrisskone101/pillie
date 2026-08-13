//
//  BreakDayInterventionTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class BreakDayInterventionTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testTwentySixTwoBreakDaysClearBlockingAndNextCycleResumes() throws {
        let cycleStart = InMemoryStoreFactory.fixedDate("2026-07-01")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: cycleStart,
            regimen: .twentySixTwo,
            startDate: cycleStart
        )
        let mirror = fixture.store.blockingScheduleMirror
        let day26 = try date(offset: 25, from: cycleStart)
        let day27 = try date(offset: 26, from: cycleStart)
        let day28 = try date(offset: 27, from: cycleStart)
        let nextCycleStart = try date(offset: 28, from: cycleStart)
        let staleHandledStamp = TodayTakenStamp(
            isTaken: true,
            epochDay: TodayTakenStamp.epochDay(for: day26)
        )

        XCTAssertTrue(mirror.requiresAction(on: day26))
        for breakDay in [day27, day28] {
            XCTAssertFalse(mirror.requiresAction(on: breakDay))
            XCTAssertEqual(
                BlockingInterventionPolicy.decision(
                    schedule: mirror,
                    handledStamp: staleHandledStamp,
                    now: breakDay
                ),
                .clearShields
            )
        }
        XCTAssertTrue(mirror.requiresAction(on: nextCycleStart))
        XCTAssertEqual(
            BlockingInterventionPolicy.decision(
                schedule: mirror,
                handledStamp: staleHandledStamp,
                now: nextCycleStart
            ),
            .applyShields
        )
    }

    func testReminderPlannerRejectsBreakCandidatesAtFinalBoundary() throws {
        let cycleStart = InMemoryStoreFactory.fixedDate("2026-07-01")
        let day27 = try date(offset: 26, from: cycleStart)
        let day28 = try date(offset: 27, from: cycleStart)
        let nextCycleStart = try date(offset: 28, from: cycleStart)
        let fixture = try InMemoryStoreFactory.makeStore(
            now: day27,
            regimen: .twentySixTwo,
            startDate: cycleStart
        )
        let pack = fixture.store.pack
        let candidates = try [day27, day28, nextCycleStart].map {
            try XCTUnwrap(DoseScheduleEngine.dueAction(on: $0, pack: pack))
        }

        let intents = ReminderSchedulePlanner().planReminders(
            ReminderSchedulePlanner.Input(
                now: day27,
                pack: pack,
                reminderHour: 8,
                reminderMinute: 0,
                autoReminderIntervalMinutes: 15,
                autoReminderRetryLimit: 3,
                refillReminderThresholdDays: fixture.store.refillReminderThresholdDays,
                patchRestockReminderThresholdPatches: fixture.store.patchRestockReminderThresholdPatches,
                candidateDueActions: candidates,
                statusByEpochDay: [:],
                snoozeOverride: ReminderSchedulePlanner.SnoozeOverride(
                    dueDayEpoch: epochDay(for: day27),
                    firstFireDate: day27.addingTimeInterval(10 * 60)
                ),
                smartRemindersEnabled: true,
                cycleTransitionEnabled: false,
                lastCallEnabled: true,
                lastCallHour: 21,
                lastCallMinute: 0,
                trialGrantDate: nil,
                hasEntitlement: false,
                calendar: .current
            )
        )
        let dueIntents = intents.compactMap { intent -> ReminderSchedulePlanner.DueReminderIntent? in
            if case .due(let due) = intent { return due }
            return nil
        }

        XCTAssertFalse(dueIntents.contains { $0.action.type.isBreakType })
        XCTAssertFalse(dueIntents.contains { $0.dueDayEpoch == epochDay(for: day27) })
        XCTAssertFalse(dueIntents.contains { $0.dueDayEpoch == epochDay(for: day28) })
        XCTAssertTrue(dueIntents.contains { $0.dueDayEpoch == epochDay(for: nextCycleStart) })
    }

    func testAppAndExtensionUseIdenticalBlockingPolicySource() throws {
        let projectDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = projectDirectory
            .appendingPathComponent("Pillie/Shared/BlockingScheduleMirror.swift")
        let monitorSource = projectDirectory
            .appendingPathComponent("PillieDeviceActivityMonitor/BlockingScheduleMirror.swift")

        XCTAssertEqual(try Data(contentsOf: appSource), try Data(contentsOf: monitorSource))
    }

    private func date(offset: Int, from date: Date) throws -> Date {
        try XCTUnwrap(Calendar.current.date(byAdding: .day, value: offset, to: date))
    }

    private func epochDay(for date: Date) -> Int {
        Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970)
    }
}
