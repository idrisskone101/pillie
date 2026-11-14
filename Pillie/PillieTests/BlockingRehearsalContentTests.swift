import FamilyControls
import Foundation
import Testing

@testable import Pillie

struct BlockingRehearsalContentTests {
    private let english = Locale(identifier: "en_US")

    private var content: BlockingRehearsalContent {
        BlockingRehearsalContent.localized(
            script: BlockingRehearsalScript(featuredApp: .tiktok, method: .pill, reminderHour: 20, reminderMinute: 0),
            locale: english
        )
    }

    private func chrome(
        _ stage: BlockingRehearsalStage,
        refusal: ScreenTimeRefusal? = nil,
        isAuthorized: Bool = true,
        hasEntitlement: Bool = false
    ) -> BlockingRehearsalChrome {
        content.chrome(for: stage, refusal: refusal, isAuthorized: isAuthorized, hasEntitlement: hasEntitlement)
    }

    private func plainSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private let trialLine =
        "Pillie Plus is on for your next 14 days, free. No\u{00A0}card. We’ll remind you before it ends."

    // MARK: The per-screen table

    @Test func `The reminder beat names her time and her app and has no footer`() {
        let chrome = chrome(.reminder)
        #expect(chrome.layout == .page)
        #expect(chrome.header == "Try it")
        #expect(plainSpaces(chrome.title) == "Your 8:00 PM reminder just rang.")
        #expect(chrome.body == "Try opening TikTok anyway.")
        #expect(chrome.footnotes == [])
        #expect(chrome.primary == nil)
        #expect(chrome.quietTitle == nil)
    }

    @Test func `The paused beat says her app is paused and has no footer`() {
        let chrome = chrome(.paused)
        #expect(chrome.header == "Try it")
        #expect(chrome.title == "TikTok is paused.")
        #expect(chrome.body == "Everything else you pick pauses too. The rest of your phone works as usual.")
        #expect(chrome.footnotes == [])
        #expect(chrome.primary == nil)
        #expect(chrome.quietTitle == nil)
    }

    @Test func `The shake beat covers the screen and offers the tap`() {
        let chrome = chrome(.shake)
        #expect(chrome.layout == .shakeCover)
        #expect(chrome.header == nil)
        #expect(chrome.eyebrow == "This is a practice run.")
        #expect(chrome.title == "Shake to check in")
        #expect(chrome.body == nil)
        #expect(chrome.footnotes == [])
        #expect(chrome.primary == .init(title: "Tap to check in instead", event: .beatControlTapped, showsArrow: false))
        #expect(chrome.quietTitle == nil)
    }

