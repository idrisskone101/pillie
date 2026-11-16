import Foundation
import Testing

@testable import Pillie

struct BlockingSetupLockedContentTests {
    private let english = Locale(identifier: "en_US")

    @Test func `The locked step explains the lock and leaves through the free plan`() {
        let content = BlockingSetupLockedContent.localized(locale: english)
        #expect(content.title == "Pick the apps to pause")
        #expect(content.subtitle == "App blocking is a Pillie Plus feature you can set up after upgrading.")
        #expect(content.cardTitle == "App blocking is a Pillie Plus feature you can set up after upgrading.")
        #expect(content.detail == "Daily reminders, check-ins, and history are free.")
        #expect(content.cta == "Continue")
    }

    @Test func `Under the hard paywall the locked step offers the upgrade instead of a free exit`() {
        let content = BlockingSetupLockedContent.localized(locale: english, trialEndTerms: .hardPaywall)
        #expect(content.detail == "Choose monthly, annual, or lifetime to keep using Pillie.")
        #expect(content.cta == "Get Pillie Plus")
    }

    @Test func `VoiceOver reads the lock card as two sentences without doubled punctuation`() {
        let content = BlockingSetupLockedContent.localized(locale: english)
        #expect(
            content.accessibilityLabel
                == "App blocking is a Pillie Plus feature you can set up after upgrading. "
                + "Daily reminders, check-ins, and history are free."
        )
    }
}
