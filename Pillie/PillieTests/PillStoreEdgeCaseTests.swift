//
//  PillStoreEdgeCaseTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

@MainActor
final class PillStoreEdgeCaseTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testConsecutiveDueActionsBuildStreakOverMultipleDays() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let startDate = InMemoryStoreFactory.fixedDate("2026-05-24")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: startDate)
        let store = fixture.store

        store.markActionAsTaken(on: InMemoryStoreFactory.fixedDate("2026-05-24"))
        store.markActionAsTaken(on: InMemoryStoreFactory.fixedDate("2026-05-25"))
        XCTAssertEqual(store.currentStreak, 2)

        store.markActionAsTaken(on: today)
        XCTAssertEqual(store.currentStreak, 3)
    }

    func testScheduledBreakWeekPreservesStreak() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-28")
        let startDate = InMemoryStoreFactory.fixedDate("2026-05-01")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: today,
            regimen: .twentyOneSeven,
            startDate: startDate
        )
        let store = fixture.store

        store.markActionAsTaken(on: InMemoryStoreFactory.fixedDate("2026-05-19"))
        store.markActionAsTaken(on: InMemoryStoreFactory.fixedDate("2026-05-20"))
        store.markActionAsTaken(on: InMemoryStoreFactory.fixedDate("2026-05-21"))

        XCTAssertEqual(store.scheduleSnapshot(for: today)?.status, .breakDay)
        XCTAssertEqual(store.currentStreak, 3)
    }

    func testCycleDayAdjustmentBackfillDoesNotInflateStreak() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let fixture = try InMemoryStoreFactory.makeStore(now: today)
        let store = fixture.store

        store.updateCycleDay(21)

        let startDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -20, to: today))
        XCTAssertEqual(store.scheduleSnapshot(for: startDate)?.status, .taken)
        XCTAssertEqual(store.currentStreak, 0)
        XCTAssertEqual(store.streakResetDate, PillieClock.today)

        store.markActionAsTaken(on: today)

        XCTAssertEqual(store.currentStreak, 1)
    }

    func testCycleDayAdjustmentKeepsPriorBreakDaysNeutral() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-27")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: today,
            regimen: .twentyOneSeven
        )
        let store = fixture.store

        store.updateCycleDay(27)

        let finalActiveDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -6, to: today))
        XCTAssertEqual(store.scheduleSnapshot(for: finalActiveDay)?.actionType, .pillActive)
        XCTAssertEqual(store.scheduleSnapshot(for: finalActiveDay)?.status, .taken)

        for offset in -5 ... -1 {
            let breakDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: offset, to: today))
            let snapshot = try XCTUnwrap(store.scheduleSnapshot(for: breakDay))
            XCTAssertEqual(snapshot.actionType, .pillBreak)
            XCTAssertEqual(snapshot.status, .breakDay, "Past cycle day \(27 + offset) must stay neutral.")
        }

        let persistedBreakRecords = try fixture.context.fetch(FetchDescriptor<PillDay>())
            .filter { $0.actionType == .pillBreak }
        XCTAssertEqual(persistedBreakRecords.count, 5)
        XCTAssertTrue(persistedBreakRecords.allSatisfy { $0.status == .breakDay })

        XCTAssertEqual(store.scheduleSnapshot(for: today)?.status, .breakDay)
    }

    func testCycleDayAdjustmentKeepsPatchOffWeekNeutral() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-28")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, method: .patch)

        fixture.store.updateCycleDay(28)

        let removalDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -6, to: today))
        let removalSnapshot = try XCTUnwrap(fixture.store.scheduleSnapshot(for: removalDay))
        XCTAssertEqual(removalSnapshot.actionType, .patchRemove)
        XCTAssertEqual(removalSnapshot.status, .taken)

        let records = try fixture.context.fetch(FetchDescriptor<PillDay>())
        let breakRecords = records.filter { $0.actionType == .patchBreak }
        XCTAssertEqual(breakRecords.count, 5)
        XCTAssertTrue(breakRecords.allSatisfy { $0.status == .breakDay })
        XCTAssertEqual(fixture.store.scheduleSnapshot(for: today)?.actionType, .patchBreak)
        XCTAssertEqual(fixture.store.scheduleSnapshot(for: today)?.status, .breakDay)
    }

    func testCycleDayAdjustmentKeepsPinnedRingOffWeekNeutral() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-28")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: today,
            method: .ring,
            ringInsertionDate: today
        )

        fixture.store.updateCycleDay(28)

        let removalDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -6, to: today))
        let removalSnapshot = try XCTUnwrap(fixture.store.scheduleSnapshot(for: removalDay))
        XCTAssertEqual(removalSnapshot.actionType, .ringRemove)
        XCTAssertEqual(removalSnapshot.status, .taken)

        let records = try fixture.context.fetch(FetchDescriptor<PillDay>())
        let breakRecords = records.filter { $0.actionType == .ringBreak }
        XCTAssertEqual(breakRecords.count, 5)
        XCTAssertTrue(breakRecords.allSatisfy { $0.status == .breakDay })
        XCTAssertEqual(fixture.store.scheduleSnapshot(for: today)?.actionType, .ringBreak)
        XCTAssertEqual(fixture.store.scheduleSnapshot(for: today)?.status, .breakDay)
    }

    func testPersistedTakenBreakRecordIsRepairedOnReload() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-27")
        let cycleStart = InMemoryStoreFactory.fixedDate("2026-05-01")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: today,
            regimen: .twentyOneSeven,
            startDate: cycleStart
        )
        let priorBreakDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: today))
        fixture.context.insert(PillDay(
            date: priorBreakDay,
            status: .taken,
            actionType: .pillBreak,
            pack: fixture.pack
        ))
        try fixture.context.save()

        _ = PillStore(modelContext: fixture.context)
        let repairedRecord = try XCTUnwrap(
            fixture.context.fetch(FetchDescriptor<PillDay>()).first
        )

        XCTAssertEqual(repairedRecord.status, .breakDay)
    }

    func testTakenBreakRecordResolvesAsBreakDayAtReadBoundary() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-27")
        let cycleStart = InMemoryStoreFactory.fixedDate("2026-05-01")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: today,
            regimen: .twentyOneSeven,
            startDate: cycleStart
        )
        let priorBreakDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: today))
        fixture.context.insert(PillDay(
            date: priorBreakDay,
            status: .taken,
            actionType: .pillBreak,
            pack: fixture.pack
        ))
        try fixture.context.save()

        let reloadedStore = PillStore(modelContext: fixture.context)
        let indexedRecord = try XCTUnwrap(
            fixture.context.fetch(FetchDescriptor<PillDay>()).first
        )
        // Simulate an invalid row arriving after initialization so the one-time
        // migration cannot hide a regression in live snapshot canonicalization.
        indexedRecord.status = .taken

        let snapshot = try XCTUnwrap(reloadedStore.scheduleSnapshot(for: priorBreakDay))
        XCTAssertEqual(snapshot.actionType, .pillBreak)
        XCTAssertEqual(snapshot.status, .breakDay)
    }

    func testBlockingScheduleMirrorUsesRealRegimenActionDays() throws {
        let cycleStart = InMemoryStoreFactory.fixedDate("2026-07-01")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: cycleStart,
            regimen: .twentySixTwo,
            startDate: cycleStart
        )
        let mirror = fixture.store.blockingScheduleMirror
        let day26 = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 25, to: cycleStart))
        let day27 = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 26, to: cycleStart))
        let day28 = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 27, to: cycleStart))
        let nextCycleStart = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 28, to: cycleStart))

        XCTAssertTrue(mirror.requiresAction(on: day26))
        XCTAssertFalse(mirror.requiresAction(on: day27))
        XCTAssertFalse(mirror.requiresAction(on: day28))
        XCTAssertTrue(mirror.requiresAction(on: nextCycleStart))
    }

    func testStoreMirrorStaysAlignedWithPackAfterDSTTimezoneChange() throws {
        var torontoCalendar = Calendar(identifier: .gregorian)
        torontoCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Toronto"))
        var limaCalendar = Calendar(identifier: .gregorian)
        limaCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Lima"))
        let cycleStart = try XCTUnwrap(torontoCalendar.date(from: DateComponents(
            calendar: torontoCalendar,
            timeZone: torontoCalendar.timeZone,
            year: 2026,
            month: 3,
            day: 1,
            hour: 0
        )))
        let mirrorWriteDate = try XCTUnwrap(torontoCalendar.date(from: DateComponents(
            calendar: torontoCalendar,
            timeZone: torontoCalendar.timeZone,
            year: 2026,
            month: 3,
            day: 15,
            hour: 12
        )))
        let targetDate = try XCTUnwrap(limaCalendar.date(from: DateComponents(
            calendar: limaCalendar,
            timeZone: limaCalendar.timeZone,
            year: 2026,
            month: 3,
            day: 21,
            hour: 12
        )))
        let fixture = try InMemoryStoreFactory.makeStore(
            now: mirrorWriteDate,
            regimen: .twentyOneSeven,
            startDate: cycleStart
        )
        let mirror = fixture.store.blockingScheduleMirror
        let packCycleDayIndex = fixture.pack.cycleDayIndex(
            on: targetDate,
            calendar: limaCalendar
        )
        let action = try XCTUnwrap(DoseScheduleEngine.dueAction(
            on: targetDate,
            pack: fixture.pack,
            calendar: limaCalendar
        ))

        XCTAssertEqual(packCycleDayIndex, 20)
        XCTAssertTrue(action.type.requiresUserAction)
        XCTAssertEqual(
            mirror.requiresAction(on: targetDate, calendar: limaCalendar),
            action.type.requiresUserAction
        )
    }

    func testBlockingScheduleMirrorMatchesPatchActionAndPassiveDays() throws {
        let cycleStart = InMemoryStoreFactory.fixedDate("2026-07-01")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: cycleStart,
            method: .patch,
            startDate: cycleStart
        )
        let mirror = fixture.store.blockingScheduleMirror
        let passiveDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: cycleStart))
        let patchChangeDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 7, to: cycleStart))
        let removalDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 21, to: cycleStart))
        let breakDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 22, to: cycleStart))

        XCTAssertTrue(mirror.requiresAction(on: cycleStart))
        XCTAssertFalse(mirror.requiresAction(on: passiveDay))
        XCTAssertTrue(mirror.requiresAction(on: patchChangeDay))
        XCTAssertTrue(mirror.requiresAction(on: removalDay))
        XCTAssertFalse(mirror.requiresAction(on: breakDay))
    }

    func testBlockingScheduleMirrorMatchesPinnedRingActionAndPassiveDays() throws {
        let cycleStart = InMemoryStoreFactory.fixedDate("2026-07-01")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: cycleStart,
            method: .ring,
            startDate: cycleStart,
            ringInsertionDate: cycleStart
        )
        let mirror = fixture.store.blockingScheduleMirror
        let passiveDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: cycleStart))
        let removalDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 21, to: cycleStart))
        let breakDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 22, to: cycleStart))
        let nextInsertionDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 28, to: cycleStart))

        XCTAssertTrue(mirror.requiresAction(on: cycleStart))
        XCTAssertFalse(mirror.requiresAction(on: passiveDay))
        XCTAssertTrue(mirror.requiresAction(on: removalDay))
        XCTAssertFalse(mirror.requiresAction(on: breakDay))
        XCTAssertTrue(mirror.requiresAction(on: nextInsertionDay))
    }

    func testStoreMirrorSurvivesAppGroupWriterAndExtensionReadPath() throws {
        let cycleStart = InMemoryStoreFactory.fixedDate("2026-07-01")
        let fixture = try InMemoryStoreFactory.makeStore(
            now: cycleStart,
            regimen: .twentySixTwo,
            startDate: cycleStart
        )
        let suiteName = "pillie.tests.blocking-schedule.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        ScreenTimeSharedState.setBlockingScheduleMirror(
            fixture.store.blockingScheduleMirror,
            in: defaults
        )

        // Mirrors the extension read boundary: shared key -> Data -> shared codec.
        let decoded = try XCTUnwrap(BlockingScheduleMirror.decode(
            from: defaults.data(forKey: BlockingScheduleMirror.storageKey)
        ))
        let day26 = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 25, to: cycleStart))
        let day27 = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 26, to: cycleStart))
        let staleHandledStamp = TodayTakenStamp(
            isTaken: true,
            epochDay: TodayTakenStamp.epochDay(for: day26)
        )

        XCTAssertEqual(
            BlockingInterventionPolicy.decision(
                schedule: decoded,
                handledStamp: staleHandledStamp,
                now: day27
            ),
            .clearShields
        )
    }

    func testMarkTodayAfterCycleDayAdjustmentRefreshesStreakObservers() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let fixture = try InMemoryStoreFactory.makeStore(now: today)
        let store = fixture.store

        store.updateCycleDay(21)
        let versionAfterCycleDayChange = store.protocolChangeVersion

        store.markTodayAsTaken()

        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertGreaterThan(store.protocolChangeVersion, versionAfterCycleDayChange)
    }

    func testMonthBoundarySeparatesPastAndToday() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-03-01")
        let startDate = InMemoryStoreFactory.fixedDate("2026-02-28")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: startDate)
        let store = fixture.store

        XCTAssertEqual(store.scheduleSnapshot(for: startDate)?.status, .missed)
        XCTAssertEqual(store.scheduleSnapshot(for: today)?.status, .upcoming)

        store.markActionAsTaken(on: startDate)
        let adherence = store.monthAdherence(for: startDate)
        XCTAssertEqual(adherence.completed, 1)
        XCTAssertEqual(adherence.due, 1)
        XCTAssertEqual(adherence.percentage, 100)
    }

    func testLeapDayProducesExpectedDueAction() throws {
        let leapDay = InMemoryStoreFactory.fixedDate("2024-02-29")
        let fixture = try InMemoryStoreFactory.makeStore(now: leapDay, startDate: leapDay)

        let snapshot = fixture.store.scheduleSnapshot(for: leapDay)
        XCTAssertEqual(snapshot?.dueAction?.type, .pillActive)
        XCTAssertEqual(snapshot?.dueAction?.cycleDay, 1)
        XCTAssertEqual(snapshot?.status, .upcoming)
    }

    func testCustomReminderCopySurvivesContraceptionMethodChangeAndTrackingReset() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, method: .pill, startDate: today)
        let store = fixture.store

        store.customDueReminderTitle = "My own title 💖"
        store.customDueReminderBody = "Just for me."

        // A method change is a Tracking Data Reset (resetAndStartFresh wipes the records
        // and switches method). Custom copy is a Personalization Setting, so it must remain.
        store.resetAndStartFresh(
            method: .ring,
            regimen: .twentyOneSeven,
            customActiveDays: nil,
            customBreakDays: nil,
            cycleDay: 1
        )

        XCTAssertEqual(store.contraceptiveMethod, .ring)
        XCTAssertEqual(store.customDueReminderTitle, "My own title 💖")
        XCTAssertEqual(store.customDueReminderBody, "Just for me.")
    }

    func testCustomReminderCopyPersistsAcrossStoreReload() throws {
        let today = InMemoryStoreFactory.fixedDate("2026-05-26")
        let fixture = try InMemoryStoreFactory.makeStore(now: today, startDate: today)
        fixture.store.customDueReminderTitle = "Persisted title"
        fixture.store.customDueReminderBody = "Persisted body"

        // A fresh PillStore over the same context reloads settings from UserDefaults —
        // models the app relaunching (e.g. after Plus lapses and later resubscribes).
        let reloaded = PillStore(modelContext: fixture.context)
        XCTAssertEqual(reloaded.customDueReminderTitle, "Persisted title")
        XCTAssertEqual(reloaded.customDueReminderBody, "Persisted body")
    }

    func testCustomPillValuesClampUnsafePersistedInput() {
        XCTAssertEqual(PillPack.normalizedCustomValues(active: nil, breakDays: nil).active, 21)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: nil, breakDays: nil).breakDays, 7)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 0, breakDays: 99).active, 1)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 0, breakDays: 99).breakDays, 7)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 999, breakDays: -1).active, 365)
        XCTAssertEqual(PillPack.normalizedCustomValues(active: 999, breakDays: -1).breakDays, 0)
    }
}
