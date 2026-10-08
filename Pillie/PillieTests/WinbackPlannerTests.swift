//  Value types and literal dates in a fixed Toronto calendar. Class doubles
//  are kept alive for the process: the Xcode 27 beta test host crashes on
//  @MainActor-adjacent deinit.

import Foundation
import Testing

@testable import Pillie

@MainActor
struct WinbackPlannerTests {
    // Expiry is local midnight starting trial day 15.
    private let expiry = date("2026-10-15T00:00:00-04:00")
    private let beforeExpiry = date("2026-10-14T12:00:00-04:00")

    // MARK: - Slot table

    @Test func threeSlotsLandOnTheTableDaysForAnEveningReminder() {
        #expect(plan(reminderHour: 21) == [
            WinbackIntent(
                slot: .expiryDay,
                variant: .reminder,
                fireDate: date("2026-10-15T19:00:00-04:00"),
                detail: .reminderTime(hour: 21, minute: 0)
            ),
            WinbackIntent(
                slot: .dayAfter,
                variant: .reminder,
                fireDate: date("2026-10-16T21:00:00-04:00"),
                detail: .reminderTime(hour: 21, minute: 0)
            ),
            WinbackIntent(
                slot: .lastNote,
                variant: .days,
                fireDate: date("2026-10-22T19:00:00-04:00"),
                detail: .daysLogged(5)
            ),
        ])
    }

    @Test func leadTimeNeverFiresBeforeNine() {
        #expect(plan(reminderHour: 8).map(\.fireDate) == [
            date("2026-10-15T09:00:00-04:00"),
            date("2026-10-16T08:00:00-04:00"),
            date("2026-10-22T09:00:00-04:00"),
        ])
        #expect(plan(reminderHour: 0, reminderMinute: 30).map(\.fireDate) == [
            date("2026-10-15T09:00:00-04:00"),
            date("2026-10-16T00:30:00-04:00"),
            date("2026-10-22T09:00:00-04:00"),
        ])
        #expect(WinbackPlanner.leadMinute(reminderHour: 11, reminderMinute: 15) == 9 * 60 + 15)
        #expect(WinbackPlanner.leadMinute(reminderHour: 10, reminderMinute: 30) == 9 * 60)
    }

    @Test func slotTwoFiresAtTheReminderTime() {
        let slot2 = plan(reminderHour: 18, reminderMinute: 45).first { $0.slot == .dayAfter }
        #expect(slot2?.fireDate == date("2026-10-16T18:45:00-04:00"))
        #expect(slot2?.detail == .reminderTime(hour: 18, minute: 45))
    }

    @Test func slotsKeepWallClockAcrossDSTEnd() {
        // US DST ends 2026-11-01, between slots 2 and 4.
        let intents = plan(expiry: date("2026-10-29T00:00:00-04:00"), reminderHour: 21)
        #expect(intents.map(\.fireDate) == [
            date("2026-10-29T19:00:00-04:00"),
            date("2026-10-30T21:00:00-04:00"),
            date("2026-11-05T19:00:00-05:00"),
        ])
    }

    // MARK: - Skips

    @Test func openWithinADayAfterExpirySkipsTheSlotForGood() {
        let expiryMorning = date("2026-10-15T08:00:00-04:00")
        let openedExpiryMorning = context(lastAppOpen: expiryMorning)
        #expect(
            plan(now: expiryMorning, reminderHour: 21, context: openedExpiryMorning).map(\.slot)
                == [.dayAfter, .lastNote]
        )

        // Later replans keep it skipped: the open only moves forward.
        let laterReplan = plan(now: date("2026-10-15T18:00:00-04:00"), reminderHour: 21, context: openedExpiryMorning)
        #expect(laterReplan.map(\.slot) == [.dayAfter, .lastNote])

        let openedDayAfterEvening = context(lastAppOpen: date("2026-10-16T20:00:00-04:00"))
        #expect(
            plan(now: date("2026-10-16T20:00:00-04:00"), reminderHour: 21, context: openedDayAfterEvening).map(\.slot)
                == [.lastNote]
        )
    }

    @Test func openBeforeExpiryDoesNotSkip() {
        // The evening log on trial day 14 happens before there is a wall to see.
        let loggedLastTrialEvening = context(lastAppOpen: date("2026-10-14T21:05:00-04:00"))
        #expect(plan(reminderHour: 21, context: loggedLastTrialEvening).map(\.slot) == [.expiryDay, .dayAfter, .lastNote])
    }

    @Test func pastSlotsAreDroppedAndNothingFollowsSlotFour() {
        #expect(plan(now: date("2026-10-17T12:00:00-04:00"), reminderHour: 21).map(\.slot) == [.lastNote])
        #expect(plan(now: date("2026-10-22T19:00:00-04:00"), reminderHour: 21).isEmpty)
        #expect(plan(now: date("2027-01-01T12:00:00-05:00"), reminderHour: 21).isEmpty)
    }

    // MARK: - Variants

    @Test func slotFourThanksNewcomersWithoutACount() {
        for days in 0...2 {
            let slot4 = plan(reminderHour: 21, context: context(daysLogged: days)).last
            #expect(slot4?.variant == .new, "\(days) days")
            #expect(slot4?.detail == .daysLogged(days))
        }
        #expect(plan(reminderHour: 21, context: context(daysLogged: 3)).last?.variant == .days)
        #expect(plan(reminderHour: 21, cohort: .blockerConfigured, context: context(daysLogged: 2)).last?.variant == .new)
    }

    @Test func blockerUsersGetBlockerLinesAndStayOutOfTheTest() {
        let blocker = plan(reminderHour: 21, cohort: .blockerConfigured, context: context(slot2Arm: .challenger))
        #expect(blocker.map(\.variant) == [.blocker, .blocker, .blocker])
    }

    @Test func challengerArmOnlyChangesSlotTwoForReminderUsers() {
        let challenger = plan(reminderHour: 21, context: context(slot2Arm: .challenger))
        #expect(challenger.map(\.variant) == [.reminder, .notAReminder, .days])
        let control = plan(reminderHour: 21, context: context(slot2Arm: .control))
        #expect(control.map(\.variant) == [.reminder, .reminder, .days])
    }

    // MARK: - Copy keys

    @Test func slotTwoSaysTodayForADaytimeReminder() {
        #expect(WinbackCopy.titleKey(slot: .dayAfter, variant: .reminder, reminderHour: 8) == "notification.winback.slot2.day.title")
        #expect(WinbackCopy.titleKey(slot: .dayAfter, variant: .reminder, reminderHour: 16) == "notification.winback.slot2.day.title")
        #expect(WinbackCopy.titleKey(slot: .dayAfter, variant: .reminder, reminderHour: 17) == "notification.winback.slot2.title")
        #expect(WinbackCopy.titleKey(slot: .dayAfter, variant: .blocker, reminderHour: 8) == "notification.winback.slot2.blocker.day.title")
        #expect(WinbackCopy.titleKey(slot: .dayAfter, variant: .blocker, reminderHour: 21) == "notification.winback.slot2.blocker.title")
        #expect(WinbackCopy.titleKey(slot: .dayAfter, variant: .notAReminder, reminderHour: 8) == "notification.winback.slot2.challenger.title")
    }

    @Test func everyVariantMapsToItsCatalogKeys() {
        let keys: [(WinbackSlot, WinbackVariant, String, String)] = [
            (.expiryDay, .reminder, "slot1.title", "slot1.body"),
            (.expiryDay, .blocker, "slot1.title", "slot1.blocker.body"),
            (.dayAfter, .reminder, "slot2.title", "slot2.body"),
            (.dayAfter, .notAReminder, "slot2.challenger.title", "slot2.challenger.body"),
            (.dayAfter, .blocker, "slot2.blocker.title", "slot2.blocker.body"),
            (.lastNote, .days, "slot4.title", "slot4.body"),
            (.lastNote, .blocker, "slot4.title", "slot4.blocker.body"),
            (.lastNote, .new, "slot4.title", "slot4.new.body"),
        ]
        for (slot, variant, title, body) in keys {
            #expect(WinbackCopy.titleKey(slot: slot, variant: variant, reminderHour: 21) == "notification.winback.\(title)")
            #expect(WinbackCopy.bodyKey(slot: slot, variant: variant) == "notification.winback.\(body)")
        }
    }

    // MARK: - Payload

    @Test func payloadRoundTripsThroughTheTapParser() {
        let intent = WinbackIntent(
            slot: .lastNote,
            variant: .new,
            fireDate: date("2026-10-22T19:00:00-04:00"),
            detail: .daysLogged(1)
        )
        let parsed = WinbackPayload.push(from: WinbackPayload.userInfo(for: intent))
        #expect(parsed?.slot == .lastNote)
        #expect(parsed?.variant == .new)
        let trialWarning = WinbackPayload.push(from: ["requestKind": "trialExpiryWarning", "winbackSlot": 4])
        #expect(trialWarning?.slot == nil)
    }

    @Test func aDeliveredRetiredSlotThreePushOpensNothing() {
        let retired: [AnyHashable: Any] = ["requestKind": "winback", "winbackSlot": 3, "winbackVariant": "days"]
        #expect(WinbackPayload.push(from: retired)?.slot == nil)
        let slotFour: [AnyHashable: Any] = ["requestKind": "winback", "winbackSlot": 4, "winbackVariant": "days"]
        #expect(WinbackPayload.push(from: slotFour)?.slot == .lastNote)
    }

    // MARK: - Helpers

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    private func context(
        daysLogged: Int = 5,
        lastAppOpen: Date? = nil,
        slot2Arm: WinbackSlot2Arm = .control
    ) -> WinbackContext {
        WinbackContext(daysLogged: daysLogged, lastAppOpen: lastAppOpen, slot2Arm: slot2Arm)
    }

    private func plan(
        now: Date? = nil,
        expiry: Date? = nil,
        reminderHour: Int,
        reminderMinute: Int = 0,
        cohort: TrialEndPaywallCohort = .reminderOnly,
        context: WinbackContext? = nil
    ) -> [WinbackIntent] {
        WinbackPlanner.plan(
            WinbackPlanInput(
                now: now ?? beforeExpiry,
                expiry: expiry ?? self.expiry,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                cohort: cohort,
                context: context ?? self.context(),
                calendar: Self.calendar
            )
        )
    }
}

