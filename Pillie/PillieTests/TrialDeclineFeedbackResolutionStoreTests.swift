//
//  TrialDeclineFeedbackResolutionStoreTests.swift
//  PillieTests
//
//  Keychain persistence contract for issue #243.
//

import XCTest

@testable import Pillie

final class TrialDeclineFeedbackResolutionStoreTests: XCTestCase {
    func testKeychainMarkerPersistsResolutionIdempotently() {
        let store = KeychainTrialDeclineFeedbackResolutionStore()
        defer { store.clearResolution() }
        store.clearResolution()

        XCTAssertFalse(store.isResolved())

        store.markResolved()
        XCTAssertTrue(store.isResolved())

        store.markResolved()
        XCTAssertTrue(store.isResolved())
    }
}
