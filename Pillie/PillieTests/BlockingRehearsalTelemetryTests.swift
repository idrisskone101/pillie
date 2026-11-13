import Testing

@testable import Pillie

struct BlockingRehearsalTelemetryTests {
    private func recorded(_ signals: BlockingRehearsalSignal...) -> [DemoFunnelRecorder.Event] {
        let recorder = DemoFunnelRecorder()
        let telemetry = BlockingRehearsalTelemetry(analytics: recorder, isPlus: { false })
        signals.forEach(telemetry.record)
        return recorder.events
    }

    private func event(
        _ event: AnalyticsEvent,
        step: AnalyticsStep,
        shakeCount: Int? = nil
    ) -> DemoFunnelRecorder.Event {
        DemoFunnelRecorder.Event(
            event: event, source: .onboarding, step: step, stepIndex: nil, result: nil, shakeCount: shakeCount
        )
    }

    @Test func `Each stage viewed reports its own step`() {
        #expect(
            recorded(.viewed(.reminder), .viewed(.paused), .viewed(.shake), .viewed(.ask), .viewed(.refused), .viewed(.picks))
                == [
                    event(.blockingRehearsalStageViewed, step: .rehearsalReminder),
                    event(.blockingRehearsalStageViewed, step: .rehearsalPaused),
                    event(.blockingRehearsalStageViewed, step: .rehearsalShake),
                    event(.blockingRehearsalStageViewed, step: .rehearsalAsk),
                    event(.blockingRehearsalStageViewed, step: .rehearsalRefused),
                    event(.blockingRehearsalStageViewed, step: .rehearsalPicks),
                ]
        )
    }

    @Test func `A second refusal is a second view`() {
        #expect(recorded(.viewed(.refused), .viewed(.refused)).count == 2)
    }

    @Test func `A beat she played and a beat the demo played are different events`() {
        #expect(
            recorded(.played(.reminder, by: .herTap), .played(.paused, by: .demo))
                == [
                    event(.blockingRehearsalBeatPlayed, step: .rehearsalReminder),
                    event(.blockingRehearsalBeatSelfPlayed, step: .rehearsalPaused),
                ]
        )
    }

    @Test func `The shake beat says whether she shook, tapped, or waited`() {
        #expect(
            recorded(.played(.shake, by: .herShake), .played(.shake, by: .herTap), .played(.shake, by: .demo))
                == [
                    event(.blockingRehearsalBeatPlayed, step: .rehearsalShake, shakeCount: 1),
                    event(.blockingRehearsalBeatPlayed, step: .rehearsalShake, shakeCount: 0),
                    event(.blockingRehearsalBeatSelfPlayed, step: .rehearsalShake),
                ]
        )
    }

    @Test func `Each answer to a refusal has its own event`() {
        #expect(
            recorded(.refusalAnswered(.askAgain), .refusalAnswered(.remindersOnly))
                == [
                    event(.blockingRehearsalAskAgain, step: .rehearsalRefused),
                    event(.blockingRehearsalRemindersOnly, step: .rehearsalRefused),
                ]
        )
    }

    @Test func `The shake count rides the payload as an int`() {
        #expect(AnalyticsPayload(shakeCount: 1).properties["shake_count"] == .int(1))
        #expect(AnalyticsPayload().properties["shake_count"] == nil)
    }
}
