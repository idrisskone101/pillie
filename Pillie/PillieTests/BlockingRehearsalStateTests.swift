import Testing

@testable import Pillie

struct BlockingRehearsalStateTests {
    private func opened(
        demoSeen: Bool = false,
        hasSelection: Bool = false,
        isAuthorized: Bool = false,
        voiceOver: Bool = false,
        sceneActive: Bool = true
    ) -> BlockingRehearsalState {
        var state = BlockingRehearsalState()
        _ = state.handle(.appeared(BlockingRehearsalOpening(
            demoSeen: demoSeen,
            hasSelection: hasSelection,
            isAuthorized: isAuthorized,
            voiceOverRunning: voiceOver,
            sceneActive: sceneActive
        )))
        return state
    }

    private func atAsk() -> BlockingRehearsalState {
        var state = opened()
        _ = state.handle(.beatControlTapped)
        _ = state.handle(.timerFired(.appPressed(by: .herTap)))
        _ = state.handle(.beatControlTapped)
        _ = state.handle(.timerFired(.coralSpreads(by: .herTap)))
        _ = state.handle(.shaken)
        _ = state.handle(.shakeClipFinished)
        _ = state.handle(.timerFired(.settleAfterPop))
        return state
    }

    private func refused(_ refusal: ScreenTimeRefusal = .notAllowed) -> BlockingRehearsalState {
        var state = atAsk()
        _ = state.handle(.chooseTapped)
        _ = state.handle(.authorizationResolved(.refused(refusal)))
        return state
    }

    // MARK: Where the screen opens

    @Test func `Nothing is on screen until the opening facts arrive`() {
        var state = BlockingRehearsalState()
        #expect(state.stage == nil)
        #expect(state.timer == nil)
        #expect(state.handle(.beatControlTapped) == [])
        #expect(state.handle(.chooseTapped) == [])
        #expect(state.stage == nil)
    }

    @Test func `A first visit opens on the reminder beat and reports it once`() {
        var state = BlockingRehearsalState()
        let opening = BlockingRehearsalOpening(
            demoSeen: false, hasSelection: false, isAuthorized: false, voiceOverRunning: false
        )
        #expect(state.handle(.appeared(opening)) == [.report(.viewed(.reminder))])
        #expect(state.stage == .reminder)
        #expect(state.handle(.appeared(opening)) == [])
    }

    @Test func `A seen demo opens on the ask with no replay`() {
        var state = BlockingRehearsalState()
        let effects = state.handle(.appeared(BlockingRehearsalOpening(
            demoSeen: true, hasSelection: false, isAuthorized: false, voiceOverRunning: false
        )))
        #expect(effects == [.report(.viewed(.ask))])
        #expect(state.stage == .ask)
        #expect(state.timer == nil)
    }

    @Test func `An existing selection opens on the picks`() {
        #expect(opened(hasSelection: true).stage == .picks)
        #expect(opened(demoSeen: true, hasSelection: true).stage == .picks)
    }

    // MARK: Beats by her hand

    @Test func `Tapping the featured app plays its exit, then the app is paused`() {
        var state = opened()
        #expect(state.handle(.beatControlTapped) == [.report(.played(.reminder, by: .herTap))])
        #expect(state.stage == .reminder)
        #expect(state.resolvedBy == .herTap)
        #expect(state.timer == .appPressed(by: .herTap))
        #expect(state.handle(.timerFired(.appPressed(by: .herTap))) == [.report(.viewed(.paused))])
        #expect(state.stage == .paused)
        #expect(state.resolvedBy == nil)
    }

    @Test func `A second tap during the exit does not skip a beat`() {
        var state = opened()
        _ = state.handle(.beatControlTapped)
        #expect(state.handle(.beatControlTapped) == [])
        #expect(state.handle(.timerFired(.appPressed(by: .herTap))) == [.report(.viewed(.paused))])
        #expect(state.handle(.timerFired(.appPressed(by: .herTap))) == [])
        #expect(state.stage == .paused)
    }

