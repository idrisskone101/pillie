//
//  CalendarGrid.swift
//  Pillie
//

import SwiftUI

struct CalendarGrid: View {
    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale
    let displayedMonth: Date
    let monthSnapshots: [Int: PillScheduleSnapshot]
    var highlightedDay: Int?
    var onEditableDayActivate: ((Int) -> Void)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var calendar: Calendar {
        var value = Calendar.current
        value.locale = locale
        return value
    }

    private var weekdays: [String] {
        calendar.veryShortStandaloneWeekdaySymbols
    }

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

    init(
        displayedMonth: Date,
        monthSnapshots: [Int: PillScheduleSnapshot] = [:],
        highlightedDay: Int? = nil,
        onEditableDayActivate: ((Int) -> Void)? = nil
    ) {
        self.displayedMonth = displayedMonth
        self.monthSnapshots = monthSnapshots
        self.highlightedDay = highlightedDay
        self.onEditableDayActivate = onEditableDayActivate
    }

    private var monthID: String {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        let year = components.year ?? 0
        let monthNumber = components.month ?? 0
        return "\(year)-\(monthNumber)"
    }

    static func date(forDay day: Int, in month: Date, calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = day
        return calendar.date(from: components)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack {
                // Localized initials can repeat; the fixed weekday position is the stable identity.
                ForEach(weekdays.indices, id: \.self) { index in
                    Text(weekdays[index])
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
        let presentation = CalendarDayPresentation.resolve(
            snapshot: snapshot,
            fallbackMethod: store.pack.method,
            relation: relation(for: dayDate)
        )
        let editable = isEditable(day: day, snapshot: snapshot)

        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(
                        presentation.isPatchMethod
                            ? patchBackgroundColor(for: presentation.patchStyle)
                            : (presentation.isRingMethod
                                ? ringBackgroundColor(for: presentation.ringStyle)
                                : backgroundColor(
                                    for: presentation.visualStatus,
                                    hasContext: presentation.showVisual,
                                    isPassive: presentation.isPassiveActive
                                ))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                presentation.isPatchMethod
                                    ? patchStrokeColor(for: presentation.patchStyle)
                                    : (presentation.isRingMethod
                                        ? ringStrokeColor(for: presentation.ringStyle)
                                        : strokeColor(
                                            for: presentation.visualStatus,
                                            hasContext: presentation.showVisual,
                                            isPassive: presentation.isPassiveActive
                                        )),
                                lineWidth: presentation.isPatchMethod
                                    ? patchStrokeWidth(for: presentation.patchStyle)
                                    : (presentation.isRingMethod
                                        ? ringStrokeWidth(for: presentation.ringStyle)
                                        : defaultStrokeWidth(for: presentation))
                            )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                todayRingColor(
                                    actionType: presentation.actionType,
                                    patchStyle: presentation.patchStyle,
                                    ringStyle: presentation.ringStyle,
                                    isPatchMethod: presentation.isPatchMethod,
                                    isRingMethod: presentation.isRingMethod
                                ),
                                lineWidth: 2
                            )
                            .opacity(presentation.isToday ? 1 : 0)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(PillieTheme.coral, lineWidth: 2)
                            .opacity(highlightedDay == day ? 1 : 0)
                    )

                Text("\(day)")
                    .font(.pillie(14, weight: .medium))
                    .foregroundStyle(
                        presentation.isPatchMethod
                            ? patchTextColor(for: presentation.patchStyle)
                            : (presentation.isRingMethod
                                ? ringTextColor(for: presentation.ringStyle)
                                : textColor(for: presentation.visualStatus))
                    )
            }
            .aspectRatio(1, contentMode: .fit)

            // Indicator dot
            Circle()
                .fill(
                    presentation.isPatchMethod
                        ? patchIndicatorColor(for: presentation.patchStyle)
                        : (presentation.isRingMethod
                            ? ringIndicatorColor(for: presentation.ringStyle)
                            : eventIndicatorColor(for: presentation.actionType))
                )
                .frame(width: 6, height: 6)
                .opacity(
                    presentation.isPatchMethod
                        ? patchIndicatorOpacity(for: presentation.patchStyle)
                        : (presentation.isRingMethod
                            ? ringIndicatorOpacity(for: presentation.ringStyle)
                            : presentation.defaultIndicatorOpacity)
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayAccessibilityLabel(
            date: dayDate,
            presentation: presentation
        ))
        .accessibilityAddTraits(editable ? .isButton : [])
        .modifier(EditableDayAccessibilityID(editable: editable, id: "historyEditableDay.\(monthID).\(day)"))
        .accessibilityAction {
            guard editable else { return }
            onEditableDayActivate?(day)
        }
        .anchorPreference(key: CalendarDayHitFramesPreferenceKey.self, value: .bounds) { anchor in
            editable ? [monthID: [day: anchor]] : [:]
        }
    }

    private func isEditable(day: Int, snapshot: PillScheduleSnapshot?) -> Bool {
        guard let snapshot else { return false }
        return store.dayCorrectionOptions(for: snapshot) != nil
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

    private func dayAccessibilityLabel(
        date: Date?,
        presentation: CalendarDayPresentation
    ) -> String {
        guard let date else { return "" }
        if presentation.isFutureDay {
            return date.formatted(
                Date.FormatStyle().day().month(.wide).year().locale(locale)
            )
        }
        let status: HistoryPresentation.DayStatus
        if presentation.isBreakDay || presentation.status == .breakDay {
            status = .breakDay
        } else if presentation.status == .taken {
            status = .completed
        } else {
            status = .unlogged
        }
        return HistoryPresentation.dayAccessibilityLabel(
            date: date,
            status: status,
            locale: locale
        )
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

    private func defaultStrokeWidth(for presentation: CalendarDayPresentation) -> CGFloat {
        if presentation.showVisual &&
            (presentation.isActionDay || (presentation.isPassiveActive && presentation.visualStatus == .taken)) {
            return 1.2
        }
        return 0.8
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

#Preview {
    CalendarGrid(displayedMonth: Date())
        .padding()
        .environment(PillStore.previewStore())
}

struct CalendarDayHitFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [String: [Int: Anchor<CGRect>]] = [:]

    static func reduce(
        value: inout [String: [Int: Anchor<CGRect>]],
        nextValue: () -> [String: [Int: Anchor<CGRect>]]
    ) {
        for (monthID, dayFrames) in nextValue() {
            var merged = value[monthID] ?? [:]
            merged.merge(dayFrames) { _, latest in latest }
            value[monthID] = merged
        }
    }
}

enum CalendarDayHitTest {
    static func day(at point: CGPoint, in frames: [Int: CGRect]) -> Int? {
        frames.first { $0.value.insetBy(dx: -4, dy: -4).contains(point) }?.key
    }
}

private struct EditableDayAccessibilityID: ViewModifier {
    let editable: Bool
    let id: String

    func body(content: Content) -> some View {
        if editable {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}
