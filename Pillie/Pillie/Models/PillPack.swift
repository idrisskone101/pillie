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

        var title: String {
            switch self {
            case .custom:
                return "Custom"
            default:
                return rawValue
            }
        }

        var activeDays: Int {
            switch self {
            case .twentyOneSeven: return 21
            case .twentyFourFour: return 24
            case .twentySixTwo: return 26
            case .twentyEightZero: return 28
            case .eightyFourSeven: return 84
            case .threeSixtyFiveZero: return 365
            case .custom: return 21
            }
        }

        var breakDays: Int {
            switch self {
            case .twentyOneSeven: return 7
            case .twentyFourFour: return 4
            case .twentySixTwo: return 2
            case .twentyEightZero: return 0
            case .eightyFourSeven: return 7
            case .threeSixtyFiveZero: return 0
            case .custom: return 7
            }
        }

        var cycleLength: Int { activeDays + breakDays }
    }

    static let customActiveRange = 1...365
    static let customBreakRange = 0...28

    var method: ContraceptiveMethod {
        get { ContraceptiveMethod(rawValue: methodRaw) ?? .pill }
        set { methodRaw = newValue.rawValue }
    }

    var pillRegimen: PillRegimenPreset {
        get {
            if let regimen = PillRegimenPreset(rawValue: pillRegimenRaw) {
                return regimen
            }
            switch packType {
            case .twentyOneSeven: return .twentyOneSeven
            case .twentyFourFour: return .twentyFourFour
            case .twentyEightZero: return .twentyEightZero
            }
        }
        set {
            pillRegimenRaw = newValue.rawValue
            if newValue != .custom {
                customActiveDays = nil
                customBreakDays = nil
            }
            // Keep legacy value roughly aligned for compatibility.
            switch newValue {
            case .twentyOneSeven:
                packType = .twentyOneSeven
            case .twentyFourFour:
                packType = .twentyFourFour
            case .twentyEightZero, .twentySixTwo, .eightyFourSeven, .threeSixtyFiveZero, .custom:
                packType = .twentyEightZero
            }
        }
    }

    var activeDays: Int {
        switch method {
        case .pill:
            if pillRegimen == .custom {
                let normalized = Self.normalizedCustomValues(active: customActiveDays, breakDays: customBreakDays)
                return normalized.active
            }
            return pillRegimen.activeDays
        case .patch:
            return 21
        case .ring:
            return 21
        }
    }

    var breakDays: Int {
        switch method {
        case .pill:
            if pillRegimen == .custom {
                let normalized = Self.normalizedCustomValues(active: customActiveDays, breakDays: customBreakDays)
                return normalized.breakDays
            }
            return pillRegimen.breakDays
        case .patch:
            return 7
        case .ring:
            return 7
        }
    }

    var cycleLength: Int { max(1, activeDays + breakDays) }
    var totalDays: Int { cycleLength }

    var regimenLabel: String {
        switch method {
        case .pill:
            if pillRegimen == .custom {
                return "\(activeDays)/\(breakDays) CYCLE"
            }
            return "\(pillRegimen.title) CYCLE"
        case .patch:
            return "PATCH 3/1 CYCLE"
        case .ring:
            return "RING 21/7 CYCLE"
        }
    }

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

    func cycleDayIndex(on date: Date, calendar: Calendar = .current) -> Int {
        let anchorDate: Date
        let anchorOffset: Int
        if method == .ring, let ringDate = ringInsertionDate {
            anchorDate = ringDate
            anchorOffset = 0
        } else {
            anchorDate = startDate
            anchorOffset = Self.normalizedCycleDayAnchorIndex(cycleDayAnchorIndex, cycleLength: cycleLength)
        }
        let start = calendar.startOfDay(for: Self.validatedDate(anchorDate, fallback: Date()))
        let target = calendar.startOfDay(for: Self.validatedDate(date, fallback: start))
        let diff = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        let modulo = (diff + anchorOffset) % cycleLength
        return modulo >= 0 ? modulo : (modulo + cycleLength)
    }

    func weekNumber(for dayIndex: Int) -> Int {
        (dayIndex / 7) + 1
    }

    init(
        packType: PackType = .twentyOneSeven,
        method: ContraceptiveMethod = .pill,
        pillRegimen: PillRegimenPreset = .twentyOneSeven,
        customActiveDays: Int? = nil,
        customBreakDays: Int? = nil,
        startDate: Date,
        cycleDayAnchorIndex: Int = 0,
        packNumber: Int,
        isCurrent: Bool = true
    ) {
        let normalized = Self.normalizedCustomValues(active: customActiveDays, breakDays: customBreakDays)
        self.packType = packType
        self.methodRaw = method.rawValue
        self.pillRegimenRaw = pillRegimen.rawValue
        self.customActiveDays = pillRegimen == .custom ? normalized.active : nil
        self.customBreakDays = pillRegimen == .custom ? normalized.breakDays : nil
        self.startDate = startDate
        self.cycleDayAnchorIndex = cycleDayAnchorIndex
        self.packNumber = packNumber
        self.isCurrent = isCurrent

        self.cycleDayAnchorIndex = Self.normalizedCycleDayAnchorIndex(
            self.cycleDayAnchorIndex,
            cycleLength: self.cycleLength
        )
    }

    static func normalizedCustomValues(active: Int?, breakDays: Int?) -> (active: Int, breakDays: Int) {
        let a = min(max(active ?? 21, customActiveRange.lowerBound), customActiveRange.upperBound)
        let b = min(max(breakDays ?? 7, customBreakRange.lowerBound), customBreakRange.upperBound)
        return (a, b)
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
