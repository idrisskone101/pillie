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

    @Test func `Grant before cutover keeps legacy terms`() {
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

    @Test func `RevenueCat kill switch restores legacy terms`() {
        let configuration = HardPaywallRemoteConfiguration(
            offeringMetadata: ["hard_paywall_enabled": false]
        )

        #expect(HardPaywallPolicy.terms(
            forTrialGrantedAt: date(2026, 8, 14, 0, 0),
            hardPaywallEnabled: configuration.isEnabled
        ) == .legacy)
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
}
