//
//  PillPack.swift
//  Pillie
//

import Foundation
import SwiftData

@Model
final class PillPack {
    private static let minimumSupportedEpoch: TimeInterval = -2_208_988_800 // 1900-01-01
    private static let maximumSupportedEpoch: TimeInterval = 7_258_118_400 // 2200-01-01

    var id: UUID = UUID()
    // Legacy persisted field from earlier app versions. Kept for compatibility/migration.
    var packType: PackType
    var methodRaw: String = ContraceptiveMethod.pill.rawValue
    var pillRegimenRaw: String = PillRegimenPreset.twentyOneSeven.rawValue
    var customActiveDays: Int?
    var customBreakDays: Int?
    var customBreakHasPills: Bool?
    var startDate: Date
    var cycleDayAnchorIndex: Int = 0
    var packNumber: Int
    var isCurrent: Bool = true
    /// Pinned ring insertion date. Set on first ring check-in so that
    /// subsequent cycle-day edits in Settings don't shift the removal date.
    /// While nil the schedule engine falls back to `startDate`.
    var ringInsertionDate: Date?
    /// When the user started this pack. nil on packs from older builds.
    var startedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PillDay.pack)
    var days: [PillDay] = []

    enum PackType: String, Codable, CaseIterable {
        case twentyOneSeven = "21/7"
        case twentyFourFour = "24/4"
        case twentyEightZero = "28/0"
    }

    enum PillRegimenPreset: String, Codable, CaseIterable {
        case twentyOneSeven = "21/7"
        case twentyOneOnly = "21-ONLY"
        case twentyFourFour = "24/4"
        case twentySixTwo = "26/2"
        case everyDay = "28/0"
        case twentyOneFour = "21/4"
        case custom = "CUSTOM"

        var regimen: PackRegimen? {
            switch self {
            case .twentyOneSeven: return PackRegimen(activeDays: 21, breakDays: 7)
            case .twentyOneOnly: return PackRegimen(activeDays: 21, breakDays: 7, breakKind: .noPills)
            case .twentyFourFour: return PackRegimen(activeDays: 24, breakDays: 4)
            case .twentySixTwo: return PackRegimen(activeDays: 26, breakDays: 2)
            case .everyDay: return PackRegimen(activeDays: 28, breakDays: 0)
            case .twentyOneFour: return PackRegimen(activeDays: 21, breakDays: 4, breakKind: .noPills)
            case .custom: return nil
            }
        }

        func resolvedRegimen(custom: PackRegimen?) -> PackRegimen {
            regimen ?? custom ?? PillPack.defaultCustomRegimen
        }

        var legacyPackType: PackType {
            switch self {
            case .twentyOneSeven, .twentyOneOnly: return .twentyOneSeven
            case .twentyFourFour: return .twentyFourFour
            case .twentySixTwo, .everyDay, .twentyOneFour, .custom: return .twentyEightZero
            }
        }
    }

    static let defaultCustomRegimen = PackRegimen(activeDays: 21, breakDays: 7)
    private static let patchOrRingRegimen = PackRegimen(
        activeDays: RoutineDialDay.wearingDays,
        breakDays: RoutineDialDay.cycleLength - RoutineDialDay.wearingDays,
        breakKind: .noPills
    )

    // Presets retired from the picker. Their rows keep the raw value and read back
    // as the same-length Custom pack, so the pill number does not move.
    private static let retiredPresetRegimens: [String: PackRegimen] = [
        "84/7": PackRegimen(activeDays: 84, breakDays: 7),
        "365/0": PackRegimen(activeDays: 365, breakDays: 0),
    ]

    /// The only reader of the persisted regimen columns. Rows are never rewritten
    /// on upgrade; decoding here is the migration.
    static func decodeRegimen(
        raw: String,
        customActiveDays: Int?,
        customBreakDays: Int?,
        customBreakHasPills: Bool?,
        legacyPackType: PackType
    ) -> (preset: PillRegimenPreset, regimen: PackRegimen) {
        if let retired = retiredPresetRegimens[raw] {
            return (.custom, retired)
        }
        let preset = PillRegimenPreset(rawValue: raw) ?? fallbackPreset(for: legacyPackType)
        if let regimen = preset.regimen {
            return (preset, regimen)
        }
        let custom = PackRegimen(
            activeDays: customActiveDays ?? defaultCustomRegimen.activeDays,
            breakDays: customBreakDays ?? defaultCustomRegimen.breakDays,
            breakKind: customBreakHasPills == false ? .noPills : .sugarPills
        )
        return (.custom, custom)
    }

    private static func fallbackPreset(for packType: PackType) -> PillRegimenPreset {
        switch packType {
        case .twentyOneSeven: return .twentyOneSeven
        case .twentyFourFour: return .twentyFourFour
        case .twentyEightZero: return .everyDay
        }
    }

    var method: ContraceptiveMethod {
        get { ContraceptiveMethod(rawValue: methodRaw) ?? .pill }
        set { methodRaw = newValue.rawValue }
    }

    private var decodedRegimen: (preset: PillRegimenPreset, regimen: PackRegimen) {
        Self.decodeRegimen(
            raw: pillRegimenRaw,
            customActiveDays: customActiveDays,
            customBreakDays: customBreakDays,
            customBreakHasPills: customBreakHasPills,
            legacyPackType: packType
        )
    }

    var pillRegimen: PillRegimenPreset { decodedRegimen.preset }

    var regimen: PackRegimen {
        switch method {
        case .pill: return decodedRegimen.regimen
        case .patch, .ring: return Self.patchOrRingRegimen
        }
    }

    func setPillRegimen(_ preset: PillRegimenPreset, customRegimen: PackRegimen?) {
        pillRegimenRaw = preset.rawValue
        packType = preset.legacyPackType
        let custom = preset == .custom ? preset.resolvedRegimen(custom: customRegimen) : nil
        customActiveDays = custom?.activeDays
        customBreakDays = custom?.breakDays
        customBreakHasPills = custom.map { $0.breakKind == .sugarPills }
    }

    var activeDays: Int { regimen.activeDays }
    var breakDays: Int { regimen.breakDays }
    var cycleLength: Int { regimen.totalDays }

    var methodTitle: String {
        switch method {
        case .pill:
            return "Pill"
        case .patch:
            return "Patch"
        case .ring:
            return "Ring"
        }
    }

    func isBreakDay(dayIndex: Int) -> Bool {
        dayIndex >= activeDays
    }

    /// Non-wrapping count of days elapsed within this pack's cycle, using the same
    /// anchor resolution as `cycleDayIndex`: 0 on the first cycle day, negative before
    /// it, and `cycleLength` (or more) once the single cycle this pack models is over.
    /// A pack starting mid-cycle (`cycleDayAnchorIndex > 0`) therefore completes after
    /// `cycleLength - anchor` calendar days, not `cycleLength`.
    func elapsedCycleDays(on date: Date, calendar: Calendar = .current) -> Int {
        let anchor = resolvedCycleAnchor()
        let start = calendar.startOfDay(for: Self.validatedDate(anchor.date, fallback: Date()))
        let target = calendar.startOfDay(for: Self.validatedDate(date, fallback: start))
        let diff = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        return diff + anchor.dayIndex
    }

    /// The single anchor used by cycle math and by the DeviceActivity schedule
    /// mirror. Keeping the raw anchor date plus its cycle offset lets both sides
    /// recompute the whole day index in the same current calendar after a time-
    /// zone change.
    func resolvedCycleAnchor() -> (date: Date, dayIndex: Int) {
        if method == .ring, let ringDate = ringInsertionDate {
            return (ringDate, 0)
        }
        return (
            startDate,
            Self.normalizedCycleDayAnchorIndex(cycleDayAnchorIndex, cycleLength: cycleLength)
        )
    }

    func cycleDayIndex(on date: Date, calendar: Calendar = .current) -> Int {
        let length = cycleLength
        let modulo = elapsedCycleDays(on: date, calendar: calendar) % length
        return modulo >= 0 ? modulo : (modulo + length)
    }

    func packDay(on date: Date, calendar: Calendar = .current) -> PackDay {
        regimen.day(atIndex: cycleDayIndex(on: date, calendar: calendar))
    }

    init(
        method: ContraceptiveMethod = .pill,
        pillRegimen: PillRegimenPreset = .twentyOneSeven,
        customRegimen: PackRegimen? = nil,
        startDate: Date,
        cycleDayAnchorIndex: Int = 0,
        packNumber: Int,
        isCurrent: Bool = true,
        startedAt: Date? = nil
    ) {
        self.startedAt = startedAt
        self.packType = pillRegimen.legacyPackType
        self.methodRaw = method.rawValue
        self.startDate = startDate
        self.packNumber = packNumber
        self.isCurrent = isCurrent
        setPillRegimen(pillRegimen, customRegimen: customRegimen)
        self.cycleDayAnchorIndex = Self.normalizedCycleDayAnchorIndex(
            cycleDayAnchorIndex,
            cycleLength: self.cycleLength
        )
    }

    static func normalizedCycleDayAnchorIndex(_ value: Int, cycleLength: Int) -> Int {
        let safeCycleLength = max(1, cycleLength)
        let modulo = value % safeCycleLength
        return modulo >= 0 ? modulo : modulo + safeCycleLength
    }

    private static func validatedDate(_ date: Date, fallback: Date) -> Date {
        let epoch = date.timeIntervalSince1970
        guard epoch.isFinite, epoch >= minimumSupportedEpoch, epoch <= maximumSupportedEpoch else {
            return fallback
        }
        return date
    }
}
