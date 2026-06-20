//
//  ProtectionPlanCompletionTests.swift
//  PillieTests
//

import XCTest

@testable import Pillie

final class ProtectionPlanCompletionTests: XCTestCase {
    // MARK: - Tracer

    func testSavedBlockerConfigAndScreenTimeAuthorizationActivatesProtectionPlan() {
        let outcome = ProtectionPlanCompletion.outcome(
            for: ProtectionPlanCompletion.State(
                isEntitled: true,
                screenTimeAuthorized: true,
                blockerConfigSaved: true
            )
        )

        XCTAssertEqual(outcome, .protectionPlanActivated)
    }

    // MARK: - Reminder-Only Onboarding Completion paths

    func testFreeUserCompletionIsReminderOnly() {
        // Continued free at the paywall: never authorized Screen Time, no config saved.
        let outcome = ProtectionPlanCompletion.outcome(
            for: ProtectionPlanCompletion.State(
                isEntitled: false,
                screenTimeAuthorized: false,
                blockerConfigSaved: false
            )
        )

        XCTAssertEqual(outcome, .reminderOnly)
    }

    func testPlusUserWhoSkipsScreenTimeIsReminderOnly() {
        // Holds entitlement but skipped Screen Time setup, so nothing is saved.
        let outcome = ProtectionPlanCompletion.outcome(
            for: ProtectionPlanCompletion.State(
                isEntitled: true,
                screenTimeAuthorized: false,
                blockerConfigSaved: false
            )
        )

        XCTAssertEqual(outcome, .reminderOnly)
    }

    func testPlusUserWhoDeniesScreenTimeIsReminderOnly() {
        // Authorization was denied; entitlement is retained but blocking is incomplete.
        let outcome = ProtectionPlanCompletion.outcome(
            for: ProtectionPlanCompletion.State(
                isEntitled: true,
                screenTimeAuthorized: false,
                blockerConfigSaved: false
            )
        )

        XCTAssertEqual(outcome, .reminderOnly)
    }

    func testAuthorizedButEmptySelectionIsReminderOnly() {
        // Authorized Screen Time but saved no apps/categories — not activation.
        let outcome = ProtectionPlanCompletion.outcome(
            for: ProtectionPlanCompletion.State(
                isEntitled: true,
                screenTimeAuthorized: true,
                blockerConfigSaved: false
            )
        )

        XCTAssertEqual(outcome, .reminderOnly)
    }

    // MARK: - Ready-screen routing (issue #83)

    func testActivatedUserLandsOnProtectionPlanReady() {
        // AC1: activated users land on Pill Protection Plan Ready after a valid save.
        let state = ProtectionPlanCompletion.State(
            isEntitled: true,
            screenTimeAuthorized: true,
            blockerConfigSaved: true
        )

        XCTAssertTrue(ProtectionPlanCompletion.landsOnProtectionPlanReady(for: state))
    }

    func testReminderOnlyUsersNeverLandOnProtectionPlanReady() {
        // AC5: reminder-only users are not activated and must not see the ready screen.
        let authorizedButEmpty = ProtectionPlanCompletion.State(
            isEntitled: true,
            screenTimeAuthorized: true,
            blockerConfigSaved: false
        )
        let skippedScreenTime = ProtectionPlanCompletion.State(
            isEntitled: true,
            screenTimeAuthorized: false,
            blockerConfigSaved: false
        )
        let free = ProtectionPlanCompletion.State(
            isEntitled: false,
            screenTimeAuthorized: false,
            blockerConfigSaved: false
        )

        XCTAssertFalse(ProtectionPlanCompletion.landsOnProtectionPlanReady(for: authorizedButEmpty))
        XCTAssertFalse(ProtectionPlanCompletion.landsOnProtectionPlanReady(for: skippedScreenTime))
        XCTAssertFalse(ProtectionPlanCompletion.landsOnProtectionPlanReady(for: free))
    }

