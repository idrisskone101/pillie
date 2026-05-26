//
//  InMemoryStoreFactory.swift
//  PillieTests
//

import Foundation
import SwiftData
@testable import Pillie

@MainActor
struct InMemoryStoreFixture {
    let container: ModelContainer
    let context: ModelContext
    let store: PillStore
    let pack: PillPack
}

@MainActor
enum InMemoryStoreFactory {
    static func fixedDate(_ isoDate: String) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!

        let parts = isoDate.split(separator: "-").compactMap { Int($0) }
        precondition(parts.count == 3, "Use YYYY-MM-DD dates in tests.")

        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: parts[0],
            month: parts[1],
            day: parts[2],
            hour: 12
        ))!
    }

    static func fixedDate(
        _ isoDate: String,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!

        let parts = isoDate.split(separator: "-").compactMap { Int($0) }
        precondition(parts.count == 3, "Use YYYY-MM-DD dates in tests.")

        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: parts[0],
            month: parts[1],
            day: parts[2],
            hour: hour,
            minute: minute
        ))!
    }

    static func makeStore(
        now: Date,
        method: ContraceptiveMethod = .pill,
        regimen: PillPack.PillRegimenPreset = .twentyOneSeven,
        customActiveDays: Int? = nil,
        customBreakDays: Int? = nil,
        startDate: Date? = nil,
        ringInsertionDate: Date? = nil
    ) throws -> InMemoryStoreFixture {
        resetDefaults()
        PillieClock.setFixedNowForTesting(now)

        let schema = Schema([PillPack.self, PillDay.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let pack = PillPack(
            packType: .twentyOneSeven,
            method: method,
            pillRegimen: method == .pill ? regimen : .twentyOneSeven,
            customActiveDays: customActiveDays,
            customBreakDays: customBreakDays,
            startDate: startDate ?? PillieClock.today,
            packNumber: 1,
            isCurrent: true
        )
        pack.ringInsertionDate = ringInsertionDate
        context.insert(pack)
        try context.save()

        let store = PillStore(modelContext: context)
        store.appActivatedDate = startDate ?? PillieClock.today
        store.reminderHour = 8
        store.reminderMinute = 0
        store.autoReminderIntervalMinutes = 10
        store.refillReminderThresholdDays = 5
        store.patchRestockReminderThresholdPatches = 1

        return InMemoryStoreFixture(
            container: container,
            context: context,
            store: store,
            pack: pack
        )
    }

    static func resetClockAndDefaults() {
        PillieClock.setFixedNowForTesting(nil)
        resetDefaults()
    }

    private static func resetDefaults() {
        let defaults = UserDefaults.standard
        [
            "pillie_reminder_hour",
            "pillie_reminder_minute",
            "pillie_auto_reminder_interval_minutes",
            "pillie_refill_reminder_threshold_days",
            "pillie_patch_restock_threshold_patches",
            "pillie_contraceptive_method",
            "pillie_app_activated_date",
            "pillie_streak_reset_date",
            "pillie_pain_points",
            "personalGoal",
            "missFrequency"
        ].forEach { defaults.removeObject(forKey: $0) }
    }
}
