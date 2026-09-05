//
//  HistoryDiscoveryAnnouncementTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

final class HistoryDiscoveryAnnouncementTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "HistoryDiscoveryAnnouncementTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testFreshInstallIsSeededAsDismissed() {
        HistoryDiscoveryAnnouncement.seedForFreshInstallIfNeeded(
            hasExistingAppState: false,
            defaults: defaults
        )

        XCTAssertTrue(defaults.bool(forKey: HistoryDiscoveryAnnouncement.storageKey))
    }

    func testExistingUserKeepsAnnouncementPending() {
        HistoryDiscoveryAnnouncement.seedForFreshInstallIfNeeded(
            hasExistingAppState: true,
            defaults: defaults
        )

        XCTAssertNil(defaults.object(forKey: HistoryDiscoveryAnnouncement.storageKey))
        XCTAssertFalse(defaults.bool(forKey: HistoryDiscoveryAnnouncement.storageKey))
    }

    func testExplicitDismissalIsNeverOverwritten() {
        defaults.set(false, forKey: HistoryDiscoveryAnnouncement.storageKey)

        HistoryDiscoveryAnnouncement.seedForFreshInstallIfNeeded(
            hasExistingAppState: false,
            defaults: defaults
        )

        XCTAssertFalse(defaults.bool(forKey: HistoryDiscoveryAnnouncement.storageKey))
    }
}
