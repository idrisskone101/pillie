//
//  BlockingRehearsalState.swift
//  Pillie
//
//  The whole journey on the open blocking step as one value: three beats, the
//  ask, Apple's refusal, her picks. Events go in, effects come out. Time enters
//  as "the wait you asked for ran out", so every path runs without a clock.
//

import Foundation

struct BlockingRehearsalState: Equatable {
    /// What is on screen. nil until `.appeared` brings the opening facts.
    var stage: BlockingRehearsalStage? {
        switch position {
        case .unopened: nil
        case .reminder: .reminder
        case .paused: .paused
        case .shake: .shake
        case .ask: .ask
        case .refused: .refused
        case .picks: .picks
        }
    }

    /// Who played the beat on screen while its exit motion runs. The phone card
    /// draws the hand tap and the self-pressing button only for `.demo`.
    var resolvedBy: BlockingRehearsalPlayer? {
        switch position {
        case .reminder(.leaving(let player)), .paused(.leaving(let player)): player
        default: nil
        }
    }

    /// Apple's prompt is up. The primary shows a spinner and ignores taps.
    var isRequesting: Bool {
        switch position {
        case .ask(let requesting), .refused(_, let requesting), .picks(let requesting): requesting
        default: false
        }
    }

    var refusal: ScreenTimeRefusal? {
        if case .refused(let refusal, _) = position { return refusal }
        return nil
    }

    var playsShakeClip: Bool {
        position == .shake(.popping) || position == .shake(.popped)
    }

    var listensForShake: Bool {
        position == .shake(.waiting)
    }

    /// The wait the view should run now. The view sleeps for its duration in a
    /// `.task(id:)` and sends it back with `.timerFired`.
    var timer: BlockingRehearsalTimer? {
        switch position {
        case .reminder(.waiting): selfPlays ? .selfPlay(.reminder) : nil
        case .paused(.waiting): selfPlays ? .selfPlay(.paused) : nil
        case .shake(.waiting): selfPlays ? .selfPlay(.shake) : nil
        case .reminder(.leaving(let player)): .appPressed(by: player)
        case .paused(.leaving(let player)): .coralSpreads(by: player)
        case .shake(.popped): .settleAfterPop
        case .unopened, .shake(.popping), .ask, .refused, .picks: nil
        }
    }

    private enum BeatPhase: Equatable {
        case waiting
        case leaving(by: BlockingRehearsalPlayer)
    }

    private enum ShakePhase: Equatable {
        case waiting
        case popping
        case popped
    }

    private enum Position: Equatable {
        case unopened
        case reminder(BeatPhase)
        case paused(BeatPhase)
        case shake(ShakePhase)
        case ask(requesting: Bool)
        case refused(ScreenTimeRefusal, requesting: Bool)
        case picks(requesting: Bool)
    }

    private var position: Position = .unopened
    private(set) var isAuthorized = false
    private var hasSelection = false
    private var voiceOverRunning = false
    private var sceneActive = true

    private var selfPlays: Bool {
        !voiceOverRunning && sceneActive
    }

    /// Total: every event is legal in every position. One that does not apply
    /// returns `[]` and changes nothing.
    mutating func handle(_ event: BlockingRehearsalEvent) -> [BlockingRehearsalEffect] {
        switch event {
        case .appeared(let opening):
            guard position == .unopened else { return [] }
            hasSelection = opening.hasSelection
            isAuthorized = opening.isAuthorized
            voiceOverRunning = opening.voiceOverRunning
            if opening.hasSelection {
                return enter(.picks(requesting: false))
            }
            return enter(opening.demoSeen ? .ask(requesting: false) : .reminder(.waiting))

        case .beatControlTapped:
            return play(by: .herTap)

        case .shaken:
            guard position == .shake(.waiting) else { return [] }
            return play(by: .herShake)

        case .greyedAppTapped:
            return position == .paused(.waiting) ? [.nudgePauseCard] : []

        case .shakeClipFinished:
            guard position == .shake(.popping) else { return [] }
            position = .shake(.popped)
            return []

        case .timerFired(let fired):
            guard fired == timer else { return [] }
            switch fired {
            case .selfPlay:
                return play(by: .demo)
            case .appPressed:
                return enter(.paused(.waiting))
            case .coralSpreads:
                return enter(.shake(.waiting))
            case .settleAfterPop:
                return [.persistDemoSeen] + enter(restingPosition)
            }

        case .chooseTapped:
            return requestAccess()

        case .continueTapped:
            guard position == .picks(requesting: false) else { return [] }
            return isAuthorized ? [.saveAndContinue] : requestAccess()

        case .remindersOnlyTapped:
            guard case .refused(_, requesting: false) = position else { return [] }
            return [.report(.refusalAnswered(.remindersOnly)), .useRemindersOnly]

        case .authorizationResolved(let outcome):
            guard isRequesting else { return [] }
            switch outcome {
            case .granted:
                isAuthorized = true
                if case .refused = position {
                    return enter(restingPosition) + [.presentPicker]
                }
                position = restingPosition
                return [.presentPicker]
            case .refused(let refusal):
                isAuthorized = false
                return enter(.refused(refusal, requesting: false))
            }

        case .selectionChanged(let hasSelection):
            self.hasSelection = hasSelection
            switch position {
            case .ask(let requesting) where hasSelection:
                return enter(.picks(requesting: requesting))
            case .picks(let requesting) where !hasSelection:
                return enter(.ask(requesting: requesting))
            default:
                return []
            }

        case .authorizationChanged(let isAuthorized):
            self.isAuthorized = isAuthorized
            return []

        case .voiceOverChanged(let isRunning):
            voiceOverRunning = isRunning
            return []

        case .sceneActivityChanged(let isActive):
            sceneActive = isActive
            return []
        }
    }

