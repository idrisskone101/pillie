//
//  ReminderRebuildMainThreadTests.swift
//  PillieTests
//

import XCTest
import SwiftData
@testable import Pillie

/// UNUserNotificationCenter answers on a background queue. The reminder rebuild still
/// reads PillStore and writes the served-reminder ledger on the main thread.
@MainActor
final class ReminderRebuildMainThreadTests: XCTestCase {
    /// Stores and containers live for the process: the Xcode 27 beta aborts when they deallocate mid-test.
    private static var kept: [Any] = []

    override func setUp() {
        super.setUp()
        InMemoryStoreFactory.resetClockAndDefaults()
        UserDefaults.standard.removeObject(forKey: ServedBaseReminderLedger.userDefaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ServedBaseReminderLedger.userDefaultsKey)
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testARebuildAnsweredOnABackgroundQueueReadsTheStoreOnTheMainThread() throws {
        let store = try makeStore()
        let center = InMemoryNotificationCenter(callbackQueue: DispatchQueue(label: "ReminderRebuildMainThreadTests.center"))
        let manager = KeptNotificationManager.make(center: center, hasPlusAccess: { false })
        let baseReminders = {
            center.pending.filter { $0.content.userInfo["requestKind"] as? String == "base" }.count
        }

        manager.rescheduleFromStore(store)
        drainMainQueue(until: { center.isIdle && baseReminders() > 0 && store.statusReads > baseReminders() })

        XCTAssertGreaterThan(baseReminders(), 0)
        XCTAssertEqual(store.statusReadsOffMain, 0, "PillStore was read off the main thread")
        XCTAssertEqual(ServedBaseReminderLedger.load().fireEpochByDueDayEpoch.count, baseReminders())
    }

    private func makeStore() throws -> ThreadRecordingStore {
        let container = try ModelContainer(
            for: Schema([PillPack.self, PillDay.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let pack = PillPack(
            method: .pill,
            pillRegimen: .twentyOneSeven,
            startDate: PillieClock.today,
            packNumber: 1,
            isCurrent: true
        )
        container.mainContext.insert(pack)
        try container.mainContext.save()
        let store = ThreadRecordingStore(modelContext: container.mainContext)
        store.appActivatedDate = PillieClock.today
        Self.kept.append(contentsOf: [container, pack, store] as [Any])
        return store
    }

    private func drainMainQueue(until done: () -> Bool, timeout: TimeInterval = 10) {
        let deadline = Date().addingTimeInterval(timeout)
        while !done(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

/// Notes the thread of every day-status read, a read each reminder rebuild makes.
private final class ThreadRecordingStore: PillStore {
    private let lock = NSLock()
    private var readsOnMain: [Bool] = []

    var statusReads: Int { lock.withLock { readsOnMain.count } }
    var statusReadsOffMain: Int { lock.withLock { readsOnMain.filter { !$0 }.count } }

    override func statusesByEpochDay(for dates: [Date]) -> [Int: PillDay.Status] {
        lock.withLock { readsOnMain.append(Thread.isMainThread) }
        return super.statusesByEpochDay(for: dates)
    }
}
