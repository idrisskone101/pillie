//
//  ProtectionPlanOnboardingContentTests.swift
//  PillieTests
//
//  Verifies the onboarding copy matches the Superdesign drafts and respects Pillie's
//  privacy boundary (no medical claims). Value-type only, so it runs without a host
//  crash.
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

    func testEarlyValueProofExposesVisibleSkipDemoAction() {
        XCTAssertEqual(ProtectionPlanEarlyValueProofContent.default.skipDemoCTA, "Skip demo")
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
        let drag = ProtectionPlanEarlyValueProofContent.localized(
            locale: Locale(identifier: "en_US")
        ).dragCTA
        XCTAssertEqual(drag, "Drag to your apps")
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

    // MARK: - Personalized Diagnosis (#78)

    func testDiagnosisContentUsesAnalyzeThenVerifyCopyNotAClinicalReadout() {
        let content = ProtectionPlanDiagnosisContent.default
        XCTAssertEqual(content.eyebrow, "FINAL STEP")
        XCTAssertEqual(content.analyzingTitle, "Building your protection plan")
        XCTAssertEqual(content.analyzingSubtitle, "Analyzing your habits and focus zones")
        XCTAssertEqual(content.protectedAppsHeader, "Protected apps")
        // The reveal now leads straight into the paywall, so the CTA reflects that.
        XCTAssertEqual(content.primaryCTA, "Activate my plan")
        // The word "diagnosis" must never reach the user — the screen reveals a plan.
        for line in content.visibleCopy {
            XCTAssertFalse(line.lowercased().contains("diagnos"), "User copy must not say diagnosis: \(line)")
        }
    }

    func testDiagnosisContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanDiagnosisContent.default.visibleCopy {
            assertNoMedicalOrFakeClaims(line)
            XCTAssertFalse(line.contains("%"), "Diagnosis copy must not invent stats: \(line)")
        }
    }

    // MARK: - Mechanism Proof (#78)

    func testMechanismProofShowsTheThreeStepLoopInOrder() {
        let content = ProtectionPlanMechanismProofContent(method: .pill)
        XCTAssertEqual(content.steps.map(\.phase), ["TRIGGER", "ENFORCE", "RELEASE"])
        // Beat 1 rings, beat 2 locks, beat 3 unlocks — the cause/effect loop.
        XCTAssertEqual(content.trigger.title, "Reminder rings")
        XCTAssertTrue(content.enforce.title.lowercased().contains("lock"))
        XCTAssertTrue(content.release.title.lowercased().contains("unlock"))
        XCTAssertEqual(content.replayCTA, "Replay")
        XCTAssertEqual(content.continueCTA, "Continue")
    }

    func testMechanismProofIsMethodAwareInCopyAndCTA() {
        XCTAssertTrue(ProtectionPlanMechanismProofContent(method: .pill).headline.contains("take your pill"))
        XCTAssertTrue(ProtectionPlanMechanismProofContent(method: .patch).headline.contains("change your patch"))
        XCTAssertTrue(ProtectionPlanMechanismProofContent(method: .ring).headline.contains("check your ring"))

        XCTAssertEqual(ProtectionPlanMechanismProofContent(method: .pill).markTakenCTA, "I took my pill")
        XCTAssertEqual(ProtectionPlanMechanismProofContent(method: .patch).markTakenCTA, "I changed my patch")
        XCTAssertEqual(ProtectionPlanMechanismProofContent(method: .ring).markTakenCTA, "I checked my ring")
    }

    func testMechanismProofNeverLeaksPillWordingForPatchOrRing() {
        // The #77 contract: no pill-specific wording in a patch/ring plan. The brand
        // "Pillie" legitimately starts with "pill", so scrub it before scanning —
        // any remaining "pill" is a real leak (pill / pill time / your pill / take
        // your pill).
        for method in [ContraceptiveMethod.patch, .ring] {
            let scrubbed = ProtectionPlanMechanismProofContent(method: method)
                .visibleCopy.joined(separator: " ").lowercased()
                .replacingOccurrences(of: "pillie", with: "")
            XCTAssertFalse(scrubbed.contains("pill"), "\(method) proof leaked pill wording.")
        }
    }

    func testMechanismProofContentHasNoMedicalOrFakeStatLanguage() {
        for method in ContraceptiveMethod.allCases {
            for line in ProtectionPlanMechanismProofContent(method: method).visibleCopy {
                assertNoMedicalOrFakeClaims(line)
                XCTAssertFalse(line.contains("%"), "Proof copy must not invent stats: \(line)")
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
