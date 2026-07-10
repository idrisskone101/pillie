//
//  SubscriptionAttributionTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

/// Records every attribution write so the RevenueCat wiring can be verified
/// without configuring the real SDK (issue #197). Appends itself to a static
/// keep-alive in `init`: deallocating an implicitly-@MainActor class mid-test
/// aborts the host on the Xcode 27 beta (see memory: xcode27-beta-mainactor-deinit-crash).
private final class RecordingAttribution: RevenueCatAttributionSetting {
    private static var keepAlive: [RecordingAttribution] = []

    init() { Self.keepAlive.append(self) }

    var posthogUserIDs: [String] = []
    var appsFlyerIDs: [String] = []
    var attributeWrites: [[String: String]] = []
    var adServicesEnableCount = 0

    func setPostHogUserID(_ id: String) { posthogUserIDs.append(id) }
    func setAppsflyerID(_ id: String) { appsFlyerIDs.append(id) }
    func setAttributes(_ attributes: [String: String]) { attributeWrites.append(attributes) }
    func enableAdServicesAttributionTokenCollection() { adServicesEnableCount += 1 }
}

@MainActor
final class SubscriptionAttributionTests: XCTestCase {
    /// Sinks displaced from the shared manager, retained forever: the hosted app
    /// may already have configured RevenueCat and installed a live sink, and
    /// deallocating that (implicitly-@MainActor) object mid-test aborts the host
    /// on the Xcode 27 beta. Swapping instead of plain assignment keeps every
    /// displaced sink alive.
    private static var keptSinks: [RevenueCatAttributionSetting] = []

    private func swapSink(_ new: RevenueCatAttributionSetting?) {
        if let current = SubscriptionManager.shared.attributionSink {
            Self.keptSinks.append(current)
        }
        SubscriptionManager.shared.attributionSink = new
    }

    func testAttributionWiringEnablesAdServicesTokenCollection() {
        let recorder = RecordingAttribution()

        SubscriptionManager.shared.applyAttribution(
            to: recorder,
            distinctId: nil,
            appsFlyerId: "",
            acquisitionSource: nil
        )

        XCTAssertEqual(recorder.adServicesEnableCount, 1)
    }

    func testAcquisitionSourceIsSentAsSubscriberAttribute() {
        let recorder = RecordingAttribution()

        SubscriptionManager.shared.applyAttribution(
            to: recorder,
            distinctId: nil,
            appsFlyerId: "",
            acquisitionSource: "tiktok"
        )

        XCTAssertEqual(recorder.attributeWrites, [["acquisition_source": "tiktok"]])
    }

    func testMissingOrEmptyAcquisitionSourceWritesNoAttribute() {
        let recorder = RecordingAttribution()

        SubscriptionManager.shared.applyAttribution(
            to: recorder,
            distinctId: nil,
            appsFlyerId: "",
            acquisitionSource: nil
        )
        SubscriptionManager.shared.applyAttribution(
            to: recorder,
            distinctId: nil,
            appsFlyerId: "",
            acquisitionSource: ""
        )

        XCTAssertEqual(recorder.attributeWrites, [])
    }

    func testIdentityIdsAreForwardedOnlyWhenPresent() {
        let recorder = RecordingAttribution()
        SubscriptionManager.shared.applyAttribution(
            to: recorder,
            distinctId: "ph-123",
            appsFlyerId: "af-456",
            acquisitionSource: nil
        )
        XCTAssertEqual(recorder.posthogUserIDs, ["ph-123"])
        XCTAssertEqual(recorder.appsFlyerIDs, ["af-456"])

        let empty = RecordingAttribution()
        SubscriptionManager.shared.applyAttribution(
            to: empty,
            distinctId: "",
            appsFlyerId: "",
            acquisitionSource: nil
        )
        XCTAssertEqual(empty.posthogUserIDs, [])
        XCTAssertEqual(empty.appsFlyerIDs, [])
    }

    func testSourceCommittedAfterConfigureIsForwardedImmediately() {
        let recorder = RecordingAttribution()
        swapSink(recorder)

        SubscriptionManager.shared.recordAcquisitionSource(.tiktok)

        XCTAssertEqual(recorder.attributeWrites, [["acquisition_source": "tiktok"]])
    }

    func testSourceCommittedBeforeConfigureIsDeferredSafely() {
        // Before configure there is no attribution sink; the commit must be a
        // no-op (the value is persisted by PillStore and picked up by the
        // configure-time wiring), not a crash or an SDK touch.
        swapSink(nil)

        SubscriptionManager.shared.recordAcquisitionSource(.reddit)
    }
}
