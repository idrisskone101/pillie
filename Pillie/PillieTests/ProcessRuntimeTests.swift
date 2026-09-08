#if DEBUG
import Foundation
import Testing

@testable import Pillie

struct ProcessRuntimeTests {
    @Test func configurationFilePathMarksTests() {
        #expect(
            ProcessRuntime.isRunningTests(
                environment: ["XCTestConfigurationFilePath": "/tmp/Pillie.xctestconfiguration"],
                hasXCTestRuntime: false
            )
        )
    }

    @Test func emptyConfigurationPathStillMarksTests() {
        #expect(
            ProcessRuntime.isRunningTests(
                environment: ["XCTestConfigurationFilePath": ""],
                hasXCTestRuntime: false
            )
        )
    }

    @Test func injectedBundlePathMarksTests() {
        #expect(
            ProcessRuntime.isRunningTests(
                environment: ["XCTestBundlePath": "PlugIns/PillieTests.xctest"],
                hasXCTestRuntime: false
            )
        )
    }

    @Test func sessionIdentifierMarksTests() {
        #expect(
            ProcessRuntime.isRunningTests(
                environment: ["XCTestSessionIdentifier": "3B127C55-13E6-4F13-84BD-53FF9FBBC8B2"],
                hasXCTestRuntime: false
            )
        )
    }

    @Test func hostedXCTestRuntimeMarksTestsWithoutEnvironmentKeys() {
        #expect(
            ProcessRuntime.isRunningTests(
                environment: [:],
                hasXCTestRuntime: true
            )
        )
    }

    @Test func productionLaunchIsNotTesting() {
        #expect(
            !ProcessRuntime.isRunningTests(
                environment: [:],
                hasXCTestRuntime: false
            )
        )
    }
}
#endif
