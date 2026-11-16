import Testing

@testable import Pillie

struct BlockingSetupAccessTests {
    @Test func `Unresolved commerce state verifies before anything else`() {
        #expect(resolve(.verifyingAccess, plus: false, granted: false, freePlan: false) == .verifying)
        #expect(resolve(.verifyingAccess, plus: true, granted: true, freePlan: true) == .verifying)
    }

    @Test func `A subscriber and a running trial both get the rehearsal`() {
        #expect(resolve(.subscriber, plus: true, granted: false, freePlan: false) == .open)
        #expect(resolve(.grantTrial, plus: true, granted: true, freePlan: false) == .open)
    }

    @Test func `The frame before the trial grant is written is already the rehearsal`() {
        #expect(resolve(.grantTrial, plus: false, granted: false, freePlan: false) == .open)
    }

    @Test func `A trial that ran out is locked`() {
        #expect(resolve(.grantTrial, plus: false, granted: true, freePlan: false) == .locked)
    }

    @Test func `Choosing the free plan is locked even with Plus access`() {
        #expect(resolve(.grantTrial, plus: true, granted: true, freePlan: true) == .locked)
        #expect(resolve(.subscriber, plus: true, granted: false, freePlan: true) == .locked)
    }

    private func resolve(
        _ activation: OnboardingTrialActivationRoute,
        plus: Bool,
        granted: Bool,
        freePlan: Bool
    ) -> BlockingSetupAccess {
        BlockingSetupAccess.resolve(
            activation: activation,
            hasPlusAccess: plus,
            trialGranted: granted,
            selectedFreePlan: freePlan
        )
    }
}
