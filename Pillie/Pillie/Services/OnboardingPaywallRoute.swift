enum OnboardingPaywallRoute {
    static let freePlanConfirmationStep = 13
    static let appBlockingSetupStep = 14

    static func nextStepAfterPaywall(isPlus: Bool, selectedFreePlan: Bool) -> Int {
        if selectedFreePlan || !isPlus {
            return freePlanConfirmationStep
        }

        return appBlockingSetupStep
    }
}
