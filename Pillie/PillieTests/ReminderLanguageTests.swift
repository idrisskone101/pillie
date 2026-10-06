//
//  ReminderLanguageTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class ReminderLanguageTests: XCTestCase {
    private var storedLanguage: String?

    override func setUp() {
        super.setUp()
        storedLanguage = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.set(storedLanguage, forKey: AppLanguage.storageKey)
        super.tearDown()
    }

    func testCopyWithoutALocaleFollowsTheLanguagePickedInPillie() {
        UserDefaults.standard.set(AppLanguage.german.rawValue, forKey: AppLanguage.storageKey)

        XCTAssertEqual(PillieLocalization.string("notification.reminder.pill.title"), "Zeit für deine Pille")
        XCTAssertEqual(PillieLocalization.string("notification.followup.title"), "Heute noch zu erledigen")
    }

    func testSystemLanguageFallsBackToThePhone() {
        UserDefaults.standard.set(AppLanguage.system.rawValue, forKey: AppLanguage.storageKey)

        XCTAssertEqual(PillieLocalization.appLocale.identifier, Locale.current.identifier)
    }

    func testOnlyPendingRemindersWhoseWordsChangedAreRewritten() {
        typealias Wording = NotificationManager.ReminderWording
        let existing = [
            "a": Wording(title: "Time for your pill", body: "Take today’s pill."),
            "b": Wording(title: "Still to do today", body: "Check in when you can."),
            "stale": Wording(title: "Old", body: "Old"),
        ]
        let new = [
            "a": Wording(title: "Zeit für deine Pille", body: "Nimm die heutige Pille."),
            "b": Wording(title: "Still to do today", body: "Check in when you can."),
            "added": Wording(title: "New", body: "New"),
        ]

        XCTAssertEqual(NotificationManager.rewordedReminderIDs(existing: existing, new: new), ["a"])
    }
}