    @Test func `Before Apple has been asked, the ask has one button and no way to skip`() {
        let chrome = chrome(.ask, isAuthorized: false)
        #expect(chrome.header == "Set it up")
        #expect(chrome.title == "Checked in.\nTikTok is open.")
        #expect(chrome.body == "Every reminder works like this. Choose what should wait for you.")
        #expect(chrome.footnotes == [
            .trial(content.trialLine),
            .apple("Apple asks for Screen Time access first. Tap Continue."),
        ])
        #expect(chrome.primary == .init(title: "Choose what to pause", event: .chooseTapped, showsArrow: true))
        #expect(chrome.quietTitle == nil)
    }

    @Test func `Once Screen Time is allowed, the ask drops the Apple line and offers reminders only`() {
        let chrome = chrome(.ask, isAuthorized: true)
        #expect(chrome.title == "Checked in.\nTikTok is open.")
        #expect(chrome.footnotes == [.trial(content.trialLine)])
        #expect(chrome.primary == .init(title: "Choose what to pause", event: .chooseTapped, showsArrow: true))
        #expect(chrome.quietTitle == "Use reminders only")
    }

    @Test func `After a refusal she can ask again or use reminders only`() {
        let chrome = chrome(.refused, refusal: .notAllowed, isAuthorized: false)
        #expect(chrome.header == "Set it up")
        #expect(chrome.title == "Pausing apps needs Screen Time.")
        #expect(chrome.body == "Pillie only uses it to pause what you pick. Apple will ask again.")
        #expect(chrome.footnotes == [.trial(content.trialLine)])
        #expect(chrome.primary == .init(title: "Try again", event: .chooseTapped, showsArrow: false))
        #expect(chrome.quietTitle == "Use reminders only")
        #expect(BlockingRehearsalContent.showsPromptPreview(for: .notAllowed))
    }

    @Test func `Another app holding Screen Time does not promise a second prompt`() {
        #expect(ScreenTimeRefusal(FamilyControlsError.authorizationConflict) == .heldByAnotherApp)
        #expect(ScreenTimeRefusal(FamilyControlsError.authorizationCanceled) == .notAllowed)

        let chrome = chrome(.refused, refusal: .heldByAnotherApp, isAuthorized: false)
        #expect(
            chrome.body
                == "Another app on this iPhone is using Screen Time. Turn it off in that app, then try again."
        )
        #expect(chrome.primary == .init(title: "Try again", event: .chooseTapped, showsArrow: false))
        #expect(chrome.quietTitle == "Use reminders only")
        #expect(!BlockingRehearsalContent.showsPromptPreview(for: .heldByAnotherApp))
    }

    @Test func `Picks continue once authorized and ask first when access was revoked`() {
        let authorized = chrome(.picks, isAuthorized: true)
        #expect(authorized.title == "They’ll wait for you.")
        #expect(authorized.body == "You can change them anytime in Settings.")
        #expect(authorized.footnotes == [.trial(content.trialLine)])
        #expect(authorized.primary == .init(title: "Continue", event: .continueTapped, showsArrow: false))
        #expect(authorized.quietTitle == nil)

        let revoked = chrome(.picks, isAuthorized: false)
        #expect(revoked.primary == .init(title: "Choose what to pause", event: .chooseTapped, showsArrow: true))
        #expect(revoked.quietTitle == nil)
    }

    @Test func `A paid entitlement never sees the trial line`() {
        #expect(chrome(.ask, isAuthorized: false, hasEntitlement: true).footnotes
            == [.apple("Apple asks for Screen Time access first. Tap Continue.")])
        #expect(chrome(.ask, isAuthorized: true, hasEntitlement: true).footnotes == [])
        #expect(chrome(.refused, refusal: .notAllowed, hasEntitlement: true).footnotes == [])
        #expect(chrome(.picks, hasEntitlement: true).footnotes == [])
    }

    // MARK: Words on the cards

    @Test func `The banner and the pause card use the shipped reminder and shield copy`() {
        #expect(content.bannerTitle == PillieLocalization.string("notification.reminder.pill.title", locale: english))
        #expect(content.bannerBody == PillieLocalization.string("notification.reminder.pill.body", locale: english))
        #expect(content.bannerTime == "now")
        #expect(content.pauseCardTitle == "Paused until you check in")
        #expect(content.pauseCardBody == "Check in on Pillie and this app opens again.")
        #expect(content.openPillie == "Open Pillie")
    }

    @Test func `A patch user's banner is the patch reminder`() {
        let patch = BlockingRehearsalContent.localized(
            script: BlockingRehearsalScript(featuredApp: .youtube, method: .patch, reminderHour: 9, reminderMinute: 30),
            locale: english
        )
        #expect(patch.bannerTitle == PillieLocalization.string("notification.reminder.patch.title", locale: english))
        #expect(patch.bannerBody == PillieLocalization.string("notification.reminder.patch.apply.body", locale: english))
        #expect(plainSpaces(patch.reminderTitle) == "Your 9:30 AM reminder just rang.")
        #expect(patch.reminderBody == "Try opening YouTube anyway.")
    }

    @Test func `She checks in one minute after her reminder`() {
        #expect(plainSpaces(content.checkedIn) == "Checked in at 8:01 PM")
        #expect(plainSpaces(content.pauseRowTitle) == "8:00 PM")
        #expect(content.pauseRowBody == "Your reminder rings and these pause.")
        #expect(content.resumeRowTitle == "When you check in")
        #expect(content.resumeRowBody == "They open again straight away.")
    }

    @Test func `The picks card keeps the shipped privacy line`() {
        #expect(content.picksHeader == "Your picks")
        #expect(content.changePicks == "Change")
        #expect(content.categoryCaption == "All apps")
        #expect(
            content.privacyLine
                == "Pillie only sees how many you picked. The apps themselves stay private on this device."
        )
        #expect(content.refusedCaption == "On Apple’s prompt, tap Continue.")
    }

    @Test(arguments: [
        ("Checked in. TikTok is open.", "Checked in.\nTikTok is open."),
        ("記録しました。TikTokが開けるようになりました。", "記録しました。\nTikTokが開けるようになりました。"),
        ("दर्ज हो गया। TikTok ऐप खुला है।", "दर्ज हो गया।\nTikTok ऐप खुला है।"),
        ("درج ہو گیا۔ TikTok ایپ کھلی ہے۔", "درج ہو گیا۔\nTikTok ایپ کھلی ہے۔"),
        ("เช็กอินแล้ว TikTok เปิดได้แล้ว", "เช็กอินแล้ว TikTok เปิดได้แล้ว"),
        ("Checked in.", "Checked in."),
    ])
    func `The ask title breaks after its first sentence`(text: String, expected: String) {
        #expect(BlockingRehearsalContent.breakingAfterFirstSentence(text) == expected)
    }

    // MARK: The trial line

    @Test func `The trial line says the trial starts here`() {
        #expect(BlockingRehearsalContent.trialLine(locale: english) == trialLine)
    }

    @Test func `The trial line counts what an earlier grant has left`() {
        let calendar = Calendar.current
        let resumed = BlockingRehearsalContent.trialLine(
            locale: english,
            trialClock: ReverseTrialClock(
                grantDate: calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 12))!
            ),
            now: calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 10))!
        )
        #expect(resumed == "Pillie Plus is on for your next 10 days, free. No\u{00A0}card. We’ll remind you before it ends.")
    }

    // MARK: Every catalog

    @Test func `Every rehearsal key is translated in every shipped catalog and keeps its arguments`() {
        let catalogs = AppLanguage.allCases.compactMap(\.catalogIdentifier)
        #expect(catalogs.count == 44)

        for identifier in catalogs {
            let locale = Locale(identifier: identifier)
            for key in BlockingRehearsalCopyKey.allCases {
                let value = key.string(locale: locale)
                #expect(value != key.rawValue, "\(identifier) has no value for \(key.rawValue)")
                #expect(!value.isEmpty, "\(identifier) is empty for \(key.rawValue)")
                #expect(
                    value.components(separatedBy: "%@").count - 1 == key.argumentCount,
                    "\(identifier) changes the arguments of \(key.rawValue)"
                )
            }
        }
    }

    @Test func `The catalog holds no rehearsal key the app does not read`() throws {
        let url = try #require(
            Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "en")
        )
        let table = try #require(NSDictionary(contentsOf: url) as? [String: Any])
        let shipped = Set(table.keys.filter { $0.hasPrefix("onboarding.blocking_rehearsal.") })
        #expect(shipped == Set(BlockingRehearsalCopyKey.allCases.map(\.rawValue)))
    }
}
