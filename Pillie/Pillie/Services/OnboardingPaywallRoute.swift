enum OnboardingPaywallRoute {
    static let freePlanConfirmationStep = 14
    static let appBlockingSetupStep = 15

    static func nextStepAfterPaywall(isPlus: Bool, selectedFreePlan: Bool) -> Int {
        if selectedFreePlan || !isPlus {
            return freePlanConfirmationStep
        }

        return appBlockingSetupStep
    }
}
