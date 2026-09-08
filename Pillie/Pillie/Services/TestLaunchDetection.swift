//
//  TestLaunchDetection.swift
//  Pillie
//
//  Hosted XCTest and Swift Testing on Xcode 27 do not always set
//  XCTestConfigurationFilePath. Any of these keys means the process is a
//  test host and must not configure RevenueCat, analytics, or disk stores.
//

import Foundation

enum TestLaunchDetection {
    static func isRunningTests(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }
}
