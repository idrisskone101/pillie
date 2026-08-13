//
//  HardPaywallPolicyTests.swift
//  PillieTests
//
//  Cohort and remote rollback behavior for issue #257.
//

import Foundation
import Testing

@testable import Pillie

struct HardPaywallPolicyTests {
    private var montrealCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Montreal")!
        return calendar
    }

    private func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int, _ minute: Int
    ) -> Date {
        montrealCalendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    @Test func `Historical grant before cutover keeps legacy terms`() {
        let grantDate = date(2026, 8, 13, 23, 59)

        #expect(HardPaywallPolicy.terms(
            forTrialGrantedAt: grantDate,
            hardPaywallEnabled: true
        ) == .legacy)
    }

    @Test func `Grant at cutover receives hard paywall terms`() {
        let grantDate = date(2026, 8, 14, 0, 0)

        #expect(HardPaywallPolicy.terms(
            forTrialGrantedAt: grantDate,
            hardPaywallEnabled: true
        ) == .hardPaywall)
    }

    @Test func `Existing pre cutover install is grandfathered when grant happens later`() {
        let postCutoverGrant = date(2026, 8, 20, 9, 0)

        #expect(TrialInstallCohort.assignment(
            at: postCutoverGrant,
            hasExistingAppState: true,
            previousAssignment: nil
        ) == .preCutover)
        #expect(TrialInstallCohort.assignment(
            at: postCutoverGrant,
            hasExistingAppState: false,
            previousAssignment: nil
        ) == .postCutover)
    }

    @Test func `Fresh install gets hard-paywall terms regardless of the old date`() {
        #expect(TrialInstallCohort.assignment(
            at: date(2026, 8, 12, 9, 0),
            hasExistingAppState: false,
            previousAssignment: nil
        ) == .postCutover)
    }

    @Test func `Recorded post cutover install assignment never changes`() {
        #expect(TrialInstallCohort.assignment(
            at: date(2026, 8, 21, 9, 0),
            hasExistingAppState: true,
            previousAssignment: .postCutover
        ) == .postCutover)
    }

    @Test func `Persisted grandfathered cohort keeps legacy expiry terms`() throws {
        let content = try #require(TrialEndPaywallContent.make(
            state: PlusAccessState(
                hasEntitlement: false,
                trialGrantDate: date(2026, 8, 20, 9, 0)
            ),
            blockerConfigSaved: false,
            stats: .none,
            calendar: montrealCalendar,
            now: date(2026, 9, 5, 9, 0),
            locale: Locale(identifier: "en_CA"),
            hardPaywallEnabled: true,
            termsCohort: .preCutover
        ))

        #expect(content.termsCohort == .preCutover)
        #expect(content.terms == .legacy)
    }

    @Test func `RevenueCat kill switch restores legacy terms`() {
        let configuration = HardPaywallRemoteConfiguration(
            offeringMetadata: ["hard_paywall_enabled": false]
        )

        #expect(HardPaywallPolicy.terms(
            forTrialGrantedAt: date(2026, 8, 14, 0, 0),
            hardPaywallEnabled: configuration.isEnabled
        ) == .legacy)
    }

    @Test func `RevenueCat kill switch preserves post cutover cohort`() throws {
        let content = try #require(TrialEndPaywallContent.make(
            state: PlusAccessState(
                hasEntitlement: false,
                trialGrantDate: date(2026, 8, 14, 0, 0)
            ),
            blockerConfigSaved: false,
            stats: .none,
            calendar: montrealCalendar,
            now: date(2026, 8, 29, 9, 0),
            locale: Locale(identifier: "en_CA"),
            hardPaywallEnabled: false
        ))

        #expect(content.terms == .legacy)
        #expect(content.termsCohort == .postCutover)
    }

    @Test func `Expired post cutover content removes continue free`() throws {
        let content = try #require(TrialEndPaywallContent.make(
            state: PlusAccessState(
                hasEntitlement: false,
                trialGrantDate: date(2026, 8, 14, 0, 0)
            ),
            blockerConfigSaved: false,
            stats: .none,
            calendar: montrealCalendar,
            now: date(2026, 8, 29, 9, 0),
            locale: Locale(identifier: "en_CA"),
            hardPaywallEnabled: true
        ))

        #expect(!content.allowsContinueFree)
    }

    @Test func `Hard paywall debug scenario is post cutover and expired`() {
        let scenario = TrialEndPaywallDebugScenario.make(
            forceHardPaywall: true,
            now: date(2026, 8, 2, 9, 0),
            calendar: montrealCalendar
        )

        #expect(scenario.termsCohort == .postCutover)
        #expect(scenario.grantDate == HardPaywallPolicy.cutoverInstant)
        #expect(!PlusAccessState(
            hasEntitlement: false,
            trialGrantDate: scenario.grantDate
        ).trialActive(calendar: montrealCalendar, now: scenario.evaluationDate))
    }
}
