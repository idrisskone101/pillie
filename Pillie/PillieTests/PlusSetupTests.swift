//
//  PlusSetupTests.swift
//  PillieTests
//
//  ENG-135 value tests: setup progress, the sheet's step machine, and the
//  reminders sentence splitter. No hosted views.
//

import Foundation
import Testing

@testable import Pillie

struct PlusSetupTests {
    // MARK: - Progress

    @Test func `default trial settings start at one of three`() {
        let progress = PlusSetupProgress(
            blockingActive: false,
            messagesCustomized: false,
            retryLimit: 3
        )

        #expect(progress.completed == [.reminders])
        #expect(progress.completedCount == 1)
        #expect(progress.total == 3)
        #expect(progress.isComplete == false)
        #expect(progress.firstIncomplete == .blocking)
    }

    @Test func `retries off leaves reminders incomplete`() {
        let progress = PlusSetupProgress(
            blockingActive: true,
            messagesCustomized: true,
            retryLimit: 0
        )

        #expect(progress.completed == [.blocking, .messages])
        #expect(progress.firstIncomplete == .reminders)
    }

    @Test func `first incomplete follows sheet order`() {
        let blockingDone = PlusSetupProgress(completed: [.blocking, .reminders])
        #expect(blockingDone.firstIncomplete == .messages)

        let all = PlusSetupProgress(completed: [.blocking, .messages, .reminders])
        #expect(all.isComplete)
        #expect(all.firstIncomplete == nil)
    }

    @Test func `strip shows only in an unfinished trial with work left`() {
        let partial = PlusSetupProgress(completed: [.reminders])
        let full = PlusSetupProgress(completed: [.blocking, .messages, .reminders])

        #expect(partial.showsStrip(inTrial: true, finished: false))
        #expect(!partial.showsStrip(inTrial: false, finished: false))
        #expect(!partial.showsStrip(inTrial: true, finished: true))
        #expect(!full.showsStrip(inTrial: true, finished: false))
    }

    // MARK: - Step machine

    @Test func `next walks blocking messages reminders then done`() {
        #expect(PlusSetupSheetStep.next(after: .blocking) == .step(.messages))
        #expect(PlusSetupSheetStep.next(after: .messages) == .step(.reminders))
        #expect(PlusSetupSheetStep.next(after: .reminders) == .done)
    }

    @Test func `skipping every step from the opening step ends in done`() {
        var current = PlusSetupSheetStep.opening(
            for: PlusSetupProgress(completed: [.reminders])
        )
        var visited: [PlusSetupSheetStep] = [current]
        while case .step(let step) = current {
            current = PlusSetupSheetStep.next(after: step)
            visited.append(current)
        }

        #expect(visited == [.step(.blocking), .step(.messages), .step(.reminders), .done])
    }

    @Test func `sheet opens at the first incomplete step or done`() {
        #expect(
            PlusSetupSheetStep.opening(for: PlusSetupProgress(completed: [.blocking]))
                == .step(.messages)
        )
        #expect(
            PlusSetupSheetStep.opening(
                for: PlusSetupProgress(completed: [.blocking, .messages, .reminders])
            ) == .done
        )
    }

    // MARK: - Sentence splitter

    @Test func `english sentence splits into words and two chips`() {
        let format = PillieLocalization.string(
            "plus_setup.reminders.sentence",
            locale: Locale(identifier: "en")
        )

        #expect(PlusSetupSentence.parts(of: format) == [
            .text("Nudge me every"),
            .interval,
            .text("up to"),
            .repeats,
            .text("until I check in."),
        ])
    }

    @Test func `reordered placeholders keep the locale word order`() {
        #expect(PlusSetupSentence.parts(of: "最大%2$@まで、%1$@ごとにお知らせします。") == [
            .text("最大"),
            .repeats,
            .text("まで、"),
            .interval,
            .text("ごとにお知らせします。"),
        ])
    }

    @Test func `bare placeholders count up in reading order`() {
        #expect(PlusSetupSentence.parts(of: "%@ then %@") == [
            .interval,
            .text("then"),
            .repeats,
        ])
    }
}
