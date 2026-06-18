//
//  ProtectionPlanDiagnosisTests.swift
//  PillieTests
//
//  Covers the Personalized Diagnosis slice (#78): the deterministic Primary
//  Distraction derivation, the protected-apps list, and the method-aware,
//  privacy-safe copy of the Draft Pill Protection Plan. Value types only, so there
//  is no main-actor `@Observable` deinit hazard in the test host.
//

import XCTest

@testable import Pillie

final class ProtectionPlanDiagnosisTests: XCTestCase {
    // MARK: - DistractionApp (the canonical named-app vocabulary)

    func testDistractionAppDisplayNamesAndCanonicalPriorityOrder() {
        // Canonical priority is the declaration order: scroll-first apps outrank
        // Messages, so a tie always resolves the same way.
        XCTAssertEqual(
            DistractionApp.allCases,
            [.tiktok, .instagram, .snapchat, .youtube, .x, .messages]
        )
        XCTAssertEqual(
            DistractionApp.allCases.map(\.displayName),
            ["TikTok", "Instagram", "Snapchat", "YouTube", "X", "Messages"]
        )
        for app in DistractionApp.allCases {
            XCTAssertFalse(app.symbolName.isEmpty, "\(app) needs an SF Symbol.")
        }
    }

    // MARK: - Primary Distraction: draft-blocked-apps tier (slice 1)

    func testPrimaryDistractionPrefersDraftBlockedAppsByCanonicalPriority() {
        // Both named in the "which apps should Pillie block" answer — the highest
        // canonical priority (TikTok) wins, regardless of Set ordering.
        let primary = ProtectionPlanDiagnosisEngine.primaryDistraction(
            distractionChoices: [],
            draftBlockedApps: [.instagram, .tiktok]
        )
        XCTAssertEqual(primary, .app(.tiktok))
    }

    func testPrimaryDistractionResolvesCanonicalTieBreakDeterministically() {
        // Instagram outranks YouTube outranks X.
        let primary = ProtectionPlanDiagnosisEngine.primaryDistraction(
            distractionChoices: [],
            draftBlockedApps: [.youtube, .x, .instagram]
        )
        XCTAssertEqual(primary, .app(.instagram))
    }

    func testPrimaryDistractionMapsTheDraftMessagesCategoryToMessages() {
        let primary = ProtectionPlanDiagnosisEngine.primaryDistraction(
            distractionChoices: [],
            draftBlockedApps: [.messages]
        )
        XCTAssertEqual(primary, .app(.messages))
    }

    // MARK: - Primary Distraction: distraction-choices fallback tier (slice 2)

    func testPrimaryDistractionFallsBackToDistractionChoicesWhenNoDraftApps() {
        // Draft answer is categories-only (no named app), so the named apps from the
        // Distraction Choices answer are used instead.
        let primary = ProtectionPlanDiagnosisEngine.primaryDistraction(
            distractionChoices: [.youtube, .tiktok],
            draftBlockedApps: [.shortVideos, .games]
        )
        XCTAssertEqual(primary, .app(.tiktok))
    }

    func testDraftBlockedAppsOutrankDistractionChoices() {
        // The draft-blocked tier wins even when a distraction choice has a higher
        // canonical priority: the user's explicit "block this" answer is preferred.
        let primary = ProtectionPlanDiagnosisEngine.primaryDistraction(
            distractionChoices: [.tiktok],
            draftBlockedApps: [.instagram]
        )
        XCTAssertEqual(primary, .app(.instagram))
    }

    // MARK: - Primary Distraction: safe generic fallback (slice 3)

    func testPrimaryDistractionIsGenericWhenOnlyCategoriesSelected() {
        let primary = ProtectionPlanDiagnosisEngine.primaryDistraction(
            distractionChoices: [],
            draftBlockedApps: [.shortVideos, .socialFeeds, .games]
        )
        XCTAssertEqual(primary, .generic)
    }

    func testPrimaryDistractionIsGenericWhenOnlyBehaviorsSelected() {
        let primary = ProtectionPlanDiagnosisEngine.primaryDistraction(
            distractionChoices: [.snooze, .busy, .forget],
            draftBlockedApps: []
        )
        XCTAssertEqual(primary, .generic)
    }

    func testPrimaryDistractionIsGenericForOtherOnly() {
        let primary = ProtectionPlanDiagnosisEngine.primaryDistraction(
            distractionChoices: [.other],
            draftBlockedApps: [.other]
        )
        XCTAssertEqual(primary, .generic)
    }

    func testPrimaryDistractionIsGenericWhenNothingSelected() {
        let primary = ProtectionPlanDiagnosisEngine.primaryDistraction(
            distractionChoices: [],
            draftBlockedApps: []
        )
        XCTAssertEqual(primary, .generic)
    }

