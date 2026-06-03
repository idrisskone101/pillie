//
//  PersonalizationOnboardingTests.swift
//  PillieTests
//

import XCTest

@testable import Pillie

@MainActor
final class PersonalizationOnboardingTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testAcquisitionSourcePersistsAsCoarseLocalValue() throws {
        let fixture = try InMemoryStoreFactory.makeStore(
            now: InMemoryStoreFactory.fixedDate("2026-06-03")
        )

        fixture.store.acquisitionSource = .appStoreSearch

        let reloadedStore = PillStore(modelContext: fixture.context)
        XCTAssertEqual(reloadedStore.acquisitionSource, .appStoreSearch)
    }
}
