//
//  TrialDeclineFeedbackRouteTests.swift
//  PillieTests
//
//  Public route behavior for issue #243. Kept value-only so the decision can
//  be verified without pinning SwiftUI presentation details.
//

import XCTest

@testable import Pillie

final class TrialDeclineFeedbackRouteTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 12
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    func testEligibleExpiredTrialContinueFreePresentsFeedback() {
        let route = TrialDeclineFeedbackRoute.evaluate(
            action: .continueFree,
            state: PlusAccessState(
                hasEntitlement: false,
                trialGrantDate: date(2026, 6, 21, 10)
            ),
            entitlementResolved: true,
            questionnaireResolved: false,
            calendar: calendar,
            now: date(2026, 7, 6, 9)
        )

        XCTAssertEqual(route, .presentFeedback)
    }

    func testPaywallCloseAlwaysEntersFreeApp() {
        let route = TrialDeclineFeedbackRoute.evaluate(
            action: .close,
            state: PlusAccessState(
                hasEntitlement: false,
                trialGrantDate: date(2026, 6, 21, 10)
            ),
            entitlementResolved: true,
            questionnaireResolved: false,
            calendar: calendar,
            now: date(2026, 7, 6, 9)
        )

        XCTAssertEqual(route, .enterFreeApp)
    }

    func testIneligibleContinueFreeStatesEnterFreeApp() {
        let expiredGrant = date(2026, 6, 21, 10)
        let activeGrant = date(2026, 7, 1, 10)
        let now = date(2026, 7, 6, 9)

        func route(
            hasEntitlement: Bool = false,
            grantDate: Date? = expiredGrant,
            entitlementResolved: Bool = true,
            questionnaireResolved: Bool = false
        ) -> TrialDeclineFeedbackRoute {
            TrialDeclineFeedbackRoute.evaluate(
                action: .continueFree,
                state: PlusAccessState(
                    hasEntitlement: hasEntitlement,
                    trialGrantDate: grantDate
                ),
                entitlementResolved: entitlementResolved,
                questionnaireResolved: questionnaireResolved,
                calendar: calendar,
                now: now
            )
        }

        XCTAssertEqual(route(entitlementResolved: false), .enterFreeApp)
        XCTAssertEqual(route(hasEntitlement: true), .enterFreeApp)
        XCTAssertEqual(route(grantDate: activeGrant), .enterFreeApp)
        XCTAssertEqual(route(grantDate: nil), .enterFreeApp)
        XCTAssertEqual(route(questionnaireResolved: true), .enterFreeApp)
    }
}
