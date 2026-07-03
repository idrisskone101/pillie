//
//  BlockerInterventionCounterTests.swift
//  PillieTests
//
//  Pure counting logic behind blocker_intervention_fired (#161 / ADR 0007):
//  the shield extension increments an App Group counter it cannot send itself,
//  the main app flushes the accumulated delta on next open, and the lifetime
//  total survives every flush for the Trial-End Paywall's own-stats.
//

import XCTest

@testable import Pillie

final class BlockerInterventionCounterTests: XCTestCase {

    func testRecordingInterceptsIncrementsUnflushedAndLifetimeCounts() {
        var counter = BlockerInterventionCounter()

        counter.recordIntercept()
        counter.recordIntercept()

        XCTAssertEqual(counter.unflushedCount, 2)
        XCTAssertEqual(counter.lifetimeTotal, 2)
    }

    func testFlushReturnsDeltaResetsUnflushedAndPreservesLifetimeTotal() {
        var counter = BlockerInterventionCounter()
        counter.recordIntercept()
        counter.recordIntercept()
        counter.recordIntercept()

        let flushed = counter.flush()

        XCTAssertEqual(flushed, 3)
        XCTAssertEqual(counter.unflushedCount, 0)
        XCTAssertEqual(counter.lifetimeTotal, 3)

        // Intercepts after a flush accumulate a fresh delta on top of the
        // running lifetime total.
        counter.recordIntercept()
        XCTAssertEqual(counter.unflushedCount, 1)
        XCTAssertEqual(counter.lifetimeTotal, 4)

        // Flushing with nothing accumulated reports zero and changes nothing.
        XCTAssertEqual(counter.flush(), 1)
        XCTAssertEqual(counter.flush(), 0)
        XCTAssertEqual(counter.lifetimeTotal, 4)
    }
}