    func testPrimaryDistractionDisplayNameAndSpecificity() {
        XCTAssertEqual(PrimaryDistraction.app(.tiktok).displayName, "TikTok")
        XCTAssertTrue(PrimaryDistraction.app(.tiktok).isSpecific)
        XCTAssertEqual(PrimaryDistraction.generic.displayName, "your distracting apps")
        XCTAssertFalse(PrimaryDistraction.generic.isSpecific)
    }

    // MARK: - Protected apps list (slice 4)

    func testProtectedAppsAreCanonicalOrderedAndDeduped() {
        let apps = ProtectionPlanDiagnosisEngine.protectedApps(
            distractionChoices: [.tiktok, .instagram],
            draftBlockedApps: [.x, .tiktok]
        )
        // Union of {tiktok, instagram} and {x, tiktok}, canonical-ordered, deduped.
        XCTAssertEqual(apps, [.tiktok, .instagram, .x])
    }

    func testProtectedAppsAreCappedAtThree() {
        let apps = ProtectionPlanDiagnosisEngine.protectedApps(
            distractionChoices: [],
            draftBlockedApps: [.tiktok, .instagram, .youtube, .x, .snapchat]
        )
        // Canonical order is tiktok, instagram, snapchat, youtube, x → first three.
        XCTAssertEqual(apps, [.tiktok, .instagram, .snapchat])
    }

    func testProtectedAppsAreEmptyWhenNoNamedAppsSelected() {
        let apps = ProtectionPlanDiagnosisEngine.protectedApps(
            distractionChoices: [.snooze, .other],
            draftBlockedApps: [.shortVideos, .games]
        )
        XCTAssertTrue(apps.isEmpty)
    }

    // MARK: - Method-aware diagnosis copy (slice 5)

    private func diagnosis(
        primary: PrimaryDistraction = .app(.tiktok),
        protectedApps: [DistractionApp] = [.tiktok, .instagram, .x],
        method: ContraceptiveMethod,
        time: String = "8:00 AM",
        riskWindow: RiskWindow? = .rightAfterAlarm
    ) -> ProtectionPlanDiagnosis {
        ProtectionPlanDiagnosis(
            primaryDistraction: primary,
            protectedApps: protectedApps,
            method: method,
            dueActionTimeText: time,
            riskWindow: riskWindow
        )
    }

    func testDiagnosisHeadlineUsesTheMethodWord() {
        XCTAssertEqual(diagnosis(method: .pill).headline, "Your Draft Pill Protection Plan")
        XCTAssertEqual(diagnosis(method: .patch).headline, "Your Draft Patch Protection Plan")
        XCTAssertEqual(diagnosis(method: .ring).headline, "Your Draft Ring Protection Plan")
    }

    func testDiagnosisLeadLineNamesThePrimaryDistractionAndDueActionTime() {
        let lead = diagnosis(primary: .app(.tiktok), method: .pill, time: "8:00 AM").leadLine
        XCTAssertTrue(lead.contains("TikTok"), "Specific lead should name the app: \(lead)")
        XCTAssertTrue(lead.contains("8:00 AM"), "Lead should reference the Due Action Time: \(lead)")
        XCTAssertTrue(lead.contains("take your pill"), "Pill lead should use the pill action: \(lead)")
    }

    func testDiagnosisLeadLineIsMethodAwareForPatchAndRing() {
        XCTAssertTrue(diagnosis(method: .patch).leadLine.contains("change your patch"))
        XCTAssertTrue(diagnosis(method: .ring).leadLine.contains("check your ring"))
    }

    func testDiagnosisGenericLeadLineAvoidsNamingAnApp() {
        let lead = diagnosis(primary: .generic, protectedApps: [], method: .pill).leadLine
        XCTAssertTrue(lead.lowercased().contains("distracting apps"), "Generic lead frames apps broadly: \(lead)")
        XCTAssertTrue(lead.contains("8:00 AM"))
    }

    func testDiagnosisNeverLeaksPillWordingForPatchOrRing() {
        // The #77 contract: no pill-specific wording in a patch/ring plan. The brand
        // "Pillie" legitimately starts with "pill", so scrub it before scanning —
        // any remaining "pill" is a real leak.
        for method in [ContraceptiveMethod.patch, .ring] {
            let scrubbed = diagnosis(method: method).visibleCopy
                .joined(separator: " ").lowercased()
                .replacingOccurrences(of: "pillie", with: "")
            XCTAssertFalse(scrubbed.contains("pill"), "\(method) plan leaked pill wording.")
        }
    }

