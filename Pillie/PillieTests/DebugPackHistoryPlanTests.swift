#if DEBUG
import Foundation
import Testing

@testable import Pillie

struct DebugPackHistoryPlanTests {
    @Test func missedRecentPlanMarksTheLastTwoDaysMissed() {
        let plan = DebugPackHistoryPlan.missedRecentDays()

        #expect(plan.startDaysAgo == 10)
        #expect(plan.pastStatuses.count == 10)
        #expect(plan.pastStatuses.suffix(2) == [.missed, .missed])
        #expect(plan.pastStatuses.dropLast(2).allSatisfy { $0 == .taken })
    }

    @Test func completedPackSpansAFullTwentyOneSevenCycle() {
        let plan = DebugPackHistoryPlan.completedTwentyOneSevenPack()

        #expect(plan.startDaysAgo == 28)
        #expect(plan.pastStatuses.count == 28)
        #expect(plan.pastStatuses.prefix(21).allSatisfy { $0 == .taken })
        #expect(plan.pastStatuses.dropFirst(21).allSatisfy { $0 == .breakDay })
    }

    @Test func marketingCalendarMixesTakenAndMissedDays() {
        let plan = DebugPackHistoryPlan.marketingScreenshot()

        #expect(plan.startDaysAgo == 18)
        #expect(plan.pastStatuses.contains(.taken))
        #expect(plan.pastStatuses.contains(.missed))
        #expect(!plan.pastStatuses.contains(.breakDay))
    }

    @Test func freshReinstallHasNoPastDays() {
        let plan = DebugPackHistoryPlan.freshReinstall()

        #expect(plan.startDaysAgo == 0)
        #expect(plan.pastStatuses.isEmpty)
    }

    @Test func expiredScenarioPinsGrandfatherGrantBeforeCutover() {
        let scenario = TrialEndPaywallDebugScenario.expired(termsCohort: .preCutover)

        #expect(scenario.termsCohort == .preCutover)
        #expect(scenario.grantDate < HardPaywallPolicy.cutoverInstant)
        #expect(scenario.evaluationDate > scenario.grantDate)
    }

    @Test func expiredScenarioPinsNewUserGrantAtCutover() {
        let scenario = TrialEndPaywallDebugScenario.expired(termsCohort: .postCutover)

        #expect(scenario.termsCohort == .postCutover)
        #expect(scenario.grantDate == HardPaywallPolicy.cutoverInstant)
    }
}
#endif
