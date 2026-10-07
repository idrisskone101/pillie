//
//  HonestPaywallBoardResolverTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct HonestPaywallBoardResolverTests {
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

    private func resolve(
        grant: Date?,
        hasEntitlement: Bool = false,
        entry: PaywallEntryPoint,
        method: ContraceptiveMethod = .pill,
        now: Date,
        termsCohort: TrialTermsCohort? = nil
    ) -> HonestPaywallBoard? {
        HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: hasEntitlement, trialGrantDate: grant),
            entry: entry,
            method: method,
            calendar: calendar,
            now: now,
            locale: english,
            hardPaywallEnabled: true,
            termsCohort: termsCohort
        )
    }

    @Test func `Entitled user gets no board`() {
        let board = resolve(
            grant: nil,
            hasEntitlement: true,
            entry: .settingsSubscription,
            now: date(2026, 7, 20)
        )
        #expect(board == nil)
    }

    @Test func `Grant-day paywall count matches the home badge at 14`() {
        let grant = date(2026, 7, 1, 10)
        let now = date(2026, 7, 1, 10)
        let board = resolve(grant: grant, entry: .trialStatus, now: now)
        let presentation = TrialStatusPresentation.make(
            state: PlusAccessState(hasEntitlement: false, trialGrantDate: grant),
            calendar: calendar,
            now: now,
            locale: english
        )

        #expect(board?.moment == .duringTrial)
        #expect(board?.story.subtitle == "You have 14 active days left. Pick a plan now and nothing turns off on day 14.")
        #expect(presentation?.displayedDaysRemaining == 14)
    }

    @Test func `Mid-trial board counts the active days left`() {
        let board = resolve(
            grant: date(2026, 7, 10, 9),
            entry: .settingsSubscription,
            now: date(2026, 7, 20)
        )
        #expect(board?.moment == .duringTrial)
        #expect(board?.story.title == "Keep Plus after your trial ends.")
        #expect(board?.story.subtitle == "You have 5 active days left. Pick a plan now and nothing turns off on day 14.")
    }

    @Test func `Last trial day resolves to the ends-tonight story`() {
        let board = resolve(
            grant: date(2026, 7, 1, 10),
            entry: .trialStatus,
            now: date(2026, 7, 15, 20)
        )
        #expect(board?.moment == .duringTrial)
        #expect(board?.story.subtitle == "Your trial ends tonight. Pick a plan now and nothing turns off tomorrow.")
    }

    @Test(arguments: [
        (ContraceptiveMethod.pill, "Lock your apps until you take your pill."),
        (.patch, "Lock your apps until you change your patch."),
        (.ring, "Lock your apps until you change your ring."),
    ])
    func `Settings free user resolves to C3 for their method`(
        method: ContraceptiveMethod,
        title: String
    ) {
        let board = resolve(
            grant: date(2026, 5, 1, 9),
            entry: .settingsSubscription,
            method: method,
            now: date(2026, 7, 20)
        )
        #expect(board?.moment == .settingsFree)
        #expect(board?.story.title == title)
    }

    @Test func `Trial end hard paywall uses locked chrome and the get-back story`() {
        let board = resolve(
            grant: date(2026, 8, 14, 0),
            entry: .trialEndAutoPresent,
            method: .patch,
            now: date(2026, 8, 29),
            termsCohort: .postCutover
        )
        #expect(board?.moment == .trialEnded(.hardPaywall))
        #expect(board?.isTrialEnd == true)
        #expect(board?.chrome == HonestPaywallChrome(
            showsClose: false,
            allowsInteractiveDismiss: false,
            showsContinueFree: false
        ))
        #expect(board?.story.title == "Get your reminders and app blocking back.")
        #expect(board?.story.subtitle == "Pick a plan and they’re back before your next patch change. Your setup and streak are saved.")
    }

    @Test func `Trial end legacy cohort allows dismiss and sells Get Plus`() {
        let board = resolve(
            grant: date(2026, 6, 21, 10),
            entry: .trialEndAutoPresent,
            now: date(2026, 7, 6, 9),
            termsCohort: .preCutover
        )
        #expect(board?.moment == .trialEnded(.legacy))
        #expect(board?.isTrialEnd == true)
        #expect(board?.chrome == HonestPaywallChrome(
            showsClose: true,
            allowsInteractiveDismiss: true,
            showsContinueFree: true
        ))
        #expect(board?.story.title == "Lock your apps until you take your pill.")
    }

    @Test func `Board CTA verb is keep during trial and get when free`() {
        let trialBoard = resolve(
            grant: date(2026, 7, 10, 9),
            entry: .trialStatus,
            now: date(2026, 7, 20)
        )
        #expect(trialBoard?.ctaVerb == .keep)

        let freeBoard = resolve(grant: nil, entry: .homeBlockingCard, now: date(2026, 7, 20))
        #expect(freeBoard?.moment == .settingsFree)
        #expect(freeBoard?.ctaVerb == .get)
    }

    @Test func `C1 and C3 chrome close without continue free`() {
        let dismissible = HonestPaywallChrome(
            showsClose: true,
            allowsInteractiveDismiss: true,
            showsContinueFree: false
        )
        let trialBoard = resolve(
            grant: date(2026, 7, 10, 9),
            entry: .settingsSubscription,
            now: date(2026, 7, 20)
        )
        #expect(trialBoard?.chrome == dismissible)
        #expect(trialBoard?.isTrialEnd == false)

        let freeBoard = resolve(grant: nil, entry: .settingsSubscription, now: date(2026, 7, 20))
        #expect(freeBoard?.chrome == dismissible)
    }

    @Test func `Protection off with expired grant resolves to C2`() {
        let board = resolve(
            grant: date(2026, 8, 14, 0),
            entry: .protectionOffCard,
            now: date(2026, 8, 29),
            termsCohort: .postCutover
        )
        #expect(board?.moment == .trialEnded(.hardPaywall))
        #expect(board?.chrome.showsClose == false)
    }
}
