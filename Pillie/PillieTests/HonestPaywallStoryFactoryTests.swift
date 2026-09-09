//
//  HonestPaywallStoryFactoryTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct HonestPaywallStoryFactoryTests {
    private let english = Locale(identifier: "en_US")

    @Test func `Known C2 stats become tiles`() {
        let story = HonestPaywallStoryFactory.trialEnded(
            stats: TrialEndOwnStats(
                blocksIntercepted: 3,
                dosesTaken: 11,
                dosesDue: 15,
                currentStreak: 3
            ),
            terms: .hardPaywall,
            locale: english
        )
        guard case .stats(let dose, let streak, let lossLine) = story.body else {
            Issue.record("Expected own-record stats body")
            return
        }
        #expect(dose?.value == "11")
        #expect(streak?.value == "3")
        #expect(!lossLine.isEmpty)
    }

    @Test func `Empty stats on hard terms use the locked returning story`() {
        let story = HonestPaywallStoryFactory.trialEnded(
            stats: .none,
            terms: .hardPaywall,
            locale: english
        )
        #expect(story.title == commerce("paywall.story.trial_ended.returning.hard.title"))
        #expect(story.subtitle == commerce("paywall.story.trial_ended.returning.hard.subtitle"))
        #expect(!story.chrome.showsClose)
        #expect(!story.chrome.showsContinueFree)
        guard case .chips(let chips, let aside) = story.body else {
            Issue.record("Expected returning hard chips")
            return
        }
        #expect(chips.count == 3)
        #expect(chips[2].label == commerce("paywall.story.trial_ended.returning.hard.chip.history"))
        #expect(aside == commerce("paywall.story.trial_ended.returning.hard.aside"))
    }

    @Test func `Empty stats on legacy terms use the dismissible returning story`() {
        let story = HonestPaywallStoryFactory.trialEnded(
            stats: .none,
            terms: .legacy,
            locale: english
        )
        #expect(story.title == commerce("paywall.story.trial_ended.returning.legacy.title"))
        #expect(story.subtitle == commerce("paywall.story.trial_ended.returning.legacy.subtitle"))
        #expect(story.chrome.showsClose)
        #expect(story.chrome.showsContinueFree)
        guard case .comparison = story.body else {
            Issue.record("Expected returning legacy comparison")
            return
        }
    }

    @Test func `Zero C2 stats use the dismissible returning story`() {
        let story = HonestPaywallStoryFactory.trialEnded(
            stats: TrialEndOwnStats(
                blocksIntercepted: 0,
                dosesTaken: 0,
                dosesDue: 14,
                currentStreak: 0
            ),
            terms: .legacy,
            locale: english
        )
        #expect(story.title == commerce("paywall.story.trial_ended.returning.legacy.title"))
        #expect(story.subtitle == commerce("paywall.story.trial_ended.returning.legacy.subtitle"))
        #expect(story.chrome.showsClose)
        #expect(story.chrome.showsContinueFree)
        guard case .comparison = story.body else {
            Issue.record("Expected returning legacy comparison")
            return
        }
    }

    private func commerce(_ key: String) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: english)
    }
}