@MainActor
struct WinbackReminderPlannerTests {
    private let planner = ReminderSchedulePlanner()

    @Test func hardPaywallWinbacksReplaceTheExpiryDayNotice() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        let intents = plan(fixture.store, now: now, terms: .hardPaywall, winback: winbackContext)

        #expect(intents.compactMap(\.trialWarningDay).sorted() == [10, 13])
        #expect(intents.compactMap(\.winbackSlot) == [.expiryDay, .dayAfter, .lastNote])
    }

    @Test func withoutContextThePlanIsUnchanged() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        let intents = plan(fixture.store, now: now, terms: .hardPaywall, winback: nil)

        #expect(intents.compactMap(\.trialWarningDay).sorted() == [10, 13, 15])
        #expect(intents.compactMap(\.winbackSlot).isEmpty)
    }

    @Test func legacyAndEntitledUsersGetNoWinbacks() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: now)

        let legacy = plan(fixture.store, now: now, terms: .legacy, winback: winbackContext)
        let entitled = plan(fixture.store, now: now, terms: .hardPaywall, hasEntitlement: true, winback: winbackContext)

        #expect(legacy.compactMap(\.winbackSlot).isEmpty)
        #expect(legacy.compactMap(\.trialWarningDay).sorted() == [10, 13, 15])
        #expect(!entitled.isEmpty)
        #expect(entitled.compactMap(\.winbackSlot).isEmpty)
        #expect(entitled.compactMap(\.trialWarningDay).isEmpty)
    }

    @Test func winbacksOutliveTheHardPaywallAccessEnd() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let now = InMemoryStoreFactory.fixedDate("2026-05-26", hour: 9)
        let grant = try #require(Calendar.current.date(byAdding: .day, value: -16, to: now))
        let fixture = try InMemoryStoreFactory.makeStore(now: now, startDate: grant)

        let intents = plan(fixture.store, now: now, grant: grant, terms: .hardPaywall, winback: winbackContext)

        #expect(intents.allSatisfy { $0.winbackSlot != nil })
        #expect(intents.compactMap(\.winbackSlot) == [.lastNote])
    }

    private var winbackContext: WinbackContext {
        WinbackContext(daysLogged: 4, lastAppOpen: nil, slot2Arm: .control)
    }

    private func plan(
        _ store: PillStore,
        now: Date,
        grant: Date? = nil,
        terms: TrialEndAccessTerms,
        hasEntitlement: Bool = false,
        winback: WinbackContext?
    ) -> [ReminderSchedulePlanner.Intent] {
        let candidateDueActions = DoseScheduleEngine.nextDueActions(
            from: now,
            limit: ReminderSchedulePlanner.dueScanLimit,
            pack: store.pack
        )
        return planner.planReminders(
            ReminderSchedulePlanner.Input(
                now: now,
                scheduleDay: store.today,
                pack: store.pack,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute,
                autoReminderIntervalMinutes: store.autoReminderIntervalMinutes,
                autoReminderRetryLimit: store.autoReminderRetryLimit,
                refillReminderThresholdDays: store.refillReminderThresholdDays,
                patchRestockReminderThresholdPatches: store.patchRestockReminderThresholdPatches,
                candidateDueActions: candidateDueActions,
                statusByEpochDay: store.statusesByEpochDay(for: candidateDueActions.map(\.date)),
                snoozeOverride: nil,
                smartRemindersEnabled: true,
                cycleTransitionEnabled: true,
                trialGrantDate: grant ?? now,
                hasEntitlement: hasEntitlement,
                trialEndTerms: terms,
                winback: winback,
                servedBaseFireDateByDueDayEpoch: [:],
                calendar: .current
            )
        )
    }
}

