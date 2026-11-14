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

    var resolvedBy: BlockingRehearsalPlayer? {
        switch position {
        case .reminder(.leaving(let player)), .paused(.leaving(let player)): player
        default: nil
        }
    }

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

    #if DEBUG
    /// A debug-seeded beat holds still for screenshots unless `selfPlay=on`.
    private var holdsBeats = false
    #endif

    private var selfPlays: Bool {
        #if DEBUG
        if holdsBeats { return false }
        #endif
        return !voiceOverRunning && sceneActive
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
            sceneActive = opening.sceneActive
            #if DEBUG
            if let seed = opening.debugSeed {
                return jump(to: seed)
            }
            #endif
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
            switch position {
            case .refused(_, requesting: false):
                return [.report(.choseRemindersOnly(on: .refused)), .useRemindersOnly]
            // Once Screen Time is allowed, Apple's prompt is no longer a way to
            // say no, so the ask needs its own.
            case .ask(requesting: false) where isAuthorized:
                return [.report(.choseRemindersOnly(on: .ask)), .useRemindersOnly]
            default:
                return []
            }

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

        #if DEBUG
        case .debugSeeded(let seed):
            guard position != .unopened else { return [] }
            return jump(to: seed)
        #endif
        }
    }

    #if DEBUG
    private mutating func jump(to seed: BlockingRehearsalDebugSeed) -> [BlockingRehearsalEffect] {
        holdsBeats = !seed.selfPlays
        if seed.accessNotAsked { isAuthorized = false }
        switch seed.stage {
        case .reminder: return enter(.reminder(.waiting))
        case .paused: return enter(.paused(.waiting))
        case .shake: return enter(.shake(.waiting))
        case .ask: return enter(.ask(requesting: false))
        case .refused: return enter(.refused(seed.refusal, requesting: false))
        case .picks: return enter(.picks(requesting: false))
        }
    }
    #endif

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
            return [.report(.askedAgain), .authorize]
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

enum ScreenTimeAuthorizationOutcome: Equatable {
    case granted
    case refused(ScreenTimeRefusal)
}

enum BlockingRehearsalTimer: Hashable {
    case selfPlay(BlockingRehearsalBeat)
    case appPressed(by: BlockingRehearsalPlayer)
    case coralSpreads(by: BlockingRehearsalPlayer)
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

struct BlockingRehearsalOpening: Equatable {
    var demoSeen: Bool
    var hasSelection: Bool
    var isAuthorized: Bool
    var voiceOverRunning: Bool
    var sceneActive = true
    #if DEBUG
    var debugSeed: BlockingRehearsalDebugSeed?
    #endif
}

enum BlockingRehearsalEvent: Equatable {
    case appeared(BlockingRehearsalOpening)

    case beatControlTapped
    case shaken
    case greyedAppTapped
    case shakeClipFinished
    case timerFired(BlockingRehearsalTimer)

    case chooseTapped
    case continueTapped
    case remindersOnlyTapped
    case authorizationResolved(ScreenTimeAuthorizationOutcome)

    case selectionChanged(hasSelection: Bool)
    case authorizationChanged(isAuthorized: Bool)
    case voiceOverChanged(isRunning: Bool)
    case sceneActivityChanged(isActive: Bool)

    #if DEBUG
    case debugSeeded(BlockingRehearsalDebugSeed)
    #endif
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
    case viewed(BlockingRehearsalStage)
    case played(BlockingRehearsalBeat, by: BlockingRehearsalPlayer)
    case askedAgain
    case choseRemindersOnly(on: BlockingRehearsalStage)
}
