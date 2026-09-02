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
        let cycleLength = PillPack.PillRegimenPreset.twentyOneSeven.cycleLength
        let activeDays = PillPack.PillRegimenPreset.twentyOneSeven.activeDays

        #expect(plan.startDaysAgo == cycleLength)
        #expect(plan.pastStatuses.count == cycleLength)
        #expect(plan.pastStatuses.prefix(activeDays).allSatisfy { $0 == .taken })
        #expect(plan.pastStatuses.dropFirst(activeDays).allSatisfy { $0 == .breakDay })
    }

    @Test func marketingCalendarMixesTakenAndMissedDays() {
        let plan = DebugPackHistoryPlan.marketingScreenshot()

        #expect(plan.startDaysAgo == 18)
        #expect(plan.pastStatuses.contains(.taken))
        #expect(plan.pastStatuses.contains(.missed))
        #expect(!plan.pastStatuses.contains(.breakDay))
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
