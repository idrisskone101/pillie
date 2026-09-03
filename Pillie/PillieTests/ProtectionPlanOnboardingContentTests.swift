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
    private let english = Locale(identifier: "en_US")

    // MARK: - Welcome

    func testWelcomeContentMatchesCurrentReminderFirstCopy() {
        let content = ProtectionPlanWelcomeContent.localized(locale: english)
        XCTAssertEqual(
            content.title,
            PillieLocalization.string("onboarding.welcome.title", locale: english)
        )
        XCTAssertEqual(
            content.primaryCTA,
            PillieLocalization.string("global.action.get_started", locale: english)
        )
        XCTAssertEqual(
            content.subtitle,
            PillieLocalization.string("onboarding.welcome.subtitle", locale: english)
        )
    }

    func testWelcomeContentHasNoMedicalOrFakeUrgencyLanguage() {
        for line in ProtectionPlanWelcomeContent.localized(locale: english).visibleCopy {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    // MARK: - Early Value Proof (#74)

    func testEarlyValueProofCommunicatesReminderPauseAndRelease() {
        let content = ProtectionPlanEarlyValueProofContent.localized(locale: english)
        XCTAssertEqual(content.beats.count, 3, "The proof reads as three beats: reminder, pause, release.")

        // Beat 1 — the reminder arrives and asks for the action to be logged.
        let first = (content.drift.title + " " + content.drift.detail).lowercased()
        XCTAssertTrue(first.contains("reminder"), "Beat 1 must name the reminder.")
        XCTAssertTrue(first.contains("log"), "Beat 1 must explain the check-in action.")

        // Beat 2 — selected apps pause until the user confirms.
        let second = (content.checkpoint.title + " " + content.checkpoint.detail).lowercased()
        XCTAssertTrue(second.contains("pause"), "Beat 2 must show the selected apps pausing.")
        XCTAssertTrue(second.contains("confirm"), "Beat 2 must explain how the pause ends.")

        // Beat 3 — logging the action makes the apps available again.
        let third = (content.resolved.title + " " + content.resolved.detail).lowercased()
        XCTAssertTrue(third.contains("available"), "Beat 3 must make the apps available again.")
        XCTAssertTrue(third.contains("logged"), "Beat 3 must follow a logged action.")
    }

    func testEarlyValueProofCopyAvoidsConfusingJargon() {
        // Terms the team flagged as unclear for the women's-health audience.
        let banned = ["drift", "endless scroll", "social guard", "held"]
        for line in ProtectionPlanEarlyValueProofContent.localized(locale: english).visibleCopy {
            let lowered = line.lowercased()
            for term in banned {
                XCTAssertFalse(lowered.contains(term), "Copy should avoid the unclear term \"\(term)\": \(line)")
            }
        }
    }

    func testEarlyValueProofExposesCheckInAndContinueCTAs() {
        let content = ProtectionPlanEarlyValueProofContent.localized(locale: english)
        XCTAssertEqual(
            content.checkInCTA,
            PillieLocalization.string("notification.action.complete", locale: english)
        )
        XCTAssertEqual(
            content.continueCTA,
            PillieLocalization.string("global.action.continue", locale: english)
        )
    }

    func testEarlyValueProofExposesVisibleSkipDemoAction() {
        XCTAssertEqual(
            ProtectionPlanEarlyValueProofContent.localized(locale: english).skipDemoCTA,
            PillieLocalization.string("global.action.not_now", locale: english)
        )
    }

    func testEarlyValueProofIdleLineIsOnTopic() {
        // The idle line is the enticing hook; the lock mechanic now lives in the
        // CTA + the demo, so the idle line only needs to stay about the pill.
        let rest = ProtectionPlanEarlyValueProofContent.localized(locale: english).restCue.lowercased()
        XCTAssertFalse(rest.isEmpty)
        XCTAssertTrue(rest.contains("pause"))
    }

    func testEarlyValueProofRestCTAInstructsTheDrag() {
        // At rest the CTA must instruct the drag (so the demo isn't skipped), not
        // offer a one-tap "I took my pill".
        let drag = ProtectionPlanEarlyValueProofContent.localized(
            locale: Locale(identifier: "en_US")
        ).dragCTA
        XCTAssertEqual(drag, "drag this onto your apps.")
        XCTAssertTrue(drag.lowercased().contains("drag"))
    }

    func testEarlyValueProofTeachesTheShakeCheckIn() {
        let content = ProtectionPlanEarlyValueProofContent.localized(locale: english)
        // The locked-state cue + CTA teach the real check-in gesture: a phone shake.
        XCTAssertTrue(content.shakeCue.lowercased().contains("shake"))
        XCTAssertTrue(content.shakeCue.lowercased().contains("phone"))
        XCTAssertEqual(content.shakeToTakeCTA, "Try Shake to Confirm")
        // The static / VoiceOver narrative still explains the pause-and-log loop.
        XCTAssertTrue(content.resolved.detail.lowercased().contains("logged"))
        XCTAssertTrue(content.resolved.title.lowercased().contains("available"))
        XCTAssertTrue(content.accessibilitySummary.lowercased().contains("check"))
    }

    func testEarlyValueProofHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanEarlyValueProofContent.localized(locale: english).visibleCopy {
            assertNoMedicalOrFakeClaims(line)
            XCTAssertFalse(
                line.contains("%"),
                "Proof must not invent effectiveness stats; found a percentage in: \(line)"
            )
        }
    }

    func testEarlyValueProofUsesAGenericAppStandInNotThirdPartyBrands() {
        let brands = ["tiktok", "instagram", "snapchat", "youtube", "facebook", "reddit"]
        for line in ProtectionPlanEarlyValueProofContent.localized(locale: english).visibleCopy {
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
        let content = ProtectionPlanDiagnosisContent.localized(locale: english)
        XCTAssertEqual(content.eyebrow, "next")
        XCTAssertEqual(content.analyzingTitle, "Your personalised reminder plan")
        XCTAssertEqual(content.analyzingSubtitle, "Built from the routine you selected.")
        XCTAssertEqual(content.protectedAppsHeader, "Protected apps")
        XCTAssertEqual(content.primaryCTA, "Continue")
        // The word "diagnosis" must never reach the user — the screen reveals a plan.
        for line in content.visibleCopy {
            XCTAssertFalse(line.lowercased().contains("diagnos"), "User copy must not say diagnosis: \(line)")
        }
    }

    func testDiagnosisContentHasNoMedicalOrFakeStatLanguage() {
        for line in ProtectionPlanDiagnosisContent.localized(locale: english).visibleCopy {
            assertNoMedicalOrFakeClaims(line)
            XCTAssertFalse(line.contains("%"), "Diagnosis copy must not invent stats: \(line)")
        }
    }

    // MARK: - Mechanism Proof (#78)

    func testMechanismProofShowsTheThreeStepLoopInOrder() {
        let content = ProtectionPlanMechanismProofContent(method: .pill, locale: english)
        XCTAssertEqual(content.steps.map(\.phase), ["REMINDER", "APP PAUSE", "CONTINUE"])
        // Beat 1 rings, beat 2 locks, beat 3 unlocks — the cause/effect loop.
        XCTAssertEqual(content.trigger.title, "Reminder rings")
        XCTAssertTrue(content.enforce.title.lowercased().contains("pause"))
        XCTAssertTrue(content.release.title.lowercased().contains("log"))
        XCTAssertEqual(content.replayCTA, "Replay")
        XCTAssertEqual(content.continueCTA, "Continue")
    }

    func testMechanismProofIsMethodAwareInCopyAndCTA() {
        XCTAssertEqual(
            Set(ContraceptiveMethod.allCases.map {
                ProtectionPlanMechanismProofContent(method: $0, locale: english).headline
            }).count,
            1,
            "The shared explanation should stay compact while the action remains method-aware."
        )

        XCTAssertEqual(ProtectionPlanMechanismProofContent(method: .pill, locale: english).markTakenCTA, "I took my pill")
        XCTAssertEqual(ProtectionPlanMechanismProofContent(method: .patch, locale: english).markTakenCTA, "I changed my patch")
        XCTAssertEqual(ProtectionPlanMechanismProofContent(method: .ring, locale: english).markTakenCTA, "I checked my ring")
    }

    func testMechanismProofPresentsCompleteIdiomaticGermanCopy() {
        let german = Locale(identifier: "de_DE")
        let content = ProtectionPlanMechanismProofContent(method: .pill, locale: german)

        XCTAssertEqual(content.eyebrow, "SO FUNKTIONIERT’S")
        XCTAssertEqual(
            content.headline,
            "Deine Apps werden wieder verfügbar, sobald du die heutige Aktion protokollierst."
        )
        XCTAssertEqual(
            content.steps.map { [$0.phase, $0.title, $0.detail] },
            [
                ["ERINNERUNG", "Erinnerung klingelt", "Eine sanfte Erinnerung zur gewählten Zeit."],
                ["APP-PAUSE", "Ablenkende Apps pausieren", "Ausgewählte Apps bleiben pausiert, bis du die Aktion protokollierst."],
                ["WEITER", "Aktion protokollieren", "Danach sind deine Apps sofort wieder verfügbar."],
            ]
        )
        XCTAssertEqual(content.lockedLabel, "PAUSIERT")
        XCTAssertEqual(content.markTakenCTA, "Ich habe meine Pille genommen")
        XCTAssertEqual(
            ProtectionPlanMechanismProofContent(method: .patch, locale: german).markTakenCTA,
            "Ich habe mein Pflaster gewechselt"
        )
        XCTAssertEqual(
            ProtectionPlanMechanismProofContent(method: .ring, locale: german).markTakenCTA,
            "Ich habe meinen Ring geprüft"
        )
        XCTAssertEqual(content.replayCTA, "Noch einmal")
        XCTAssertEqual(content.continueCTA, "Weiter")
        XCTAssertEqual(content.footer, "Teil deines Pillie-Erinnerungsplans.")
        XCTAssertEqual(
            content.unlockedConfirmation,
            "Erledigt — deine Apps sind wieder verfügbar."
        )
        XCTAssertEqual(
            content.replayAccessibilityHint,
            "Spielt die Demonstration der App-Pause erneut ab."
        )
        XCTAssertFalse(content.visibleCopy.joined(separator: " ").contains("HOW IT WORKS"))
    }

    func testMechanismProofNeverLeaksPillWordingForPatchOrRing() {
        // The #77 contract: no pill-specific wording in a patch/ring plan. The brand
        // "Pillie" legitimately starts with "pill", so scrub it before scanning —
        // any remaining "pill" is a real leak (pill / pill time / your pill / take
        // your pill).
        for method in [ContraceptiveMethod.patch, .ring] {
            let scrubbed = ProtectionPlanMechanismProofContent(method: method, locale: english)
                .visibleCopy.joined(separator: " ").lowercased()
                .replacingOccurrences(of: "pillie", with: "")
            XCTAssertFalse(scrubbed.contains("pill"), "\(method) proof leaked pill wording.")
        }
    }

    func testMechanismProofContentHasNoMedicalOrFakeStatLanguage() {
        for method in ContraceptiveMethod.allCases {
            for line in ProtectionPlanMechanismProofContent(method: method, locale: english).visibleCopy {
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
