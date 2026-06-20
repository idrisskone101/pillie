//
//  ProtectionPlanReadyContentTests.swift
//  PillieTests
//
//  Issue #83: the Pill Protection Plan Ready screen (faithful "Protection pulse"
//  variant 1). The screen's one data-driven element is the live reminder time; the
//  rest is fixed handoff copy. These value-type tests assert the reminder time is
//  rendered dynamically and that the activation-landing copy never leaks which apps
//  or how many were blocked.
//

import XCTest

@testable import Pillie

final class ProtectionPlanReadyContentTests: XCTestCase {
    // MARK: - Tracer: the configured reminder time is shown

    func testReadyScreenShowsTheConfiguredMorningReminderTime() {
        let content = ProtectionPlanReadyContent.make(reminderHour: 8, reminderMinute: 0)
        XCTAssertEqual(content.statusLabel, "Active from 8:00 AM daily")
    }

    func testReminderTimeIsDynamicAcrossAfternoonAndMidnight() {
        XCTAssertEqual(
            ProtectionPlanReadyContent.make(reminderHour: 20, reminderMinute: 30).statusLabel,
            "Active from 8:30 PM daily"
        )
        XCTAssertEqual(
            ProtectionPlanReadyContent.make(reminderHour: 0, reminderMinute: 5).statusLabel,
            "Active from 12:05 AM daily"
        )
    }

    // MARK: - Fixed handoff copy ("You're protected.")

    func testReadyScreenKeepsTheProtectedHandoffCopy() {
        let content = ProtectionPlanReadyContent.make(reminderHour: 9, reminderMinute: 0)
        XCTAssertEqual(content.title, "You're")
        XCTAssertEqual(content.titleAccent, "protected.")
        XCTAssertEqual(content.handNote, "we've got you")
        XCTAssertEqual(content.primaryCTA, "Start Using Pillie")
        XCTAssertFalse(content.subtitle.isEmpty)
        XCTAssertTrue(content.visibleCopy.contains(content.statusLabel))
    }

    // MARK: - Privacy boundary (generic summary only)

    func testReadyScreenSummaryNeverNamesBlockedApps() {
        // The ready screen is the activation landing. It shows the reminder time but
        // must stay generic — never which apps were blocked.
        let content = ProtectionPlanReadyContent.make(reminderHour: 8, reminderMinute: 0)
        let copy = content.visibleCopy.joined(separator: " ").lowercased()
        for name in ["tiktok", "instagram", "snapchat", "youtube", "messages", "facebook"] {
            XCTAssertFalse(copy.contains(name), "Ready copy must not name app \(name).")
        }
    }

    func testReadyScreenSummaryNeverLeaksABlockedAppCount() {
        // The only digits in the screen belong to the reminder clock time; no
        // "12 apps paused" style count may appear.
        let content = ProtectionPlanReadyContent.make(reminderHour: 8, reminderMinute: 0)
        let nonTimeDigits = content.visibleCopy
            .filter { $0 != content.statusLabel }
            .joined()
            .filter(\.isNumber)
        XCTAssertTrue(nonTimeDigits.isEmpty, "Only the reminder time may contain digits.")
    }
}
