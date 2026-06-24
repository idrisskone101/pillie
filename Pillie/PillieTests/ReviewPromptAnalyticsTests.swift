//
//  ReviewPromptAnalyticsTests.swift
//  PillieTests
//
//  Asserts the Review Prompt telemetry is PII-free (ADR 0001/0004): the four
//  Sentiment Gate events use stable low-cardinality names and carry no
//  event-specific properties — never method, Streak, ordinal, or feedback text
//  (PRD #132 / #133). CoreEngagementAnalyticsTests style.
//

import XCTest

@testable import Pillie

final class ReviewPromptAnalyticsTests: XCTestCase {

    func testReviewPromptEventsUseApprovedEventNames() {
        XCTAssertEqual(AnalyticsEvent.reviewPromptShown.rawValue, "review_prompt_shown")
        XCTAssertEqual(AnalyticsEvent.reviewPromptPositiveTapped.rawValue, "review_prompt_positive_tapped")
        XCTAssertEqual(AnalyticsEvent.reviewPromptNegativeTapped.rawValue, "review_prompt_negative_tapped")
        XCTAssertEqual(AnalyticsEvent.reviewPromptDismissed.rawValue, "review_prompt_dismissed")
    }

    func testEachReviewPromptEventNameIsDistinct() {
        let names = [
            AnalyticsEvent.reviewPromptShown.rawValue,
            AnalyticsEvent.reviewPromptPositiveTapped.rawValue,
            AnalyticsEvent.reviewPromptNegativeTapped.rawValue,
            AnalyticsEvent.reviewPromptDismissed.rawValue
        ]
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testReviewPromptPayloadCarriesNoEventSpecificProperties() {
        // The events ride only the structural envelope; there is no payload field
        // for method, Streak value, or appearance ordinal, so none can be sent.
        let properties = AnalyticsPayload(source: .home, isPlus: false).properties
        XCTAssertEqual(Set(properties.keys), ["source", "is_plus"])
        XCTAssertEqual(properties["source"], .string("home"))
        XCTAssertEqual(properties["is_plus"], .bool(false))
    }
}
