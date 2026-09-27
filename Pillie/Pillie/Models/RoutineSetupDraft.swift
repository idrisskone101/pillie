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
    let customRegimen: PackRegimen?
    let cycleDay: Int
}

struct RoutineSetupDraft: Equatable {
    let method: ContraceptiveMethod
    private(set) var selectedRegimen: PillPack.PillRegimenPreset
    private(set) var customRegimen: PackRegimen
    private(set) var cycleDay: Int

    init(method: ContraceptiveMethod) {
        self.method = method
        self.selectedRegimen = .twentyOneSeven
        self.customRegimen = PillPack.defaultCustomRegimen
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
            self.customRegimen = activePack.pillRegimen == .custom
                ? activePack.regimen
                : PillPack.defaultCustomRegimen
        } else {
            self.selectedRegimen = .twentyOneSeven
            self.customRegimen = PillPack.defaultCustomRegimen
        }
        self.cycleDay = activePack.method == method
            ? activePack.cycleDayIndex(on: today, calendar: calendar) + 1
            : 1
        clampCycleDay()
    }

    var cycleLength: Int {
        switch method {
        case .pill:
            return (selectedRegimen.regimen ?? customRegimen).totalDays
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
            case .active: customRegimen.activeDays
            case .breakDays: customRegimen.breakDays
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
        customRegimen = PackRegimen(
            activeDays: days,
            breakDays: customRegimen.breakDays,
            breakKind: customRegimen.breakKind
        )
        clampCycleDay()
    }

    mutating func setCustomBreakDays(_ days: Int) {
        customRegimen = PackRegimen(
            activeDays: customRegimen.activeDays,
            breakDays: days,
            breakKind: customRegimen.breakKind
        )
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
            customRegimen: selectedRegimen == .custom ? customRegimen : nil,
            cycleDay: cycleDay
        )
    }

    private mutating func clampCycleDay() {
        cycleDay = min(max(1, cycleDay), max(1, cycleLength))
    }
}
