//
//  DayCorrectionPolicyTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class DayCorrectionPolicyTests: XCTestCase {
    private static var keepAlivePacks: [PillPack] = []

    override func tearDown() {
        Self.keepAlivePacks.removeAll(keepingCapacity: true)
        super.tearDown()
    }

    func testPastDueDayWithNoRecordOffersAllOutcomesWithUnloggedCurrent() {
        let snapshot = makeSnapshot(
            method: .pill,
            type: .pillActive,
            status: .missed,
            relationDate: fixedDate("2026-06-01")
        )

        let options = DayCorrectionPolicy.options(for: snapshot, relation: .past)

        XCTAssertEqual(options?.selectableOutcomes, [.taken, .unlogged, .breakDay])
        XCTAssertEqual(options?.currentOutcome, .unlogged)
    }

    func testTodayFutureNoDataAndPassiveActiveReturnNilOptions() {
        let dueSnapshot = makeSnapshot(
            method: .pill,
            type: .pillActive,
            status: .missed,
            relationDate: fixedDate("2026-06-01")
        )
        XCTAssertNil(DayCorrectionPolicy.options(for: dueSnapshot, relation: .today))
        XCTAssertNil(DayCorrectionPolicy.options(for: dueSnapshot, relation: .future))

        let noDataSnapshot = makeSnapshot(
            method: .pill,
            type: .pillActive,
            status: .noData,
            relationDate: fixedDate("2026-06-01")
        )
        XCTAssertNil(DayCorrectionPolicy.options(for: noDataSnapshot, relation: .past))

        let passiveSnapshot = makeSnapshot(
            method: .patch,
            type: .patchActive,
            status: .taken,
            relationDate: fixedDate("2026-06-01")
        )
        XCTAssertNil(DayCorrectionPolicy.options(for: passiveSnapshot, relation: .past))
    }

    func testScheduledBreakDayWithNoRecordIsNotEditable() {
        let snapshot = makeSnapshot(
            method: .pill,
            type: .pillBreak,
            status: .breakDay,
            relationDate: fixedDate("2026-06-01")
        )

        XCTAssertNil(DayCorrectionPolicy.options(for: snapshot, relation: .past))
    }

    func testCountsTowardAdherenceIsFalseForBreakStatusOnDueDay() {
        let snapshot = makeSnapshot(
            method: .pill,
            type: .pillActive,
            status: .breakDay,
            relationDate: fixedDate("2026-06-01")
        )

        XCTAssertTrue(snapshot.isDue)
        XCTAssertFalse(snapshot.countsTowardAdherence)
    }

    func testTakenAndBreakCurrentOutcomesReflectSnapshotStatus() {
        let taken = makeSnapshot(
            method: .pill,
            type: .pillActive,
            status: .taken,
            relationDate: fixedDate("2026-06-01")
        )
        XCTAssertEqual(
            DayCorrectionPolicy.options(for: taken, relation: .past)?.currentOutcome,
            .taken
        )

        let breakDay = makeSnapshot(
            method: .pill,
            type: .pillActive,
            status: .breakDay,
            relationDate: fixedDate("2026-06-01")
        )
        XCTAssertEqual(
            DayCorrectionPolicy.options(for: breakDay, relation: .past)?.currentOutcome,
            .breakDay
        )
    }

    private func fixedDate(_ value: String) -> Date {
        var components = DateComponents()
        components.year = Int(value.prefix(4))
        components.month = Int(value.dropFirst(5).prefix(2))
        components.day = Int(value.suffix(2))
        return Calendar.current.date(from: components)!
    }

    private func makeSnapshot(
        method: ContraceptiveMethod,
        type: PillDay.ActionType,
        status: PillDay.Status,
        relationDate: Date
    ) -> PillScheduleSnapshot {
        let pack = PillPack(
            packType: .twentyOneSeven,
            method: method,
            pillRegimen: .twentyOneSeven,
            startDate: relationDate,
            packNumber: 1,
            isCurrent: true
        )
        Self.keepAlivePacks.append(pack)

        let action = DoseScheduleAction(
            date: relationDate,
            type: type,
            method: method,
            cycleDay: 1,
            cycleLength: pack.cycleLength
        )

        return PillScheduleSnapshot(
            date: relationDate,
            pack: pack,
            cycleDayIndex: 0,
            dueAction: action,
            status: status,
            actionType: type
        )
    }
}
