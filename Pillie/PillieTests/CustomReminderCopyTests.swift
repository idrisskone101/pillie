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

    func testGentlePresetPopulatesEveryReminderMessage() {
        XCTAssertEqual(
            CustomReminderPreset.gentle.messages,
            CustomReminderMessages(
                dueTitle: "A gentle reminder",
                dueBody: "It’s time to check in with Pillie.",
                retryTitle: "Still time to check in",
                retryBody: "Open Pillie when you’re ready.",
            )
        )
    }

    func testDirectPresetPopulatesEveryReminderMessage() {
        XCTAssertEqual(
            CustomReminderPreset.direct.messages,
            CustomReminderMessages(
                dueTitle: "Pillie check-in due",
                dueBody: "Open Pillie to mark today’s pill.",
                retryTitle: "Pillie check-in waiting",
                retryBody: "Open Pillie to update your status.",
            )
        )
    }

    func testEncouragingPresetPopulatesEveryReminderMessage() {
        XCTAssertEqual(
            CustomReminderPreset.encouraging.messages,
            CustomReminderMessages(
                dueTitle: "You’re building consistency",
                dueBody: "Open Pillie for today’s check-in.",
                retryTitle: "Keep your routine moving",
                retryBody: "Open Pillie to update today’s status.",
            )
        )
    }

    func testPrivateDiscreetPresetPopulatesEveryReminderMessage() {
        XCTAssertEqual(
            CustomReminderPreset.privateDiscreet.messages,
            CustomReminderMessages(
                dueTitle: "Time for your check-in",
                dueBody: "Open Pillie when convenient.",
                retryTitle: "Check-in still pending",
                retryBody: "Open Pillie when convenient.",
            )
        )
    }

    func testPresetMatchingDistinguishesAnUneditedPresetFromManualCopy() {
        let gentle = CustomReminderPreset.gentle.messages
        XCTAssertEqual(CustomReminderPreset.matching(gentle), .gentle)

        let edited = CustomReminderMessages(
            dueTitle: gentle.dueTitle,
            dueBody: "My own follow-up",
            retryTitle: gentle.retryTitle,
            retryBody: gentle.retryBody,
        )
        XCTAssertNil(CustomReminderPreset.matching(edited))
    }

    func testPresetDisplayNamesMatchTheApprovedProductNames() {
        XCTAssertEqual(
            CustomReminderPreset.allCases.map(\.displayName),
            ["Gentle", "Direct", "Encouraging", "Private / discreet"]
        )
    }

    func testDraftPreservesExistingCustomMessagesOnOpen() {
        let existing = CustomReminderMessages(
            dueTitle: "My title",
            dueBody: "My message",
            retryTitle: "Retry title",
            retryBody: "Retry message",
        )

        XCTAssertEqual(CustomReminderDraft(messages: existing).messages, existing)
    }

    func testApplyingPresetReplacesTheDraftWithoutSavingEarly() {
        var draft = CustomReminderDraft(messages: CustomReminderPreset.gentle.messages)

        draft.apply(.direct)

        XCTAssertEqual(draft.messages, CustomReminderPreset.direct.messages)
        XCTAssertEqual(draft.appliedPreset, .direct)
        XCTAssertFalse(draft.wasEditedAfterPreset)
    }

    func testApplyingItalianPresetIsNotReportedAsAManualEdit() {
        var draft = CustomReminderDraft(messages: CustomReminderPreset.gentle.messages)

        draft.apply(.direct, locale: Locale(identifier: "it_IT"))

        XCTAssertEqual(
            draft.messages,
            CustomReminderPreset.direct.localizedMessages(locale: Locale(identifier: "it_IT"))
        )
        XCTAssertEqual(draft.appliedPreset, .direct)
        XCTAssertFalse(draft.wasEditedAfterPreset)
    }

    func testManualEditAfterPresetIsDistinguishableWithoutLosingPresetIdentity() {
        var draft = CustomReminderDraft(messages: CustomReminderPreset.gentle.messages)
        draft.apply(.gentle)

        draft.messages.dueBody = "My private wording"

        XCTAssertEqual(draft.appliedPreset, .gentle)
        XCTAssertTrue(draft.wasEditedAfterPreset)
    }

    func testRestoreDefaultsReplacesDraftAndClearsPresetAttribution() {
        var draft = CustomReminderDraft(messages: CustomReminderPreset.direct.messages)
        draft.apply(.direct)
        let defaults = CustomReminderPreset.gentle.messages

        draft.restoreDefaults(defaults)

        XCTAssertEqual(draft.messages, defaults)
        XCTAssertNil(draft.appliedPreset)
        XCTAssertFalse(draft.wasEditedAfterPreset)
    }

    func testCancellingDiscardsPresetChangesAndRestoresTheOpenedCopy() {
        let existing = CustomReminderPreset.gentle.messages
        var draft = CustomReminderDraft(messages: existing)
        draft.apply(.direct)

        draft.discardChanges()

        XCTAssertEqual(draft.messages, existing)
        XCTAssertNil(draft.appliedPreset)
    }

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
