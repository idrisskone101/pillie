//
//  HistoryView.swift
//  Pillie
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(PillStore.self) private var store
    @State private var displayedMonth: Date = MonthCursor.monthStart(for: Date())
    @State private var infoMonth: Date = MonthCursor.monthStart(for: Date())
    @State private var appeared = false
    @State private var hasAnimatedIn = false
    @State private var measuredMonthHeights: [String: CGFloat] = [:]
    @State private var calendarContainerHeight: CGFloat?

    // Unified transition state
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var adjacentMonth: Date?
    @State private var transitionDirection: CGFloat = 0
    @State private var isAnimatingTransition = false
    @State private var suppressAdherenceValueAnimation = false
    @State private var calendarWidth: CGFloat = 0
    @State private var horizontalLocked = false
    @State private var monthSnapshotCache: [String: [Int: PillScheduleSnapshot]] = [:]

    private let performanceTier = PerformanceTier.current

    private var transitionAnimation: Animation {
        performanceTier == .constrained
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.4, dampingFraction: 0.86)
    }

    private var infoTransition: Animation {
        .easeInOut(duration: performanceTier == .constrained ? 0.14 : 0.2)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                PrimaryTitleAnchor(
                    title: "History",
                    titleFont: .pillieExtraBold(36),
                    showsAccessorySlot: true,
                    accessory: nil
                )
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                // Subtitle
                Text("Your tracking overview")
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                // Color legend
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 16) {
                        legendItem(color: PillieTheme.sage, label: legendLabels.active)
                        legendItem(color: PillieTheme.amber, label: legendLabels.missed)
                        legendItem(color: PillieTheme.lavender, label: legendLabels.rest)
                    }
                    if store.pack.method == .patch {
                        HStack(spacing: 16) {
                            legendItem(color: PillieTheme.patchChangeRose, label: "Change / Remove")
                        }
                    }
                    if store.pack.method == .ring {
                        HStack(spacing: 16) {
                            legendItem(color: PillieTheme.ringReinsertCoral, label: "Reinsert Date")
                        }
                    }
                }
                .padding(.top, 4)
                .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                // Month navigation
                HStack {
                    Button {
                        navigateMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(PillieTheme.textMuted)
                    }
                    .disabled(isAnimatingTransition)

                    Spacer()

                    Text(monthYearString)
                        .font(.pillieBodyBold())
                        .foregroundStyle(PillieTheme.textPrimary)
                        .contentTransition(.opacity)
                        .animation(infoTransition, value: infoMonth)

                    Spacer()

                    Button {
                        navigateMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(PillieTheme.textMuted)
                    }
                    .disabled(isAnimatingTransition)
                }
                .padding(.vertical, 8)
                .modifier(FadeInUp(appeared: appeared, delay: 0.1))

                // Calendar grid
                ZStack(alignment: .top) {
                    if let adjacentMonth {
                        monthGrid(for: adjacentMonth)
                            .offset(x: transitionDirection * slideDistance + dragOffset)
                            .transition(.identity)
                            .zIndex(0)
                    }

                    monthGrid(for: displayedMonth)
                        .offset(x: dragOffset)
                        .transition(.identity)
                        .zIndex(1)
                }
                .contentShape(Rectangle())
                .gesture(monthDragGesture)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: CalendarMonthWidthPreferenceKey.self,
                            value: proxy.size.width
                        )
                    }
                }
                .frame(height: calendarContainerHeight, alignment: .top)
                .clipped()
                .modifier(FadeInUp(appeared: appeared, delay: 0.2))
                .onPreferenceChange(CalendarMonthHeightPreferenceKey.self) { heights in
                    updateCalendarHeight(with: heights)
                }
                .onPreferenceChange(CalendarMonthWidthPreferenceKey.self) { width in
                    guard width > 0 else { return }
                    calendarWidth = width
                }

                // Adherence card
                AdherenceCard(
                    displayedMonth: infoMonth,
                    animatesValueChanges: !suppressAdherenceValueAnimation
                )
                    .modifier(FadeInUp(appeared: appeared, delay: 0.3))
            }
            .padding(.horizontal, PillieTheme.screenHorizontalPadding)
            .padding(.top, PillieTheme.scrollTopPadding)
            .padding(.bottom, PillieTheme.scrollBottomPaddingDefault)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .onAppear {
            guard !hasAnimatedIn else { return }
            hasAnimatedIn = true
            warmMonthSnapshotCache(for: displayedMonth)
            warmMonthSnapshotCache(for: MonthCursor.month(byAdding: -1, to: displayedMonth))
            warmMonthSnapshotCache(for: MonthCursor.month(byAdding: 1, to: displayedMonth))
            withAnimation(PillieTheme.fadeInUpCurve) {
                appeared = true
            }
        }
        .onChange(of: store.protocolChangeVersion) { _, _ in
            resetToCurrentMonthForProtocolChange()
        }
    }

    // MARK: - Computed Properties

    private var legendLabels: (active: String, missed: String, rest: String) {
        switch store.pack.method {
        case .pill:
            return ("Taken", "Missed", "Break")
        case .patch:
            return ("Changed", "Missed", "Off Week")
        case .ring:
            return ("Inserted", "Missed", "Ring-Free")
        }
    }

    private var monthYearString: String {
        PillieDateFormatters.monthYear.string(from: infoMonth)
    }

    private var monthIdentity: String {
        Self.monthIdentity(for: displayedMonth)
    }

    private var slideDistance: CGFloat {
        max(calendarWidth, 320)
    }

    private static func monthIdentity(for month: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: month)
        let year = components.year ?? 0
        let monthNumber = components.month ?? 0
        return "\(year)-\(monthNumber)"
    }

    private func snapshots(for month: Date) -> [Int: PillScheduleSnapshot] {
        let key = Self.monthIdentity(for: month)
        return monthSnapshotCache[key] ?? store.monthSnapshots(for: month)
    }

    // MARK: - Month Grid

    @ViewBuilder
    private func monthGrid(for month: Date) -> some View {
        let monthID = Self.monthIdentity(for: month)
        CalendarGrid(displayedMonth: month, monthSnapshots: snapshots(for: month))
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: CalendarMonthHeightPreferenceKey.self,
                        value: [monthID: proxy.size.height]
                    )
                }
            }
            .onAppear {
                warmMonthSnapshotCache(for: month)
            }
    }

    // MARK: - Drag Gesture

    private var monthDragGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                guard !isAnimatingTransition else { return }

                let tx = value.translation.width
                let ty = value.translation.height

                // Direction-lock: only claim horizontal if it's dominant
                if !isDragging {
                    guard abs(tx) > abs(ty) * 1.2 else { return }
                    isDragging = true
                    horizontalLocked = true
                }
                guard horizontalLocked else { return }

                dragOffset = tx

                // Determine which adjacent month to show
                let dir: CGFloat = tx < 0 ? 1 : -1 // swipe left → next month (dir +1)
                if adjacentMonth == nil || transitionDirection != dir {
                    transitionDirection = dir
                    let month = MonthCursor.month(byAdding: Int(dir), to: displayedMonth)
                    adjacentMonth = month
                    warmMonthSnapshotCache(for: month)
                }

                // Interpolate container height during drag
                interpolateHeight(progress: abs(tx) / slideDistance)
            }
            .onEnded { value in
                guard isDragging, horizontalLocked else {
                    resetDragState()
                    return
                }

                let tx = value.translation.width
                let vx = value.velocity.width
                let threshold = slideDistance * 0.25

                // Complete if dragged far enough or flicked fast enough
                let matchingVelocity = (tx < 0 && vx < -200) || (tx > 0 && vx > 200)
                if abs(tx) > threshold || matchingVelocity {
                    completeMonthTransition()
                } else {
                    cancelMonthTransition()
                }
            }
    }

    // MARK: - Navigation (buttons)

    private func navigateMonth(by value: Int) {
        guard !isAnimatingTransition, !isDragging else { return }
        isAnimatingTransition = true

        let dir: CGFloat = value >= 0 ? 1 : -1
        transitionDirection = dir
        let month = MonthCursor.month(byAdding: value, to: displayedMonth)
        adjacentMonth = month
        warmMonthSnapshotCache(for: month)
        dragOffset = 0

        completeMonthTransition()
    }

    // MARK: - Transition Completion / Cancellation

    private func completeMonthTransition() {
        guard let nextMonth = adjacentMonth else {
            resetDragState()
            return
        }
        isAnimatingTransition = true
        withAnimation(infoTransition) {
            infoMonth = nextMonth
        }

        let nextMonthID = Self.monthIdentity(for: nextMonth)
        let targetOffset = -transitionDirection * slideDistance
        suppressAdherenceValueAnimation = shouldSuppressAdherenceValueAnimation(nextMonthID: nextMonthID)

        withAnimation(transitionAnimation, completionCriteria: .logicallyComplete) {
            dragOffset = targetOffset
            if let knownHeight = measuredMonthHeights[nextMonthID] {
                calendarContainerHeight = knownHeight
            }
        } completion: {
            displayedMonth = nextMonth
            warmMonthSnapshotCache(for: nextMonth)
            resetDragState()
        }
    }

    private func cancelMonthTransition() {
        withAnimation(transitionAnimation, completionCriteria: .logicallyComplete) {
            dragOffset = 0
            // Restore current month height
            if let currentHeight = measuredMonthHeights[monthIdentity] {
                calendarContainerHeight = currentHeight
            }
        } completion: {
            resetDragState()
        }
    }

    private func resetDragState() {
        dragOffset = 0
        isDragging = false
        horizontalLocked = false
        adjacentMonth = nil
        transitionDirection = 0
        isAnimatingTransition = false
        suppressAdherenceValueAnimation = false
    }

    // MARK: - Height Management

    private func interpolateHeight(progress: CGFloat) {
        guard let adj = adjacentMonth else { return }
        let currentID = monthIdentity
        let adjID = Self.monthIdentity(for: adj)

        guard let currentH = measuredMonthHeights[currentID],
              let adjH = measuredMonthHeights[adjID] else { return }

        let clamped = min(max(progress, 0), 1)
        calendarContainerHeight = currentH + (adjH - currentH) * clamped
    }

    private func updateCalendarHeight(with heights: [String: CGFloat]) {
        guard !heights.isEmpty else { return }

        var merged = measuredMonthHeights
        for (monthID, height) in heights where height > 0 {
            merged[monthID] = height
        }
        measuredMonthHeights = merged

        // Skip height updates during active transitions to prevent fighting
        guard !isAnimatingTransition, !isDragging else { return }

        guard let targetHeight = merged[monthIdentity] else { return }
        if let currentHeight = calendarContainerHeight, abs(currentHeight - targetHeight) < 0.5 {
            return
        }

        withAnimation(transitionAnimation) {
            calendarContainerHeight = targetHeight
        }
    }

    private func shouldSuppressAdherenceValueAnimation(nextMonthID: String) -> Bool {
        let currentHeight = measuredMonthHeights[monthIdentity] ?? calendarContainerHeight
        let nextHeight = measuredMonthHeights[nextMonthID]

        guard let currentHeight, let nextHeight else { return false }
        return abs(currentHeight - nextHeight) > 0.5
    }

    private func resetToCurrentMonthForProtocolChange() {
        let currentMonth = MonthCursor.monthStart(for: Date())
        withAnimation(infoTransition) {
            infoMonth = currentMonth
        }

        monthSnapshotCache.removeAll(keepingCapacity: true)
        warmMonthSnapshotCache(for: currentMonth)
        displayedMonth = currentMonth
        resetDragState()

        let currentMonthID = Self.monthIdentity(for: currentMonth)
        if let knownHeight = measuredMonthHeights[currentMonthID] {
            calendarContainerHeight = knownHeight
        } else {
            calendarContainerHeight = nil
        }
    }

    private func warmMonthSnapshotCache(for month: Date) {
        let key = Self.monthIdentity(for: month)
        guard monthSnapshotCache[key] == nil else { return }

        monthSnapshotCache[key] = store.monthSnapshots(for: month)

        // Keep cache bounded to nearby months.
        let keep = Set([
            Self.monthIdentity(for: displayedMonth),
            Self.monthIdentity(for: MonthCursor.month(byAdding: -1, to: displayedMonth)),
            Self.monthIdentity(for: MonthCursor.month(byAdding: 1, to: displayedMonth)),
            key
        ])
        monthSnapshotCache = monthSnapshotCache.filter { keep.contains($0.key) }
    }

    // MARK: - Legend

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
        }
    }
}

private struct CalendarMonthHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct CalendarMonthWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    HistoryView()
        .environment(PillStore.previewStore())
        .modelContainer(PillStore.previewContainer)
}
