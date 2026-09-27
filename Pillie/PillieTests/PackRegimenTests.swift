//
//  PackRegimenTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct PackRegimenTests {
    @Test func `21 plus 7 ends on seven sugar pills`() throws {
        let regimen = try #require(PillPack.PillRegimenPreset.twentyOneSeven.regimen)

        #expect(regimen.totalDays == 28)
        #expect(regimen.pillCount == 28)
        #expect(regimen.day(atIndex: 20) == PackDay(number: 21, kind: .active, pillNumber: 21))
        #expect(regimen.day(atIndex: 20).week == 3)
        #expect(regimen.day(atIndex: 21) == PackDay(number: 22, kind: .sugarPill, pillNumber: 22))
        #expect(regimen.day(atIndex: 21).week == 4)
        #expect(regimen.day(atIndex: 27) == PackDay(number: 28, kind: .sugarPill, pillNumber: 28))
    }

    @Test func `21 only leaves seven days with no pill`() throws {
        let regimen = try #require(PillPack.PillRegimenPreset.twentyOneOnly.regimen)

        #expect(regimen.totalDays == 28)
        #expect(regimen.pillCount == 21)
        #expect(regimen.day(atIndex: 20) == PackDay(number: 21, kind: .active, pillNumber: 21))
        #expect(regimen.day(atIndex: 21) == PackDay(number: 22, kind: .noPill, pillNumber: nil))
        #expect(regimen.day(atIndex: 21).week == 4)
        #expect(regimen.day(atIndex: 27) == PackDay(number: 28, kind: .noPill, pillNumber: nil))
    }

    @Test func `24 plus 4 switches to sugar pills on day 25`() throws {
        let regimen = try #require(PillPack.PillRegimenPreset.twentyFourFour.regimen)

        #expect(regimen.totalDays == 28)
        #expect(regimen.pillCount == 28)
        #expect(regimen.day(atIndex: 23) == PackDay(number: 24, kind: .active, pillNumber: 24))
        #expect(regimen.day(atIndex: 24) == PackDay(number: 25, kind: .sugarPill, pillNumber: 25))
    }

    @Test func `26 plus 2 switches to sugar pills on day 27`() throws {
        let regimen = try #require(PillPack.PillRegimenPreset.twentySixTwo.regimen)

        #expect(regimen.totalDays == 28)
        #expect(regimen.pillCount == 28)
        #expect(regimen.day(atIndex: 25) == PackDay(number: 26, kind: .active, pillNumber: 26))
        #expect(regimen.day(atIndex: 26) == PackDay(number: 27, kind: .sugarPill, pillNumber: 27))
    }

    @Test func `Every day is active and wraps to a new pack after day 28`() throws {
        let regimen = try #require(PillPack.PillRegimenPreset.everyDay.regimen)

        #expect(regimen.totalDays == 28)
        #expect(regimen.pillCount == 28)
        #expect(regimen.day(atIndex: 27) == PackDay(number: 28, kind: .active, pillNumber: 28))
        #expect(regimen.day(atIndex: 28) == PackDay(number: 1, kind: .active, pillNumber: 1))
    }

    @Test func `21 plus 4 is a 25 day pack ending on four pill-free days`() throws {
        let regimen = try #require(PillPack.PillRegimenPreset.twentyOneFour.regimen)

        #expect(regimen.totalDays == 25)
        #expect(regimen.pillCount == 21)
        #expect(regimen.weekCount == 4)
        #expect(regimen.day(atIndex: 21) == PackDay(number: 22, kind: .noPill, pillNumber: nil))
        #expect(regimen.day(atIndex: 24) == PackDay(number: 25, kind: .noPill, pillNumber: nil))
        #expect(regimen.day(atIndex: 24).week == 4)
        #expect(regimen.day(atIndex: 25) == PackDay(number: 1, kind: .active, pillNumber: 1))
    }

    @Test func `Long custom pack with sugar pills numbers every day`() {
        let regimen = PackRegimen(activeDays: 88, breakDays: 3)

        #expect(regimen.totalDays == 91)
        #expect(regimen.pillCount == 91)
        #expect(regimen.weekCount == 13)
        #expect(regimen.day(atIndex: 87) == PackDay(number: 88, kind: .active, pillNumber: 88))
        #expect(regimen.day(atIndex: 87).week == 13)
        #expect(regimen.day(atIndex: 88) == PackDay(number: 89, kind: .sugarPill, pillNumber: 89))
        #expect(regimen.day(atIndex: 90) == PackDay(number: 91, kind: .sugarPill, pillNumber: 91))
    }

    @Test func `Long custom pack with a pill-free break has no pill on break days`() {
        let regimen = PackRegimen(activeDays: 88, breakDays: 3, breakKind: .noPills)

        #expect(regimen.totalDays == 91)
        #expect(regimen.pillCount == 88)
        #expect(regimen.day(atIndex: 88) == PackDay(number: 89, kind: .noPill, pillNumber: nil))
        #expect(regimen.day(atIndex: 90) == PackDay(number: 91, kind: .noPill, pillNumber: nil))
    }

    @Test(arguments: [
        (365, 7, 365, 0),
        (360, 7, 360, 5),
        (400, 0, 365, 0),
        (0, 3, 1, 3),
        (21, 12, 21, 7),
        (21, -2, 21, 0),
    ])
    func `Lengths clamp under the 365 day cap`(
        requestedActive: Int,
        requestedBreak: Int,
        expectedActive: Int,
        expectedBreak: Int
    ) {
        let regimen = PackRegimen(activeDays: requestedActive, breakDays: requestedBreak)

        #expect(regimen.activeDays == expectedActive)
        #expect(regimen.breakDays == expectedBreak)
    }

    @Test func `A pack without a break ignores the break kind`() {
        #expect(
            PackRegimen(activeDays: 28, breakDays: 0, breakKind: .noPills)
                == PackRegimen(activeDays: 28, breakDays: 0, breakKind: .sugarPills)
        )
    }

    @Test func `Day index wraps into the next pack in both directions`() {
        let regimen = PackRegimen(activeDays: 21, breakDays: 7)

        #expect(regimen.day(atIndex: 28) == PackDay(number: 1, kind: .active, pillNumber: 1))
        #expect(regimen.day(atIndex: -1) == PackDay(number: 28, kind: .sugarPill, pillNumber: 28))
    }

    // MARK: - Persisted rows

    @Test(arguments: [
        ("84/7", nil, nil, nil, PillPack.PackType.twentyEightZero,
         PillPack.PillRegimenPreset.custom, 84, 7, PackRegimen.BreakKind.sugarPills),
        ("365/0", nil, nil, nil, .twentyEightZero, .custom, 365, 0, .sugarPills),
        ("CUSTOM", 30, 5, nil, .twentyEightZero, .custom, 30, 5, .sugarPills),
        ("CUSTOM", 30, 5, false, .twentyEightZero, .custom, 30, 5, .noPills),
        ("CUSTOM", nil, nil, nil, .twentyEightZero, .custom, 21, 7, .sugarPills),
        ("CUSTOM", 365, 7, nil, .twentyEightZero, .custom, 365, 0, .sugarPills),
        ("28/0", nil, nil, nil, .twentyEightZero, .everyDay, 28, 0, .sugarPills),
        ("21-ONLY", nil, nil, nil, .twentyOneSeven, .twentyOneOnly, 21, 7, .noPills),
        ("garbage", nil, nil, nil, .twentyFourFour, .twentyFourFour, 24, 4, .sugarPills),
    ] as [(String, Int?, Int?, Bool?, PillPack.PackType, PillPack.PillRegimenPreset, Int, Int, PackRegimen.BreakKind)])
    func `Stored regimen columns decode to a preset and pack length`(
        raw: String,
        customActiveDays: Int?,
        customBreakDays: Int?,
        customBreakHasPills: Bool?,
        packType: PillPack.PackType,
        expectedPreset: PillPack.PillRegimenPreset,
        expectedActive: Int,
        expectedBreak: Int,
        expectedKind: PackRegimen.BreakKind
    ) {
        let decoded = PillPack.decodeRegimen(
            raw: raw,
            customActiveDays: customActiveDays,
            customBreakDays: customBreakDays,
            customBreakHasPills: customBreakHasPills,
            legacyPackType: packType
        )

        #expect(decoded.preset == expectedPreset)
        #expect(decoded.regimen == PackRegimen(activeDays: expectedActive, breakDays: expectedBreak, breakKind: expectedKind))
        #expect(decoded.regimen.breakKind == expectedKind)
    }

    @Test @MainActor func `An 84 plus 7 user keeps the same pill number after upgrading`() {
        let pack = Self.packAsOldVersionsStoredIt(raw: "84/7", packType: .twentyEightZero, anchor: 60)

        #expect(pack.pillRegimen == .custom)
        #expect(pack.cycleDayIndex(on: Self.day(2026, 1, 11), calendar: Self.utc) == 70)
        #expect(pack.packDay(on: Self.day(2026, 1, 11), calendar: Self.utc)
            == PackDay(number: 71, kind: .active, pillNumber: 71))
        #expect(pack.packDay(on: Self.day(2026, 2, 10), calendar: Self.utc).pillNumber == 10)
    }

    @Test @MainActor func `A 365 day user keeps the same pill number after upgrading`() {
        let pack = Self.packAsOldVersionsStoredIt(raw: "365/0", packType: .twentyEightZero, anchor: 300)

        #expect(pack.pillRegimen == .custom)
        #expect(pack.cycleDayIndex(on: Self.day(2026, 3, 2), calendar: Self.utc) == 360)
        #expect(pack.packDay(on: Self.day(2026, 3, 2), calendar: Self.utc).pillNumber == 361)
        #expect(pack.packDay(on: Self.day(2026, 3, 12), calendar: Self.utc).pillNumber == 6)
    }

    @Test @MainActor func `A custom 24 plus 4 user keeps the same pill number after upgrading`() {
        let pack = Self.packAsOldVersionsStoredIt(
            raw: "CUSTOM",
            packType: .twentyEightZero,
            anchor: 20,
            customActiveDays: 24,
            customBreakDays: 4
        )

        #expect(pack.packDay(on: Self.day(2026, 1, 6), calendar: Self.utc)
            == PackDay(number: 26, kind: .sugarPill, pillNumber: 26))
        #expect(pack.packDay(on: Self.day(2026, 1, 11), calendar: Self.utc).pillNumber == 3)
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
    }

    @MainActor
    private static func packAsOldVersionsStoredIt(
        raw: String,
        packType: PillPack.PackType,
        anchor: Int,
        customActiveDays: Int? = nil,
        customBreakDays: Int? = nil
    ) -> PillPack {
        let pack = PillPack(method: .pill, startDate: day(2026, 1, 1), packNumber: 1)
        pack.pillRegimenRaw = raw
        pack.packType = packType
        pack.customActiveDays = customActiveDays
        pack.customBreakDays = customBreakDays
        pack.customBreakHasPills = nil
        pack.cycleDayAnchorIndex = anchor
        return pack
    }
}
