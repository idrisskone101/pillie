import XCTest

@testable import Pillie

final class OnboardingPaywallRouteTests: XCTestCase {
    func testPlusUsersRouteFromPaywallToAppBlockingSetup() {
        XCTAssertEqual(
            OnboardingPaywallRoute.nextStepAfterPaywall(isPlus: true, selectedFreePlan: false),
            OnboardingPaywallRoute.appBlockingSetupStep
        )
    }

    func testFreeUsersRouteFromPaywallToFreePlanConfirmation() {
        XCTAssertEqual(
            OnboardingPaywallRoute.nextStepAfterPaywall(isPlus: false, selectedFreePlan: true),
            OnboardingPaywallRoute.freePlanConfirmationStep
        )
        XCTAssertEqual(
            OnboardingPaywallRoute.nextStepAfterPaywall(isPlus: false, selectedFreePlan: false),
            OnboardingPaywallRoute.freePlanConfirmationStep
        )
    }
}
