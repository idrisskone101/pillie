//
//  HonestPaywallTelemetryTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct HonestPaywallTelemetryTests {
    private let english = Locale(identifier: "en")

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        return cal
    }

    private func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour
        ))!
    }

    private var expiredTrialContent: TrialEndPaywallContent {
        TrialEndPaywallContent.make(
            state: PlusAccessState(
                hasEntitlement: false,
                trialGrantDate: date(2026, 8, 14)
            ),
            blockerConfigSaved: true,
            stats: .none,
            calendar: calendar,
            now: date(2026, 8, 29),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: .postCutover
        )!
    }

    @Test func `Expired grant on C3 stays surface-scoped`() {
        let board = HonestPaywallBoard(
            moment: .settingsFree,
            story: HonestPaywallStoryFactory.settingsFree(method: .pill, locale: english)
        )
        #expect(
            HonestPaywallTelemetry.mode(
                board: board,
                trialEndContent: expiredTrialContent
            ) == .surface
        )
    }

    @Test func `Expired grant on C1 stays surface-scoped`() {
        let board = HonestPaywallBoard(
            moment: .duringTrial,
            story: HonestPaywallStoryFactory.duringTrial(
                daysRemaining: 4,
                endsTonight: false,
                locale: english
            )
        )
        #expect(
            HonestPaywallTelemetry.mode(
                board: board,
                trialEndContent: expiredTrialContent
            ) == .surface
        )
    }

    @Test func `C2 board without trial-end content stays surface-scoped`() {
        let board = HonestPaywallBoard(
            moment: .trialEnded(.hardPaywall),
            story: HonestPaywallStoryFactory.trialEnded(
                terms: .hardPaywall,
                method: .pill,
                locale: english
            )
        )
        #expect(HonestPaywallTelemetry.mode(board: board, trialEndContent: nil) == .surface)
    }

    @Test(arguments: [TrialEndAccessTerms.hardPaywall, .legacy])
    func `C2 board uses trial-end events`(terms: TrialEndAccessTerms) throws {
        let board = HonestPaywallBoard(
            moment: .trialEnded(terms),
            story: HonestPaywallStoryFactory.trialEnded(
                terms: terms,
                method: .pill,
                locale: english
            )
        )
        let mode = HonestPaywallTelemetry.mode(
            board: board,
            trialEndContent: expiredTrialContent
        )
        let content = try #require(
            {
                if case .trialEnd(let content) = mode { return content }
                return nil
            }(),
            "Expected trial-end telemetry for C2"
        )
        #expect(content.termsCohort == .postCutover)
        #expect(content.cohort == .blockerConfigured)
    }
}
