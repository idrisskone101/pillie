import XCTest

@testable import Pillie

final class TrialAccessLifecycleTests: XCTestCase {
    func testCalendarDayChangeRefreshesTrialAccess() {
        var refreshCount = 0

        TrialAccessLifecycle.handle(
            .calendarDayChanged,
            refreshAccess: { refreshCount += 1 },
            reconcileProtection: {}
        )

        XCTAssertEqual(refreshCount, 1)
    }

    func testSignificantTimeChangeRefreshesTrialAccess() {
        var refreshCount = 0

        TrialAccessLifecycle.handle(
            .significantTimeChanged,
            refreshAccess: { refreshCount += 1 },
            reconcileProtection: {}
        )

        XCTAssertEqual(refreshCount, 1)
    }

    func testCalendarDayChangeRefreshesAccessBeforeReconcilingProtection() {
        var operations: [String] = []

        TrialAccessLifecycle.handle(
            .calendarDayChanged,
            refreshAccess: { operations.append("refresh-access") },
            reconcileProtection: { operations.append("reconcile-protection") }
        )

        XCTAssertEqual(operations, ["refresh-access", "reconcile-protection"])
    }

    func testForegroundExpiryReconcilesProtectionEvenDuringOnboarding() {
        var operations: [String] = []

        let shouldRunPostOnboardingWork = TrialAccessLifecycle.handleForeground(
            isOnboardingActive: true,
            refreshAccess: { operations.append("refresh-access") },
            reconcileProtection: { operations.append("reconcile-protection") }
        )

        XCTAssertEqual(operations, ["refresh-access", "reconcile-protection"])
        XCTAssertFalse(shouldRunPostOnboardingWork)
    }
}
