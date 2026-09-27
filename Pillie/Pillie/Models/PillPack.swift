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

    @Relationship(deleteRule: .cascade, inverse: \PillDay.pack)
    var days: [PillDay] = []

    enum PackType: String, Codable, CaseIterable {
        case twentyOneSeven = "21/7"
        case twentyFourFour = "24/4"
        case twentyEightZero = "28/0"

        var activeDays: Int {
            switch self {
            case .twentyOneSeven: return 21
            case .twentyFourFour: return 24
            case .twentyEightZero: return 28
            }
        }

        var totalDays: Int { 28 }

        var breakDays: Int { totalDays - activeDays }

        var label: String { rawValue + " CYCLE" }
    }

    enum PillRegimenPreset: String, Codable, CaseIterable {
        case twentyOneSeven = "21/7"
        case twentyFourFour = "24/4"
        case twentySixTwo = "26/2"
        case twentyEightZero = "28/0"
        case eightyFourSeven = "84/7"
        case threeSixtyFiveZero = "365/0"
        case custom = "CUSTOM"

        var regimen: PackRegimen? {
            switch self {
            case .twentyOneSeven: return PackRegimen(activeDays: 21, breakDays: 7)
            case .twentyFourFour: return PackRegimen(activeDays: 24, breakDays: 4)
            case .twentySixTwo: return PackRegimen(activeDays: 26, breakDays: 2)
            case .twentyEightZero: return PackRegimen(activeDays: 28, breakDays: 0)
            case .eightyFourSeven: return PackRegimen(activeDays: 84, breakDays: 7)
            case .threeSixtyFiveZero: return PackRegimen(activeDays: 365, breakDays: 0)
            case .custom: return nil
            }
        }

        var legacyPackType: PackType {
            switch self {
            case .twentyOneSeven: return .twentyOneSeven
            case .twentyFourFour: return .twentyFourFour
            case .twentySixTwo, .twentyEightZero, .eightyFourSeven, .threeSixtyFiveZero, .custom:
                return .twentyEightZero
            }
        }
    }

    static let defaultCustomRegimen = PackRegimen(activeDays: 21, breakDays: 7)
    private static let patchOrRingRegimen = PackRegimen(activeDays: 21, breakDays: 7, breakKind: .noPills)

    /// The only reader of the persisted regimen columns. Rows are never rewritten
    /// on upgrade; decoding here is the migration.
    static func decodeRegimen(
        raw: String,
        customActiveDays: Int?,
        customBreakDays: Int?,
        customBreakHasPills: Bool?,
        legacyPackType: PackType
    ) -> (preset: PillRegimenPreset, regimen: PackRegimen) {
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
        case .twentyEightZero: return .twentyEightZero
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
        let custom = preset == .custom ? (customRegimen ?? Self.defaultCustomRegimen) : nil
        customActiveDays = custom?.activeDays
        customBreakDays = custom?.breakDays
        customBreakHasPills = custom.map { $0.breakKind == .sugarPills }
    }

    var activeDays: Int { regimen.activeDays }
    var breakDays: Int { regimen.breakDays }
    var cycleLength: Int { regimen.totalDays }
    var totalDays: Int { cycleLength }

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
        let modulo = elapsedCycleDays(on: date, calendar: calendar) % cycleLength
        return modulo >= 0 ? modulo : (modulo + cycleLength)
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
        isCurrent: Bool = true
    ) {
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
