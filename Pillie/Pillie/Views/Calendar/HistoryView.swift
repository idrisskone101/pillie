//
//  HistoryView.swift
//  Pillie
//

import SwiftUI
import SwiftData
import UIKit

struct HistoryView: View {
    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var monthSnapshotCache: [String: [Int: PillScheduleSnapshot]] = [:]
    @State private var dayHitFrames: [String: [Int: CGRect]] = [:]
    @State private var correctionTarget: HistoryEditableDay?
    @AppStorage(HistoryCoachMarkState.storageKey) private var coachMarkDismissed = false

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
                    title: PillieLocalization.string("history.navigation.title", locale: locale),
                    titleFont: .pillieExtraBold(36),
                    showsAccessorySlot: true,
                    accessory: nil
                )
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                // Subtitle
                Text(PillieLocalization.string("history.title", locale: locale))
                    .font(.pillieBody())
                    .foregroundStyle(PillieTheme.textMuted)
                    .modifier(FadeInUp(appeared: appeared, delay: 0))

                // Color legend
                VStack(alignment: .leading, spacing: 6) {
                    primaryLegend
                    if store.pack.method == .patch {
                        HStack(spacing: 16) {
                            legendItem(
                                color: PillieTheme.patchChangeRose,
                                label: legendLabels.active
                            )
                        }
                    }
                    if store.pack.method == .ring {
                        HStack(spacing: 16) {
                            legendItem(
                                color: PillieTheme.ringReinsertCoral,
                                label: legendLabels.active
                            )
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
                ZStack(alignment: .topLeading) {
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
                    .clipped()
                }
                .contentShape(Rectangle())
                .overlayPreferenceValue(CalendarDayHitFramesPreferenceKey.self) { anchors in
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                resolveDayHitFrames(anchors, in: proxy)
                            }
                            .onChange(of: anchorFrameToken(anchors)) { _, _ in
                                resolveDayHitFrames(anchors, in: proxy)
                            }
                    }
                }
                .overlay {
                    HorizontalMonthDragSurface(
                        onChanged: updateMonthDrag,
                        onEnded: endMonthDrag,
                        onCancelled: cancelMonthDrag,
                        onTap: handleCalendarTap
                    )
                    .accessibilityHidden(true)
                }
                .overlay(alignment: .topLeading) {
                    if let targetDay = coachMarkTargetDay,
                       let frame = dayHitFrames[monthIdentity]?[targetDay],
                       calendarWidth > 0,
                       let calendarHeight = calendarContainerHeight {
                        HistoryCoachMark(
                            targetFrame: frame,
                            calendarWidth: calendarWidth,
                            calendarHeight: calendarHeight,
                            onDismiss: dismissCoachMark
                        )
                    }
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: CalendarMonthWidthPreferenceKey.self,
                            value: proxy.size.width
                        )
                    }
                }
                .frame(height: calendarContainerHeight, alignment: .top)
                .zIndex(1)
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
        .onChange(of: store.lastDayCorrection) { _, event in
            patchMonthSnapshotCache(for: event)
        }
        .sheet(item: $correctionTarget) { target in
            HistoryDayCorrectionSheet(day: target) { outcome in
                store.correctPastDay(on: target.date, to: outcome)
            }
            .presentationDetents([
                .height(HistoryDayCorrectionSheet.height(rowCount: target.options.selectableOutcomes.count))
            ])
            .presentationDragIndicator(.hidden)
            .presentationBackground(PillieTheme.cardWhite)
            .presentationCornerRadius(28)
        }
    }

    // MARK: - Computed Properties

    private var legendLabels: (active: String, missed: String, rest: String) {
        (
            PillieLocalization.string("history.legend.completed", locale: locale),
            PillieLocalization.string("history.legend.unlogged", locale: locale),
            PillieLocalization.string("history.legend.break", locale: locale)
        )
    }

    private var monthYearString: String {
        infoMonth.formatted(
            Date.FormatStyle().month(.wide).year().locale(locale)
        )
    }

    private var monthIdentity: String {
        Self.monthIdentity(for: displayedMonth)
    }

    private var coachMarkTargetDay: Int? {
        guard !coachMarkDismissed else { return nil }
        return HistoryCoachMarkState.target(
            in: snapshots(for: displayedMonth),
            month: displayedMonth,
            today: store.today
        )
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
        CalendarGrid(
            displayedMonth: month,
            monthSnapshots: snapshots(for: month),
            highlightedDay: month == displayedMonth ? coachMarkTargetDay : nil,
            onEditableDayActivate: { day in
                openCorrectionSheet(for: day, in: month)
            }
        )
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

    private func handleCalendarTap(at point: CGPoint) {
        dismissCoachMark()

        guard let day = CalendarDayHitTest.day(
            at: point,
            in: dayHitFrames[monthIdentity] ?? [:]
        ) else {
            return
        }

        openCorrectionSheet(for: day, in: displayedMonth)
    }

    private func openCorrectionSheet(for day: Int, in month: Date) {
        dismissCoachMark()

        guard let date = CalendarGrid.date(forDay: day, in: month),
              let snapshot = store.scheduleSnapshot(for: date),
              let options = store.dayCorrectionOptions(for: snapshot) else {
            return
        }

        correctionTarget = HistoryEditableDay(
            date: date,
            snapshot: snapshot,
            options: options
        )
    }

    private func dismissCoachMark() {
        coachMarkDismissed = true
    }

    private func anchorFrameToken(_ anchors: [String: [Int: Anchor<CGRect>]]) -> String {
        anchors
            .sorted { $0.key < $1.key }
            .map { monthID, dayAnchors in
                let days = dayAnchors.keys.sorted().map(String.init).joined(separator: ",")
                return "\(monthID)[\(days)]"
            }
            .joined(separator: "|")
    }

    private func resolveDayHitFrames(
        _ anchors: [String: [Int: Anchor<CGRect>]],
        in proxy: GeometryProxy
    ) {
        var resolved: [String: [Int: CGRect]] = [:]
        for (monthID, dayAnchors) in anchors {
            var frames: [Int: CGRect] = [:]
            for (day, anchor) in dayAnchors {
                frames[day] = proxy[anchor]
            }
            resolved[monthID] = frames
        }
        dayHitFrames = resolved
    }

    private func patchMonthSnapshotCache(for event: DayCorrectionEvent?) {
        guard let event else { return }
        let key = Self.monthIdentity(for: event.monthStart)
        guard var monthCache = monthSnapshotCache[key] else { return }
        guard let updated = store.scheduleSnapshot(for: event.date) else { return }
        monthCache[event.dayOfMonth] = updated
        monthSnapshotCache[key] = monthCache
    }

    // MARK: - Drag Gesture

    private func updateMonthDrag(_ translation: CGFloat) {
        guard !isAnimatingTransition else { return }

        isDragging = true
        dragOffset = translation

        let direction: CGFloat = translation < 0 ? 1 : -1
        if adjacentMonth == nil || transitionDirection != direction {
            transitionDirection = direction
            let month = MonthCursor.month(byAdding: Int(direction), to: displayedMonth)
            adjacentMonth = month
            warmMonthSnapshotCache(for: month)
        }
    }

    private func endMonthDrag(translation: CGFloat, velocity: CGFloat) {
        guard isDragging else {
            resetDragState()
            return
        }

        let threshold = slideDistance * 0.25
        let matchingVelocity = (translation < 0 && velocity < -200)
            || (translation > 0 && velocity > 200)

        if abs(translation) > threshold || matchingVelocity {
            completeMonthTransition()
        } else {
            cancelMonthTransition()
        }
    }

    private func cancelMonthDrag() {
        guard isDragging else {
            resetDragState()
            return
        }
        cancelMonthTransition()
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
        let nextMonthHeight = measuredMonthHeights[nextMonthID]
        suppressAdherenceValueAnimation = shouldSuppressAdherenceValueAnimation(nextMonthID: nextMonthID)

        withAnimation(transitionAnimation, completionCriteria: .logicallyComplete) {
            dragOffset = targetOffset
        } completion: {
            displayedMonth = nextMonth
            warmMonthSnapshotCache(for: nextMonth)
            resetDragState()
            if let nextMonthHeight {
                withAnimation(transitionAnimation) {
                    calendarContainerHeight = nextMonthHeight
                }
            }
        }
    }

    private func cancelMonthTransition() {
        withAnimation(transitionAnimation, completionCriteria: .logicallyComplete) {
            dragOffset = 0
        } completion: {
            resetDragState()
        }
    }

    private func resetDragState() {
        dragOffset = 0
        isDragging = false
        adjacentMonth = nil
        transitionDirection = 0
        isAnimatingTransition = false
        suppressAdherenceValueAnimation = false
    }

    // MARK: - Height Management

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

    @ViewBuilder
    private var primaryLegend: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                legendItem(color: PillieTheme.sage, label: legendLabels.active)
                legendItem(color: PillieTheme.amber, label: legendLabels.missed)
                legendItem(color: PillieTheme.lavender, label: legendLabels.rest)
            }
        } else {
            HStack(spacing: 16) {
                legendItem(color: PillieTheme.sage, label: legendLabels.active)
                legendItem(color: PillieTheme.amber, label: legendLabels.missed)
                legendItem(color: PillieTheme.lavender, label: legendLabels.rest)
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.pillieBody())
                .foregroundStyle(PillieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A horizontal-only pan surface that explicitly wins over the surrounding
/// vertical scroll view. The ancestor waits for this recognizer to reject a
/// vertical drag; horizontal drags therefore cannot move both axes at once.
private struct HorizontalMonthDragSurface: UIViewRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void
    var onCancelled: () -> Void
    var onTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled,
            onTap: onTap
        )
    }

    func makeUIView(context: Context) -> MonthDragSurfaceView {
        let view = MonthDragSurfaceView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false

        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.delegate = context.coordinator
        panGesture.cancelsTouchesInView = true
        view.addGestureRecognizer(panGesture)

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tapGesture.delegate = context.coordinator
        view.addGestureRecognizer(tapGesture)
        tapGesture.require(toFail: panGesture)

        context.coordinator.panGesture = panGesture
        view.didMoveToWindowHandler = { [weak view, weak coordinator = context.coordinator] in
            guard let view, let coordinator else { return }
            coordinator.configureGesturePriority(from: view)
        }

        return view
    }

    func updateUIView(_ uiView: MonthDragSurfaceView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
        context.coordinator.onTap = onTap
        context.coordinator.configureGesturePriority(from: uiView)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void
        var onCancelled: () -> Void
        var onTap: (CGPoint) -> Void
        weak var panGesture: UIPanGestureRecognizer?
        weak var configuredScrollView: UIScrollView?

        init(
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (_ translation: CGFloat, _ velocity: CGFloat) -> Void,
            onCancelled: @escaping () -> Void,
            onTap: @escaping (CGPoint) -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
            self.onTap = onTap
        }

        func configureGesturePriority(from view: UIView) {
            guard let panGesture else { return }

            var ancestor = view.superview
            while let candidate = ancestor {
                if let scrollView = candidate as? UIScrollView {
                    guard configuredScrollView !== scrollView else { return }
                    scrollView.panGestureRecognizer.require(toFail: panGesture)
                    configuredScrollView = scrollView
                    return
                }
                ancestor = candidate.superview
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UITapGestureRecognizer {
                return true
            }
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
            }
            let velocity = panGesture.velocity(in: panGesture.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view).x

            switch gesture.state {
            case .began, .changed:
                onChanged(translation)
            case .ended:
                onEnded(
                    translation,
                    gesture.velocity(in: gesture.view).x
                )
            case .cancelled, .failed:
                onCancelled()
            case .possible:
                break
            @unknown default:
                onCancelled()
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            onTap(gesture.location(in: gesture.view))
        }
    }
}

private final class MonthDragSurfaceView: UIView {
    var didMoveToWindowHandler: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        didMoveToWindowHandler?()
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
