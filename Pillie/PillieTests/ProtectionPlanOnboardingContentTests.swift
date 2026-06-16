//
//  ProtectionPlanOnboardingContentTests.swift
//  PillieTests
//
//  Verifies the Welcome + Analytics Consent copy matches the Superdesign drafts
//  and respects Pillie's privacy boundary (no medical claims; names exactly what
//  analytics never collects). Value-type only, so it runs without a host crash.
//

import XCTest

@testable import Pillie

final class ProtectionPlanOnboardingContentTests: XCTestCase {
    // MARK: - Welcome

    func testWelcomeContentMatchesDraftAndLeadsWithTheBlockingDifferentiator() {
        let content = ProtectionPlanWelcomeContent.default
        XCTAssertEqual(content.title, "Pill reminders that fight back.")
        XCTAssertEqual(content.primaryCTA, "Build my plan")
        XCTAssertTrue(
            content.subtitle.lowercased().contains("block"),
            "Welcome must lead with the app-blocking differentiator."
        )
    }

    func testWelcomeContentHasNoMedicalOrFakeUrgencyLanguage() {
        for line in ProtectionPlanWelcomeContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Analytics Consent

    func testAnalyticsConsentContentMatchesDraftCopyAndCTAs() {
        let content = ProtectionPlanAnalyticsConsentContent.default
        XCTAssertEqual(content.title, "Help improve Pillie?")
        XCTAssertEqual(content.allowCTA, "Allow Analytics")
        XCTAssertEqual(content.declineCTA, "Not Now")
        XCTAssertEqual(content.points.count, 3)
        XCTAssertEqual(content.points.map(\.title), ["Strict Privacy", "Technical Health", "No Tracking"])
    }

    func testAnalyticsConsentNamesWhatIsNeverCollected() {
        let strictPrivacy = ProtectionPlanAnalyticsConsentContent.default.points[0].detail.lowercased()
        // PRD privacy boundary: method, reminder time, and typed text are never sent.
        XCTAssertTrue(strictPrivacy.contains("method"))
        XCTAssertTrue(strictPrivacy.contains("reminder time"))
        XCTAssertTrue(strictPrivacy.contains("typed text"))
    }

    func testAnalyticsConsentDisclaimsAdTrackingAndThirdPartySharing() {
        let noTracking = ProtectionPlanAnalyticsConsentContent.default.points[2].detail.lowercased()
        XCTAssertTrue(noTracking.contains("ad tracking"))
        XCTAssertTrue(noTracking.contains("third-party"))
    }

    func testAnalyticsConsentContentHasNoMedicalOrFakeUrgencyLanguage() {
        for line in ProtectionPlanAnalyticsConsentContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Helpers

    private func assertNoMedicalOrFakeClaims(
        _ line: String,
        file: StaticString = #filePath,
        line lineNumber: UInt = #line
    ) {
        let banned = ["doctor", "prescri", "diagnos", "guarantee", "clinically", "% of users", "FDA"]
        let lowered = line.lowercased()
        for term in banned {
            XCTAssertFalse(
                lowered.contains(term.lowercased()),
                "Copy must avoid medical/fake claims; found \"\(term)\" in: \(line)",
                file: file,
                line: lineNumber
            )
        }
    }
}