@MainActor
struct WinbackExtendSecondChanceTests {
    @Test func slotThreeRearmsADeclinedCardExactlyOnce() {
        let store = InMemoryTrialEndExtendOfferStore()

        #expect(store.record(.present) == .shown)
        #expect(store.record(.decline) == .declined)
        #expect(store.record(.rearm) == .rearmed)
        #expect(store.record(.present) == .reshown)
        #expect(store.record(.decline) == .closed)
        #expect(store.record(.rearm) == .closed)
        #expect(store.record(.present) == .closed)
        #expect(store.loadPhase().offers == false)
    }

    @Test func rearmFromShownAndAcceptOnTheSecondShowing() {
        let store = InMemoryTrialEndExtendOfferStore()

        #expect(store.record(.present) == .shown)
        #expect(store.record(.rearm) == .rearmed)
        #expect(store.record(.rearm) == .rearmed)
        #expect(store.record(.present) == .reshown)
        #expect(store.record(.accept) == .accepted)
        #expect(store.record(.rearm) == .accepted)
    }

    @Test func rearmNeverAppliesBeforeTheFirstShowing() {
        #expect(TrialEndExtendOfferPhase.unseen.next(on: .rearm) == .unseen)
    }

    @Test func onlyUnseenAndRearmedOffer() {
        let all: [TrialEndExtendOfferPhase] = [.unseen, .shown, .accepted, .declined, .rearmed, .reshown, .closed]
        #expect(all.filter(\.offers) == [.unseen, .rearmed])
        #expect(all.filter(\.allowsWinbackPitch) == [.unseen, .shown, .declined])
    }