    func testLockMechanismSummaryIsGenericAndMethodAware() {
        // The app-lock card no longer depends on a chosen app list, so its copy must
        // read on its own: generic "distracting apps", method-aware action verb, no
        // specific brand even when one was derived.
        let pill = diagnosis(primary: .app(.tiktok), method: .pill).lockMechanismSummary
        XCTAssertTrue(pill.lowercased().contains("distracting apps"), "Summary should frame apps broadly: \(pill)")
        XCTAssertTrue(pill.contains("take your pill"), "Pill summary should use the pill action: \(pill)")
        XCTAssertFalse(pill.contains("TikTok"), "Summary must not name a specific app: \(pill)")

        XCTAssertTrue(diagnosis(method: .patch).lockMechanismSummary.contains("change your patch"))
        XCTAssertTrue(diagnosis(method: .ring).lockMechanismSummary.contains("check your ring"))
    }

    func testDiagnosisCardValuesReflectTheDerivedPlan() {
        let plan = diagnosis(primary: .app(.tiktok), protectedApps: [.tiktok, .instagram, .x], method: .pill, time: "8:00 AM")
        XCTAssertEqual(plan.mainRiskValue, "TikTok")
        XCTAssertEqual(plan.windowValue, "8:00 AM")
        XCTAssertEqual(plan.protectionModeValue, "Auto-Lock")
        XCTAssertEqual(plan.protectedAppsLabel, "TikTok, Instagram, X")
    }

    func testDiagnosisGenericCardValuesFallBackSafely() {
        let plan = diagnosis(primary: .generic, protectedApps: [], method: .pill)
        XCTAssertEqual(plan.mainRiskValue, "Distracting apps")
        XCTAssertFalse(plan.protectedAppsLabel.isEmpty)
    }

    // MARK: - Detected signals (analyze chips) + strategy points (verified card)

    func testDetectedSignalsReflectPrimaryDistractionTimeAndRiskWindow() {
        let plan = diagnosis(primary: .app(.tiktok), method: .pill, time: "8:00 AM", riskWindow: .rightAfterAlarm)
        XCTAssertEqual(plan.detectedSignals, ["TikTok", "8:00 AM", "Right after the alarm"])
    }

    func testDetectedSignalsOmitRiskWindowWhenUnanswered() {
        let plan = diagnosis(primary: .app(.tiktok), method: .pill, time: "8:00 AM", riskWindow: nil)
        XCTAssertEqual(plan.detectedSignals, ["TikTok", "8:00 AM"])
    }

    func testDetectedSignalsDrawFromFrequencyFeelingAndHabitAnswers() {
        // The analyzing chips should reflect the user's own answers across the flow,
        // so the plan feels built from what they told us.
        let plan = ProtectionPlanDiagnosis(
            primaryDistraction: .app(.tiktok),
            protectedApps: [.tiktok],
            method: .pill,
            dueActionTimeText: "9:30 PM",
            riskWindow: .withinFiveMinutes,
            distractionChoices: [.tiktok, .snooze, .forget],
            delayConsequence: .stressful,
            missFrequency: .often
        )
        let chips = plan.detectedSignals
        XCTAssertTrue(chips.contains("TikTok"))
        XCTAssertTrue(chips.contains("9:30 PM"))
        XCTAssertTrue(chips.contains("Within 5 minutes"))
        XCTAssertTrue(chips.contains("Weekly slips"), "Failure frequency should surface: \(chips)")
        XCTAssertTrue(chips.contains("Late = stress"), "Delay-consequence feeling should surface: \(chips)")
        XCTAssertTrue(
            chips.contains("Snoozes reminders") || chips.contains("Easy to forget"),
            "A specific habit should surface: \(chips)"
        )
        XCTAssertLessThanOrEqual(chips.count, 6, "Chips are capped so the scan stays readable.")
        XCTAssertEqual(Set(chips).count, chips.count, "Chips must be de-duplicated.")
    }

    func testDetectedSignalsSkipTheDontCareFeeling() {
        let plan = ProtectionPlanDiagnosis(
            primaryDistraction: .generic,
            protectedApps: [],
            method: .pill,
            dueActionTimeText: "8:00 AM",
            riskWindow: nil,
            distractionChoices: [],
            delayConsequence: .dontCare,
            missFrequency: nil
        )
        // "I don't care much" is not surfaced as a chip (nothing judgmental).
        XCTAssertEqual(plan.detectedSignals, ["Distracting apps", "8:00 AM"])
    }

