//
//  ExistingUserTrialGrantTests.swift
//  PillieTests
//
//  Issue #165 (Reverse Trial 6/10): granting the Reverse Trial to the existing
//  base on first launch after the introducing update. Pure value-type tests for
//  the grant-eligibility decision — entitled / trialed / onboarded /
//  fresh-install combinations — per the hosted-XCTest instability on the
//  Xcode 27 beta (no @MainActor classes, no stored reference-type ivars).
//

import XCTest

@testable import Pillie

final class ExistingUserTrialGrantTests: XCTestCase {

    /// Defaults model the target cohort from ADR 0007: an onboarded user without
    /// Plus (and without an onboarding trial grant) whose window is still open.
    /// Each test overrides exactly the dimension it is about.
    private func state(
        isOnboardingComplete: Bool = true,
        isEntitlementResolved: Bool = true,
        hasEntitlement: Bool = false,
        hasTrialGrant: Bool = false,
        alreadyHandled: Bool = false
    ) -> ExistingUserTrialGrant.State {
        ExistingUserTrialGrant.State(
            isOnboardingComplete: isOnboardingComplete,
            isEntitlementResolved: isEntitlementResolved,
            hasEntitlement: hasEntitlement,
            hasTrialGrant: hasTrialGrant,
            alreadyHandled: alreadyHandled
        )
    }

    func testOnboardedFreeUserIsGrantedAndAnnounced() {
        XCTAssertEqual(
            ExistingUserTrialGrant.evaluate(for: state()),
            .grantAndAnnounce
        )
    }

    func testMidOnboardingUserIsNotGrantedTwice() {
        // A user mid-onboarding at update time (or a fresh install) receives the
        // onboarding grant at the Trial Granted Moment — this path must stay out.
        XCTAssertEqual(
            ExistingUserTrialGrant.evaluate(for: state(isOnboardingComplete: false)),
            .suppressed(.stillOnboarding)
        )
    }

    func testPlusSubscriberSeesNothing() {
        XCTAssertEqual(
            ExistingUserTrialGrant.evaluate(for: state(hasEntitlement: true)),
            .suppressed(.alreadyEntitled)
        )
    }

    func testUserWhoAlreadyHoldsATrialGrantIsExcluded() {
        // Covers both an active grant (onboarding Trial Granted Moment) and an
        // expired one — `grantReverseTrial` never restarts the 14-day clock, and
        // neither does the update path.
        XCTAssertEqual(
            ExistingUserTrialGrant.evaluate(for: state(hasTrialGrant: true)),
            .suppressed(.alreadyTrialed)
        )
    }

    func testConsumedWindowNeverAnnouncesAgain() {
        // The announcement shows exactly once; the persisted handled flag keeps
        // it away on every later launch.
        XCTAssertEqual(
            ExistingUserTrialGrant.evaluate(for: state(alreadyHandled: true)),
            .suppressed(.alreadyHandled)
        )
    }

    func testNoDecisionBeforeEntitlementStateHasLoaded() {
        // `hasEntitlement` starts `false` until RevenueCat's first customer-info
        // load. Deciding earlier would misread a paying subscriber as free and
        // show them the sheet; the window stays open and is re-evaluated once
        // entitlement state resolves (or on the next launch).
        XCTAssertEqual(
            ExistingUserTrialGrant.evaluate(for: state(isEntitlementResolved: false)),
            .suppressed(.entitlementUnresolved)
        )
    }

    // MARK: - One-shot window semantics

    func testTerminalDecisionsConsumeTheUpdateWindow() {
        // Granting consumes the window, and so do the terminal exclusions: a
        // subscriber (or already-trialed user) evaluated once must not receive a
        // surprise grant on some later launch (e.g. after churning) — that would
        // no longer be "first launch after the introducing update".
        XCTAssertTrue(ExistingUserTrialGrant.closesWindow(.grantAndAnnounce))
        XCTAssertTrue(ExistingUserTrialGrant.closesWindow(.suppressed(.alreadyEntitled)))
        XCTAssertTrue(ExistingUserTrialGrant.closesWindow(.suppressed(.alreadyTrialed)))
    }

    func testUndecidedLaunchesLeaveTheWindowOpen() {
        // Mid-onboarding and unresolved-entitlement launches made no decision —
        // the check must run again (later this launch or on the next one).
        XCTAssertFalse(ExistingUserTrialGrant.closesWindow(.suppressed(.stillOnboarding)))
        XCTAssertFalse(ExistingUserTrialGrant.closesWindow(.suppressed(.entitlementUnresolved)))
        XCTAssertFalse(ExistingUserTrialGrant.closesWindow(.suppressed(.alreadyHandled)))
    }

    func testHandledFlagStorageKeyIsStable() {
        // The key is persisted user state — renaming it would re-show the
        // announcement to users who already saw it.
        XCTAssertEqual(ExistingUserTrialGrant.handledStorageKey, "updateTrialGrantHandled")
    }
}
