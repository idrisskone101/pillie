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
    func testConsolidatedPersonalizationContentIncludesBothRequiredSections() {
        let intent = ProtectionPlanDistractionChoicesContent.default
        XCTAssertEqual(intent.choices, DistractionChoice.allCases)
        XCTAssertEqual(intent.desiredOutcomes, DelayConsequence.allCases)
        XCTAssertFalse(intent.desiredOutcomeTitle.isEmpty)

        let timing = ProtectionPlanFailureFrequencyContent.default
        XCTAssertEqual(timing.options.map(\.bucket), MissFrequency.allCases)
        XCTAssertEqual(timing.riskWindows, RiskWindow.allCases)
        XCTAssertTrue(timing.riskWindowFootnote.contains("Settings"))

        for line in intent.visibleCopy + timing.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Distraction Choices

    func testDistractionChoicesContentMatchesDraftAndIsMultiSelectWithOther() {
        let content = ProtectionPlanDistractionChoicesContent.default
        XCTAssertEqual(content.title, "What's in the way?")
        XCTAssertEqual(content.subtitle, "Choose the answer that feels closest.")
        XCTAssertEqual(content.helper, "Choose categories or specific apps for your draft blocklist.")
        XCTAssertEqual(content.primaryCTA, "Continue")
        XCTAssertTrue(content.helper.lowercased().contains("blocklist"))
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
        XCTAssertEqual(content.title, "How often?")
        XCTAssertEqual(
            content.subtitle,
            "Your answer helps tailor the reminder support level."
        )
        XCTAssertEqual(content.primaryCTA, "Continue")

        // Acceptance criterion: exactly these labels, in ascending order.
        XCTAssertEqual(
            content.options.map(\.title),
            ["Rarely", "A few times a month", "Weekly", "Several times a week"]
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
        XCTAssertEqual(content.title, "When do you usually drift?")
        XCTAssertEqual(content.subtitle, "Choose the pattern that sounds most like you.")
        XCTAssertEqual(
            content.footnote,
            "This reminder setup is based on your selections. You can change it later in Settings."
        )
        XCTAssertEqual(content.primaryCTA, "Continue")
        XCTAssertEqual(content.choices, RiskWindow.allCases)

        XCTAssertTrue(content.footnote.contains("Settings"))
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
        XCTAssertEqual(content.eyebrow, "Next")
        XCTAssertEqual(content.title, "Where did you find Pillie?")
        XCTAssertEqual(
            content.subtitle,
            "Your answer helps more people find the app."
        )
        XCTAssertEqual(content.primaryCTA, "Continue")
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
