import Foundation
import Testing
import UIKit

@testable import Pillie

struct BlockingRehearsalScriptTests {
    private let english = Locale(identifier: "en_US")

    private func script(
        _ choices: Set<DistractionChoice> = [],
        method: ContraceptiveMethod = .pill,
        hour: Int = 20,
        minute: Int = 0
    ) -> BlockingRehearsalScript {
        BlockingRehearsalScript(distractionChoices: choices, method: method, reminderHour: hour, reminderMinute: minute)
    }

    private func plainSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    @Test func `Her first named app is featured, in the list's order`() {
        #expect(script([.youtube, .instagram, .busy]).featuredApp == .instagram)
        #expect(script([.messages, .youtube]).featuredApp == .youtube)
        #expect(script([.messages]).featuredApp == .messages)
        #expect(script([.tiktok, .instagram, .youtube, .messages]).featuredApp == .tiktok)
    }

    @Test func `With no named app TikTok is featured`() {
        #expect(script([.snooze, .busy, .forget, .other]).featuredApp == .tiktok)
        #expect(script([]).featuredApp == .tiktok)
    }

    @Test func `The featured app carries its shipped name`() {
        #expect(BlockingRehearsalApp.instagram.name(locale: english) == "Instagram")
        #expect(BlockingRehearsalApp.messages.name(locale: Locale(identifier: "de")) == "Nachrichten")
    }

    @Test func `She checks in one minute after her reminder, across midnight too`() {
        #expect(plainSpaces(script(hour: 20, minute: 0).reminderClock(locale: english)) == "8:00 PM")
        #expect(plainSpaces(script(hour: 20, minute: 0).checkedInClock(locale: english)) == "8:01 PM")
        #expect(plainSpaces(script(hour: 8, minute: 59).checkedInClock(locale: english)) == "9:00 AM")
        #expect(plainSpaces(script(hour: 23, minute: 59).checkedInClock(locale: english)) == "12:00 AM")
        #expect(plainSpaces(script(hour: 0, minute: 0).reminderClock(locale: english)) == "12:00 AM")
    }

    @Test func `Each method plays its own clip and shows its own reminder`() {
        #expect(script(method: .pill).shakeClip == .pill)
        #expect(script(method: .patch).shakeClip == .patchApply)
        #expect(script(method: .ring).shakeClip == .ringInsert)

        #expect(
            script(method: .pill).reminderAction.localizedReminderBody(locale: english)
                == PillieLocalization.string("notification.reminder.pill.body", locale: english)
        )
        #expect(
            script(method: .patch).reminderAction.localizedReminderBody(locale: english)
                == PillieLocalization.string("notification.reminder.patch.apply.body", locale: english)
        )
        #expect(
            script(method: .ring).reminderAction.localizedReminderBody(locale: english)
                == PillieLocalization.string("notification.reminder.ring.insert.body", locale: english)
        )
    }

    @Test func `The paused apps are neutral tiles with the distraction question's symbols`() {
        #expect(BlockingRehearsalApp.allCases.map(\.icon) == [
            .symbol("music.note"),
            .symbol("camera.fill"),
            .symbol("play.rectangle.fill"),
            .symbol("message.fill"),
        ])
    }

    @Test func `Row two is labeled with the catalog's home screen names`() {
        #expect(BlockingRehearsalSystemApp.allCases.map { $0.label.string(locale: english) }
            == ["Photos", "Camera", "Maps", "Notes"])
        #expect(BlockingRehearsalSystemApp.camera.label.string(locale: Locale(identifier: "fr")) == "Appareil photo")
    }
}