    @Test func `A greyed app only nudges the pause card and keeps the wait running`() {
        var state = opened()
        _ = state.handle(.beatControlTapped)
        _ = state.handle(.timerFired(.appPressed(by: .herTap)))
        #expect(state.handle(.greyedAppTapped) == [.nudgePauseCard])
        #expect(state.stage == .paused)
        #expect(state.resolvedBy == nil)
        #expect(state.timer == .selfPlay(.paused))
    }

    @Test func `A greyed app does nothing on another beat`() {
        var state = opened()
        #expect(state.handle(.greyedAppTapped) == [])
    }

    @Test func `Open Pillie spreads the coral, then the shake beat is on`() {
        var state = opened()
        _ = state.handle(.beatControlTapped)
        _ = state.handle(.timerFired(.appPressed(by: .herTap)))
        #expect(state.handle(.beatControlTapped) == [.report(.played(.paused, by: .herTap))])
        #expect(state.resolvedBy == .herTap)
        #expect(state.timer == .coralSpreads(by: .herTap))
        #expect(state.handle(.timerFired(.coralSpreads(by: .herTap))) == [.report(.viewed(.shake))])
        #expect(state.stage == .shake)
        #expect(state.listensForShake)
        #expect(!state.playsShakeClip)
    }

    @Test func `One shake starts the pop and a second shake does nothing`() {
        var state = opened()
        _ = state.handle(.beatControlTapped)
        _ = state.handle(.timerFired(.appPressed(by: .herTap)))
        _ = state.handle(.beatControlTapped)
        _ = state.handle(.timerFired(.coralSpreads(by: .herTap)))
        #expect(state.handle(.shaken) == [.report(.played(.shake, by: .herShake))])
        #expect(state.playsShakeClip)
        #expect(!state.listensForShake)
        #expect(state.handle(.shaken) == [])
        #expect(state.handle(.beatControlTapped) == [])
    }

    @Test func `A shake before the shake beat is ignored`() {
        var state = opened()
        #expect(state.handle(.shaken) == [])
        #expect(state.stage == .reminder)
    }

    @Test func `The ask arrives half a second after the pop and the demo is marked seen`() {
        var state = opened()
        _ = state.handle(.beatControlTapped)
        _ = state.handle(.timerFired(.appPressed(by: .herTap)))
        _ = state.handle(.beatControlTapped)
        _ = state.handle(.timerFired(.coralSpreads(by: .herTap)))
        _ = state.handle(.beatControlTapped)
        #expect(state.timer == nil)
        #expect(state.handle(.timerFired(.settleAfterPop)) == [])
        #expect(state.handle(.shakeClipFinished) == [])
        #expect(state.timer == .settleAfterPop)
        #expect(BlockingRehearsalTimer.settleAfterPop.duration == .milliseconds(500))
        #expect(state.handle(.timerFired(.settleAfterPop)) == [.persistDemoSeen, .report(.viewed(.ask))])
        #expect(state.stage == .ask)
        #expect(!state.playsShakeClip)
    }

    // MARK: Self-play

    @Test(arguments: [
        (BlockingRehearsalBeat.reminder, Duration.milliseconds(3500)),
        (.paused, .seconds(3)),
        (.shake, .seconds(4)),
    ])
    func `Each beat waits its own time before playing itself`(beat: BlockingRehearsalBeat, wait: Duration) {
        #expect(BlockingRehearsalTimer.selfPlay(beat).duration == wait)
    }

    @Test func `The demo's exits run longer than hers because the hand moves first`() {
        #expect(BlockingRehearsalTimer.appPressed(by: .herTap).duration == .milliseconds(450))
        #expect(BlockingRehearsalTimer.appPressed(by: .demo).duration == .milliseconds(900))
        #expect(BlockingRehearsalTimer.coralSpreads(by: .herTap).duration == .milliseconds(500))
        #expect(BlockingRehearsalTimer.coralSpreads(by: .demo).duration == .milliseconds(700))
    }

