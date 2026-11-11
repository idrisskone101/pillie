//
//  ClassicPaywallStoryFactoryTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct ClassicPaywallStoryFactoryTests {
    private let english = Locale(identifier: "en_US")

    @Test func `During trial reads the classic copy and chips`() {
        let story = ClassicPaywallStoryFactory.duringTrial(displayedDaysRemaining: 6, locale: english)
        #expect(story.title == "You still have Pillie Plus.")
        #expect(story.subtitle == "Keep Plus to have follow-up reminders and app blocking after your trial.")
        #expect(story.daysRemaining == 6)
        #expect(story.daysStampText == "active days left on Pillie Plus")
        #expect(story.benefitChips == [
            ClassicPaywallBenefitChip(label: "Follow-up reminders stay on", tint: .lavender),
            ClassicPaywallBenefitChip(label: "App blocking stays on", tint: .sage),
            ClassicPaywallBenefitChip(label: "Your history stays here", tint: .coralSoft),
        ])
    }

    @Test func `Known stats become tiles`() {
        let story = ClassicPaywallStoryFactory.trialEnded(
            stats: TrialEndOwnStats(
                blocksIntercepted: 3,
                dosesTaken: 11,
                dosesDue: 15,
                currentStreak: 3
            ),
            terms: .hardPaywall,
            locale: english
        )
        #expect(story.title == "Your Pillie Plus trial is over.")
        #expect(story.subtitle == "Your daily reminders and app blocking are off. Pick a plan to turn them back on.")
        #expect(story.body == .stats(
            dose: ClassicPaywallStatTile(label: "doses taken", value: "11", background: .coralSoft),
            streak: ClassicPaywallStatTile(label: "day streak", value: "3", background: .ink),
            lossLine: "11 so far. Keep it up."
        ))
    }

    @Test func `Known stats on legacy terms keep the stay-on subtitle`() {
        let story = ClassicPaywallStoryFactory.trialEnded(
            stats: TrialEndOwnStats(
                blocksIntercepted: nil,
                dosesTaken: nil,
                dosesDue: nil,
                currentStreak: 4
            ),
            terms: .legacy,
            locale: english
        )
        #expect(story.subtitle == "Stay on Pillie Plus to keep follow-up reminders and app blocking.")
        #expect(story.body == .stats(
            dose: nil,
            streak: ClassicPaywallStatTile(label: "day streak", value: "4", background: .ink),
            lossLine: "4 so far. Keep it up."
        ))
    }

    @Test func `Empty stats on hard terms use the returning chips`() {
        let story = ClassicPaywallStoryFactory.trialEnded(stats: .none, terms: .hardPaywall, locale: english)
        #expect(story.title == "Your trial has ended.")
        #expect(story.subtitle == "Your daily reminders and app blocking are off. Pick a plan to turn them back on.")
        #expect(story.body == .chips(
            [
                ClassicPaywallBenefitChip(label: "App blocking turns back on", tint: .sage),
                ClassicPaywallBenefitChip(label: "Daily reminders come back", tint: .lavender),
                ClassicPaywallBenefitChip(label: "Your history comes back", tint: .coralSoft),
            ],
            aside: "pick up where you left off"
        ))
    }

    @Test func `Zero stats on legacy terms use the welcome-back comparison`() {
        let story = ClassicPaywallStoryFactory.trialEnded(
            stats: TrialEndOwnStats(
                blocksIntercepted: 0,
                dosesTaken: 0,
                dosesDue: 14,
                currentStreak: 0
            ),
            terms: .legacy,
            locale: english
        )
        #expect(story.title == "Welcome back.")
        #expect(story.subtitle == "Your trial ended. Daily reminders stay free.")
        guard case .comparison(let free, let plus) = story.body else {
            Issue.record("Expected the free and Plus comparison")
            return
        }
        #expect(free.bullets == ["Daily reminders"])
        #expect(plus.tierLabel == "Pillie Plus")
    }

    @Test func `Settings free compares Free with Plus`() {
        let story = ClassicPaywallStoryFactory.settingsFree(locale: english)
        #expect(story.title == "Daily reminders are free.")
        #expect(story.subtitle == "Pillie Plus adds follow-up reminders and app blocking.")
        #expect(story.freeCard == ClassicPaywallComparisonCard(
            tierLabel: "Free",
            bullets: ["Daily reminders"],
            background: .lavender
        ))
        #expect(story.plusCard == ClassicPaywallComparisonCard(
            tierLabel: "Pillie Plus",
            bullets: ["Daily reminders", "Follow-up reminders", "App blocking"],
            background: .coralSoft
        ))
    }

    @Test func `German reads the restored classic translation`() {
        let story = ClassicPaywallStoryFactory.trialEnded(
            stats: .none,
            terms: .legacy,
            locale: Locale(identifier: "de")
        )
        #expect(story.title == "Willkommen zurück.")
    }
}
