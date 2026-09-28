//
//  PackRegimenChangeTests.swift
//  PillieTests
//

import Testing

@testable import Pillie

struct PackRegimenChangeTests {
    private let twentyOneSeven = PackRegimen(activeDays: 21, breakDays: 7)
    private let twentyFourFour = PackRegimen(activeDays: 24, breakDays: 4)
    private let twentyOneFour = PackRegimen(activeDays: 21, breakDays: 4, breakKind: .noPills)
    private let thirtyFive = PackRegimen(activeDays: 30, breakDays: 5)

    @Test func `Picking the pack you already have changes nothing`() {
        let change = PackRegimenChange.resolve(from: twentyOneSeven, to: twentyOneSeven, elapsedDays: 11, anchorIndex: 0)

        #expect(change == .unchanged)
    }

    @Test func `Today keeps its pill number when it fits the new pack`() {
        #expect(PackRegimenChange.resolve(from: twentyOneSeven, to: twentyFourFour, elapsedDays: 11, anchorIndex: 0) == .keepAnchor)
        #expect(PackRegimenChange.resolve(from: twentyOneSeven, to: twentyOneFour, elapsedDays: 24, anchorIndex: 3) == .keepAnchor)
        #expect(PackRegimenChange.resolve(from: twentyOneFour, to: thirtyFive, elapsedDays: 24, anchorIndex: 0) == .keepAnchor)
    }

    @Test func `A pill number past the shorter pack lands on its last day`() {
        #expect(PackRegimenChange.resolve(from: twentyOneSeven, to: twentyOneFour, elapsedDays: 26, anchorIndex: 0) == .moveToday(toIndex: 24))
        #expect(PackRegimenChange.resolve(from: twentyOneSeven, to: twentyOneFour, elapsedDays: 25, anchorIndex: 10) == .moveToday(toIndex: 24))
    }

    @Test func `An anchor past the new pack length re-anchors on the same pill number`() {
        let change = PackRegimenChange.resolve(from: thirtyFive, to: twentyOneFour, elapsedDays: 20, anchorIndex: 27)

        #expect(change == .moveToday(toIndex: 20))
    }

    @Test func `A finished pack stays finished`() {
        #expect(PackRegimenChange.resolve(from: twentyOneSeven, to: twentyOneFour, elapsedDays: 30, anchorIndex: 0) == .keepAnchor)
        #expect(PackRegimenChange.resolve(from: twentyOneSeven, to: twentyOneFour, elapsedDays: 30, anchorIndex: 26) == .moveToday(toIndex: 30))
    }

    @Test func `A pack that has not started yet keeps its countdown`() {
        #expect(PackRegimenChange.resolve(from: twentyOneSeven, to: twentyFourFour, elapsedDays: -1, anchorIndex: 0) == .keepAnchor)
    }
}
