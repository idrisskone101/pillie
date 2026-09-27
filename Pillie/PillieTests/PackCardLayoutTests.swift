//
//  PackCardLayoutTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct PackCardLayoutTests {
    private let twentyOneSeven = PackRegimen(activeDays: 21, breakDays: 7)
    private let twentyOneFour = PackRegimen(activeDays: 21, breakDays: 4, breakKind: .noPills)
    private let eightyEightThree = PackRegimen(activeDays: 88, breakDays: 3)

    // MARK: State derivation

    @Test func `Days before today are popped, today is ringed, later days stay sealed`() {
        let layout = PackCardLayout(regimen: twentyOneSeven, todayIndex: 11)

        #expect(layout.state(at: 0) == .popped)
        #expect(layout.state(at: 10) == .popped)
        #expect(layout.state(at: 11) == .today)
        #expect(layout.state(at: 12) == .sealed)
        #expect(layout.state(at: 27) == .sealed)
    }

    @Test func `Marks win over position`() {
        let layout = PackCardLayout(
            regimen: twentyOneSeven,
            todayIndex: 11,
            marks: [11: .taken, 10: .missed, 9: .late, 14: .taken]
        )

        #expect(layout.state(at: 11) == .logged)
        #expect(layout.state(at: 10) == .missed)
        #expect(layout.state(at: 9) == .late)
        #expect(layout.state(at: 14) == .popped)
        #expect(layout.state(at: 8) == .popped)
    }

    @Test func `A pill-free day ignores marks`() {
        let layout = PackCardLayout(regimen: twentyOneFour, todayIndex: 22, marks: [22: .taken, 21: .missed])

        #expect(layout.state(at: 22) == .today)
        #expect(layout.state(at: 21) == .popped)
    }

    @Test func `No today keeps the whole pack sealed`() {
        let layout = PackCardLayout(regimen: twentyOneSeven, todayIndex: nil)

        #expect(layout.states == Array(repeating: .sealed, count: 28))
        #expect(layout.todayPage == 0)
    }

    @Test func `A finished pack is popped end to end`() {
        let layout = PackCardLayout(regimen: twentyOneSeven, todayIndex: 28)

        #expect(layout.states == Array(repeating: .popped, count: 28))
    }

    // MARK: Paging

    @Test func `A 28 day pack is one page without a pager`() {
        let layout = PackCardLayout(regimen: twentyOneSeven, todayIndex: 11)

        #expect(layout.pageCount == 1)
        #expect(layout.showsPager == false)
        #expect(layout.dayIndices(onPage: 0) == 0..<28)
        #expect(layout.rows(onPage: 0) == [0..<7, 7..<14, 14..<21, 21..<28])
    }

    @Test func `21 plus 4 ends on a four tile row`() {
        let layout = PackCardLayout(regimen: twentyOneFour, todayIndex: 22)

        #expect(layout.pageCount == 1)
        #expect(layout.showsPager == false)
        #expect(layout.dayIndices(onPage: 0) == 0..<25)
        #expect(layout.rows(onPage: 0) == [0..<7, 7..<14, 14..<21, 21..<25])
        #expect(layout.rows(onPage: 0).last?.count == 4)
    }

    @Test func `88 plus 3 pages four weeks at a time`() {
        let layout = PackCardLayout(regimen: eightyEightThree, todayIndex: 39)

        #expect(layout.pageCount == 4)
        #expect(layout.showsPager)
        #expect(layout.dayIndices(onPage: 0) == 0..<28)
        #expect(layout.dayIndices(onPage: 1) == 28..<56)
        #expect(layout.dayIndices(onPage: 2) == 56..<84)
        #expect(layout.dayIndices(onPage: 3) == 84..<91)
        #expect(layout.rows(onPage: 3) == [84..<91])
        #expect(layout.todayPage == 1)
    }

    @Test func `A 365 day pack has 14 pages and today clamps to the last`() {
        let layout = PackCardLayout(regimen: PackRegimen(activeDays: 365, breakDays: 0), todayIndex: 500)

        #expect(layout.pageCount == 14)
        #expect(layout.dayIndices(onPage: 13) == 364..<365)
        #expect(layout.rows(onPage: 13) == [364..<365])
        #expect(layout.todayPage == 13)
    }

    @Test func `Page labels name a week range or a single week`() {
        let layout = PackCardLayout(regimen: eightyEightThree, todayIndex: 39)

        #expect(layout.pageLabel(forPage: 0) == .weeks(first: 1, last: 4, total: 13))
        #expect(layout.pageLabel(forPage: 1) == .weeks(first: 5, last: 8, total: 13))
        #expect(layout.pageLabel(forPage: 3) == .week(13, total: 13))
    }

    @Test func `Track tones follow the viewed page and flag upcoming break weeks`() {
        let layout = PackCardLayout(regimen: eightyEightThree, todayIndex: 39)

        #expect(layout.trackTones(viewedPage: 1) == [
            .passed, .passed, .passed, .passed,
            .viewed, .viewed, .viewed, .viewed,
            .upcoming, .upcoming, .upcoming, .upcoming,
            .upcomingBreak,
        ])
    }

    // MARK: Pop cascade

    @Test func `Popping cascades upward and crunches active pills before they settle`() {
        let from: [PackTileState] = [.sealed, .sealed, .sealed, .sealed]
        let to: [PackTileState] = [.popped, .popped, .today, .sealed]
        let regimen = PackRegimen(activeDays: 1, breakDays: 3)

        let steps = PackPopSequence.steps(from: from, to: to, regimen: regimen)

        #expect(steps == [
            .init(at: .zero, index: 2, change: .settle(.today)),
            .init(at: .zero, index: 0, change: .crunch),
            .init(at: .milliseconds(45), index: 1, change: .settle(.popped)),
            .init(at: .milliseconds(90), index: 0, change: .settle(.popped)),
        ])
    }

    @Test func `Resealing cascades downward from the highest tile`() {
        let from: [PackTileState] = [.popped, .popped, .popped, .today]
        let to: [PackTileState] = [.popped, .today, .sealed, .sealed]

        let steps = PackPopSequence.steps(from: from, to: to, regimen: twentyOneSeven)

        #expect(steps == [
            .init(at: .zero, index: 3, change: .settle(.sealed)),
            .init(at: .zero, index: 2, change: .settle(.sealed)),
            .init(at: .milliseconds(45), index: 1, change: .settle(.today)),
        ])
    }
}
