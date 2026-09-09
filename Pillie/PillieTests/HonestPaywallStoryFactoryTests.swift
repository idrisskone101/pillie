//
//  HonestPaywallStoryFactoryTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct HonestPaywallStoryFactoryTests {
    private let english = Locale(identifier: "en_US")

    @Test func `Unknown C2 stats omit tiles`() {
        let story = HonestPaywallStoryFactory.trialEnded(
            stats: .none,
            terms: .hardPaywall,
            locale: english
        )
        #expect(story.doseTile == nil)
        #expect(story.streakTile == nil)
    }

    @Test func `Zero C2 stats omit tiles`() {
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
        #expect(story.doseTile == nil)
        #expect(story.streakTile == nil)
    }

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
        #expect(story.doseTile?.value == "11")
        #expect(story.streakTile?.value == "3")
        #expect(story.fallback == nil)
        #expect(!story.handwrittenLossLine.isEmpty)
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
        guard case .chips(let chips) = story.fallback else {
            Issue.record("Expected returning hard chips")
            return
        }
        #expect(chips.count == 3)
        #expect(story.handwrittenLossLine == commerce("paywall.story.trial_ended.returning.hard.aside"))
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
        #expect(story.handwrittenLossLine.isEmpty)
        guard case .comparison = story.fallback else {
            Issue.record("Expected returning legacy comparison")
            return
        }
    }

    private func commerce(_ key: String) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: english)
    }
}
