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

    // MARK: - Early Value Proof (#74)

    func testEarlyValueProofCommunicatesReminderLockAndRelease() {
        let content = ProtectionPlanEarlyValueProofContent.default
        XCTAssertEqual(content.beats.count, 3, "The proof reads as three beats: reminder, lock, release.")

        // Beat 1 — it's pill time, and the apps are tempting.
        let first = (content.drift.title + " " + content.drift.detail).lowercased()
        XCTAssertTrue(first.contains("pill"), "Beat 1 must name the pill reminder.")
        XCTAssertTrue(first.contains("app"), "Beat 1 must show the distracting apps.")

        // Beat 2 — Pillie locks the apps until the pill is taken.
        let second = content.checkpoint.detail.lowercased()
        XCTAssertTrue(second.contains("lock"), "Beat 2 must show the apps being locked.")
        XCTAssertTrue(second.contains("pill"), "Beat 2 must gate the lock on taking the pill.")

        // Beat 3 — checking in unlocks the apps.
        let third = content.resolved.detail.lowercased()
        XCTAssertTrue(third.contains("unlock"), "Beat 3 must release the apps once checked in.")
    }

    func testEarlyValueProofCopyAvoidsConfusingJargon() {
        // Terms the team flagged as unclear for the women's-health audience.
        let banned = ["drift", "endless scroll", "social guard", "held"]
        for line in ProtectionPlanEarlyValueProofContent.default.visibleCopy {
            let lowered = line.lowercased()
            for term in banned {
                XCTAssertFalse(lowered.contains(term), "Copy should avoid the unclear term \"\(term)\": \(line)")
            }
        }
    }

    func testEarlyValueProofExposesCheckInAndContinueCTAs() {
        let content = ProtectionPlanEarlyValueProofContent.default
        XCTAssertEqual(content.checkInCTA, "I took my pill")
        XCTAssertEqual(content.continueCTA, "Continue")
    }

    func testEarlyValueProofIdleLineIsOnTopic() {
        // The idle line is the enticing hook; the lock mechanic now lives in the
        // CTA + the demo, so the idle line only needs to stay about the pill.
        let rest = ProtectionPlanEarlyValueProofContent.default.restCue.lowercased()
        XCTAssertFalse(rest.isEmpty)
        XCTAssertTrue(rest.contains("pill"))
    }

    func testEarlyValueProofRestCTAInstructsTheDrag() {
        // At rest the CTA must instruct the drag (so the demo isn't skipped), not
        // offer a one-tap "I took my pill".
        let drag = ProtectionPlanEarlyValueProofContent.default.dragCTA
        XCTAssertEqual(drag, "Drag the dot to your apps")
        XCTAssertTrue(drag.lowercased().contains("drag"))
    }

    func testEarlyValueProofTeachesTheShakeCheckIn() {
        let content = ProtectionPlanEarlyValueProofContent.default
        // The locked-state cue + CTA teach the real check-in gesture: a phone shake.
        XCTAssertTrue(content.shakeCue.lowercased().contains("shake"))
        XCTAssertTrue(content.shakeCue.lowercased().contains("pill"))
        XCTAssertEqual(content.shakeToTakeCTA, "Shake to take your pill")
        // The written resolved beat (the static / VoiceOver narrative) names shaking too.
        XCTAssertTrue(content.resolved.detail.lowercased().contains("shake"))
        XCTAssertTrue(content.resolved.detail.lowercased().contains("unlock"))
        XCTAssertTrue(content.accessibilitySummary.lowercased().contains("shake"))
    }

    func testEarlyValueProofHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanEarlyValueProofContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
            XCTAssertFalse(
                line.contains("%"),
                "Proof must not invent effectiveness stats; found a percentage in: \(line)"
            )
        }
    }

    func testEarlyValueProofUsesAGenericAppStandInNotThirdPartyBrands() {
        let brands = ["tiktok", "instagram", "snapchat", "youtube", "facebook", "reddit"]
        for line in ProtectionPlanEarlyValueProofContent.default.visibleCopy {
            let lowered = line.lowercased()
            for brand in brands {
                XCTAssertFalse(
                    lowered.contains(brand),
                    "Proof copy must use a generic stand-in, not the brand \"\(brand)\": \(line)"
                )
            }
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
