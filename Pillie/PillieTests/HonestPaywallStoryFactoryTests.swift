//
//  HonestPaywallStoryFactoryTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct HonestPaywallStoryFactoryTests {
    private let english = Locale(identifier: "en")

    @Test func `During trial counts active days left and quotes the trial review`() {
        let story = HonestPaywallStoryFactory.duringTrial(
            daysRemaining: 6,
            endsTonight: false,
            locale: english
        )
        #expect(story == HonestPaywallStory(
            title: "Keep Plus after your trial ends.",
            subtitle: "You have 6 active days left. Pick a plan now and nothing turns off on day 14.",
            review: PaywallReview(
                quote: "Within just 10 days of my free trial, I was already convinced that I would be getting a membership.",
                source: "5-star review on the App Store"
            )
        ))
    }

    @Test func `Grant-day rollover count is clamped to the 14-day promise`() {
        let story = HonestPaywallStoryFactory.duringTrial(
            daysRemaining: 15,
            endsTonight: false,
            locale: english
        )
        #expect(story.subtitle == "You have 14 active days left. Pick a plan now and nothing turns off on day 14.")
    }

    @Test func `Last trial day says it ends tonight`() {
        let story = HonestPaywallStoryFactory.duringTrial(
            daysRemaining: 1,
            endsTonight: true,
            locale: english
        )
        #expect(story.subtitle == "Your trial ends tonight. Pick a plan now and nothing turns off tomorrow.")
    }

    @Test(arguments: [
        (ContraceptiveMethod.pill, "Pick a plan and they’re back before tonight’s pill. Your setup is saved."),
        (.patch, "Pick a plan and they’re back before your next patch change. Your setup is saved."),
        (.ring, "Pick a plan and they’re back before your next ring change. Your setup is saved."),
    ])
    func `Hard trial-end story names the method's next dose`(
        method: ContraceptiveMethod,
        subtitle: String
    ) {
        let story = HonestPaywallStoryFactory.trialEnded(
            terms: .hardPaywall,
            method: method,
            locale: english
        )
        #expect(story == HonestPaywallStory(
            title: "Get your reminders and app blocking back.",
            subtitle: subtitle,
            review: PaywallReview(
                quote: "I have always struggled with keeping up with my pill. Now I don’t even have to think about it!",
                source: "5-star review on the App Store"
            )
        ))
    }

    @Test(arguments: ContraceptiveMethod.allCases)
    func `Legacy trial-end story is the Get Plus story`(method: ContraceptiveMethod) {
        let legacy = HonestPaywallStoryFactory.trialEnded(
            terms: .legacy,
            method: method,
            locale: english
        )
        #expect(legacy == HonestPaywallStoryFactory.settingsFree(method: method, locale: english))
        #expect(legacy.title != "Get your reminders and app blocking back.")
    }

    @Test(arguments: [
        (ContraceptiveMethod.pill, "Lock your apps until you take your pill."),
        (.patch, "Lock your apps until you change your patch."),
        (.ring, "Lock your apps until you change your ring."),
    ])
    func `Get Plus title follows the method`(method: ContraceptiveMethod, title: String) {
        let story = HonestPaywallStoryFactory.settingsFree(method: method, locale: english)
        #expect(story == HonestPaywallStory(
            title: title,
            subtitle: "Plus pauses the apps you choose until you check in, and keeps reminding you until you do.",
            review: PaywallReview(
                quote: "I especially like that I can choose which apps I want to block until I take my pill.",
                source: "5-star review on the App Store"
            )
        ))
    }
}
