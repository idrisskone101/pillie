//
//  CustomReminderCopyTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

/// Unit tests for the pure cap/fallback resolver (ADR 0004). These are value-type
/// only — no reference types are allocated, so they are immune to the Xcode 27 beta
/// @MainActor/class-deinit hosted-XCTest crash.
final class CustomReminderCopyTests: XCTestCase {

    private let defaultTitle = "Pillie check-in"
    private let defaultBody = "A quick moment to take your pill and log it."

    // MARK: - Plus, under cap

    func testUnderCapCustomIsPreservedForPlus() {
        let result = CustomReminderCopy.effective(
            custom: "Take your pill, love",
            default: defaultTitle,
            cap: CustomReminderCopy.titleCap,
            isPlus: true
        )
        XCTAssertEqual(result, "Take your pill, love")
    }

    // MARK: - Plus, over cap → clamped

    func testOverCapCustomIsClampedToCap() {
        let longTitle = String(repeating: "a", count: 80)
        let result = CustomReminderCopy.effective(
            custom: longTitle,
            default: defaultTitle,
            cap: CustomReminderCopy.titleCap,
            isPlus: true
        )
        XCTAssertEqual(result.count, CustomReminderCopy.titleCap)
        XCTAssertEqual(result, String(repeating: "a", count: CustomReminderCopy.titleCap))
    }

    func testOverCapClampsByCharacterCountPreservingEmoji() {
        // A string of emoji grapheme clusters clamps by Character, never splitting a glyph.
        let emoji = String(repeating: "💊", count: 60)
        let result = CustomReminderCopy.effective(
            custom: emoji,
            default: defaultBody,
            cap: CustomReminderCopy.bodyCap,
            isPlus: true
        )
        XCTAssertEqual(result, emoji) // 60 < 150 cap, untouched
        XCTAssertEqual(result.count, 60)
    }

    // MARK: - Whitespace trimming

    func testLeadingAndTrailingWhitespaceIsTrimmed() {
        let result = CustomReminderCopy.effective(
            custom: "   Time to log 💊   ",
            default: defaultBody,
            cap: CustomReminderCopy.bodyCap,
            isPlus: true
        )
        XCTAssertEqual(result, "Time to log 💊")
    }

    func testInteriorPunctuationAndEmojiPreservedExactly() {
        let custom = "Hey! Don't forget — log it 💖 (please)"
        let result = CustomReminderCopy.effective(
            custom: custom,
            default: defaultBody,
            cap: CustomReminderCopy.bodyCap,
            isPlus: true
        )
        XCTAssertEqual(result, custom)
    }

    // MARK: - Blank → default

    func testEmptyCustomFallsBackToDefault() {
        let result = CustomReminderCopy.effective(
            custom: "",
            default: defaultTitle,
            cap: CustomReminderCopy.titleCap,
            isPlus: true
        )
        XCTAssertEqual(result, defaultTitle)
    }

    func testWhitespaceOnlyCustomFallsBackToDefault() {
        let result = CustomReminderCopy.effective(
            custom: "   \n\t  ",
            default: defaultTitle,
            cap: CustomReminderCopy.titleCap,
            isPlus: true
        )
        XCTAssertEqual(result, defaultTitle)
    }

    // MARK: - Not Plus → default (build-time gate)

    func testNonPlusIgnoresCustomAndReturnsDefault() {
        let result = CustomReminderCopy.effective(
            custom: "My private nudge",
            default: defaultTitle,
            cap: CustomReminderCopy.titleCap,
            isPlus: false
        )
        XCTAssertEqual(result, defaultTitle)
    }

    func testNonPlusReturnsDefaultEvenWhenCustomIsBlank() {
        let result = CustomReminderCopy.effective(
            custom: "",
            default: defaultBody,
            cap: CustomReminderCopy.bodyCap,
            isPlus: false
        )
        XCTAssertEqual(result, defaultBody)
    }

    // MARK: - isCustomized

    func testIsCustomizedReflectsNonBlankContent() {
        XCTAssertTrue(CustomReminderCopy.isCustomized("hi"))
        XCTAssertTrue(CustomReminderCopy.isCustomized("  hi  "))
        XCTAssertFalse(CustomReminderCopy.isCustomized(""))
        XCTAssertFalse(CustomReminderCopy.isCustomized("   \n  "))
    }
}
