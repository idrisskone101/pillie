enum SubscriptionLaunchPolicy {
    static func shouldConfigureRevenueCat(isRunningTests: Bool) -> Bool {
        !isRunningTests
    }
}
