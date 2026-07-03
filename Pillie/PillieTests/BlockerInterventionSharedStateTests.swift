//
//  BlockerInterventionSharedStateTests.swift
//  PillieTests
//
//  App Group persistence for the intercept counter (#161): the shield
//  extension records intercepts into shared UserDefaults; the main app —
//  a different process, so a different instance — flushes the delta and
//  reads the lifetime total. Exercised here through two independent
//  instances over the same defaults suite.
//

import XCTest

@testable import Pillie

final class BlockerInterventionSharedStateTests: XCTestCase {
    private static let suiteName = "BlockerInterventionSharedStateTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: Self.suiteName)
        defaults = UserDefaults(suiteName: Self.suiteName)
    }

    func testInterceptsRecordedByOneInstanceAreVisibleToAnother() {
        let shieldSide = BlockerInterventionSharedState(defaults: defaults)
        let appSide = BlockerInterventionSharedState(defaults: defaults)

        shieldSide.recordIntercept()
        shieldSide.recordIntercept()

        XCTAssertEqual(appSide.counter.unflushedCount, 2)
        XCTAssertEqual(appSide.counter.lifetimeTotal, 2)
    }

    func testFlushPersistsResetAndPreservesLifetimeTotal() {
        let state = BlockerInterventionSharedState(defaults: defaults)
        state.recordIntercept()
        state.recordIntercept()
        state.recordIntercept()

        XCTAssertEqual(state.flushUnflushed(), 3)

        // A fresh instance over the same defaults sees the persisted reset.
        let reread = BlockerInterventionSharedState(defaults: defaults)
        XCTAssertEqual(reread.counter.unflushedCount, 0)
        XCTAssertEqual(reread.counter.lifetimeTotal, 3)
        XCTAssertEqual(reread.flushUnflushed(), 0)
    }
}
