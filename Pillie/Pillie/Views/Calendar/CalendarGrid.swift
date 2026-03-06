//
//  CalendarGrid.swift
//  Pillie
//

import SwiftUI

enum CalendarDayRelation {
    case past
    case today
    case future
}

enum CalendarPatchSemanticStyle: Equatable {
    case invalid
    case neutral
    case patchApplied
    case plannedApplied
    case changedTaken
    case changedMissed
    case changedUpcoming
    case offWeek
    case plannedChange
    case plannedOffWeek
}

enum CalendarRingSemanticStyle: Equatable {
    case invalid
    case neutral
    case inserted
    case reinserted
    case missed
    case ringFree
    case plannedInserted
    case plannedReinserted
    case plannedRingFree
}

struct CalendarGrid: View {
    @Environment(PillStore.self) private var store
    let displayedMonth: Date
    let monthSnapshots: [Int: PillScheduleSnapshot]

    private let weekdays = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private let calendar = Calendar.current

    private var year: Int {
        calendar.component(.year, from: displayedMonth)
    }

    private var month: Int {
        calendar.component(.month, from: displayedMonth)
    }

    private var firstWeekdayOffset: Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let firstDate = calendar.date(from: comps) else { return 0 }
        // Sunday = 1 in Calendar, offset = weekday - 1
        return calendar.component(.weekday, from: firstDate) - 1
    }

    private var daysInMonth: Int {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return 30 }
        return range.count
    }

    private var totalGridSlots: Int {
        let occupiedSlots = firstWeekdayOffset + daysInMonth
        return ((occupiedSlots + 6) / 7) * 7
    }

    init(displayedMonth: Date, monthSnapshots: [Int: PillScheduleSnapshot] = [:]) {
        self.displayedMonth = displayedMonth
        self.monthSnapshots = monthSnapshots
    }

    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.pillieCaption())
                        .textCase(.uppercase)
                        .foregroundStyle(PillieTheme.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<totalGridSlots, id: \.self) { slot in
                    if let day = dayForSlot(slot) {
                        dayCell(day: day)
                    } else {
                        emptyCell
                    }
                }
            }
        }
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCell(day: Int) -> some View {
        let dayDate = dateForDay(day)
        let snapshot = monthSnapshots[day] ?? dayDate.flatMap { store.scheduleSnapshot(for: $0) }
        let method = snapshot?.pack.method ?? store.pack.method
        let relation = relation(for: dayDate)
        let isPatchMethod = method == .patch
        let isRingMethod = method == .ring
        let patchStyle = isPatchMethod ? Self.patchSemanticStyle(snapshot: snapshot, relation: relation) : .invalid
        let ringStyle = isRingMethod ? Self.ringSemanticStyle(snapshot: snapshot, relation: relation) : .invalid

        let status = snapshot?.status
        let actionType = snapshot?.actionType
        let hasContext = snapshot?.hasScheduleContext ?? false
        let isActionDay = snapshot?.isDue ?? false
        let isPassive = snapshot?.isPassiveActive ?? false
        let isBreakDay = snapshot?.isBreak ?? false
        let isFutureDay = relation == .future
        let visualStatus: PillDay.Status? = isFutureDay ? nil : status
        let showVisual = !isFutureDay && hasContext
        let isToday = relation == .today

        Button {
            // tap action placeholder
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(
                            isPatchMethod
                                ? patchBackgroundColor(for: patchStyle)
                                : (isRingMethod
                                    ? ringBackgroundColor(for: ringStyle)
                                    : backgroundColor(for: visualStatus, hasContext: showVisual, isPassive: isPassive))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isPatchMethod
                                        ? patchStrokeColor(for: patchStyle)
                                        : (isRingMethod
                                            ? ringStrokeColor(for: ringStyle)
                                            : strokeColor(for: visualStatus, hasContext: showVisual, isPassive: isPassive)),
                                    lineWidth: isPatchMethod
                                        ? patchStrokeWidth(for: patchStyle)
                                        : (isRingMethod
                                            ? ringStrokeWidth(for: ringStyle)
                                            : ((showVisual && (isActionDay || (isPassive && visualStatus == .taken))) ? 1.2 : 0.8))
                                )
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    todayRingColor(
                                        actionType: actionType,
                                        patchStyle: patchStyle,
                                        ringStyle: ringStyle,
                                        isPatchMethod: isPatchMethod,
                                        isRingMethod: isRingMethod
                                    ),
                                    lineWidth: 2
                                )
                                .opacity(isToday ? 1 : 0)
                        )

                    Text("\(day)")
                        .font(.pillie(14, weight: .medium))
                        .foregroundStyle(
                            isPatchMethod
                                ? patchTextColor(for: patchStyle)
                                : (isRingMethod
                                    ? ringTextColor(for: ringStyle)
                                    : textColor(for: visualStatus))
                        )
                }
                .aspectRatio(1, contentMode: .fit)

                // Indicator dot: only prominent on action days, not passive days
                Circle()
                    .fill(
                        isPatchMethod
                            ? patchIndicatorColor(for: patchStyle)
                            : (isRingMethod ? ringIndicatorColor(for: ringStyle) : eventIndicatorColor(for: actionType))
                    )
                    .frame(width: 6, height: 6)
                    .opacity(
                        isPatchMethod
                            ? patchIndicatorOpacity(for: patchStyle)
                            : (isRingMethod
                                ? ringIndicatorOpacity(for: ringStyle)
                                : ((isToday || isActionDay || isBreakDay) ? 1 : 0))
                    )
            }
        }
        .buttonStyle(CalendarDayCellStyle())
    }

    static func patchSemanticStyle(
        snapshot: PillScheduleSnapshot?,
        relation: CalendarDayRelation
    ) -> CalendarPatchSemanticStyle {
        guard let snapshot, snapshot.hasScheduleContext, snapshot.status != .noData else {
            return .invalid
        }

        let actionType = snapshot.actionType ?? snapshot.dueAction?.type

        switch relation {
        case .future:
            switch actionType {
            case .some(.patchChange), .some(.patchRemove):
                return .plannedChange
            case .some(.patchBreak):
                return .plannedOffWeek
            case .some(.patchActive):
                return .plannedApplied
            default:
                return snapshot.status == .breakDay ? .plannedOffWeek : .neutral
            }

        case .past, .today:
            switch actionType {
            case .some(.patchBreak):
                return .offWeek
            case .some(.patchActive):
                return .patchApplied
            case .some(.patchChange), .some(.patchRemove):
                switch snapshot.status {
                case .taken:
                    return .changedTaken
                case .missed:
                    return .changedMissed
                case .upcoming:
                    return .changedUpcoming
                case .breakDay:
                    return .offWeek
                case .noData, nil:
                    return relation == .past ? .changedMissed : .changedUpcoming
                }
            default:
                return snapshot.status == .breakDay ? .offWeek : .neutral
            }
        }
    }

    static func ringSemanticStyle(
        snapshot: PillScheduleSnapshot?,
        relation: CalendarDayRelation
    ) -> CalendarRingSemanticStyle {
        guard let snapshot, snapshot.hasScheduleContext, snapshot.status != .noData else {
            return .invalid
        }

        let actionType = snapshot.actionType ?? snapshot.dueAction?.type

        switch relation {
        case .future:
            switch actionType {
            case .some(.ringBreak):
                return .plannedRingFree
            case .some(.ringReinsert):
                return .plannedReinserted
            case .some(.ringInsert), .some(.ringRemove), .some(.ringActive):
                return .plannedInserted
            default:
                return snapshot.status == .breakDay ? .plannedRingFree : .neutral
            }

        case .past, .today:
            if snapshot.status == .missed {
                return .missed
            }
            switch actionType {
            case .some(.ringBreak):
                return .ringFree
            case .some(.ringReinsert):
                return .reinserted
            case .some(.ringInsert), .some(.ringRemove), .some(.ringActive):
                return .inserted
            default:
                return snapshot.status == .breakDay ? .ringFree : .neutral
            }
        }
    }

    // MARK: - Status Lookup

    private func dateForDay(_ day: Int) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)
    }

    private func dayForSlot(_ slot: Int) -> Int? {
        let day = slot - firstWeekdayOffset + 1
        guard day >= 1 && day <= daysInMonth else { return nil }
        return day
    }

    private func relation(for date: Date?) -> CalendarDayRelation {
        guard let date else { return .past }
        let day = calendar.startOfDay(for: date)
        if calendar.isDate(day, inSameDayAs: store.today) {
            return .today
        }
        return day < store.today ? .past : .future
    }

    private var emptyCell: some View {
        VStack(spacing: 2) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
            Circle()
                .fill(Color.clear)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Colors

    private func patchBackgroundColor(for style: CalendarPatchSemanticStyle) -> Color {
        switch style {
        case .changedTaken:
            return PillieTheme.sage
        case .changedMissed:
            return PillieTheme.amber
        case .changedUpcoming:
            return PillieTheme.patchChangeRose.opacity(0.18)
        case .offWeek:
            return PillieTheme.lavender
        case .patchApplied:
            return PillieTheme.sage
        case .plannedChange:
            return PillieTheme.patchChangeRose.opacity(0.12)
        case .invalid, .neutral, .plannedApplied, .plannedOffWeek:
            return .clear
        }
    }

    private func patchTextColor(for style: CalendarPatchSemanticStyle) -> Color {
        switch style {
        case .changedMissed:
            return .white
        case .changedTaken, .changedUpcoming, .offWeek, .neutral, .patchApplied, .plannedChange:
            return PillieTheme.textPrimary
        case .invalid, .plannedOffWeek, .plannedApplied:
            return PillieTheme.textMuted
        }
    }

    private func patchStrokeColor(for style: CalendarPatchSemanticStyle) -> Color {
        switch style {
        case .changedTaken:
            return PillieTheme.sageHalf
        case .changedUpcoming:
            return PillieTheme.patchChangeRose.opacity(0.35)
        case .changedMissed:
            return PillieTheme.amberFaded
        case .offWeek:
            return PillieTheme.lavender
        case .patchApplied:
            return PillieTheme.sageHalf
        case .plannedChange:
            return PillieTheme.patchChangeRose.opacity(0.3)
        case .invalid, .neutral, .plannedApplied, .plannedOffWeek:
            return .clear
        }
    }

    private func patchStrokeWidth(for style: CalendarPatchSemanticStyle) -> CGFloat {
        switch style {
        case .changedTaken, .changedMissed, .changedUpcoming, .plannedChange, .patchApplied:
            return 1.2
        case .invalid, .neutral, .plannedApplied, .offWeek, .plannedOffWeek:
            return 0.8
        }
    }

    private func patchIndicatorColor(for style: CalendarPatchSemanticStyle) -> Color {
        switch style {
        case .changedTaken, .changedUpcoming, .plannedChange:
            return PillieTheme.patchChangeRose
        case .patchApplied, .plannedApplied:
            return PillieTheme.coral
        case .changedMissed:
            return PillieTheme.amber
        case .offWeek, .plannedOffWeek:
            return PillieTheme.lavender
        case .invalid, .neutral:
            return .clear
        }
    }

    private func patchIndicatorOpacity(for style: CalendarPatchSemanticStyle) -> Double {
        switch style {
        case .changedTaken, .changedMissed, .changedUpcoming, .offWeek, .patchApplied:
            return 1
        case .plannedChange, .plannedOffWeek, .plannedApplied:
            return 0.45
        case .invalid, .neutral:
            return 0
        }
    }

    private func ringBackgroundColor(for style: CalendarRingSemanticStyle) -> Color {
        switch style {
        case .inserted:
            return PillieTheme.sage
        case .reinserted:
            return PillieTheme.sage
        case .missed:
            return PillieTheme.amber
        case .ringFree:
            return PillieTheme.lavender
        case .plannedReinserted:
            return PillieTheme.ringReinsertCoral.opacity(0.12)
        case .invalid, .neutral, .plannedInserted, .plannedRingFree:
            return .clear
        }
    }

    private func ringStrokeColor(for style: CalendarRingSemanticStyle) -> Color {
        switch style {
        case .inserted:
            return PillieTheme.sageHalf
        case .reinserted:
            return PillieTheme.sageHalf
        case .missed:
            return PillieTheme.amberFaded
        case .ringFree:
            return PillieTheme.lavender
        case .plannedReinserted:
            return PillieTheme.ringReinsertCoral.opacity(0.3)
        case .invalid, .neutral, .plannedInserted, .plannedRingFree:
            return .clear
        }
    }

    private func ringStrokeWidth(for style: CalendarRingSemanticStyle) -> CGFloat {
        switch style {
        case .inserted, .reinserted, .missed, .plannedReinserted:
            return 1.2
        case .invalid, .neutral, .plannedInserted, .ringFree, .plannedRingFree:
            return 0.8
        }
    }

    private func ringTextColor(for style: CalendarRingSemanticStyle) -> Color {
        switch style {
        case .missed:
            return .white
        case .inserted, .reinserted, .ringFree, .neutral, .plannedReinserted:
            return PillieTheme.textPrimary
        case .invalid, .plannedInserted, .plannedRingFree:
            return PillieTheme.textMuted
        }
    }

    private func ringIndicatorColor(for style: CalendarRingSemanticStyle) -> Color {
        switch style {
        case .inserted, .plannedInserted:
            return PillieTheme.coral
        case .reinserted, .plannedReinserted:
            return PillieTheme.ringReinsertCoral
        case .missed:
            return PillieTheme.amber
        case .ringFree, .plannedRingFree:
            return PillieTheme.lavender
        case .invalid, .neutral:
            return .clear
        }
    }

    private func ringIndicatorOpacity(for style: CalendarRingSemanticStyle) -> Double {
        switch style {
        case .inserted, .reinserted, .missed, .ringFree:
            return 1
        case .plannedInserted, .plannedReinserted, .plannedRingFree:
            return 0.45
        case .invalid, .neutral:
            return 0
        }
    }

    private func todayRingColor(
        actionType: PillDay.ActionType?,
        patchStyle: CalendarPatchSemanticStyle,
        ringStyle: CalendarRingSemanticStyle,
        isPatchMethod: Bool,
        isRingMethod: Bool
    ) -> Color {
        if isPatchMethod {
            switch patchStyle {
            case .offWeek, .plannedOffWeek:
                return PillieTheme.lavender
            case .changedTaken, .changedMissed, .changedUpcoming, .plannedChange:
                return PillieTheme.patchChangeRose
            default:
                return PillieTheme.coral
            }
        }
        if isRingMethod {
            switch ringStyle {
            case .ringFree, .plannedRingFree:
                return PillieTheme.lavender
            case .reinserted, .plannedReinserted:
                return PillieTheme.ringReinsertCoral
            default:
                return PillieTheme.coral
            }
        }
        return actionType?.isBreakType == true ? PillieTheme.lavender : PillieTheme.coral
    }

    private func backgroundColor(for status: PillDay.Status?, hasContext: Bool, isPassive: Bool) -> Color {
        guard hasContext else { return Color.clear }

        if isPassive {
            switch status {
            case .taken:
                return PillieTheme.sage
            case .upcoming:
                return PillieTheme.sage.opacity(0.30)
            default:
                return PillieTheme.sage.opacity(0.35)
            }
        }

        switch status {
        case .taken:
            return PillieTheme.sage
        case .missed:
            return PillieTheme.amber
        case .breakDay:
            return PillieTheme.lavender
        case .upcoming:
            return PillieTheme.sage.opacity(0.22)
        case .noData, nil:
            return Color.clear
        }
    }

    private func textColor(for status: PillDay.Status?) -> Color {
        switch status {
        case .missed:
            return .white
        case .taken:
            return PillieTheme.textPrimary
        case .breakDay:
            return PillieTheme.textPrimary
        case .upcoming:
            return PillieTheme.textPrimary
        case .noData, nil:
            return PillieTheme.textMuted
        }
    }

    private func strokeColor(for status: PillDay.Status?, hasContext: Bool, isPassive: Bool) -> Color {
        guard hasContext else { return .clear }

        if isPassive {
            return PillieTheme.sageHalf
        }

        switch status {
        case .taken:
            return PillieTheme.sageHalf
        case .missed:
            return PillieTheme.amberFaded
        case .breakDay:
            return PillieTheme.lavender
        case .noData:
            return .clear
        case .upcoming, nil:
            return PillieTheme.sageHalf
        }
    }

    private func eventIndicatorColor(for actionType: PillDay.ActionType?) -> Color {
        switch actionType {
        case .pillActive:
            return PillieTheme.coral
        case .pillBreak:
            return PillieTheme.lavender
        case .patchChange, .patchRemove:
            return PillieTheme.sage
        case .patchActive:
            return .clear
        case .patchBreak:
            return PillieTheme.lavender
        case .ringInsert, .ringRemove:
            return PillieTheme.textPrimary
        case .ringReinsert:
            return .clear
        case .ringActive:
            return .clear
        case .ringBreak:
            return PillieTheme.textMuted.opacity(0.5)
        case nil:
            return .clear
        }
    }
}

// MARK: - Calendar Day Cell Button Style

private struct CalendarDayCellStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    CalendarGrid(displayedMonth: Date())
        .padding()
        .environment(PillStore.previewStore())
}