    @Test func `Left alone, the demo plays every beat and says so`() {
        var state = opened()
        #expect(state.timer == .selfPlay(.reminder))
        #expect(state.handle(.timerFired(.selfPlay(.reminder))) == [.report(.played(.reminder, by: .demo))])
        #expect(state.resolvedBy == .demo)
        #expect(state.handle(.timerFired(.appPressed(by: .demo))) == [.report(.viewed(.paused))])
        #expect(state.timer == .selfPlay(.paused))
        #expect(state.handle(.timerFired(.selfPlay(.paused))) == [.report(.played(.paused, by: .demo))])
        #expect(state.handle(.timerFired(.coralSpreads(by: .demo))) == [.report(.viewed(.shake))])
        #expect(state.timer == .selfPlay(.shake))
        #expect(state.handle(.timerFired(.selfPlay(.shake))) == [.report(.played(.shake, by: .demo))])
        #expect(state.playsShakeClip)
        _ = state.handle(.shakeClipFinished)
        #expect(state.handle(.timerFired(.settleAfterPop)) == [.persistDemoSeen, .report(.viewed(.ask))])
    }

    @Test func `A self-play timer that fires after her tap is ignored`() {
        var state = opened()
        _ = state.handle(.beatControlTapped)
        #expect(state.handle(.timerFired(.selfPlay(.reminder))) == [])
        #expect(state.resolvedBy == .herTap)
    }

    @Test func `VoiceOver turns self-play off and every beat still has a control`() {
        var state = opened(voiceOver: true)
        #expect(state.timer == nil)
        #expect(state.handle(.timerFired(.selfPlay(.reminder))) == [])
        _ = state.handle(.beatControlTapped)
        #expect(state.timer == .appPressed(by: .herTap))
        _ = state.handle(.timerFired(.appPressed(by: .herTap)))
        #expect(state.timer == nil)
        _ = state.handle(.beatControlTapped)
        _ = state.handle(.timerFired(.coralSpreads(by: .herTap)))
        #expect(state.timer == nil)
        #expect(state.handle(.beatControlTapped) == [.report(.played(.shake, by: .herTap))])
        #expect(state.playsShakeClip)
    }

    @Test func `Turning VoiceOver off mid-beat starts the wait`() {
        var state = opened(voiceOver: true)
        #expect(state.handle(.voiceOverChanged(isRunning: false)) == [])
        #expect(state.timer == .selfPlay(.reminder))
    }

    @Test func `VoiceOver turning on mid-beat stops the wait`() {
        var state = opened()
        #expect(state.handle(.voiceOverChanged(isRunning: true)) == [])
        #expect(state.timer == nil)
        #expect(state.handle(.timerFired(.selfPlay(.reminder))) == [])
        #expect(state.stage == .reminder)
    }

    @Test func `A screen that opens while the scene is inactive waits until it is active`() {
        var state = opened(sceneActive: false)
        #expect(state.timer == nil)
        _ = state.handle(.sceneActivityChanged(isActive: true))
        #expect(state.timer == .selfPlay(.reminder))
    }

    @Test func `An exit already under way finishes even if the scene goes inactive`() {
        var state = opened()
        _ = state.handle(.beatControlTapped)
        _ = state.handle(.sceneActivityChanged(isActive: false))
        #expect(state.timer == .appPressed(by: .herTap))
        #expect(state.handle(.timerFired(.appPressed(by: .herTap))) == [.report(.viewed(.paused))])
        #expect(state.timer == nil)
    }

    @Test func `An inactive scene holds the beat and coming back restarts the wait`() {
        var state = opened()
        _ = state.handle(.sceneActivityChanged(isActive: false))
        #expect(state.timer == nil)
        _ = state.handle(.sceneActivityChanged(isActive: true))
        #expect(state.timer == .selfPlay(.reminder))
    }

    @Test func `The ask never plays itself`() {
        #expect(atAsk().timer == nil)
    }

    // MARK: The ask, Apple's answer, the picks

    @Test func `Choose asks Apple once however often it is tapped`() {
        var state = atAsk()
        #expect(state.handle(.chooseTapped) == [.authorize])
        #expect(state.isRequesting)
        #expect(state.handle(.chooseTapped) == [])
    }

