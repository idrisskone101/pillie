//
//  StreakAcrossPacksTests.swift
//  PillieTests
//

#if DEBUG
import Foundation
import Testing

@testable import Pillie

@MainActor
struct StreakAcrossPacksTests {
    private static var retained: [Any] = []

    private func store(method: ContraceptiveMethod, now: String) throws -> PillStore {
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.localDate(now, hour: 12),
            method: method,
            startDate: InMemoryStoreFactory.localDate("2026-09-28", hour: 0)
        )
        Self.retained.append(fixture)
        return fixture.store
    }

    private func setNow(_ isoDate: String) {
        PillieClock.setFixedNowForTesting(InMemoryStoreFactory.localDate(isoDate, hour: 12))
    }

    private func log(_ store: PillStore, _ isoDates: String...) {
        for isoDate in isoDates {
            store.markActionAsTaken(on: InMemoryStoreFactory.localDate(isoDate, hour: 12))
        }
    }

    @Test func onTimeRingChangeKeepsTheStreak() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(method: .ring, now: "2026-09-28")
        store.markTodayAsTaken()
        setNow("2026-10-19")
        store.markTodayAsTaken()
        setNow("2026-10-26")
        let before = (store.todayDueAction?.type, store.currentStreak, store.streakAfterCompletingToday)

        store.markTodayAsTaken()

        #expect(before.0 == .ringReinsert)
        #expect(before.1 == 2)
        #expect(before.2 == 3)
        #expect(store.activePack?.packNumber == 2)
        #expect(store.currentStreak == 3)
    }

    @Test func newPillPackKeepsTheStreak() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(method: .pill, now: "2026-10-26")
        log(store, "2026-10-16", "2026-10-17", "2026-10-18")
        let before = store.currentStreak

        store.startNewPack()
        let afterNewPack = store.currentStreak
        store.markTodayAsTaken()

        #expect(before == 3)
        #expect(afterNewPack == 3)
        #expect(store.currentStreak == 4)
    }

    @Test func newPatchCycleKeepsTheStreak() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(method: .patch, now: "2026-10-26")
        log(store, "2026-10-05", "2026-10-12", "2026-10-19")
        let before = store.currentStreak

        store.startNewPack()
        store.markTodayAsTaken()

        #expect(before == 3)
        #expect(store.todayDueAction?.type == .patchChange)
        #expect(store.currentStreak == 4)
    }

    @Test func lateNewPackBreaksTheStreak() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(method: .pill, now: "2026-10-28")
        log(store, "2026-10-16", "2026-10-17", "2026-10-18")

        store.startNewPack()
        store.markTodayAsTaken()

        #expect(store.currentStreak == 1)
    }

    @Test func switchingMethodStartsANewStreak() throws {
        defer { InMemoryStoreFactory.resetClockAndDefaults() }
        let store = try store(method: .pill, now: "2026-10-19")
        log(store, "2026-10-16", "2026-10-17", "2026-10-18")
        let before = store.currentStreak

        let switched = store.startNewProtocol(
            method: .ring,
            regimen: .twentyOneSeven,
            customRegimen: nil,
            cycleDay: 1,
            preserveHistory: true
        )

        #expect(before == 3)
        #expect(switched)
        #expect(store.currentStreak == 0)
    }
}
#endif
