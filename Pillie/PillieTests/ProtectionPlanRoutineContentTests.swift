//
//  ProtectionPlanRoutineContentTests.swift
//  PillieTests
//
//  Verifies the copy for Routine Method and Reminder Time (#77)
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
        XCTAssertEqual(content.footnote, "This reminder setup is based on your selections. You can change it later in Settings.")
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
