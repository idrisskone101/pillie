//
//  RoutineSetupDraft.swift
//  Pillie
//
//  Value-type routine setup state shared by the onboarding view and its behavior
//  tests. It keeps progressive-disclosure presentation separate from the exact
//  values committed to PillStore.
//

import Foundation

enum RoutineCustomDayField {
    case active
    case breakDays
}

struct RoutineSetupCommit: Equatable {
    let regimen: PillPack.PillRegimenPreset
    let customActiveDays: Int?
    let customBreakDays: Int?
    let cycleDay: Int
}

struct RoutineSetupDraft: Equatable {
    let method: ContraceptiveMethod
    private(set) var selectedRegimen: PillPack.PillRegimenPreset
    private(set) var customActiveDays: Int
    private(set) var customBreakDays: Int
    private(set) var cycleDay: Int

    init(method: ContraceptiveMethod) {
        self.method = method
        self.selectedRegimen = .twentyOneSeven
        self.customActiveDays = 21
        self.customBreakDays = 7
        self.cycleDay = 1
    }

    init(
        method: ContraceptiveMethod,
        activePack: PillPack,
        today: Date,
        calendar: Calendar = .current
    ) {
        self.method = method
        if method == .pill, activePack.method == .pill {
            self.selectedRegimen = activePack.pillRegimen
            self.customActiveDays = activePack.customActiveDays ?? 21
            self.customBreakDays = activePack.customBreakDays ?? 7
        } else {
            self.selectedRegimen = .twentyOneSeven
            self.customActiveDays = 21
            self.customBreakDays = 7
        }
        self.cycleDay = activePack.method == method
            ? activePack.cycleDayIndex(on: today, calendar: calendar) + 1
            : 1
        clampCycleDay()
    }

    var cycleLength: Int {
        switch method {
        case .pill:
            return selectedRegimen == .custom
                ? customActiveDays + customBreakDays
                : selectedRegimen.cycleLength
        case .patch, .ring:
            return 28
        }
    }

    var section: RoutineDetailsSection {
        RoutineDetailsSection(method: method)
    }

    var visibleCommonRegimens: [PillPack.PillRegimenPreset] {
        method == .pill ? RoutineRegimenCatalog.common : []
    }

    var requiresMoreOptions: Bool {
        RoutineRegimenCatalog.more.contains(selectedRegimen)
    }

    subscript(customDays field: RoutineCustomDayField) -> Int {
        get {
            switch field {
            case .active: customActiveDays
            case .breakDays: customBreakDays
            }
        }
        set {
            switch field {
            case .active: setCustomActiveDays(newValue)
            case .breakDays: setCustomBreakDays(newValue)
            }
        }
    }

    mutating func selectRegimen(_ regimen: PillPack.PillRegimenPreset) {
        selectedRegimen = regimen
        clampCycleDay()
    }

    mutating func setCustomActiveDays(_ days: Int) {
        customActiveDays = min(max(days, PillPack.customActiveRange.lowerBound), PillPack.customActiveRange.upperBound)
        clampCycleDay()
    }

    mutating func setCustomBreakDays(_ days: Int) {
        customBreakDays = min(max(days, PillPack.customBreakRange.lowerBound), PillPack.customBreakRange.upperBound)
        clampCycleDay()
    }

    mutating func selectPosition(_ position: CyclePosition) {
        cycleDay = position.cycleDay(in: cycleLength)
    }

    mutating func setExactCycleDay(_ day: Int) {
        cycleDay = min(max(1, day), max(1, cycleLength))
    }

    var commit: RoutineSetupCommit {
        RoutineSetupCommit(
            regimen: selectedRegimen,
            customActiveDays: selectedRegimen == .custom ? customActiveDays : nil,
            customBreakDays: selectedRegimen == .custom ? customBreakDays : nil,
            cycleDay: cycleDay
        )
    }

    private mutating func clampCycleDay() {
        cycleDay = min(max(1, cycleDay), max(1, cycleLength))
    }
}
