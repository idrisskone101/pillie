//
//  BlockingOnStatusTests.swift
//  PillieTests
//

#if DEBUG
import XCTest
@testable import Pillie

/// "On" means apps really get blocked: switched on, apps saved, and Screen Time access granted.
@MainActor
final class BlockingOnStatusTests: XCTestCase {
    private let manager = AppBlockingManager.shared

    override func setUp() {
        super.setUp()
        manager.debugBlockerConfiguredOverride = true
        manager.blockingEnabled = true
    }

    override func tearDown() {
        manager.debugSimulatorRefusal = nil
        manager.updateAuthorizationStatus()
        manager.debugBlockerConfiguredOverride = nil
        manager.blockingEnabled = true
        super.tearDown()
    }

    func testBlockingReadsOnWithAccessGranted() {
        manager.debugSimulatorRefusal = nil
        manager.updateAuthorizationStatus()

        XCTAssertTrue(manager.isEffectivelyOn)
    }

    func testBlockingReadsOffOnceScreenTimeAccessIsRevoked() {
        manager.debugSimulatorRefusal = .notAllowed
        manager.updateAuthorizationStatus()

        XCTAssertFalse(manager.isEffectivelyOn)
    }
}
#endif
