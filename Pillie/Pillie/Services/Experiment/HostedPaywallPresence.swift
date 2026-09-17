import RevenueCat

enum HostedPaywallPresence {
    static func isPresent(on offering: Offering?) -> Bool {
        offering?.hasPaywall == true
    }
}
