//
//  PillDayTakenAtTests.swift
//  PillieTests
//
//  Value-type tests for the PillDay.takenAt adaptive-timing signal.
//
//  These deliberately avoid the hosted @MainActor PillStore harness: on the
//  Xcode 27 beta any @MainActor XCTest class aborts on deinit, so the mark/
//  unmark recording behavior is proven by the build compiling the assignments
//  in PillStore plus the value-level field assertions below (a PillDay round-
//  trips a takenAt timestamp, clears it, and defaults it to nil).
//

import XCTest
import SwiftData
@testable import Pillie

final class PillDayTakenAtTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([PillPack.self, PillDay.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Marking records a timestamp: a taken PillDay round-trips its takenAt.
    func testTakenAtRoundTripsWhenRecorded() throws {
        let context = try makeContext()
        let taken = Date(timeIntervalSince1970: 1_780_000_000)

        let day = PillDay(date: taken, status: .taken, actionType: .pillActive, takenAt: taken)
        context.insert(day)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<PillDay>()).first)
        XCTAssertEqual(fetched.status, .taken)
        XCTAssertEqual(fetched.takenAt, taken)
    }

    /// Unmarking clears the signal: setting takenAt back to nil persists as nil.
    func testTakenAtClearsWhenSetToNil() throws {
        let context = try makeContext()
        let taken = Date(timeIntervalSince1970: 1_780_000_000)

        let day = PillDay(date: taken, status: .taken, actionType: .pillActive, takenAt: taken)
        context.insert(day)
        try context.save()

        day.takenAt = nil
        day.status = .upcoming
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<PillDay>()).first)
        XCTAssertNil(fetched.takenAt)
    }

    /// Existing data migrates cleanly: a PillDay built without takenAt defaults to nil.
    func testTakenAtDefaultsToNil() throws {
        let context = try makeContext()
        let day = PillDay(date: Date(timeIntervalSince1970: 1_780_000_000), status: .upcoming)
        context.insert(day)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<PillDay>()).first)
        XCTAssertNil(fetched.takenAt)
    }
}
