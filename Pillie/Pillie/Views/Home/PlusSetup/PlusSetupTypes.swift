//
//  PlusSetupTypes.swift
//  Pillie
//
//  ENG-135: the Reverse Trial's setup duty on Today. The strip and the setup
//  sheet read one derived progress value; the sheet walks a step machine.
//

import Foundation

/// The Plus features the trial asks a user to set up, in sheet order.
enum PlusSetupStep: String, CaseIterable, Hashable {
    case blocking
    case messages
    case reminders

    var titleKey: String { "plus_setup.tab.\(rawValue)" }
}

/// Which steps are done, derived from live settings on every read and never
/// persisted, so turning blocking off or clearing messages reopens a step.
struct PlusSetupProgress: Equatable {
    /// Set once the user reaches Done. Hides the strip even with steps skipped.
    static let finishedStorageKey = "plusSetupFinished"

    let completed: Set<PlusSetupStep>

    init(completed: Set<PlusSetupStep>) {
        self.completed = completed
    }

    /// `blockingActive` is the same signal the trial badge reads for "Plus is
    /// on", so the strip and the badge can never disagree about blocking.
    init(blockingActive: Bool, messagesCustomized: Bool, retryLimit: Int) {
        var completed: Set<PlusSetupStep> = []
        if blockingActive { completed.insert(.blocking) }
        if messagesCustomized { completed.insert(.messages) }
        if retryLimit > 0 { completed.insert(.reminders) }
        self.completed = completed
    }

    var completedCount: Int { completed.count }
    var total: Int { PlusSetupStep.allCases.count }
    var isComplete: Bool { completedCount == total }
    var firstIncomplete: PlusSetupStep? {
        PlusSetupStep.allCases.first { !completed.contains($0) }
    }

    func isDone(_ step: PlusSetupStep) -> Bool {
        completed.contains(step)
    }

    func showsStrip(inTrial: Bool, finished: Bool) -> Bool {
        inTrial && !finished && !isComplete
    }

    static func live(
        store: PillStore,
        blocking: AppBlockingManager = .shared
    ) -> PlusSetupProgress {
        PlusSetupProgress(
            blockingActive: blocking.authorizationStatus == .approved
                && blocking.isEffectivelyOn,
            messagesCustomized: [
                store.customDueReminderTitle,
                store.customDueReminderBody,
                store.customRetryReminderTitle,
                store.customRetryReminderBody,
            ].contains { CustomReminderCopy.isCustomized($0) },
            retryLimit: store.autoReminderRetryLimit
        )
    }
}

/// Where the setup sheet is. Every exit from a step (Skip, a finished editor,
/// Save) goes through `next(after:)`, so the order lives in one place.
enum PlusSetupSheetStep: Equatable {
    case step(PlusSetupStep)
    case done

    static func opening(for progress: PlusSetupProgress) -> PlusSetupSheetStep {
        progress.firstIncomplete.map(PlusSetupSheetStep.step) ?? .done
    }

    static func next(after step: PlusSetupStep) -> PlusSetupSheetStep {
        let steps = PlusSetupStep.allCases
        guard let index = steps.firstIndex(of: step), index + 1 < steps.endIndex else {
            return .done
        }
        return .step(steps[index + 1])
    }
}

/// One run of the localized reminders sentence: plain words, or the slot a
/// menu chip fills.
enum PlusSetupSentencePart: Equatable {
    case text(String)
    case interval
    case repeats
}

enum PlusSetupSentence {
    /// Splits `plus_setup.reminders.sentence` at its placeholders so each
    /// locale keeps its own word order. `%1$@` is the interval chip and `%2$@`
    /// the repeats chip; bare `%@` counts up in reading order.
    static func parts(of format: String) -> [PlusSetupSentencePart] {
        var parts: [PlusSetupSentencePart] = []
        var cursor = format.startIndex
        var nextImplicitSlot = 1

        func appendText(_ range: Range<String.Index>) {
            let text = format[range].trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { parts.append(.text(text)) }
        }

        for match in format.matches(of: /%(?:([0-9]+)\$)?@/) {
            appendText(cursor..<match.range.lowerBound)
            let slot = match.output.1.flatMap { Int($0) } ?? nextImplicitSlot
            nextImplicitSlot = slot + 1
            parts.append(slot == 1 ? .interval : .repeats)
            cursor = match.range.upperBound
        }
        appendText(cursor..<format.endIndex)
        return parts
    }
}