    func testStrategyLockPointIsTimeAwareMethodAwareAndNamesNoBrand() {
        // The lock point stays concrete (the time + the method-aware action) but never
        // names a specific app, even when one was derived — avoiding trademark snags.
        let pill = diagnosis(primary: .app(.tiktok), protectedApps: [.tiktok, .instagram], method: .pill, time: "9:30 PM").strategyPoints
        XCTAssertEqual(pill.count, 3)
        XCTAssertTrue(pill[0].contains("9:30 PM"), "Lock point names the time: \(pill[0])")
        XCTAssertTrue(pill[0].contains("take your pill"), "Lock point is method-aware: \(pill[0])")
        XCTAssertTrue(pill[0].lowercased().contains("distracting apps"), "Lock point stays generic: \(pill[0])")
        for brand in ["TikTok", "Instagram", "Snapchat", "YouTube"] {
            XCTAssertFalse(pill[0].contains(brand), "Lock point must not name a brand: \(pill[0])")
        }

        let patch = diagnosis(method: .patch).strategyPoints
        XCTAssertTrue(patch[0].contains("change your patch"), "Patch lock point is method-aware: \(patch[0])")
    }

    func testStrategyRiskPointReflectsTheRiskWindowAnswer() {
        // Each window produces a distinct, recognizable line in Pillie's voice.
        let alarm = diagnosis(method: .pill, riskWindow: .rightAfterAlarm).strategyPoints
        XCTAssertTrue(alarm[1].lowercased().contains("snooze"), "Risk point reflects the window: \(alarm[1])")

        let within = diagnosis(method: .pill, riskWindow: .withinFiveMinutes).strategyPoints
        XCTAssertTrue(within[1].lowercased().contains("first few minutes"), "Risk point reflects the window: \(within[1])")

        let later = diagnosis(method: .pill, riskWindow: .laterInDay).strategyPoints
        XCTAssertTrue(later[1].lowercased().contains("later"), "Risk point reflects the window: \(later[1])")
    }

    func testDiagnosisCopyUsesNoEmDashes() {
        // Brand voice: never use em dashes anywhere in the user-facing plan copy.
        for line in diagnosis(method: .pill).visibleCopy {
            XCTAssertFalse(line.contains("\u{2014}"), "Copy must not use em dashes: \(line)")
        }
    }

    func testStrategyReassurancePointReflectsHowMissingFeels() {
        let plan = ProtectionPlanDiagnosis(
            primaryDistraction: .app(.tiktok), protectedApps: [.tiktok], method: .pill,
            dueActionTimeText: "9:30 PM", riskWindow: .rightAfterAlarm,
            distractionChoices: [], delayConsequence: .scary, missFrequency: nil
        )
        XCTAssertTrue(
            plan.strategyPoints[2].lowercased().contains("peace of mind"),
            "Reassurance reflects the 'scary' feeling: \(plan.strategyPoints[2])"
        )
    }

    func testStrategyLockPointUsesGenericPhrasingWhenNoNamedApp() {
        let points = diagnosis(primary: .generic, protectedApps: [], method: .pill).strategyPoints
        XCTAssertTrue(points[0].lowercased().contains("distracting apps"), "Generic lock point: \(points[0])")
    }

    // MARK: - Safe-copy boundary (slice 6)

    func testDiagnosisCopyHasNoFakeStatsOrMedicalClaims() {
        // Both the specific and generic variants must stay clear of invented scores,
        // stats, and medical-risk claims. App names are the user's own answer (safe).
        let specific = diagnosis(method: .pill).visibleCopy
        let generic = diagnosis(primary: .generic, protectedApps: [], method: .pill).visibleCopy
        for line in specific + generic {
            assertNoMedicalOrFakeClaims(line)
        }
    }

    func testGenericFallbackNeverEchoesARawOtherAnswer() {
        // Other / non-app answers must derive to .generic, and the rendered plan must
        // never echo a raw "Other" selection back at the user (no free-text leak —
        // acceptance criterion #3: avoid raw sensitive detail).
        let primary = ProtectionPlanDiagnosisEngine.primaryDistraction(
            distractionChoices: [.other],
            draftBlockedApps: [.other]
        )
        XCTAssertEqual(primary, .generic)

        let plan = diagnosis(primary: primary, protectedApps: [], method: .pill)
        let joined = plan.visibleCopy.joined(separator: " ").lowercased()
        XCTAssertFalse(joined.contains("other"), "Generic copy must not echo a raw Other answer: \(joined)")
        XCTAssertEqual(plan.mainRiskValue, "Distracting apps")
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
                "Diagnosis copy must avoid medical/fake claims; found \"\(term)\" in: \(line)",
                file: file,
                line: lineNumber
            )
        }
        XCTAssertFalse(line.contains("%"), "Diagnosis copy must not invent stats: \(line)", file: file, line: lineNumber)
    }
}
