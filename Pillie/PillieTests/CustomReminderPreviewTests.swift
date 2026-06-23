//
//  CustomReminderPreviewTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

/// Verifies the live notification preview resolver for the Reminder Messages editor (#111).
///
/// The preview must show the *effective* copy that will actually fire, so every assertion
/// here pins it to `CustomReminderCopy.effective` (the same helper `NotificationManager`
/// builds notifications from) and to the method-aware default copy. Pure value type — runs
/// without a host crash.
final class CustomReminderPreviewTests: XCTestCase {

    // MARK: - Daily reminder preview

    func testCustomDailyTextWinsWhenPresent() {
        XCTAssertEqual(
            CustomReminderPreview.dailyTitle(custom: "Take your pill, love 💖", method: .pill, isPlus: true),
            "Take your pill, love 💖"
        )
        XCTAssertEqual(
            CustomReminderPreview.dailyBody(custom: "Just a tiny moment for you.", method: .pill, isPlus: true),
            "Just a tiny moment for you."
        )
    }

    func testBlankDailyFieldFallsBackToMethodDefault() {
        let defaultTitle = CustomReminderPreview.defaultDailyTitle(method: .pill)
        let defaultBody = CustomReminderPreview.defaultDailyBody(method: .pill)
        XCTAssertFalse(defaultTitle.isEmpty)
        XCTAssertFalse(defaultBody.isEmpty)

        XCTAssertEqual(
            CustomReminderPreview.dailyTitle(custom: "   ", method: .pill, isPlus: true),
            defaultTitle
        )
        XCTAssertEqual(
            CustomReminderPreview.dailyBody(custom: "", method: .pill, isPlus: true),
            defaultBody
        )
    }

    func testDailyDefaultIsMethodAware() {
        let titles = ContraceptiveMethod.allCases.map { CustomReminderPreview.defaultDailyTitle(method: $0) }
        let bodies = ContraceptiveMethod.allCases.map { CustomReminderPreview.defaultDailyBody(method: $0) }
        // Every method has non-empty default copy.
        XCTAssertTrue(titles.allSatisfy { !$0.isEmpty })
        XCTAssertTrue(bodies.allSatisfy { !$0.isEmpty })
        // Patch and ring users must never see pill wording in their default body.
        XCTAssertTrue(CustomReminderPreview.defaultDailyBody(method: .patch).lowercased().contains("patch"))
        XCTAssertTrue(CustomReminderPreview.defaultDailyBody(method: .ring).lowercased().contains("ring"))
        XCTAssertFalse(CustomReminderPreview.defaultDailyBody(method: .patch).lowercased().contains("pill"))
        XCTAssertFalse(CustomReminderPreview.defaultDailyBody(method: .ring).lowercased().contains("pill"))
    }

    func testNonPlusPreviewShowsDefaultEvenWithCustomText() {
        XCTAssertEqual(
            CustomReminderPreview.dailyTitle(custom: "Resubscribe to see me", method: .pill, isPlus: false),
            CustomReminderPreview.defaultDailyTitle(method: .pill)
        )
    }

    func testPreviewClampsAndTrimsExactlyLikeTheNotification() {
        let longCustom = String(repeating: "A", count: CustomReminderCopy.titleCap + 25)
        XCTAssertEqual(
            CustomReminderPreview.dailyTitle(custom: longCustom, method: .pill, isPlus: true),
            CustomReminderCopy.effective(
                custom: longCustom,
                default: CustomReminderPreview.defaultDailyTitle(method: .pill),
                cap: CustomReminderCopy.titleCap,
                isPlus: true
            )
        )

        let padded = "   Log it 💊   "
        XCTAssertEqual(
            CustomReminderPreview.dailyTitle(custom: padded, method: .pill, isPlus: true),
            "Log it 💊"
        )
    }

    // MARK: - Follow-up (retry) reminder preview

    func testCustomRetryTextWinsWhenPresent() {
        XCTAssertEqual(
            CustomReminderPreview.retryTitle(custom: "Still nudging you 👀", isPlus: true),
            "Still nudging you 👀"
        )
    }

    func testBlankRetryFallsBackToDefaultRetryCopy() {
        XCTAssertEqual(
            CustomReminderPreview.retryTitle(custom: "   ", isPlus: true),
            NotificationManager.defaultRetryTitle
        )
        XCTAssertEqual(
            CustomReminderPreview.retryBody(custom: "", isPlus: true),
            NotificationManager.defaultRetryBody
        )
    }

    // MARK: - Last Call reminder preview

    func testCustomLastCallTextWinsWhenPresent() {
        XCTAssertEqual(
            CustomReminderPreview.lastCallTitle(custom: "Last chance, love 🌙", method: .pill, isPlus: true),
            "Last chance, love 🌙"
        )
        XCTAssertEqual(
            CustomReminderPreview.lastCallBody(custom: "The day's nearly done — log it.", method: .pill, isPlus: true),
            "The day's nearly done — log it."
        )
    }

    func testBlankLastCallFieldFallsBackToMethodDefault() {
        let defaultTitle = CustomReminderPreview.defaultLastCallTitle(method: .pill)
        let defaultBody = CustomReminderPreview.defaultLastCallBody(method: .pill)
        XCTAssertFalse(defaultTitle.isEmpty)
        XCTAssertFalse(defaultBody.isEmpty)

        XCTAssertEqual(
            CustomReminderPreview.lastCallTitle(custom: "   ", method: .pill, isPlus: true),
            defaultTitle
        )
        XCTAssertEqual(
            CustomReminderPreview.lastCallBody(custom: "", method: .pill, isPlus: true),
            defaultBody
        )
    }

    func testLastCallDefaultBodyIsMethodAware() {
        let bodies = ContraceptiveMethod.allCases.map { CustomReminderPreview.defaultLastCallBody(method: $0) }
        XCTAssertTrue(bodies.allSatisfy { !$0.isEmpty })
        // Patch and ring users must never see pill wording in their default Last Call body.
        XCTAssertTrue(CustomReminderPreview.defaultLastCallBody(method: .patch).lowercased().contains("patch"))
        XCTAssertTrue(CustomReminderPreview.defaultLastCallBody(method: .ring).lowercased().contains("ring"))
        XCTAssertFalse(CustomReminderPreview.defaultLastCallBody(method: .patch).lowercased().contains("pill"))
        XCTAssertFalse(CustomReminderPreview.defaultLastCallBody(method: .ring).lowercased().contains("pill"))
    }

    func testNonPlusLastCallPreviewShowsDefaultEvenWithCustomText() {
        XCTAssertEqual(
            CustomReminderPreview.lastCallTitle(custom: "Resubscribe to see me", method: .pill, isPlus: false),
            CustomReminderPreview.defaultLastCallTitle(method: .pill)
        )
    }

    func testLastCallPreviewClampsAndTrimsExactlyLikeTheNotification() {
        let longCustom = String(repeating: "B", count: CustomReminderCopy.bodyCap + 25)
        XCTAssertEqual(
            CustomReminderPreview.lastCallBody(custom: longCustom, method: .pill, isPlus: true),
            CustomReminderCopy.effective(
                custom: longCustom,
                default: CustomReminderPreview.defaultLastCallBody(method: .pill),
                cap: CustomReminderCopy.bodyCap,
                isPlus: true
            )
        )

        let padded = "   Last call 🌙   "
        XCTAssertEqual(
            CustomReminderPreview.lastCallTitle(custom: padded, method: .pill, isPlus: true),
            "Last call 🌙"
        )
    }
}