    func testLandingOnProtectionPlanReadyAlwaysAgreesWithActivationClassification() {
        // The ready screen is shown iff the terminal outcome is activation; the
        // routing and the telemetry classification must never disagree.
        let states = [
            ProtectionPlanCompletion.State(isEntitled: true, screenTimeAuthorized: true, blockerConfigSaved: true),
            ProtectionPlanCompletion.State(isEntitled: true, screenTimeAuthorized: true, blockerConfigSaved: false),
            ProtectionPlanCompletion.State(isEntitled: true, screenTimeAuthorized: false, blockerConfigSaved: true),
            ProtectionPlanCompletion.State(isEntitled: false, screenTimeAuthorized: false, blockerConfigSaved: false),
        ]
        for state in states {
            XCTAssertEqual(
                ProtectionPlanCompletion.landsOnProtectionPlanReady(for: state),
                ProtectionPlanCompletion.outcome(for: state) == .protectionPlanActivated
            )
        }
    }

    // MARK: - Entitlement without activation

    func testPlusEntitlementWithoutActivationIsFlaggedAsUnactivatedEntitlement() {
        // The "do not call them free, but they are not activated" case.
        let state = ProtectionPlanCompletion.State(
            isEntitled: true,
            screenTimeAuthorized: false,
            blockerConfigSaved: false
        )

        XCTAssertTrue(ProtectionPlanCompletion.hasUnactivatedEntitlement(for: state))
        XCTAssertEqual(ProtectionPlanCompletion.outcome(for: state), .reminderOnly)
    }

    func testFreeReminderOnlyUserIsNotAnUnactivatedEntitlement() {
        let state = ProtectionPlanCompletion.State(
            isEntitled: false,
            screenTimeAuthorized: false,
            blockerConfigSaved: false
        )

        XCTAssertFalse(ProtectionPlanCompletion.hasUnactivatedEntitlement(for: state))
    }

    func testActivatedUserIsNotAnUnactivatedEntitlement() {
        let state = ProtectionPlanCompletion.State(
            isEntitled: true,
            screenTimeAuthorized: true,
            blockerConfigSaved: true
        )

        XCTAssertFalse(ProtectionPlanCompletion.hasUnactivatedEntitlement(for: state))
    }

    // MARK: - Telemetry classification
    //
    // The outcome -> analytics-event mapping is the testable telemetry contract.
    // (`ProductAnalyticsTelemetry` itself wraps the analytics stack, whose hosted
    // XCTest is unstable on the Xcode 27 beta; this value-type mapping is the
    // behavior that matters and is verified without the test host.)

    func testActivationOutcomeReportsProtectionPlanActivatedEvent() {
        XCTAssertEqual(
            ProtectionPlanCompletion.Outcome.protectionPlanActivated.analyticsEvent,
            .protectionPlanActivated
        )
    }

    func testReminderOnlyOutcomeReportsReminderOnlyCompletionEvent() {
        XCTAssertEqual(
            ProtectionPlanCompletion.Outcome.reminderOnly.analyticsEvent,
            .reminderOnlyCompletion
        )
    }

    func testReminderOnlyNeverReportsAnActivationEvent() {
        // AC5: reminder-only completion must not fire Protection Plan Activation.
        XCTAssertNotEqual(
            ProtectionPlanCompletion.Outcome.reminderOnly.analyticsEvent,
            .protectionPlanActivated
        )
    }

    func testCompletionEventsUseStableLowCardinalityNames() {
        XCTAssertEqual(AnalyticsEvent.reminderOnlyCompletion.rawValue, "reminder_only_completion")
        XCTAssertEqual(AnalyticsEvent.protectionPlanActivated.rawValue, "protection_plan_activated")
    }

    func testEveryOutcomeMapsToADistinctCompletionEvent() {
        let events: [AnalyticsEvent] = [
            ProtectionPlanCompletion.Outcome.reminderOnly.analyticsEvent,
            ProtectionPlanCompletion.Outcome.protectionPlanActivated.analyticsEvent
        ]
        XCTAssertEqual(Set(events).count, events.count, "Each completion outcome reports a distinct event.")
    }
}
