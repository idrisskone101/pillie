//
//  DataMigration.swift
//  Pillie
//

import Foundation
import SwiftData

enum DataMigration {

    // MARK: - Legacy types matching the old JSON format

    private struct LegacyPillDay: Codable {
        let id: UUID
        let date: Date
        var status: Status

        enum Status: String, Codable {
            case taken
            case missed
            case upcoming
            case breakDay
        }
    }

    private struct LegacyPillPack: Codable {
        var packType: PackType
        var startDate: Date
        var packNumber: Int

        enum PackType: String, Codable {
            case twentyOneSeven = "21/7"
            case twentyFourFour = "24/4"
            case twentyEightZero = "28/0"
        }
    }

    // MARK: - Keys

    private static let sentinelKey = "pillie_migrated_to_swiftdata"
    private static let relationshipBackfillKey = "pillie_backfilled_day_pack_relationship"
    private static let protocolBackfillKey = "pillie_backfilled_pack_protocol_metadata"
    private static let actionTypeBackfillKey = "pillie_backfilled_day_action_type"
    private static let activationDateBackfillKey = "pillie_backfilled_activation_date"
    private static let packKey = "pillie_pack"
    private static let daysKey = "pillie_days"

    // MARK: - Migration

    static func migrateFromUserDefaultsIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard

        if !defaults.bool(forKey: sentinelKey) {
            let decoder = JSONDecoder()
            var migratedPack: PillPack?

            // Migrate PillPack
            if let data = defaults.data(forKey: packKey),
               let legacy = try? decoder.decode(LegacyPillPack.self, from: data) {
                let packType: PillPack.PackType
                let regimen: PillPack.PillRegimenPreset
                switch legacy.packType {
                case .twentyOneSeven:
                    packType = .twentyOneSeven
                    regimen = .twentyOneSeven
                case .twentyFourFour:
                    packType = .twentyFourFour
                    regimen = .twentyFourFour
                case .twentyEightZero:
                    packType = .twentyEightZero
                    regimen = .twentyEightZero
                }
                let pack = PillPack(
                    packType: packType,
                    method: .pill,
                    pillRegimen: regimen,
                    startDate: legacy.startDate,
                    packNumber: legacy.packNumber,
                    isCurrent: true
                )
                context.insert(pack)
                migratedPack = pack
            }

            // Migrate PillDays
            if let data = defaults.data(forKey: daysKey),
               let legacyDays = try? decoder.decode([LegacyPillDay].self, from: data) {
                for legacy in legacyDays {
                    let status: PillDay.Status
                    switch legacy.status {
                    case .taken: status = .taken
                    case .missed: status = .missed
                    case .upcoming: status = .upcoming
                    case .breakDay: status = .breakDay
                    }
                    let day = PillDay(
                        id: legacy.id,
                        date: legacy.date,
                        status: status,
                        actionType: status == .breakDay ? .pillBreak : .pillActive,
                        pack: migratedPack
                    )
                    context.insert(day)
                }
            }

            try? context.save()

            // Clean up old keys
            defaults.removeObject(forKey: packKey)
            defaults.removeObject(forKey: daysKey)
            defaults.set(true, forKey: sentinelKey)
        }

