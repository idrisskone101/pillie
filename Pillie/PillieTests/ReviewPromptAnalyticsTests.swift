//
//  ReviewPromptAnalyticsTests.swift
//  PillieTests
//
//  Asserts the Review Prompt telemetry is PII-free (ADR 0001/0004): the two
//  Sentiment Gate events use stable low-cardinality names and carry no
//  event-specific properties — never method, Streak, or ordinal (#133).
//  CoreEngagementAnalyticsTests style.
//

import XCTest

@testable import Pillie

final class ReviewPromptAnalyticsTests: XCTestCase {

    func testReviewPromptEventsUseApprovedEventNames() {
        XCTAssertEqual(AnalyticsEvent.reviewPromptShown.rawValue, "review_prompt_shown")
        XCTAssertEqual(AnalyticsEvent.reviewPromptPositiveTapped.rawValue, "review_prompt_positive_tapped")
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
