//
//  HonestPaywallBoardResolverTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct HonestPaywallBoardResolverTests {
    private let english = Locale(identifier: "en_US")

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

    @Test func `Entitled user gets no board`() {
        let board = HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: true, trialGrantDate: nil),
            entry: .settingsSubscription,
            stats: nil,
            calendar: calendar,
            now: date(2026, 7, 20),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: nil
        )
        #expect(board == nil)
    }

    @Test func `Settings during trial resolves to C1`() {
        let grant = date(2026, 7, 10, 9)
        let board = HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: false, trialGrantDate: grant),
            entry: .settingsSubscription,
            stats: nil,
            calendar: calendar,
            now: date(2026, 7, 20),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: nil
        )
        guard case .duringTrial = board else {
            Issue.record("Expected duringTrial board for active trial on Settings")
            return
        }
    }

    @Test func `Settings free user resolves to C3`() {
        let expiredGrant = date(2026, 5, 1, 9)
        let board = HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: false, trialGrantDate: expiredGrant),
            entry: .settingsSubscription,
            stats: nil,
            calendar: calendar,
            now: date(2026, 7, 20),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: nil
        )
        guard case .settingsFree = board else {
            Issue.record("Expected settingsFree board for expired trial on Settings")
            return
        }
    }

    @Test func `Trial end hard paywall uses locked chrome`() {
        let expiredGrant = date(2026, 8, 14, 0)
        let board = HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: false, trialGrantDate: expiredGrant),
            entry: .trialEndAutoPresent,
            stats: .none,
            calendar: calendar,
            now: date(2026, 8, 29),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: .postCutover
        )
        guard case .trialEnded(let story) = board else {
            Issue.record("Expected trialEnded board")
            return
        }
        #expect(!story.chrome.showsClose)
        #expect(!story.chrome.allowsInteractiveDismiss)
        #expect(!story.chrome.showsContinueFree)
    }

    @Test func `Trial end legacy cohort allows dismiss`() {
        let expiredGrant = date(2026, 6, 21, 10)
        let board = HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: false, trialGrantDate: expiredGrant),
            entry: .trialEndAutoPresent,
            stats: .none,
            calendar: calendar,
            now: date(2026, 7, 6, 9),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: .preCutover
        )
        guard case .trialEnded(let story) = board else {
            Issue.record("Expected trialEnded board")
            return
        }
        #expect(story.chrome.showsClose)
        #expect(story.chrome.allowsInteractiveDismiss)
        #expect(story.chrome.showsContinueFree)
    }

    @Test func `Board CTA verb is keep during trial and get when free`() {
        let trialBoard = HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: false, trialGrantDate: date(2026, 7, 10, 9)),
            entry: .trialStatus,
            stats: nil,
            calendar: calendar,
            now: date(2026, 7, 20),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: nil
        )
        #expect(trialBoard?.ctaVerb == .keep)

        let freeBoard = HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: false, trialGrantDate: nil),
            entry: .homeBlockingCard,
            stats: nil,
            calendar: calendar,
            now: date(2026, 7, 20),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: nil
        )
        #expect(freeBoard?.ctaVerb == .get)
    }

    @Test func `C1 and C3 chrome omit continue free`() {
        let trialBoard = HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: false, trialGrantDate: date(2026, 7, 10, 9)),
            entry: .settingsSubscription,
            stats: nil,
            calendar: calendar,
            now: date(2026, 7, 20),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: nil
        )
        #expect(trialBoard?.chrome.showsContinueFree == false)
        #expect(trialBoard?.chrome.showsClose == true)

        let freeBoard = HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: false, trialGrantDate: nil),
            entry: .settingsSubscription,
            stats: nil,
            calendar: calendar,
            now: date(2026, 7, 20),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: nil
        )
        #expect(freeBoard?.chrome.showsContinueFree == false)
    }

    @Test func `Protection off with expired grant resolves to C2`() {
        let expiredGrant = date(2026, 8, 14, 0)
        let board = HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: false, trialGrantDate: expiredGrant),
            entry: .protectionOffCard,
            stats: .none,
            calendar: calendar,
            now: date(2026, 8, 29),
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: .postCutover
        )
        guard case .trialEnded(let story) = board else {
            Issue.record("Expected trialEnded board for Protection Off after trial")
            return
        }
        #expect(!story.chrome.showsClose)
    }
}
