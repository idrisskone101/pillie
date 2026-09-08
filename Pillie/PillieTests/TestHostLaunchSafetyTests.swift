import Foundation
import Testing

@testable import Pillie

struct TestHostLaunchSafetyTests {
    @Test func xcode27SessionIdentifierCountsAsATestLaunch() {
        #expect(
            TestLaunchDetection.isRunningTests(
                environment: ["XCTestSessionIdentifier": "session"]
            )
        )
    }

    @Test func xcode27BundlePathCountsAsATestLaunch() {
        #expect(
            TestLaunchDetection.isRunningTests(
                environment: ["XCTestBundlePath": "/tmp/PillieTests.xctest"]
            )
        )
    }

    @Test func configurationFilePathStillCountsAsATestLaunch() {
        #expect(
            TestLaunchDetection.isRunningTests(
                environment: ["XCTestConfigurationFilePath": "/tmp/config"]
            )
        )
    }

    @Test func aNormalLaunchIsNotATest() {
        #expect(!TestLaunchDetection.isRunningTests(environment: [:]))
    }

    @Test func hostedTestsMustNotConfigureRevenueCat() {
        #expect(!SubscriptionLaunchPolicy.shouldConfigureRevenueCat(isRunningTests: true))
    }

    @Test func refreshCommerceStateDoesNotTrapWhenRevenueCatIsUnconfigured() async {
        await SubscriptionManager.shared.refreshCommerceState()
    }

    @Test func setPlusForTestingResolvesCommerceSoSetupIsNotBlocked() {
        let manager = SubscriptionManager.shared
        manager.setPlusForTesting(true)
        defer { manager.setPlusForTesting(false) }
        #expect(manager.hasResolvedEntitlement)
        #expect(manager.hasResolvedHardPaywallConfiguration)
        #expect(manager.hasPlusAccess)
        #expect(
            OnboardingTrialActivationRoute.resolve(
                hasEntitlement: true,
                entitlementResolved: true,
                configurationResolved: true
            ) == .subscriber
        )
    }
}
