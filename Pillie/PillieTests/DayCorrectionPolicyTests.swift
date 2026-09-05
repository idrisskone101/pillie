//
//  DayCorrectionPolicyTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class DayCorrectionPolicyTests: XCTestCase {
    private let anchor = InMemoryStoreFactory.fixedDate("2026-06-01")

    func testPastDueDayWithNoRecordOffersAllOutcomesWithUnloggedCurrent() {
        let snapshot = makeSnapshot(method: .pill, type: .pillActive, status: .missed)

        let options = DayCorrectionPolicy.options(for: snapshot, relation: .past)

        XCTAssertEqual(options?.selectableOutcomes, [.taken, .unlogged, .breakDay])
        XCTAssertEqual(options?.currentOutcome, .unlogged)
    }

    func testTodayFutureNoDataAndPassiveActiveReturnNilOptions() {
        let dueSnapshot = makeSnapshot(method: .pill, type: .pillActive, status: .missed)
        XCTAssertNil(DayCorrectionPolicy.options(for: dueSnapshot, relation: .today))
        XCTAssertNil(DayCorrectionPolicy.options(for: dueSnapshot, relation: .future))

        let noDataSnapshot = makeSnapshot(method: .pill, type: .pillActive, status: .noData)
        XCTAssertNil(DayCorrectionPolicy.options(for: noDataSnapshot, relation: .past))

        let passiveSnapshot = makeSnapshot(method: .patch, type: .patchActive, status: .taken)
        XCTAssertNil(DayCorrectionPolicy.options(for: passiveSnapshot, relation: .past))
    }

    func testScheduledBreakDayWithNoRecordIsNotEditable() {
        let snapshot = makeSnapshot(method: .pill, type: .pillBreak, status: .breakDay)

        XCTAssertNil(DayCorrectionPolicy.options(for: snapshot, relation: .past))
    }

    func testRingReinsertDayIsNotEditable() {
        // Reinsert starts a new cycle in `markActionAsTaken`; a single-day
        // rewrite cannot reproduce that, so the day must stay read-only.
        let missed = makeSnapshot(method: .ring, type: .ringReinsert, status: .missed)
        XCTAssertNil(DayCorrectionPolicy.options(for: missed, relation: .past))

        let taken = makeSnapshot(method: .ring, type: .ringReinsert, status: .taken)
        XCTAssertNil(DayCorrectionPolicy.options(for: taken, relation: .past))
    }

    func testRingInsertDayIsEditable() {
        let snapshot = makeSnapshot(method: .ring, type: .ringInsert, status: .missed)

        XCTAssertEqual(
            DayCorrectionPolicy.options(for: snapshot, relation: .past)?.selectableOutcomes,
            [.taken, .unlogged, .breakDay]
        )
    }

    func testCountsTowardAdherenceIsFalseForBreakStatusOnDueDay() {
        let snapshot = makeSnapshot(method: .pill, type: .pillActive, status: .breakDay)

        XCTAssertTrue(snapshot.isDue)
        XCTAssertFalse(snapshot.countsTowardAdherence)
    }

    func testScheduledBreakTakenOrMissedOffersOnlyBreakWithActualCurrent() {
        let taken = makeSnapshot(method: .pill, type: .pillBreak, status: .taken)
        let takenOptions = DayCorrectionPolicy.options(for: taken, relation: .past)
        XCTAssertEqual(takenOptions?.selectableOutcomes, [.breakDay])
        XCTAssertEqual(takenOptions?.currentOutcome, .taken)

        let missed = makeSnapshot(method: .pill, type: .pillBreak, status: .missed)
        let missedOptions = DayCorrectionPolicy.options(for: missed, relation: .past)
        XCTAssertEqual(missedOptions?.selectableOutcomes, [.breakDay])
        XCTAssertEqual(missedOptions?.currentOutcome, .unlogged)
    }

    func testTakenAndBreakCurrentOutcomesReflectSnapshotStatus() {
        let taken = makeSnapshot(method: .pill, type: .pillActive, status: .taken)
        XCTAssertEqual(
            DayCorrectionPolicy.options(for: taken, relation: .past)?.currentOutcome,
            .taken
        )

        let breakDay = makeSnapshot(method: .pill, type: .pillActive, status: .breakDay)
        XCTAssertEqual(
            DayCorrectionPolicy.options(for: breakDay, relation: .past)?.currentOutcome,
            .breakDay
        )
    }

    func testOutcomeLocalizationKeysResolve() {
        for outcome in [DayCorrectionOutcome.taken, .unlogged, .breakDay] {
            for field in ["title", "subtitle"] {
                let key = "history.dayCorrection.\(outcome.localizationKey).\(field)"
                XCTAssertNotEqual(PillieLocalization.string(key, locale: Locale(identifier: "en")), key)
            }
        }
    }

    // `PillScheduleSnapshot.pack` is a strong reference, so the snapshot keeps
    // its pack alive for the duration of the assertion.
    private func makeSnapshot(
        method: ContraceptiveMethod,
        type: PillDay.ActionType,
        status: PillDay.Status
    ) -> PillScheduleSnapshot {
        let pack = PillPack(
            packType: .twentyOneSeven,
            method: method,
            pillRegimen: .twentyOneSeven,
            startDate: anchor,
            packNumber: 1,
            isCurrent: true
        )

        let action = DoseScheduleAction(
            date: anchor,
            type: type,
            method: method,
            cycleDay: 1,
            cycleLength: pack.cycleLength
        )

        return PillScheduleSnapshot(
            date: anchor,
            pack: pack,
            cycleDayIndex: 0,
            dueAction: action,
            status: status,
            actionType: type
        )
    }
}
