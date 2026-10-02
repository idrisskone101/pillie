//
//  PackCard.swift
//  Pillie
//

import SwiftUI

/// Callers change `todayIndex` / `marks` and the card plays the pop cascade. Haptics are the caller's.
struct PackCard<Header: View>: View {
    let regimen: PackRegimen
    /// Calendar weekday (1 = Sunday) of day index 0. nil while the start day is unknown,
    /// which keeps the weekday row's space but shows no names.
    let dayOneWeekday: Int?
    let todayIndex: Int?
    let marks: [Int: PackTileMark]
    let onSelectDay: ((Int) -> Void)?
    let onSelectMissedDay: ((Int) -> Void)?
    let header: Header

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.locale) private var locale

    /// What the tiles show right now. nil until the first render settles on the inputs.
    @State private var displayed: [PackTileState]?
    @State private var crunching: Set<Int> = []
    /// nil follows today's page.
    @State private var chosenPage: Int?
    @State private var pageForward = true
    @State private var gridWidth: CGFloat = 330

    init(
        regimen: PackRegimen,
        dayOneWeekday: Int?,
        todayIndex: Int?,
        marks: [Int: PackTileMark] = [:],
        onSelectDay: ((Int) -> Void)? = nil,
        onSelectMissedDay: ((Int) -> Void)? = nil,
        @ViewBuilder header: () -> Header
    ) {
        self.regimen = regimen
        self.dayOneWeekday = dayOneWeekday
        self.todayIndex = todayIndex
        self.marks = marks
        self.onSelectDay = onSelectDay
        self.onSelectMissedDay = onSelectMissedDay
        self.header = header()
    }

    private var flagIndex: Int? {
        onSelectDay != nil ? todayIndex : nil
    }

    private var layout: PackCardLayout {
        PackCardLayout(regimen: regimen, todayIndex: todayIndex, marks: marks)
    }

    private var viewedPage: Int {
        min(chosenPage ?? layout.todayPage, layout.pageCount - 1)
    }

    private var tileSide: CGFloat {
        let columns = CGFloat(PackCardLayout.daysPerWeek)
        return (gridWidth - Self.columnGap * (columns - 1)) / columns
    }

    private var pageHeight: CGFloat {
        let rows = CGFloat(PackCardLayout.weeksPerPage)
        return tileSide * rows + Self.rowGap * (rows - 1)
    }

    private static var columnGap: CGFloat { 6 }
    private static var rowGap: CGFloat { 7 }

    var body: some View {
        let layout = layout
        VStack(spacing: Self.rowGap) {
            header
                .padding(.top, 2)
                .padding(.horizontal, 2)
                .padding(.bottom, 10)

            if layout.showsPager {
                PackCardPager(
                    tones: layout.trackTones(viewedPage: viewedPage),
                    label: layout.pageLabel(forPage: viewedPage),
                    canGoBack: viewedPage > 0,
                    canGoForward: viewedPage < layout.pageCount - 1,
                    onStep: step
                )
            }

            weekdayRow

            grid(layout: layout, states: displayed ?? layout.states)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .background(
            RoundedRectangle(cornerRadius: PillieTheme.cardRadius, style: .continuous)
                .fill(PillieTheme.cardWhite)
                .shadow(color: PillieTheme.cardShadow, radius: PillieTheme.cardShadowRadius, y: PillieTheme.cardShadowY)
        )
        .task(id: layout) {
            await play(to: layout.states)
        }
        .onChange(of: layout.todayPage) {
            chosenPage = nil
        }
    }

    // MARK: Weekdays

    private var weekdayRow: some View {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.shortStandaloneWeekdaySymbols
        return HStack(spacing: Self.columnGap) {
            ForEach(0..<PackCardLayout.daysPerWeek, id: \.self) { column in
                Text(symbols[((dayOneWeekday ?? 1) - 1 + column) % PackCardLayout.daysPerWeek].uppercased(with: locale))
                    .contentTransition(.opacity)
                    .font(.pillie(11, weight: .semibold))
                    .tracking(11 * 0.06)
                    .foregroundStyle(PackCardColor.weekday)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, minHeight: 14)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.bottom, 2)
        .opacity(dayOneWeekday == nil ? 0 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: dayOneWeekday)
        .accessibilityHidden(true)
    }

    // MARK: Grid

    private func grid(layout: PackCardLayout, states: [PackTileState]) -> some View {
        // The outgoing and incoming pages overlap while paging, so they share a ZStack.
        ZStack(alignment: .top) {
            VStack(spacing: Self.rowGap) {
                ForEach(layout.rows(onPage: viewedPage), id: \.lowerBound) { row in
                    HStack(spacing: Self.columnGap) {
                        ForEach(0..<PackCardLayout.daysPerWeek, id: \.self) { column in
                            let index = row.lowerBound + column
                            if row.contains(index) {
                                tile(at: index, state: states[index])
                            } else {
                                Color.clear.frame(width: tileSide, height: tileSide)
                            }
                        }
                    }
                }
            }
            .id(viewedPage)
            .transition(.push(from: pageForward == (layoutDirection == .leftToRight) ? .trailing : .leading))
        }
        // A short last page keeps the full page height so paging never shifts the screen below the card.
        .frame(
            maxWidth: .infinity,
            minHeight: layout.showsPager ? pageHeight : nil,
            alignment: .top
        )
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { gridWidth = $0 }
        // Clip at the card edge, not the grid edge, so rings, badges, and glows keep their overflow.
        .padding(16)
        .clipped()
        .padding(-16)
        .overlay {
            flag(layout: layout)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.2), value: flagIndex)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(pageSwipe, including: layout.showsPager ? .all : .subviews)
    }

    @ViewBuilder
    private func tile(at index: Int, state: PackTileState) -> some View {
        let day = regimen.day(atIndex: index)
        let face = PackTile(kind: day.kind, state: state, isCrunching: crunching.contains(index))
            .scaleEffect(tileSide / PackTile.designSide)
            .frame(width: tileSide, height: tileSide)
        if let onSelectDay {
            tileButton(face, day: day, state: state) { onSelectDay(index) }
                .accessibilityAddTraits(index == flagIndex ? .isSelected : [])
        } else if state == .missed, let onSelectMissedDay {
            tileButton(face, day: day, state: state) { onSelectMissedDay(index) }
                .accessibilityHint(PillieLocalization.string("history.dayCorrection.accessibilityHint", locale: locale))
        } else {
            face
                .tileAccessibility(label: accessibilityLabel(for: day), value: accessibilityValue(for: day.kind, state: state))
        }
    }

    private static var minimumHitSide: CGFloat { 44 }

    private func tileButton(
        _ face: some View, day: PackDay, state: PackTileState, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { face }
            .buttonStyle(PackTilePressStyle(reduceMotion: reduceMotion))
            .contentShape(Rectangle().inset(by: -max(0, (Self.minimumHitSide - tileSide) / 2)))
            .tileAccessibility(label: accessibilityLabel(for: day), value: accessibilityValue(for: day.kind, state: state))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .accessibilityIdentifier("packTile.\(day.pillNumber ?? day.number)")
    }

    @ViewBuilder
    private func flag(layout: PackCardLayout) -> some View {
        if let flagIndex, layout.dayIndices(onPage: viewedPage).contains(flagIndex) {
            let slot = flagIndex - viewedPage * PackCardLayout.daysPerPage
            let column = CGFloat(slot % PackCardLayout.daysPerWeek)
            let row = CGFloat(slot / PackCardLayout.daysPerWeek)
            let day = regimen.day(atIndex: flagIndex)
            PackFlag(number: day.pillNumber ?? day.number)
                .position(
                    x: column * (tileSide + Self.columnGap) + tileSide / 2,
                    y: row * (tileSide + Self.rowGap) - Self.flagLift - PackFlag.height / 2
                )
                .transition(.offset(y: reduceMotion ? 0 : -8).combined(with: .opacity))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private static var flagLift: CGFloat { 7 }

    // MARK: Paging

    private var pageSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 40, abs(dx) > abs(value.translation.height) else { return }
                let towardsEnd = (dx < 0) == (layoutDirection == .leftToRight)
                step(towardsEnd ? 1 : -1)
            }
    }

    private func step(_ delta: Int) {
        let page = min(max(viewedPage + delta, 0), layout.pageCount - 1)
        guard page != viewedPage else { return }
        pageForward = delta > 0
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0)) {
            chosenPage = page
        }
    }

    // MARK: Pop cascade

    private func play(to target: [PackTileState]) async {
        crunching = []
        guard let current = displayed, current.count == target.count else {
            displayed = target
            return
        }
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) { displayed = target }
            return
        }
        var elapsed = Duration.zero
        for step in PackPopSequence.steps(from: current, to: target, regimen: regimen, visible: layout.dayIndices(onPage: viewedPage)) {
            if step.at > elapsed {
                try? await Task.sleep(for: step.at - elapsed)
                elapsed = step.at
            }
            guard !Task.isCancelled else { return }
            apply(step)
        }
    }

    private func apply(_ step: PackPopSequence.Step) {
        switch step.change {
        case .crunch:
            crunching.insert(step.index)
        case .settle(let state):
            withAnimation(state == .logged ? .spring(duration: 0.35, bounce: 0.35) : .easeOut(duration: 0.2)) {
                displayed?[step.index] = state
                crunching.remove(step.index)
            }
        }
    }

    // MARK: Accessibility

    private func accessibilityLabel(for day: PackDay) -> String {
        switch day.kind {
        case .active:
            return PillieLocalization.formatted("pack_card.tile.pill", locale: locale, arguments: day.number)
        case .sugarPill:
            return PillieLocalization.formatted("pack_card.tile.sugar_pill", locale: locale, arguments: day.number)
        case .noPill:
            return PillieLocalization.formatted(
                "pack_card.tile.break_day", locale: locale, arguments: day.number - regimen.activeDays
            )
        }
    }

    private func accessibilityValue(for kind: PackDay.Kind, state: PackTileState) -> String {
        if kind == .noPill {
            return state == .today ? PillieLocalization.string("pack_card.tile.state.today", locale: locale) : ""
        }
        let key = switch state {
        case .sealed: "pack_card.tile.state.sealed"
        case .popped: "pack_card.tile.state.taken"
        case .today: "pack_card.tile.state.today"
        case .logged: "pack_card.tile.state.taken_today"
        case .late: "pack_card.tile.state.late"
        case .missed: "pack_card.tile.state.missed"
        }
        return PillieLocalization.string(key, locale: locale)
    }
}

