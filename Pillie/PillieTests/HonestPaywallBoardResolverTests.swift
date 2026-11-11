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
        design: PaywallDesign = .s3,
        trialStats: TrialEndOwnStats? = nil,
        now: Date,
        termsCohort: TrialTermsCohort? = nil
    ) -> HonestPaywallBoard? {
        HonestPaywallBoardResolver.resolve(
            access: PlusAccessState(hasEntitlement: hasEntitlement, trialGrantDate: grant),
            entry: entry,
            method: method,
            design: design,
            trialStats: trialStats,
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
        #expect(board?.s3Story?.subtitle == "You have 14 days left. Pick a plan now and nothing turns off on day 14.")
        #expect(presentation?.displayedDaysRemaining == 14)
    }

    @Test func `Mid-trial board counts the days left`() {
        let board = resolve(
            grant: date(2026, 7, 10, 9),
            entry: .settingsSubscription,
            now: date(2026, 7, 20)
        )
        #expect(board?.moment == .duringTrial)
        #expect(board?.s3Story?.title == "Keep Plus after your trial ends.")
        #expect(board?.s3Story?.subtitle == "You have 5 days left. Pick a plan now and nothing turns off on day 14.")
    }

    @Test func `Last trial day resolves to the ends-tonight story`() {
        let board = resolve(
            grant: date(2026, 7, 1, 10),
            entry: .trialStatus,
            now: date(2026, 7, 15, 20)
        )
        #expect(board?.moment == .duringTrial)
        #expect(board?.s3Story?.subtitle == "Your trial ends tonight. Pick a plan now and nothing turns off tomorrow.")
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
        #expect(board?.s3Story?.title == title)
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
        #expect(board?.s3Story?.title == "Get your reminders and app blocking back.")
        #expect(board?.s3Story?.subtitle == "Pick a plan and they’re back before your next patch change. Your setup is saved.")
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
        #expect(board?.s3Story?.title == "Lock your apps until you take your pill.")
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

    // MARK: - paywall_design_v1

    @Test func `S3 arm resolves to the S3 layout`() {
        let board = resolve(
            grant: date(2026, 7, 10, 9),
            entry: .trialStatus,
            design: .s3,
            now: date(2026, 7, 20)
        )
        #expect(board?.s3Story?.title == "Keep Plus after your trial ends.")
        #expect(board?.classicStory == nil)
    }

    @Test func `Classic arm during the trial keeps the moment and counts days`() {
        let board = resolve(
            grant: date(2026, 7, 10, 9),
            entry: .trialStatus,
            design: .classic,
            now: date(2026, 7, 20)
        )
        #expect(board?.moment == .duringTrial)
        #expect(board?.ctaVerb == .keep)
        #expect(board?.s3Story == nil)
        guard case .duringTrial(let story) = board?.classicStory else {
            Issue.record("Expected the classic during-trial story")
            return
        }
        #expect(story.title == "You still have Pillie Plus.")
        #expect(story.daysRemaining == 5)
    }

    @Test func `Classic arm on the grant day shows 14 like the home badge`() {
        let board = resolve(
            grant: date(2026, 7, 1, 10),
            entry: .trialStatus,
            design: .classic,
            now: date(2026, 7, 1, 10)
        )
        guard case .duringTrial(let story) = board?.classicStory else {
            Issue.record("Expected the classic during-trial story")
            return
        }
        #expect(story.daysRemaining == 14)
    }

    @Test func `Classic arm trial end hard wall uses the returning story and locked chrome`() {
        let board = resolve(
            grant: date(2026, 8, 14, 0),
            entry: .trialEndAutoPresent,
            design: .classic,
            now: date(2026, 8, 29),
            termsCohort: .postCutover
        )
        #expect(board?.moment == .trialEnded(.hardPaywall))
        #expect(board?.chrome.showsClose == false)
        guard case .trialEnded(let story) = board?.classicStory else {
            Issue.record("Expected the classic trial-ended story")
            return
        }
        #expect(story.title == "Your trial has ended.")
    }

    @Test func `Classic arm trial end passes her stats to the story`() {
        let board = resolve(
            grant: date(2026, 6, 21, 10),
            entry: .trialEndAutoPresent,
            design: .classic,
            trialStats: TrialEndOwnStats(
                blocksIntercepted: 2,
                dosesTaken: 12,
                dosesDue: 14,
                currentStreak: 0
            ),
            now: date(2026, 7, 6, 9),
            termsCohort: .preCutover
        )
        #expect(board?.moment == .trialEnded(.legacy))
        guard case .trialEnded(let story) = board?.classicStory,
              case .stats(let dose, let streak, let lossLine) = story.body
        else {
            Issue.record("Expected the classic stats body")
            return
        }
        #expect(story.title == "Your Pillie Plus trial is over.")
        #expect(dose?.value == "12")
        #expect(streak == nil)
        #expect(lossLine == "12 so far. Keep it up.")
    }

    @Test func `Classic arm free user resolves to the classic Get Plus story`() {
        let board = resolve(
            grant: nil,
            entry: .settingsSubscription,
            method: .ring,
            design: .classic,
            now: date(2026, 7, 20)
        )
        #expect(board?.moment == .settingsFree)
        #expect(board?.ctaVerb == .get)
        guard case .settingsFree(let story) = board?.classicStory else {
            Issue.record("Expected the classic settings story")
            return
        }
        #expect(story.title == "Daily reminders are free.")
    }
}

private extension HonestPaywallBoard {
    var s3Story: HonestPaywallStory? {
        guard case .s3(let story) = layout else { return nil }
        return story
    }

    var classicStory: ClassicPaywallStory? {
        guard case .classic(let story) = layout else { return nil }
        return story
    }
}
