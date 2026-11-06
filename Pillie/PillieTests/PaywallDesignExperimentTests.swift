//
//  PaywallDesignExperimentTests.swift
//  PillieTests
//

import Foundation
import Testing

@testable import Pillie

struct PaywallDesignExperimentTests {
    @Test func `A stored arm wins over the flag`() {
        let assignment = PaywallDesignExperiment.assignment(stored: .classic, flagValue: "control")
        #expect(assignment == PaywallDesignAssignment(design: .classic, isFromFlag: true))
    }

    @Test func `A stored arm holds once the flag is gone`() {
        let assignment = PaywallDesignExperiment.assignment(stored: .s3, flagValue: nil)
        #expect(assignment == PaywallDesignAssignment(design: .s3, isFromFlag: true))
    }

    @Test(arguments: [
        ("classic", PaywallDesign.classic),
        ("control", PaywallDesign.s3),
    ])
    func `A known variant becomes the arm`(variant: String, design: PaywallDesign) {
        let assignment = PaywallDesignExperiment.assignment(stored: nil, flagValue: variant)
        #expect(assignment == PaywallDesignAssignment(design: design, isFromFlag: true))
    }

    @Test func `No flag value shows S3 outside the test`() {
        let assignment = PaywallDesignExperiment.assignment(stored: nil, flagValue: nil)
        #expect(assignment == PaywallDesignAssignment(design: .s3, isFromFlag: false))
    }

    @Test func `An unknown variant shows S3 outside the test`() {
        let assignment = PaywallDesignExperiment.assignment(stored: nil, flagValue: "test")
        #expect(assignment == PaywallDesignAssignment(design: .s3, isFromFlag: false))
    }

    @Test func `An inactive flag shows S3 outside the test`() {
        let assignment = PaywallDesignExperiment.assignment(stored: nil, flagValue: false)
        #expect(assignment == PaywallDesignAssignment(design: .s3, isFromFlag: false))
    }

    @Test func `The store keeps the arm by its PostHog variant`() throws {
        let suite = "PaywallDesignExperimentTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PaywallDesignStore(defaults: defaults)

        #expect(store.load() == nil)
        store.save(.classic)
        #expect(store.load() == .classic)
        #expect(defaults.string(forKey: "paywall_design_v1_arm") == "classic")
    }
}