private extension View {
    func tileAccessibility(label: String, value: String) -> some View {
        contentShape(.accessibility, Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
    }
}

private struct PackTilePressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.4), value: configuration.isPressed)
    }
}

private struct PackFlag: View {
    static let height: CGFloat = 29

    let number: Int

    var body: some View {
        VStack(spacing: 0) {
            PackNumberChip(number: number, size: .flag)
            FlagPointer()
                .fill(PillieTheme.textPrimary)
                .frame(width: 10, height: 5)
        }
        .fixedSize()
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

private struct FlagPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Pager

private struct PackCardPager: View {
    let tones: [PackTrackTone]
    let label: PackPageLabel
    let canGoBack: Bool
    let canGoForward: Bool
    let onStep: (Int) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(Array(tones.enumerated()), id: \.offset) { _, tone in
                    Capsule()
                        .fill(PackCardColor.track(tone))
                        .frame(height: 6)
                }
            }
            .accessibilityHidden(true)

            HStack(spacing: 8) {
                arrow(back: true)
                Text(labelText)
                    .font(.pillie(13, weight: .bold))
                    .foregroundStyle(PillieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
                arrow(back: false)
            }
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }

    private var labelText: String {
        switch label {
        case let .weeks(first, last, total):
            return PillieLocalization.formatted(
                "pack_card.pager.weeks_range", locale: locale, arguments: first, last, total
            )
        case let .week(week, total):
            return PillieLocalization.formatted("pack_card.pager.week_single", locale: locale, arguments: week, total)
        }
    }

    private func arrow(back: Bool) -> some View {
        let enabled = back ? canGoBack : canGoForward
        return Button {
            onStep(back ? -1 : 1)
        } label: {
            PagerChevron()
                .stroke(PillieTheme.textPrimary, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .frame(width: 12, height: 12)
                .scaleEffect(x: back ? 1 : -1)
                .flipsForRightToLeftLayoutDirection(true)
                .frame(width: 28, height: 28)
                .background(Circle().fill(PackCardColor.pagerButton))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(PillieLocalization.string(
            back ? "pack_card.pager.previous" : "pack_card.pager.next", locale: locale
        ))
    }
}

/// A left-pointing chevron in a 12pt box.
private struct PagerChevron: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.68, y: rect.height * 0.15))
        path.addLine(to: CGPoint(x: rect.width * 0.32, y: rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.width * 0.68, y: rect.height * 0.85))
        return path
    }
}

