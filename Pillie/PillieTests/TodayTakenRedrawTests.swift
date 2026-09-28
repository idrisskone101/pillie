//
//  TodayTakenRedrawTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct TodayTakenRedrawTests {
    private static var retained: [Any] = []

    private func store(on dayOfMonth: Int) throws -> PillStore {
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.localDate("2026-05-\(dayOfMonth)", hour: 12),
            regimen: .twentyOneSeven,
            startDate: InMemoryStoreFactory.localDate("2026-05-01", hour: 0)
        )
        Self.retained.append(fixture)
        return fixture.store
    }

    @Test func notificationCompleteOnAHormonePillRedrawsHomeOnce() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(on: 12)
        let before = store.protocolChangeVersion

        store.markActionAsTaken(on: store.today)
        #expect(store.isTodayTaken == true)
        #expect(store.protocolChangeVersion == before &+ 1)

        store.markActionAsTaken(on: store.today)
        #expect(store.protocolChangeVersion == before &+ 1)

        store.unmarkActionAsTaken(on: store.today)
        #expect(store.isTodayTaken == false)
        #expect(store.protocolChangeVersion == before &+ 2)
    }

    @Test func notificationCompleteOnASugarPillRedrawsHome() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(on: 23)
        let before = store.protocolChangeVersion

        store.markActionAsTaken(on: store.today)
        #expect(store.todayDueAction?.type == .pillSugar)
        #expect(store.isTodayTaken == true)
        #expect(store.protocolChangeVersion == before &+ 1)
    }

    @Test func homeLogAndUndoBumpOncePerFlip() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(on: 12)
        let before = store.protocolChangeVersion

        store.markTodayAsTaken()
        #expect(store.protocolChangeVersion == before &+ 1)

        store.unmarkTodayAsTaken()
        #expect(store.protocolChangeVersion == before &+ 2)
    }

    @Test func loggingAPastDayLeavesHomeAlone() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(on: 12)
        let before = store.protocolChangeVersion

        store.markActionAsTaken(on: InMemoryStoreFactory.localDate("2026-05-11", hour: 12))
        #expect(store.statusForDate(InMemoryStoreFactory.localDate("2026-05-11", hour: 0)) == .taken)
        #expect(store.isTodayTaken == false)
        #expect(store.protocolChangeVersion == before)
    }
}
