//
//  ProcessRuntime.swift
//  Pillie
//

import Foundation

/// Hosted-test detection for the app process.
///
/// Xcode 27 / test plans often leave `XCTestConfigurationFilePath` empty while
/// still injecting `XCTestBundlePath` and `XCTestSessionIdentifier`. Swift
/// Testing uses those newer keys. `XCTestCase` being loaded is the hosted-bundle
/// signal when environment keys are missing.
enum ProcessRuntime {
    static var isRunningTests: Bool {
        isRunningTests(environment: ProcessInfo.processInfo.environment)
    }

    static func isRunningTests(
        environment: [String: String],
        hasXCTestRuntime: Bool = NSClassFromString("XCTestCase") != nil
    ) -> Bool {
        // Test plans may set this key to an empty string; presence is enough.
        if environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        if let bundlePath = environment["XCTestBundlePath"], !bundlePath.isEmpty {
            return true
        }
        if let session = environment["XCTestSessionIdentifier"], !session.isEmpty {
            return true
        }
        return hasXCTestRuntime
    }
}