        backfillPackRelationshipIfNeeded(context: context, defaults: defaults)
        backfillPackProtocolMetadataIfNeeded(context: context, defaults: defaults)
        backfillDayActionTypeIfNeeded(context: context, defaults: defaults)
        backfillActivationDateIfNeeded(context: context, defaults: defaults)
    }

    private static func backfillPackRelationshipIfNeeded(context: ModelContext, defaults: UserDefaults) {
        guard !defaults.bool(forKey: relationshipBackfillKey) else { return }

        let packDescriptor = FetchDescriptor<PillPack>(sortBy: [SortDescriptor(\.packNumber, order: .reverse)])
        let packs = (try? context.fetch(packDescriptor)) ?? []

        let activePack: PillPack
        if let existingPack = packs.first {
            activePack = existingPack
        } else {
            let defaultStartDate = Calendar.current.startOfDay(for: Date())
            let defaultPack = PillPack(
                packType: .twentyOneSeven,
                method: .pill,
                pillRegimen: .twentyOneSeven,
                startDate: defaultStartDate,
                packNumber: 1,
                isCurrent: true
            )
            context.insert(defaultPack)
            activePack = defaultPack
        }

        let orphanDescriptor = FetchDescriptor<PillDay>(
            predicate: #Predicate<PillDay> { day in
                day.pack == nil
            }
        )
        let orphanDays = (try? context.fetch(orphanDescriptor)) ?? []

        for day in orphanDays {
            day.pack = activePack
        }

        try? context.save()
        defaults.set(true, forKey: relationshipBackfillKey)
    }

    private static func backfillPackProtocolMetadataIfNeeded(context: ModelContext, defaults: UserDefaults) {
        guard !defaults.bool(forKey: protocolBackfillKey) else { return }

        let descriptor = FetchDescriptor<PillPack>(sortBy: [SortDescriptor(\.packNumber, order: .forward)])
        let packs = (try? context.fetch(descriptor)) ?? []
        guard !packs.isEmpty else {
            defaults.set(true, forKey: protocolBackfillKey)
            return
        }

        for pack in packs {
            if ContraceptiveMethod(rawValue: pack.methodRaw) == nil {
                pack.methodRaw = ContraceptiveMethod.pill.rawValue
            }

            if PillPack.PillRegimenPreset(rawValue: pack.pillRegimenRaw) == nil {
                switch pack.packType {
                case .twentyOneSeven:
                    pack.pillRegimenRaw = PillPack.PillRegimenPreset.twentyOneSeven.rawValue
                case .twentyFourFour:
                    pack.pillRegimenRaw = PillPack.PillRegimenPreset.twentyFourFour.rawValue
                case .twentyEightZero:
                    pack.pillRegimenRaw = PillPack.PillRegimenPreset.twentyEightZero.rawValue
                }
            }

            if pack.pillRegimen == .custom {
                let normalized = PillPack.normalizedCustomValues(
                    active: pack.customActiveDays,
                    breakDays: pack.customBreakDays
                )
                pack.customActiveDays = normalized.active
                pack.customBreakDays = normalized.breakDays
            }
        }

        if !packs.contains(where: { $0.isCurrent }),
           let latest = packs.max(by: { $0.packNumber < $1.packNumber }) {
            latest.isCurrent = true
        }

        try? context.save()
        defaults.set(true, forKey: protocolBackfillKey)
    }

    private static func backfillDayActionTypeIfNeeded(context: ModelContext, defaults: UserDefaults) {
        guard !defaults.bool(forKey: actionTypeBackfillKey) else { return }

        let dayDescriptor = FetchDescriptor<PillDay>()
        let days = (try? context.fetch(dayDescriptor)) ?? []

        for day in days {
            if PillDay.ActionType(rawValue: day.actionTypeRaw) != nil {
                continue
            }

            let inferred: PillDay.ActionType
            if let pack = day.pack, let due = DoseScheduleEngine.dueAction(on: day.date, pack: pack) {
                inferred = due.type
            } else if day.status == .breakDay {
                inferred = .pillBreak
            } else {
                inferred = .pillActive
            }

            day.actionType = inferred
        }

        try? context.save()
        defaults.set(true, forKey: actionTypeBackfillKey)
    }

    private static func backfillActivationDateIfNeeded(context: ModelContext, defaults: UserDefaults) {
        guard !defaults.bool(forKey: activationDateBackfillKey) else { return }

        // Only backfill if no activation date has been set yet
        let appActivatedDateKey = "pillie_app_activated_date"
        guard defaults.object(forKey: appActivatedDateKey) == nil else {
            defaults.set(true, forKey: activationDateBackfillKey)
            return
        }

        // For existing users, set activation date to the earliest PillDay record date
        let dayDescriptor = FetchDescriptor<PillDay>(sortBy: [SortDescriptor(\.date, order: .forward)])
        let days = (try? context.fetch(dayDescriptor)) ?? []

        if let earliestDay = days.first {
            defaults.set(earliestDay.date, forKey: appActivatedDateKey)
        }

        defaults.set(true, forKey: activationDateBackfillKey)
    }
}
