//
//  CalendarDayPresentationTests.swift
//  PillieTests
//

import XCTest
@testable import Pillie

@MainActor
final class CalendarDayPresentationTests: XCTestCase {
    override func tearDown() {
        InMemoryStoreFactory.resetClockAndDefaults()
        super.tearDown()
    }

    func testFuturePillDayHidesVisualStatusButKeepsDimmedIndicator() throws {
        let snapshot = try snapshot(
            method: .pill,
            type: .pillActive,
            status: .upcoming
        )

        let presentation = CalendarDayPresentation.resolve(
            snapshot: snapshot,
            fallbackMethod: .pill,
            relation: .future
        )

        XCTAssertEqual(presentation.visualStatus, nil)
        XCTAssertFalse(presentation.showVisual)
        XCTAssertTrue(presentation.isActionDay)
        XCTAssertEqual(presentation.defaultIndicatorOpacity, 0.4)
    }

    func testPastPatchChangeUsesTakenMissedAndUpcomingSemanticStyles() throws {
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchChange, status: .taken),
                fallbackMethod: .pill,
                relation: .past
            ).patchStyle,
            .changedTaken
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchChange, status: .missed),
                fallbackMethod: .pill,
                relation: .past
            ).patchStyle,
            .changedMissed
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchChange, status: .upcoming),
                fallbackMethod: .pill,
                relation: .today
            ).patchStyle,
            .changedUpcoming
        )
    }

    func testFuturePatchStylesSeparateChangeAppliedAndOffWeekDays() throws {
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchChange, status: .upcoming),
                fallbackMethod: .pill,
                relation: .future
            ).patchStyle,
            .plannedChange
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchActive, status: .upcoming),
                fallbackMethod: .pill,
                relation: .future
            ).patchStyle,
            .plannedApplied
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchBreak, status: .breakDay),
                fallbackMethod: .pill,
                relation: .future
            ).patchStyle,
            .plannedOffWeek
        )
    }

    func testRingPresentationStylesMissedFreeAndFutureReinsertDays() throws {
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .ring, type: .ringInsert, status: .missed),
                fallbackMethod: .pill,
                relation: .past
            ).ringStyle,
            .missed
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .ring, type: .ringBreak, status: .breakDay),
                fallbackMethod: .pill,
                relation: .today
            ).ringStyle,
            .ringFree
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .ring, type: .ringReinsert, status: .upcoming),
                fallbackMethod: .pill,
                relation: .future
            ).ringStyle,
            .plannedReinserted
        )
    }

    func testTodaysOpenRingTaskReadsAsDueUntilItIsLogged() throws {
        func todayStyle(_ type: PillDay.ActionType, _ status: PillDay.Status) throws -> CalendarRingSemanticStyle {
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .ring, type: type, status: status),
                fallbackMethod: .pill,
                relation: .today
            ).ringStyle
        }

        XCTAssertEqual(try todayStyle(.ringInsert, .upcoming), .plannedInserted)
        XCTAssertEqual(try todayStyle(.ringRemove, .upcoming), .plannedInserted)
        XCTAssertEqual(try todayStyle(.ringReinsert, .upcoming), .plannedReinserted)
        XCTAssertEqual(try todayStyle(.ringRemove, .taken), .inserted)
        XCTAssertEqual(try todayStyle(.ringReinsert, .taken), .reinserted)
        // A wearing day has nothing to log, so its open window still reads as worn.
        XCTAssertEqual(try todayStyle(.ringActive, .upcoming), .inserted)
    }

    func testUserDeclaredBreakOnPatchAndRingActiveDaysUsesOffWeekStyles() throws {
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .patch, type: .patchActive, status: .breakDay),
                fallbackMethod: .pill,
                relation: .past
            ).patchStyle,
            .offWeek
        )
        XCTAssertEqual(
            CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .ring, type: .ringInsert, status: .breakDay),
                fallbackMethod: .pill,
                relation: .past
            ).ringStyle,
            .ringFree
        )
    }

    func testMissingSnapshotFallsBackToCurrentMethodWithoutScheduleContext() {
        let presentation = CalendarDayPresentation.resolve(
            snapshot: nil,
            fallbackMethod: .ring,
            relation: .today
        )

        XCTAssertEqual(presentation.method, .ring)
        XCTAssertFalse(presentation.hasScheduleContext)
        XCTAssertEqual(presentation.ringStyle, .invalid)
        XCTAssertEqual(presentation.defaultIndicatorOpacity, 1)
    }

    // MARK: VoiceOver

    /// What VoiceOver reads for a History day, as CalendarGrid asks for it.
    private func voiceOverLabel(_ presentation: CalendarDayPresentation) -> String {
        HistoryPresentation.dayAccessibilityLabel(
            date: Self.voiceOverDate,
            status: presentation.historyStatus,
            locale: Locale(identifier: "en")
        )
    }

    private static let voiceOverDate = InMemoryStoreFactory.fixedDate("2026-06-03")

    private var voiceOverDateText: String {
        Self.voiceOverDate.formatted(Date.FormatStyle().day().month(.wide).year().locale(Locale(identifier: "en")))
    }

    func testVoiceOverNamesTodaysOpenDoseAndSugarPillToday() throws {
        for type in [PillDay.ActionType.pillActive, .pillSugar] {
            let presentation = CalendarDayPresentation.resolve(
                snapshot: try snapshot(method: .pill, type: type, status: .upcoming),
                fallbackMethod: .pill,
                relation: .today
            )

            XCTAssertEqual(voiceOverLabel(presentation), "\(voiceOverDateText): Today", "\(type)")
        }
    }

    func testVoiceOverReadsADayWithNothingRecordedByItsDateAlone() throws {
        let beforeTracking = CalendarDayPresentation.resolve(
            snapshot: try snapshot(method: .pill, type: .pillActive, status: .noData),
            fallbackMethod: .pill,
            relation: .past
        )
        let beforeAnyPack = CalendarDayPresentation.resolve(snapshot: nil, fallbackMethod: .pill, relation: .past)

        XCTAssertEqual(voiceOverLabel(beforeTracking), voiceOverDateText)
        XCTAssertEqual(voiceOverLabel(beforeAnyPack), voiceOverDateText)
    }

    func testVoiceOverStillNamesAMissedDayMissed() throws {
        let presentation = CalendarDayPresentation.resolve(
            snapshot: try snapshot(method: .pill, type: .pillActive, status: .missed),
            fallbackMethod: .pill,
            relation: .past
        )

        XCTAssertEqual(voiceOverLabel(presentation), "\(voiceOverDateText): Missed")
    }

    /// Packs backing fabricated snapshots. The Xcode 27 beta hosted-XCTest runner
    /// aborts when a @MainActor/@Observable class (which includes @Model) deallocates
    /// mid-invocation (see xcode27-beta-mainactor-deinit-crash), so every pack is
    /// retained for the process lifetime instead of being scoped to the helper.
    private static var keepAlivePacks: [PillPack] = []

    private func snapshot(
        method: ContraceptiveMethod,
        type: PillDay.ActionType,
        status: PillDay.Status
    ) throws -> PillScheduleSnapshot {
        let now = InMemoryStoreFactory.fixedDate("2026-06-03")
        // A bare, un-inserted pack is enough for presentation resolution — no
        // PillStore or ModelContainer needed (both crash the beta host when they
        // deallocate inside the test invocation).
        let pack = PillPack(
            method: method,
            pillRegimen: .twentyOneSeven,
            startDate: now,
            packNumber: 1,
            isCurrent: true
        )
        Self.keepAlivePacks.append(pack)

        let action = DoseScheduleAction(
            date: now,
            type: type,
            method: method,
            cycleDay: 1,
            cycleLength: pack.cycleLength
        )

        return PillScheduleSnapshot(
            date: now,
            pack: pack,
            cycleDayIndex: 0,
            dueAction: action,
            status: status,
            actionType: type
        )
    }
}
