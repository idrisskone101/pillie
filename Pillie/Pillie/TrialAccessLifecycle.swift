enum TrialAccessLifecycle {
    enum Event {
        case calendarDayChanged
        case significantTimeChanged
    }

    static func handle(
        _ event: Event,
        refreshAccess: () -> Void,
        reconcileProtection: () -> Void
    ) {
        switch event {
        case .calendarDayChanged, .significantTimeChanged:
            refreshAccess()
            reconcileProtection()
        }
    }

    @discardableResult
    static func handleForeground(
        isOnboardingActive: Bool,
        refreshAccess: () -> Void,
        reconcileProtection: () -> Void
    ) -> Bool {
        refreshAccess()
        reconcileProtection()
        return !isOnboardingActive
    }
}
