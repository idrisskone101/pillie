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
        #expect(story.handwrittenLossLine.isEmpty)
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
        #expect(!story.handwrittenLossLine.isEmpty)
    }
}