private enum PackCardColor {
    static let weekday = Color(hex: "A8A29E")
    static let pagerButton = Color(hex: "F5F5F4")

    static func track(_ tone: PackTrackTone) -> Color {
        switch tone {
        case .passed: return PillieTheme.hairlineStrong
        case .viewed: return PillieTheme.coral
        case .upcoming: return Color(hex: "FFE1DE")
        case .upcomingBreak: return Color(hex: "E3EBE2")
        }
    }
}

// MARK: - Previews

private struct PackCardPreviewHeader: View {
    let title: String

    var body: some View {
        Text(verbatim: title)
            .font(.pillie(16, weight: .bold))
            .foregroundStyle(PillieTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func packCardPreview(_ title: String, _ regimen: PackRegimen, today: Int?) -> some View {
    PackCard(regimen: regimen, dayOneWeekday: 2, todayIndex: today) {
        PackCardPreviewHeader(title: title)
    }
    .padding(16)
    .background(PillieTheme.bg)
}

#Preview("21+7") {
    packCardPreview("21+7", PackRegimen(activeDays: 21, breakDays: 7), today: 11)
}

#Preview("21 only") {
    packCardPreview("21 only", PackRegimen(activeDays: 21, breakDays: 7, breakKind: .noPills), today: 22)
}

#Preview("24+4") {
    packCardPreview("24+4", PackRegimen(activeDays: 24, breakDays: 4), today: 23)
}

#Preview("26+2") {
    packCardPreview("26+2", PackRegimen(activeDays: 26, breakDays: 2), today: 26)
}

#Preview("Every day") {
    packCardPreview("Every day", PackRegimen(activeDays: 28, breakDays: 0), today: 0)
}

#Preview("21+4") {
    packCardPreview("21+4", PackRegimen(activeDays: 21, breakDays: 4, breakKind: .noPills), today: 22)
}

#Preview("88+3") {
    packCardPreview("88+3", PackRegimen(activeDays: 88, breakDays: 3), today: 39)
}
