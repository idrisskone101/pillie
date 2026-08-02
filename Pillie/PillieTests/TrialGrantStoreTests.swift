//
//  TrialGrantStoreTests.swift
//  PillieTests
//
//  Contract tests for TrialGrantStoring (PRD #159 / issue #160). The same
//  behavioral contract runs against the in-memory double (used by other
//  tests) and the real Keychain store (hosted tests run inside Pillie.app,
//  so the simulator Keychain is available), keeping the double honest.
//
//  Structured without stored ivars or setUp/tearDown: the Xcode 27 beta
//  hosted-XCTest runner crashes on @MainActor-adjacent test-case deinit
//  (see repo memory), so state stays in locals.
//

import XCTest

@testable import Pillie

final class TrialGrantStoreTests: XCTestCase {

    private func assertContract(_ store: TrialGrantStoring, _ name: String) {
        defer { store.clearGrantDate() }
        store.clearGrantDate()

        // Empty store has no grant.
        XCTAssertNil(store.loadGrantDate(), "\(name): cleared store should be empty")
        XCTAssertNil(store.loadTermsCohort(), "\(name): cleared cohort should be empty")

        // Round trip.
        let grant = Date(timeIntervalSince1970: 1_750_000_000)
        store.saveGrantDate(grant)
        XCTAssertEqual(
            store.loadGrantDate()?.timeIntervalSince1970 ?? 0,
            grant.timeIntervalSince1970,
            accuracy: 0.001,
            "\(name): should round-trip the grant date"
        )
        store.saveTermsCohort(.preCutover)
        XCTAssertEqual(
            store.loadTermsCohort(),
            .preCutover,
            "\(name): should round-trip the immutable terms cohort"
        )

        // Overwrite wins.
        let laterGrant = Date(timeIntervalSince1970: 1_760_000_000)
        store.saveGrantDate(laterGrant)
        XCTAssertEqual(
            store.loadGrantDate()?.timeIntervalSince1970 ?? 0,
            laterGrant.timeIntervalSince1970,
            accuracy: 0.001,
            "\(name): a second save should overwrite the first"
        )
        store.saveTermsCohort(.postCutover)
        XCTAssertEqual(
            store.loadTermsCohort(),
            .postCutover,
            "\(name): a cohort overwrite should win"
        )

        // Clear empties it again.
        store.clearGrantDate()
        XCTAssertNil(store.loadGrantDate(), "\(name): clear should remove the grant")
        XCTAssertNil(store.loadTermsCohort(), "\(name): clear should remove the cohort")
    }

    func testInMemoryStoreHonorsContract() {
        assertContract(InMemoryTrialGrantStore(), "in-memory")
    }

    func testKeychainStoreHonorsContract() {
        assertContract(KeychainTrialGrantStore(), "keychain")
    }
}