    @Test func `A grant opens the picker and a pick shows the picks`() {
        var state = atAsk()
        _ = state.handle(.chooseTapped)
        #expect(state.handle(.authorizationResolved(.granted)) == [.presentPicker])
        #expect(!state.isRequesting)
        #expect(state.isAuthorized)
        #expect(state.handle(.selectionChanged(hasSelection: true)) == [.report(.viewed(.picks))])
        #expect(state.stage == .picks)
        #expect(state.handle(.continueTapped) == [.saveAndContinue])
    }

    @Test func `Closing the picker with nothing picked stays on the ask`() {
        var state = atAsk()
        _ = state.handle(.chooseTapped)
        _ = state.handle(.authorizationResolved(.granted))
        #expect(state.handle(.selectionChanged(hasSelection: false)) == [])
        #expect(state.stage == .ask)
    }

    @Test func `Change reopens the picker and clearing every pick returns to the ask`() {
        var state = opened(demoSeen: true, hasSelection: true, isAuthorized: true)
        #expect(state.handle(.chooseTapped) == [.authorize])
        #expect(state.handle(.authorizationResolved(.granted)) == [.presentPicker])
        #expect(state.handle(.selectionChanged(hasSelection: false)) == [.report(.viewed(.ask))])
        #expect(state.stage == .ask)
    }

    @Test func `Picks made before the beats end are waiting when they do`() {
        var state = opened()
        _ = state.handle(.selectionChanged(hasSelection: true))
        #expect(state.stage == .reminder)
        _ = state.handle(.timerFired(.selfPlay(.reminder)))
        _ = state.handle(.timerFired(.appPressed(by: .demo)))
        _ = state.handle(.timerFired(.selfPlay(.paused)))
        _ = state.handle(.timerFired(.coralSpreads(by: .demo)))
        _ = state.handle(.timerFired(.selfPlay(.shake)))
        _ = state.handle(.shakeClipFinished)
        #expect(state.handle(.timerFired(.settleAfterPop)) == [.persistDemoSeen, .report(.viewed(.picks))])
    }

    @Test func `Continue with picks but without Screen Time asks Apple before it saves`() {
        var state = opened(demoSeen: true, hasSelection: true, isAuthorized: false)
        #expect(state.handle(.continueTapped) == [.authorize])
        #expect(state.isRequesting)
        #expect(state.handle(.continueTapped) == [])
        #expect(state.handle(.authorizationResolved(.granted)) == [.presentPicker])
        #expect(state.handle(.continueTapped) == [.saveAndContinue])
    }

    @Test func `Access revoked while the picks are up is asked for again`() {
        var state = opened(demoSeen: true, hasSelection: true, isAuthorized: true)
        #expect(state.handle(.authorizationChanged(isAuthorized: false)) == [])
        #expect(!state.isAuthorized)
        #expect(state.handle(.continueTapped) == [.authorize])
    }

    @Test func `Dont Allow shows the refused state with its reason`() {
        var state = atAsk()
        _ = state.handle(.chooseTapped)
        let effects = state.handle(.authorizationResolved(.refused(.notAllowed)))
        #expect(effects == [.report(.viewed(.refused))])
        #expect(state.stage == .refused)
        #expect(state.refusal == .notAllowed)
        #expect(!state.isAuthorized)
        #expect(!state.isRequesting)
    }

    @Test func `Another app holding Screen Time is its own reason`() {
        #expect(refused(.heldByAnotherApp).refusal == .heldByAnotherApp)
    }

    @Test func `Try again asks Apple again and a grant goes back to the ask with the picker`() {
        var state = refused()
        #expect(state.handle(.chooseTapped) == [.report(.askedAgain), .authorize])
        #expect(state.isRequesting)
        #expect(state.handle(.chooseTapped) == [])
        #expect(state.handle(.authorizationResolved(.granted)) == [.report(.viewed(.ask)), .presentPicker])
        #expect(state.stage == .ask)
        #expect(state.refusal == nil)
    }

