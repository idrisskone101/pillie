//
//  PackChoiceTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct PackChoiceTests {
    @Test func `a regimen that matches a preset comes back as that preset`() {
        #expect(PackChoice(PackRegimen(activeDays: 24, breakDays: 4)).preset == .twentyFourFour)
        #expect(PackChoice(PackRegimen(activeDays: 21, breakDays: 7, breakKind: .noPills)).preset == .twentyOneOnly)
        #expect(PackChoice(PackRegimen(activeDays: 28, breakDays: 0)).preset == .everyDay)
    }

    @Test func `a regimen that matches no preset is custom`() {
        let choice = PackChoice(PackRegimen(activeDays: 88, breakDays: 3))
        #expect(choice.preset == .custom)
        #expect(choice.regimen == PackRegimen(activeDays: 88, breakDays: 3))
        #expect(choice.displayName(locale: Locale(identifier: "en")) == "88 + 3")
    }

    @Test func `a preset choice carries the preset's regimen`() {
        let choice = PackChoice(preset: .twentySixTwo)
        #expect(choice.preset == .twentySixTwo)
        #expect(choice.regimen == PackRegimen(activeDays: 26, breakDays: 2))
        #expect(PackChoice(preset: .custom) == PackChoice(preset: .twentyOneSeven))
    }

    @Test func `a decoded regimen is clamped like a constructed one`() throws {
        let json = #"{"activeDays":400,"breakDays":5,"breakKind":"noPills"}"#
        let regimen = try JSONDecoder().decode(PackRegimen.self, from: Data(json.utf8))
        #expect(regimen == PackRegimen(activeDays: 365, breakDays: 0))
        #expect(regimen.breakKind == .sugarPills)
    }

    @Test func `a regimen round-trips through JSON`() throws {
        let regimen = PackRegimen(activeDays: 88, breakDays: 3, breakKind: .noPills)
        let data = try JSONEncoder().encode(regimen)
        #expect(try JSONDecoder().decode(PackRegimen.self, from: data) == regimen)
    }
}
