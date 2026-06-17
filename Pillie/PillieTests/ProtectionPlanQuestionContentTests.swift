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

    // MARK: - Failure Frequency (#76)

    func testFailureFrequencyUsesNewLabelsOverTheExistingStorageBuckets() {
        let content = ProtectionPlanFailureFrequencyContent.default
        XCTAssertEqual(content.title, "How often do reminders fail you?")
        XCTAssertEqual(
            content.subtitle,
            "Being honest helps us adjust the Pillie Protection level for your needs."
        )
        XCTAssertEqual(content.primaryCTA, "Continue")

        // Acceptance criterion: exactly these labels, in ascending order.
        XCTAssertEqual(
            content.options.map(\.title),
            ["Rarely", "A few times a month", "Weekly", "Multiple times a week"]
        )
        // ...while each maps onto a distinct existing MissFrequency bucket, covering
        // all four, so persisted miss-frequency answers stay compatible.
        XCTAssertEqual(content.options.map(\.bucket), [.rarely, .sometimes, .often, .almostDaily])
        XCTAssertEqual(Set(content.options.map(\.bucket)), Set(MissFrequency.allCases))
    }

    func testFailureFrequencyContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanFailureFrequencyContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Risk Window (#76)

    func testRiskWindowContentMakesClearItDoesNotChangeTheSchedule() {
        let content = ProtectionPlanRiskWindowContent.default
        XCTAssertEqual(content.title, "Timing is everything")
        XCTAssertEqual(content.subtitle, "When are you most likely to drift into another app?")
        XCTAssertEqual(content.footnote, "This shapes your plan \u{2014} we don't use it to schedule alarms.")
        XCTAssertEqual(content.primaryCTA, "Continue")
        XCTAssertEqual(content.choices, RiskWindow.allCases)

        // The single bottom reassurance must explicitly tell the user this does not
        // drive the actual blocking schedule (v1 keeps Risk Window as copy only).
        XCTAssertTrue(content.footnote.lowercased().contains("schedule alarms"))
    }

    func testRiskWindowContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanRiskWindowContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Draft Blocked Apps (#76)

    func testDraftBlockedAppsContentIsGroupedMultiSelectWithOtherAndScreenTimeSeparation() {
        let content = ProtectionPlanDraftBlockedAppsContent.default
        XCTAssertEqual(content.title, "Which apps should Pillie protect pill time from?")
        XCTAssertEqual(
            content.subtitle,
            "Choose categories or specific apps to draft your distraction blocklist."
        )
        XCTAssertEqual(content.primaryCTA, "Save Selections")
        XCTAssertEqual(content.categories, DraftBlockedAppChoice.categories)
        XCTAssertEqual(content.apps, DraftBlockedAppChoice.apps)
        XCTAssertEqual(content.other, .other)
        XCTAssertTrue(content.other.isOther)

        // Must clearly keep the draft separate from the real Screen Time selection.
        let footnote = content.footnote.lowercased()
        XCTAssertTrue(footnote.contains("draft"))
        XCTAssertTrue(footnote.contains("screen time"))
    }

    func testDraftBlockedAppsContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanDraftBlockedAppsContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Acquisition Source (#76)

    func testAcquisitionSourceContentIsOptionalAndDistinctFromDistractionChoices() {
        let content = ProtectionPlanAcquisitionSourceContent.default
        XCTAssertEqual(content.eyebrow, "One last thing")
        XCTAssertEqual(content.title, "Where did you find Pillie?")
        XCTAssertEqual(
            content.subtitle,
            "Your feedback helps us reach more people who need protection."
        )
        XCTAssertEqual(content.primaryCTA, "Finish Setup")
        // Optional: there is a real skip path.
        XCTAssertFalse(content.skipCTA.isEmpty)
        XCTAssertEqual(content.skipCTA, "Not now")
        XCTAssertEqual(content.choices, AcquisitionSource.allCases)

        // Distinct from Distraction Choices: it is its own type, not a DistractionChoice.
        XCTAssertFalse(content.choices.isEmpty)
        XCTAssertTrue(type(of: content.choices) == [AcquisitionSource].self)
    }

    func testAcquisitionSourceContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanAcquisitionSourceContent.default.visibleCopy {
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
