//
//  PackRegimenTests.swift
//  PillieTests
//

import Testing

@testable import Pillie

struct PackRegimenTests {
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
}
