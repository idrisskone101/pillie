//
//  ProtectionPlanQuestionContentTests.swift
//  PillieTests
//
//  Verifies the Distraction Choices + Delay Consequence copy (#75) matches the
//  Superdesign drafts and respects Pillie's privacy/non-medical boundary. Value
//  types only, so it runs without a host crash.
//

import XCTest

@testable import Pillie

final class ProtectionPlanQuestionContentTests: XCTestCase {
    // MARK: - Distraction Choices

    func testDistractionChoicesContentMatchesDraftAndIsMultiSelectWithOther() {
        let content = ProtectionPlanDistractionChoicesContent.default
        XCTAssertEqual(content.title, "Be honest\u{2026}")
        XCTAssertEqual(content.subtitle, "What usually gets in the way after your reminder?")
        XCTAssertEqual(content.helper, "Select all that apply. We'll help you stay focused.")
        XCTAssertEqual(content.primaryCTA, "Continue")
        // Multi-select intent + an Other catch-all are part of the contract.
        XCTAssertTrue(content.helper.lowercased().contains("select all that apply"))
        XCTAssertEqual(content.choices, DistractionChoice.allCases)
        XCTAssertTrue(content.choices.contains(.other))
    }

    func testDistractionChoicesContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanDistractionChoicesContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Delay Consequence

    func testDelayConsequenceContentMatchesDraftAndIsCalibrationFramed() {
        let content = ProtectionPlanDelayConsequenceContent.default
        XCTAssertEqual(content.title, "A quick check-in")
        XCTAssertEqual(content.subtitle, "What does missing or delaying usually feel like?")
        XCTAssertEqual(
            content.helper,
            "Understanding your feelings helps us calibrate the right level of support."
        )
        XCTAssertEqual(
            content.footnote,
            "Selected option is used to adjust notification tone and frequency."
        )
        XCTAssertEqual(content.primaryCTA, "Continue")
        XCTAssertEqual(content.choices, DelayConsequence.allCases)
    }

    func testDelayConsequenceContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanDelayConsequenceContent.default.visibleCopy {
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
        XCTAssertFalse(line.contains("%"), "Question copy must not invent stats: \(line)", file: file, line: lineNumber)
    }
}
