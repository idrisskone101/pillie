//
//  EarlyValueProofInteractionTests.swift
//  PillieTests
//
//  Public behavior coverage for the skippable Catch the Drift demo (#206).
//

import XCTest

@testable import Pillie

final class EarlyValueProofInteractionTests: XCTestCase {
    func testIdleDemoOffersDragWithoutAPrimaryTapAction() {
        var demo = EarlyValueProofDemoState()

        XCTAssertNil(demo.primaryAction)
        XCTAssertEqual(demo.handle(.primary), .noChange)
        XCTAssertFalse(demo.isLatched)
        XCTAssertFalse(demo.isResolved)
    }

    func testSkipAdvancesFromTheIdleDemo() {
        var demo = EarlyValueProofDemoState()

        let outcome = demo.handle(.skip)

        XCTAssertEqual(outcome, .advance(.skip))
    }

    func testDraggingFarEnoughLatchesTheInteractiveDemo() {
        var demo = EarlyValueProofDemoState()

        let outcome = demo.handle(.drag(progress: 0.8))

        XCTAssertEqual(outcome, .latched)
        XCTAssertTrue(demo.isLatched)
    }

    func testDraggingBackBelowReleaseThresholdUnlatches() {
        var demo = EarlyValueProofDemoState()
        _ = demo.handle(.drag(progress: 0.8))

        let outcome = demo.handle(.drag(progress: 0.5))

        XCTAssertEqual(outcome, .unlatched)
        XCTAssertFalse(demo.isLatched)
    }

    func testPrimaryTapAfterDraggingResolvesAsTapFallback() {
        var demo = EarlyValueProofDemoState()
        _ = demo.handle(.drag(progress: 0.8))

        let outcome = demo.handle(.primary)

        XCTAssertEqual(outcome, .resolved(.tapFallback))
        XCTAssertTrue(demo.isResolved)
    }

    func testRequiredShakesResolveAsInteractiveCompletion() {
        var demo = EarlyValueProofDemoState()
        _ = demo.handle(.drag(progress: 0.8))

        let outcome = demo.handle(.shake(count: 3, required: 3))

        XCTAssertEqual(outcome, .resolved(.interactive))
        XCTAssertTrue(demo.isResolved)
    }

    func testVoiceOverPrimaryAdvancesWithoutInteraction() {
        var demo = EarlyValueProofDemoState(voiceOverEnabled: true)

        let outcome = demo.handle(.primary)

        XCTAssertEqual(outcome, .advance(.accessibility))
    }

    func testReduceMotionPrimaryAdvancesWithoutInteraction() {
        var demo = EarlyValueProofDemoState(reduceMotion: true)

        let outcome = demo.handle(.primary)

        XCTAssertEqual(outcome, .advance(.accessibility))
    }
}