    /// Where the journey rests once the beats are over or Apple said yes.
    private var restingPosition: Position {
        hasSelection ? .picks(requesting: false) : .ask(requesting: false)
    }

    private mutating func enter(_ next: Position) -> [BlockingRehearsalEffect] {
        position = next
        return stage.map { [.report(.viewed($0))] } ?? []
    }

    private mutating func play(by player: BlockingRehearsalPlayer) -> [BlockingRehearsalEffect] {
        switch position {
        case .reminder(.waiting):
            position = .reminder(.leaving(by: player))
            return [.report(.played(.reminder, by: player))]
        case .paused(.waiting):
            position = .paused(.leaving(by: player))
            return [.report(.played(.paused, by: player))]
        case .shake(.waiting):
            position = .shake(.popping)
            return [.report(.played(.shake, by: player))]
        default:
            return []
        }
    }

    /// "Choose what to pause", "Try again" and "Change" all mean the same
    /// thing: make sure Screen Time is allowed, then open the picker.
    private mutating func requestAccess() -> [BlockingRehearsalEffect] {
        switch position {
        case .ask(requesting: false):
            position = .ask(requesting: true)
            return [.authorize]
        case .picks(requesting: false):
            position = .picks(requesting: true)
            return [.authorize]
        case .refused(let refusal, requesting: false):
            position = .refused(refusal, requesting: true)
            return [.report(.refusalAnswered(.askAgain)), .authorize]
        default:
            return []
        }
    }
}

/// One case per Paper frame (A5 is Apple's alert, so it has none).
enum BlockingRehearsalStage: String, CaseIterable, Equatable {
    case reminder
    case paused
    case shake
    case ask
    case refused
    case picks

    var isBeat: Bool { self == .reminder || self == .paused || self == .shake }
}

/// The three stages that play themselves when she waits.
enum BlockingRehearsalBeat: String, CaseIterable, Hashable {
    case reminder
    case paused
    case shake
}

enum BlockingRehearsalPlayer: Hashable {
    case herTap
    case herShake
    case demo
}

/// What Apple's Screen Time prompt decided.
enum ScreenTimeAuthorizationOutcome: Equatable {
    case granted
    case refused(ScreenTimeRefusal)
}

/// A wait the view runs on the state's behalf.
enum BlockingRehearsalTimer: Hashable {
    /// Nobody touched the beat, so the demo plays it for her.
    case selfPlay(BlockingRehearsalBeat)
    /// A1's exit: the featured app presses in and opens.
    case appPressed(by: BlockingRehearsalPlayer)
    /// A2's exit: coral spreads from "Open Pillie" until it covers the screen.
    case coralSpreads(by: BlockingRehearsalPlayer)
    /// A3's exit: the pill popped, hold, then pull the coral back.
    case settleAfterPop

    var duration: Duration {
        switch self {
        case .selfPlay(.reminder): .milliseconds(3500)
        case .selfPlay(.paused): .seconds(3)
        case .selfPlay(.shake): .seconds(4)
        // The demo's hand travels and taps before the press everyone sees.
        case .appPressed(by: .demo): .milliseconds(900)
        case .appPressed: .milliseconds(450)
        case .coralSpreads(by: .demo): .milliseconds(700)
        case .coralSpreads: .milliseconds(500)
        case .settleAfterPop: .milliseconds(500)
        }
    }
}

/// The facts the screen opens with. Each is kept current afterwards by its own
/// event, sent from the system bridge that owns it.
struct BlockingRehearsalOpening: Equatable {
    var demoSeen: Bool
    var hasSelection: Bool
    var isAuthorized: Bool
    var voiceOverRunning: Bool
}

enum BlockingRehearsalEvent: Equatable {
    case appeared(BlockingRehearsalOpening)

    /// The beat's main control: the featured app or the banner (A1),
    /// "Open Pillie" (A2), "Tap to check in instead" (A3).
    case beatControlTapped
    case shaken
    case greyedAppTapped
    case shakeClipFinished
    case timerFired(BlockingRehearsalTimer)

    /// "Choose what to pause" (A4), "Try again" (A7), "Change" (A6).
    case chooseTapped
    case continueTapped
    case remindersOnlyTapped
    case authorizationResolved(ScreenTimeAuthorizationOutcome)

    case selectionChanged(hasSelection: Bool)
    case authorizationChanged(isAuthorized: Bool)
    case voiceOverChanged(isRunning: Bool)
    case sceneActivityChanged(isActive: Bool)
}

/// One-shot work for the view to carry out, in order.
enum BlockingRehearsalEffect: Equatable {
    case nudgePauseCard
    case persistDemoSeen
    /// Ask Apple, then send the answer back as `.authorizationResolved`.
    case authorize
    case presentPicker
    case saveAndContinue
    case useRemindersOnly
    case report(BlockingRehearsalSignal)
}

enum BlockingRehearsalSignal: Equatable {
    enum RefusalAnswer: Equatable {
        case askAgain
        case remindersOnly
    }

    case viewed(BlockingRehearsalStage)
    case played(BlockingRehearsalBeat, by: BlockingRehearsalPlayer)
    case refusalAnswered(RefusalAnswer)
}
