//
//  PackRegimen.swift
//  Pillie
//

import Foundation

struct PackRegimen: Hashable, Sendable {
    enum BreakKind: Hashable, Sendable {
        case sugarPills
        case noPills
    }

    static let maxTotalDays = 365
    // Every real combined-pill regimen keeps its hormone-free interval at 7 days or
    // fewer. A longer break is not another schedule, it only lowers efficacy.
    static let maxBreakDays = 7
    static let activeDayRange = 1...maxTotalDays

    let activeDays: Int
    let breakDays: Int
    let breakKind: BreakKind

    // Active days are clamped first so an over-long pack keeps its active pill
    // numbers and loses only the break that no longer fits under the cap.
    init(activeDays: Int, breakDays: Int, breakKind: BreakKind = .sugarPills) {
        let active = min(max(activeDays, Self.activeDayRange.lowerBound), Self.activeDayRange.upperBound)
        let breakCap = min(Self.maxBreakDays, Self.maxTotalDays - active)
        let breakLength = min(max(breakDays, 0), breakCap)
        self.activeDays = active
        self.breakDays = breakLength
        self.breakKind = breakLength == 0 ? .sugarPills : breakKind
    }

    var totalDays: Int { activeDays + breakDays }

    var pillCount: Int {
        breakKind == .sugarPills ? totalDays : activeDays
    }

    var weekCount: Int { (totalDays + 6) / 7 }

    func day(atIndex index: Int) -> PackDay {
        let wrapped = ((index % totalDays) + totalDays) % totalDays
        let number = wrapped + 1
        guard number > activeDays else {
            return PackDay(number: number, kind: .active, pillNumber: number)
        }
        switch breakKind {
        case .sugarPills:
            return PackDay(number: number, kind: .sugarPill, pillNumber: number)
        case .noPills:
            return PackDay(number: number, kind: .noPill, pillNumber: nil)
        }
    }
}

struct PackDay: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case active
        case sugarPill
        case noPill
    }

    let number: Int
    let kind: Kind
    let pillNumber: Int?

    var week: Int { (number - 1) / 7 + 1 }
}
