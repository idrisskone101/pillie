//
//  CustomReminderNotificationTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

/// Verifies the build-time Plus gate for Custom Reminder Messages through the real
/// notification build path (`managedRequestSummariesForTesting` + `setPlusForTesting`),
/// mirroring NotificationEdgeCaseTests. The default copy is captured from the build path
/// itself (a non-Plus run) so the assertions never hardcode the method-aware strings.
///
/// The class is intentionally NOT `@MainActor` (only the individual test methods are):
/// a `@MainActor` XCTestCase subclass aborts on deinit under the Xcode 27 beta hosted
/// runner. Keeping the class deinit nonisolated dodges that crash while each method still
/// hops to the main actor for the `@MainActor` store factory.
final class CustomReminderNotificationTests: XCTestCase {

    @MainActor
    private func baseReminder(
        store: PillStore,
        now: Date
    ) -> NotificationManager.ReminderRequestDebugSummary? {
        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: store,
            now: now
        )
        let todayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        return summaries.first {
            $0.dueDayEpoch == todayEpoch && $0.requestKind == "base"
        }
    }

    @MainActor
    private func retryReminder(
        store: PillStore,
        now: Date
    ) -> NotificationManager.ReminderRequestDebugSummary? {
        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: store,
            now: now
        )
        let todayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        return summaries.first {
            $0.dueDayEpoch == todayEpoch && $0.requestKind == "retry"
        }
    }

    @MainActor
    private func lastCallReminder(
        store: PillStore,
        now: Date
    ) -> NotificationManager.ReminderRequestDebugSummary? {
        let summaries = NotificationManager.shared.managedRequestSummariesForTesting(
            store: store,
            now: now
        )
        let todayEpoch = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        return summaries.first {
            $0.dueDayEpoch == todayEpoch && $0.requestKind == "lastCall"
        }
    }

    @MainActor
    private func cleanUp() {
        SubscriptionManager.shared.setPlusForTesting(false)
        InMemoryStoreFactory.resetClockAndDefaults()
    }

    @MainActor
    func testPlusUserWithCustomCopyGetsCustomTitleAndBody() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.customDueReminderTitle = "Take your pill, love 💖"
        fixture.store.customDueReminderBody = "Just a tiny moment for you."
        SubscriptionManager.shared.setPlusForTesting(true)

        let base = try XCTUnwrap(baseReminder(store: fixture.store, now: now))
        XCTAssertEqual(base.title, "Take your pill, love 💖")
        XCTAssertEqual(base.body, "Just a tiny moment for you.")
        cleanUp()
    }

    @MainActor
    func testBlankFieldFallsBackToDefaultIndependently() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        // Capture the default copy from a non-Plus run (custom is ignored → defaults).
        let defaultBase = try XCTUnwrap(baseReminder(store: fixture.store, now: now))
        let defaultBody = defaultBase.body
        XCTAssertFalse(defaultBase.title.isEmpty)
        XCTAssertFalse(defaultBody.isEmpty)

        // Plus, custom title only — body is blank and must fall back independently.
        fixture.store.customDueReminderTitle = "My own title"
        fixture.store.customDueReminderBody = "   "
        SubscriptionManager.shared.setPlusForTesting(true)

        let base = try XCTUnwrap(baseReminder(store: fixture.store, now: now))
        XCTAssertEqual(base.title, "My own title")
        XCTAssertEqual(base.body, defaultBody)
        XCTAssertFalse(base.body.isEmpty, "An empty notification body can never fire.")
        cleanUp()
    }

    @MainActor
    func testNonPlusUserIgnoresStoredCustomCopyAndDefaultsFire() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        // Default copy from a non-Plus run with no custom set.
        let defaultBase = try XCTUnwrap(baseReminder(store: fixture.store, now: now))
        let defaultTitle = defaultBase.title
        let defaultBody = defaultBase.body

        // Stored custom copy is retained but must be ignored while not Plus.
        fixture.store.customDueReminderTitle = "Resubscribe to see me"
        fixture.store.customDueReminderBody = "Hidden until Plus"
        SubscriptionManager.shared.setPlusForTesting(false)

        let base = try XCTUnwrap(baseReminder(store: fixture.store, now: now))
        XCTAssertEqual(base.title, defaultTitle)
        XCTAssertEqual(base.body, defaultBody)
        cleanUp()
    }

    @MainActor
    func testCustomCopyTrimsSurroundingWhitespaceWhenFired() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.customDueReminderTitle = "   Log it 💊   "
        fixture.store.customDueReminderBody = "  Don't forget — okay?  "
        SubscriptionManager.shared.setPlusForTesting(true)

        let base = try XCTUnwrap(baseReminder(store: fixture.store, now: now))
        XCTAssertEqual(base.title, "Log it 💊")
        XCTAssertEqual(base.body, "Don't forget — okay?")
        cleanUp()
    }

    // MARK: - Auto-Reminder Retry customization

    @MainActor
    func testPlusUserWithCustomRetryCopyGetsCustomRetryTitleAndBody() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        // Retries only build for Plus users; one retry is enough to assert its copy.
        fixture.store.autoReminderRetryLimit = 1
        fixture.store.customRetryReminderTitle = "Still nudging you 👀"
        fixture.store.customRetryReminderBody = "Whenever you're ready — no rush."
        SubscriptionManager.shared.setPlusForTesting(true)

        let retry = try XCTUnwrap(retryReminder(store: fixture.store, now: now))
        XCTAssertEqual(retry.title, "Still nudging you 👀")
        XCTAssertEqual(retry.body, "Whenever you're ready — no rush.")

        // The retry copy is independent of the base reminder.
        let base = try XCTUnwrap(baseReminder(store: fixture.store, now: now))
        XCTAssertNotEqual(retry.title, base.title)
        cleanUp()
    }

    @MainActor
    func testBlankRetryFieldFallsBackToDefaultRetryCopyIndependently() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.autoReminderRetryLimit = 1
        SubscriptionManager.shared.setPlusForTesting(true)

        // Capture the default retry copy (no custom set).
        let defaultRetry = try XCTUnwrap(retryReminder(store: fixture.store, now: now))
        let defaultRetryBody = defaultRetry.body
        XCTAssertFalse(defaultRetry.title.isEmpty)
        XCTAssertFalse(defaultRetryBody.isEmpty)

        // Custom retry title only — the blank body must fall back independently.
        fixture.store.customRetryReminderTitle = "My follow-up line"
        fixture.store.customRetryReminderBody = "   "

        let retry = try XCTUnwrap(retryReminder(store: fixture.store, now: now))
        XCTAssertEqual(retry.title, "My follow-up line")
        XCTAssertEqual(retry.body, defaultRetryBody)
        XCTAssertFalse(retry.body.isEmpty, "An empty notification body can never fire.")
        cleanUp()
    }

    // MARK: - Last Call Reminder customization

    @MainActor
    func testPlusUserWithCustomLastCallCopyGetsCustomTitleAndBody() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        // Last Call only schedules for Plus users with the backstop enabled.
        fixture.store.lastCallReminderEnabled = true
        fixture.store.customLastCallReminderTitle = "Last chance, love 🌙"
        fixture.store.customLastCallReminderBody = "The day's nearly done — log it."
        SubscriptionManager.shared.setPlusForTesting(true)

        let lastCall = try XCTUnwrap(lastCallReminder(store: fixture.store, now: now))
        XCTAssertEqual(lastCall.title, "Last chance, love 🌙")
        XCTAssertEqual(lastCall.body, "The day's nearly done — log it.")

        // The Last Call copy is independent of the base reminder.
        let base = try XCTUnwrap(baseReminder(store: fixture.store, now: now))
        XCTAssertNotEqual(lastCall.body, base.body)
        cleanUp()
    }

    @MainActor
    func testBlankLastCallFieldFallsBackToDefaultLastCallCopyIndependently() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.lastCallReminderEnabled = true
        SubscriptionManager.shared.setPlusForTesting(true)

        // Capture the default Last Call copy (no custom set).
        let defaultLastCall = try XCTUnwrap(lastCallReminder(store: fixture.store, now: now))
        let defaultBody = defaultLastCall.body
        XCTAssertFalse(defaultLastCall.title.isEmpty)
        XCTAssertFalse(defaultBody.isEmpty)

        // Custom title only — the blank body must fall back independently.
        fixture.store.customLastCallReminderTitle = "My own last call"
        fixture.store.customLastCallReminderBody = "   "

        let lastCall = try XCTUnwrap(lastCallReminder(store: fixture.store, now: now))
        XCTAssertEqual(lastCall.title, "My own last call")
        XCTAssertEqual(lastCall.body, defaultBody)
        XCTAssertFalse(lastCall.body.isEmpty, "An empty notification body can never fire.")
        cleanUp()
    }

    @MainActor
    func testCustomLastCallCopyTrimsSurroundingWhitespaceWhenFired() throws {
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 7)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)
        fixture.store.lastCallReminderEnabled = true
        fixture.store.customLastCallReminderTitle = "   Last call 🌙   "
        fixture.store.customLastCallReminderBody = "  Wrap up your day — okay?  "
        SubscriptionManager.shared.setPlusForTesting(true)

        let lastCall = try XCTUnwrap(lastCallReminder(store: fixture.store, now: now))
        XCTAssertEqual(lastCall.title, "Last call 🌙")
        XCTAssertEqual(lastCall.body, "Wrap up your day — okay?")
        cleanUp()
    }
}