    @Test func decisionOffersTheRearmedCard() {
        let offer = TrialEndExtendOfferDecision.offer(
            trigger: .sheetCancel,
            isTrialEndBoard: true,
            phase: .rearmed,
            eligibility: .eligible,
            product: TrialEndExtendProduct(productID: SubscriptionManager.extendAnnualProductID, priceDisplay: "$29.99", freeDays: 7),
            now: date("2026-10-18T19:05:00-04:00"),
            calendar: .current
        )
        #expect(offer?.trigger == .sheetCancel)
        #expect(TrialEndExtendOfferDecision.offer(
            trigger: .sheetCancel,
            isTrialEndBoard: true,
            phase: .reshown,
            eligibility: .eligible,
            product: TrialEndExtendProduct(productID: SubscriptionManager.extendAnnualProductID, priceDisplay: "$29.99", freeDays: 7),
            now: date("2026-10-18T19:05:00-04:00"),
            calendar: .current
        ) == nil)
    }
}

@MainActor
struct WinbackTelemetryTests {
    private static var keptObjects: [AnyObject] = []
    private let open = WinbackOpen(slot: .lastNote, variant: .new, date: date("2026-10-22T19:05:00-04:00"))

    @Test func pushEventsCarrySlotAndVariant() {
        let (telemetry, client) = makeTelemetry(name: "push")

        telemetry.winbackNotificationScheduled(slot: .expiryDay)
        telemetry.winbackNotificationOpened(slot: .lastNote, variant: .new)

        #expect(client.events == [
            WinbackAnalyticsClientSpy.Event(
                name: "winback_notification_scheduled",
                properties: ["slot": .int(1), "is_plus": .bool(false)]
            ),
            WinbackAnalyticsClientSpy.Event(
                name: "winback_notification_opened",
                properties: ["slot": .int(4), "variant": .string("new"), "is_plus": .bool(false)]
            ),
        ])
    }

    @Test func wallOpenedFromAPushIsAWinbackView() {
        let (telemetry, client) = makeTelemetry(name: "viewed")

        telemetry.trialEndPaywallViewed(fromWinback: open, cohort: .blockerConfigured, terms: .hardPaywall)

        #expect(client.events == [
            WinbackAnalyticsClientSpy.Event(
                name: "paywall_viewed",
                properties: [
                    "source": .string("winback"),
                    "surface": .string("trial_end"),
                    "cohort": .string("blocker_configured"),
                    "paywall_variant": .string("blocker_configured"),
                    "trial_terms_cohort": .string("post_cutover"),
                    "slot": .int(4),
                    "variant": .string("new"),
                    "is_plus": .bool(false),
                ]
            ),
        ])
    }

    @Test func conversionsWithinADayOfAnOpenCreditThePush() {
        let (attributed, attributedClient) = makeTelemetry(name: "attributed", recentOpen: open)
        attributed.trialEndPurchaseCompleted(plan: .annual, cohort: .reminderOnly, terms: .hardPaywall)
        attributed.trialEndTrialStarted(plan: .annual, cohort: .reminderOnly, terms: .hardPaywall)
        attributed.trialEndPurchaseStarted(plan: .annual, cohort: .reminderOnly, terms: .hardPaywall)

        #expect(attributedClient.events.map(\.name) == ["purchase_completed", "trial_started", "purchase_started"])
        for event in attributedClient.events.prefix(2) {
            #expect(event.properties["winback_slot"] == .int(4), "\(event.name)")
            #expect(event.properties["winback_variant"] == .string("new"), "\(event.name)")
            #expect(event.properties["source"] == .string("trial_end"), "\(event.name)")
        }
        #expect(attributedClient.events[2].properties["winback_slot"] == nil)

        let (plain, plainClient) = makeTelemetry(name: "plain", recentOpen: nil)
        plain.trialEndPurchaseCompleted(plan: .annual, cohort: .reminderOnly, terms: .hardPaywall)
        #expect(plainClient.events.first?.properties == [
            "source": .string("trial_end"),
            "surface": .string("trial_end"),
            "plan": .string("annual"),
            "result": .string("completed"),
            "cohort": .string("reminder_only"),
            "paywall_variant": .string("reminder_only"),
            "trial_terms_cohort": .string("post_cutover"),
            "is_plus": .bool(false),
        ])
    }

    @Test func attributionWindowIsOneDay() {
        #expect(open.attributes(at: date("2026-10-23T19:04:59-04:00")))
        #expect(!open.attributes(at: date("2026-10-23T19:05:00-04:00")))
        #expect(!open.attributes(at: date("2026-10-22T19:04:00-04:00")))
    }

    private func makeTelemetry(
        name: String,
        recentOpen: WinbackOpen? = nil
    ) -> (ProductAnalyticsTelemetry, WinbackAnalyticsClientSpy) {
        let client = WinbackAnalyticsClientSpy()
        let defaultsName = "WinbackTelemetryTests.\(name)"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com",
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(client)
        Self.keptObjects.append(analytics)
        analytics.configure()
        let telemetry = ProductAnalyticsTelemetry(
            analytics: analytics,
            isPlus: { false },
            recentWinbackOpen: { recentOpen }
        )
        return (telemetry, client)
    }
}

private final class WinbackAnalyticsClientSpy: ProductAnalyticsClient {
    struct Event: Equatable {
        let name: String
        let properties: [String: AnalyticsPropertyValue]
    }

    private(set) var events: [Event] = []

    func configure(_ configuration: ProductAnalyticsConfiguration) {}

    func capture(
        event: String,
        properties: [String: AnalyticsPropertyValue],
        personProperties: [String: AnalyticsPropertyValue]
    ) {
        events.append(Event(name: event, properties: properties))
    }

    func distinctId() -> String? { nil }

    func flush() {}
}

private extension ReminderSchedulePlanner.Intent {
    var trialWarningDay: Int? {
        if case .trialExpiryWarning(let warning) = self { return warning.day }
        return nil
    }

    var winbackSlot: WinbackSlot? {
        if case .winback(let winback) = self { return winback.slot }
        return nil
    }
}

private func date(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
}