    @Test func `A second refusal stays refused and is reported again`() {
        var state = refused()
        _ = state.handle(.chooseTapped)
        #expect(
            state.handle(.authorizationResolved(.refused(.heldByAnotherApp)))
                == [.report(.viewed(.refused))]
        )
        #expect(state.refusal == .heldByAnotherApp)
    }

    @Test func `Use reminders only leaves the step`() {
        var state = refused()
        #expect(
            state.handle(.remindersOnlyTapped)
                == [.report(.choseRemindersOnly(on: .refused)), .useRemindersOnly]
        )
    }

    @Test func `Reminders only waits while Apple is being asked again`() {
        var state = refused()
        _ = state.handle(.chooseTapped)
        #expect(state.handle(.remindersOnlyTapped) == [])
    }

    @Test func `Before Apple has been asked there is no way out of the ask except through Apple`() {
        var state = atAsk()
        #expect(!state.isAuthorized)
        #expect(state.handle(.remindersOnlyTapped) == [])
        #expect(state.handle(.continueTapped) == [])
        #expect(state.stage == .ask)
    }

    @Test func `Allowing Screen Time and then picking nothing still leaves a way out`() {
        var state = atAsk()
        _ = state.handle(.chooseTapped)
        #expect(state.handle(.remindersOnlyTapped) == [])
        _ = state.handle(.authorizationResolved(.granted))
        _ = state.handle(.selectionChanged(hasSelection: false))
        #expect(state.stage == .ask)
        #expect(
            state.handle(.remindersOnlyTapped)
                == [.report(.choseRemindersOnly(on: .ask)), .useRemindersOnly]
        )
    }

    @Test func `A returning user who already allowed Screen Time can leave the ask`() {
        var state = opened(demoSeen: true, isAuthorized: true)
        #expect(state.stage == .ask)
        #expect(
            state.handle(.remindersOnlyTapped)
                == [.report(.choseRemindersOnly(on: .ask)), .useRemindersOnly]
        )
    }

    @Test func `Reminders only waits while the ask is opening the picker`() {
        var state = opened(demoSeen: true, isAuthorized: true)
        _ = state.handle(.chooseTapped)
        #expect(state.handle(.remindersOnlyTapped) == [])
    }

    @Test func `A grant after a refusal lands on the picks when some are already chosen`() {
        var state = refused()
        _ = state.handle(.selectionChanged(hasSelection: true))
        #expect(state.stage == .refused)
        _ = state.handle(.chooseTapped)
        #expect(state.handle(.authorizationResolved(.granted)) == [.report(.viewed(.picks)), .presentPicker])
        #expect(state.stage == .picks)
    }

    @Test func `A refusal while confirming picks shows the refused state`() {
        var state = opened(demoSeen: true, hasSelection: true, isAuthorized: false)
        _ = state.handle(.continueTapped)
        #expect(state.handle(.authorizationResolved(.refused(.notAllowed))) == [.report(.viewed(.refused))])
        #expect(state.stage == .refused)
        #expect(state.handle(.continueTapped) == [])
    }

    @Test func `A selection that arrives while Apple is asked keeps the request open`() {
        var state = atAsk()
        _ = state.handle(.chooseTapped)
        #expect(state.handle(.selectionChanged(hasSelection: true)) == [.report(.viewed(.picks))])
        #expect(state.isRequesting)
        #expect(state.handle(.authorizationResolved(.granted)) == [.presentPicker])
        #expect(!state.isRequesting)
        #expect(state.stage == .picks)
    }

    @Test func `Continue saves again if it is tapped again`() {
        var state = opened(demoSeen: true, hasSelection: true, isAuthorized: true)
        #expect(state.handle(.continueTapped) == [.saveAndContinue])
        #expect(state.handle(.continueTapped) == [.saveAndContinue])
        #expect(state.stage == .picks)
    }

    @Test func `No beat can skip to the ask or leave the step`() {
        var state = opened()
        #expect(state.handle(.chooseTapped) == [])
        #expect(state.handle(.continueTapped) == [])
        #expect(state.handle(.remindersOnlyTapped) == [])
        #expect(state.stage == .reminder)
        #expect(!state.isRequesting)
    }

    @Test func `A late answer from Apple changes nothing`() {
        var state = atAsk()
        #expect(state.handle(.authorizationResolved(.granted)) == [])
        #expect(state.handle(.authorizationResolved(.refused(.notAllowed))) == [])
        #expect(state.stage == .ask)
    }
}
