//
//  ProtectionPlanRoutineContentTests.swift
//  PillieTests
//
//  Verifies the copy for Routine Method, Routine Details, and Reminder Time (#77)
//  matches the Superdesign drafts (consolidated to keep each screen uncluttered) and
//  respects Pillie's privacy / non-medical boundary. Value types only — no host crash.
//

import XCTest

@testable import Pillie

final class ProtectionPlanRoutineContentTests: XCTestCase {
    // MARK: - Routine Method

    func testRoutineMethodContentMatchesDraftAndOffersEveryMethod() {
        let content = ProtectionPlanRoutineMethodContent.default
        XCTAssertEqual(content.title, "The core of it")
        XCTAssertEqual(content.subtitle, "What routine should Pillie protect?")
        XCTAssertEqual(content.footnote, "Your plan adapts to how you take it. You can change this anytime.")
        XCTAssertEqual(content.primaryCTA, "Continue")
        XCTAssertEqual(content.choices, ContraceptiveMethod.allCases)
    }

    func testEachMethodHasADistinctPlainLanguageDescriptor() {
        let descriptors = ContraceptiveMethod.allCases.map(\.routineDescriptor)
        XCTAssertEqual(descriptors, ["Taken daily", "Changed weekly", "Monthly cycle"])
        XCTAssertEqual(Set(descriptors).count, ContraceptiveMethod.allCases.count)
    }

    func testRoutineMethodContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanRoutineMethodContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Routine Details

    func testRoutineDetailsContentExposesPositionAndRegimenSimplification() {
        let content = ProtectionPlanRoutineDetailsContent.default
        XCTAssertEqual(content.title, "Where are you in your routine?")
        XCTAssertEqual(content.subtitle, "How far into your cycle are you?")
        XCTAssertEqual(content.cyclePositionHeader, "Where are you now?")
        XCTAssertEqual(content.regimenHeader, "Pill regimen")
        // The "More options" disclosure is the mechanism that keeps the screen clean
        // while still reaching every regimen.
        XCTAssertEqual(content.moreLabel, "More options")
        XCTAssertEqual(content.primaryCTA, "Continue")
        // The coarse position toggle is the three CyclePosition buckets.
        XCTAssertEqual(content.visibleCopy.contains(CyclePosition.justStarting.title), true)
        XCTAssertEqual(content.visibleCopy.contains(CyclePosition.nearEnd.title), true)
    }

    func testRoutineDetailsContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanRoutineDetailsContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Reminder Time

    func testReminderTimeContentUsesDueActionFraming() {
        let content = ProtectionPlanReminderTimeContent.default
        XCTAssertEqual(content.title, "The golden hour")
        XCTAssertEqual(content.subtitle, "When should Pillie step in?")
        // The Due Action Time concept is named once, on the picker, rather than
        // repeated in a redundant helper line — the screen stays uncluttered.
        XCTAssertEqual(content.pickerLabel, "Due Action Time")
        XCTAssertEqual(content.primaryCTA, "Set Reminder Time")
    }

    func testReminderTimeContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanReminderTimeContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Helpers

    private func assertNoMedicalOrFakeClaims(
        _ line: String,
        file: StaticString = #filePath,
        line lineNumber: UInt = #line
    ) {
        let banned = ["doctor", "prescri", "diagnos", "guarantee", "clinically", "% of users", "fda"]
        let lowered = line.lowercased()
        for term in banned {
            XCTAssertFalse(
                lowered.contains(term),
                "Copy must avoid medical/fake claims; found \"\(term)\" in: \(line)",
                file: file,
                line: lineNumber
            )
        }
        XCTAssertFalse(line.contains("%"), "Routine copy must not invent stats: \(line)", file: file, line: lineNumber)
    }
}
