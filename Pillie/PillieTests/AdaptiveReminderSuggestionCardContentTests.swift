//
//  AdaptiveReminderSuggestionCardContentTests.swift
//  PillieTests
//
//  Value-type unit tests (no hosted @MainActor XCTest dependency).
//

import XCTest
@testable import Pillie

final class AdaptiveReminderSuggestionCardContentTests: XCTestCase {

    private let posix = Locale(identifier: "en_US_POSIX")

    private func suggestion(hour: Int, minute: Int, delta: Int) -> AdaptiveReminderTimeAnalyzer.Suggestion {
        AdaptiveReminderTimeAnalyzer.Suggestion(hour: hour, minute: minute, deltaMinutes: delta)
    }

    // MARK: - Pillie Plus gate (AC4)

    func testReturnsNilForFreeUsersEvenWithASuggestion() {
        let content = AdaptiveReminderSuggestionCardContent.make(
            suggestion: suggestion(hour: 8, minute: 40, delta: 40),
            isPlus: false,
            locale: posix
        )
        XCTAssertNil(content)
    }

    func testReturnsNilWhenThereIsNoSuggestion() {
        let content = AdaptiveReminderSuggestionCardContent.make(
            suggestion: nil,
            isPlus: true,
            locale: posix
        )
        XCTAssertNil(content)
    }

    // MARK: - Copy (AC1)

    func testBuildsCopyNamingTheSuggestedTimeForPlusUsers() {
        let content = AdaptiveReminderSuggestionCardContent.make(
            suggestion: suggestion(hour: 8, minute: 40, delta: 40),
            isPlus: true,
            locale: posix
        )

        let unwrapped = try? XCTUnwrap(content)
        XCTAssertNotNil(unwrapped)
        XCTAssertEqual(content?.suggestedHour, 8)
        XCTAssertEqual(content?.suggestedMinute, 40)
        XCTAssertEqual(content?.deltaMinutes, 40)
        // The headline names when the user actually logs (AC1 example wording).
        XCTAssertTrue(content?.headline.contains("8:40") ?? false, "headline: \(content?.headline ?? "nil")")
        XCTAssertTrue(content?.headline.localizedCaseInsensitiveContains("usually log") ?? false)
        // The accept CTA names the target time so the change is never ambiguous.
        XCTAssertTrue(content?.acceptTitle.contains("8:40") ?? false, "acceptTitle: \(content?.acceptTitle ?? "nil")")
        XCTAssertFalse(content?.body.isEmpty ?? true)
    }

    func testFormatsAfternoonTimesWithMeridiem() {
        let content = AdaptiveReminderSuggestionCardContent.make(
            suggestion: suggestion(hour: 21, minute: 5, delta: -30),
            isPlus: true,
            locale: posix
        )
        XCTAssertTrue(content?.headline.contains("9:05") ?? false, "headline: \(content?.headline ?? "nil")")
        XCTAssertTrue(content?.headline.localizedCaseInsensitiveContains("PM") ?? false)
    }
}
