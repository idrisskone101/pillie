//
//  InteractionFeedbackTests.swift
//  PillieTests
//

import SwiftUI
import XCTest
@testable import Pillie

@MainActor
final class InteractionFeedbackTests: XCTestCase {
    func testChangingMainTabPerformsSelectionFeedbackAndKeepsTabAnalytics() {
        let feedbackRecorder = RecordingInteractionFeedbackPerformer()
        var trackedTabs: [ProductAnalyticsTelemetry.MainTab] = []
        let selection = MainTabSelection(
            initialTab: .home,
            feedback: InteractionFeedback(performer: feedbackRecorder),
            trackSelectedTab: { trackedTabs.append($0) }
        )

        XCTAssertTrue(selection.select(.history))

        XCTAssertEqual(selection.selectedTab, .history)
        XCTAssertEqual(feedbackRecorder.performedIntents, [.tabChange])
        XCTAssertEqual(trackedTabs.map(\.analyticsScreen), [.calendar])

        XCTAssertFalse(selection.select(.history))

        XCTAssertEqual(selection.selectedTab, .history)
        XCTAssertEqual(feedbackRecorder.performedIntents, [.tabChange])
        XCTAssertEqual(trackedTabs.map(\.analyticsScreen), [.calendar])
    }

    func testMainTabDirectionMatchesHorizontalTabOrder() {
        let selection = MainTabSelection(
            initialTab: .home,
            feedback: InteractionFeedback(performer: RecordingInteractionFeedbackPerformer()),
            trackSelectedTab: { _ in }
        )

        XCTAssertTrue(selection.select(.settings))
        XCTAssertEqual(selection.tabDirection, .trailing)

        XCTAssertTrue(selection.select(.history))
        XCTAssertEqual(selection.tabDirection, .leading)
    }

    func testSharedMotionSemanticsIncludeCalmerReducedAndConstrainedProfiles() {
        XCTAssertEqual(
            PillieMotion.Semantic.allCases,
            [.quick, .standard, .entrance, .commitSpring, .rewardSpring]
        )

        XCTAssertEqual(PillieMotion.profile(for: .quick).duration, 0.16)
        XCTAssertEqual(PillieMotion.profile(for: .standard).duration, 0.25)
        XCTAssertEqual(PillieMotion.profile(for: .entrance).duration, 0.5)
        XCTAssertEqual(PillieMotion.profile(for: .commitSpring).curve, .spring)
        XCTAssertEqual(PillieMotion.profile(for: .rewardSpring).curve, .spring)

        let reducedMotion = PillieMotion.profile(
            for: .standard,
            accessibilityReduceMotion: true,
            performanceTier: .standard
        )
        let constrained = PillieMotion.profile(
            for: .rewardSpring,
            accessibilityReduceMotion: false,
            performanceTier: .constrained
        )

        XCTAssertEqual(reducedMotion.curve, .easeInOut)
        XCTAssertTrue(reducedMotion.usesCalmerSpatialMotion)
        XCTAssertEqual(constrained.curve, .easeInOut)
        XCTAssertTrue(constrained.usesCalmerSpatialMotion)
    }
}

private final class RecordingInteractionFeedbackPerformer: InteractionFeedbackPerforming {
    private(set) var performedIntents: [InteractionFeedback.Intent] = []

    func perform(_ intent: InteractionFeedback.Intent) {
        performedIntents.append(intent)
    }
}
