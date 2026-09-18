//
//  HistoryMonthSlideHost.swift
//  Pillie
//

import SwiftUI
import UIKit

/// Owns month-swipe state so History's title, legend, and adherence card do
/// not rebuild on every `dragOffset` frame.
struct HistoryMonthSlideHost: View {
    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale
    @Binding var infoMonth: Date
    @Binding var suppressAdherenceValueAnimation: Bool
    var onEditableDayActivate: (HistoryEditableDay) -> Void

    @State private var displayedMonth: Date = MonthCursor.monthStart(for: Date())
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var transitionDirection: CGFloat = 0
    @State private var isAnimatingTransition = false
    @State private var calendarWidth: CGFloat = 0
    @State private var monthSnapshotCache: [String: [Int: PillScheduleSnapshot]] = [:]
    @State private var measuredMonthHeights: [String: CGFloat] = [:]
    @State private var calendarContainerHeight: CGFloat?

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
        VStack(spacing: 0) {
            monthChrome
            monthPages
        }
        .onAppear {
            let currentMonth = MonthCursor.monthStart(for: store.today)
            displayedMonth = currentMonth
            infoMonth = currentMonth
            warmVisibleMonths()
        }
        .onChange(of: store.protocolChangeVersion) { _, _ in
            resetToCurrentMonthForProtocolChange()
        }
        .onChange(of: store.dayRecordsRevision) { _, _ in
            refreshCachedMonthSnapshots()
        }
        #if DEBUG || PILLIE_FRAME_PROBE
        .onReceive(NotificationCenter.default.publisher(for: .pillieMeasureNavigateMonth)) { note in
            guard let delta = note.userInfo?["delta"] as? Int else { return }
            navigateMonth(by: delta)
        }
        #endif
    }

    private var monthYearString: String {
        infoMonth.formatted(
            Date.FormatStyle().month(.wide).year().locale(locale)
        )
    }

    private var monthIdentity: String {
        MonthCursor.identity(for: displayedMonth)
    }

    private var slideDistance: CGFloat {
        max(calendarWidth, 320)
    }

    private var visibleMonthPages: [HistoryMonthPage] {
        (-1...1).map { shift in
            HistoryMonthPage(
                month: MonthCursor.month(byAdding: shift, to: displayedMonth),
                shift: CGFloat(shift)
            )
        }
    }

    private var monthChrome: some View {
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
    }

    private var monthPages: some View {
        ZStack(alignment: .top) {
            ForEach(visibleMonthPages) { page in
                monthGrid(for: page.month)
                    .offset(x: page.shift * slideDistance + dragOffset)
                    .allowsHitTesting(page.shift == 0)
                    .zIndex(page.shift == 0 ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .overlay {
            HorizontalMonthDragSurface(
                onChanged: updateMonthDrag,
                onEnded: endMonthDrag,
                onCancelled: cancelMonthDrag
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
        .clipped()
        .onPreferenceChange(CalendarMonthHeightPreferenceKey.self) { heights in
            updateCalendarHeight(with: heights)
        }
        .onPreferenceChange(CalendarMonthWidthPreferenceKey.self) { width in
            guard width > 0 else { return }
            calendarWidth = width
        }
    }

    private func snapshots(for month: Date) -> [Int: PillScheduleSnapshot] {
        let key = MonthCursor.identity(for: month)
        return monthSnapshotCache[key] ?? store.monthSnapshots(for: month)
    }

    @ViewBuilder
    private func monthGrid(for month: Date) -> some View {
        let monthID = MonthCursor.identity(for: month)
        CalendarGrid(
            displayedMonth: month,
            monthSnapshots: snapshots(for: month),
            recordsRevision: store.dayRecordsRevision,
            protocolChangeVersion: store.protocolChangeVersion,
            onEditableDayActivate: { day in
                guard !isDragging, !isAnimatingTransition else { return }
                onEditableDayActivate(day)
            }
        )
        .equatable()
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

    private func refreshCachedMonthSnapshots() {
        monthSnapshotCache.removeAll(keepingCapacity: true)
        warmVisibleMonths()
    }

    private func warmVisibleMonths() {
        for offset in -2...2 {
            warmMonthSnapshotCache(for: MonthCursor.month(byAdding: offset, to: displayedMonth))
        }
    }

    private func updateMonthDrag(_ translation: CGFloat) {
        guard !isAnimatingTransition else { return }

        isDragging = true
        dragOffset = translation
        transitionDirection = translation < 0 ? 1 : -1
        warmMonthSnapshotCache(
            for: MonthCursor.month(byAdding: Int(transitionDirection), to: displayedMonth)
        )
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

    private func navigateMonth(by value: Int) {
        guard !isAnimatingTransition, !isDragging else { return }
        isAnimatingTransition = true
        transitionDirection = value >= 0 ? 1 : -1
        warmMonthSnapshotCache(
            for: MonthCursor.month(byAdding: value, to: displayedMonth)
        )
        completeMonthTransition()
    }

    private func completeMonthTransition() {
        let nextMonth = MonthCursor.month(byAdding: Int(transitionDirection), to: displayedMonth)
        isAnimatingTransition = true
        let targetOffset = -transitionDirection * slideDistance
        suppressAdherenceValueAnimation = true

        withAnimation(transitionAnimation, completionCriteria: .logicallyComplete) {
            dragOffset = targetOffset
        } completion: {
            var commit = Transaction()
            commit.disablesAnimations = true
            withTransaction(commit) {
                displayedMonth = nextMonth
                infoMonth = nextMonth
                dragOffset = 0
                isDragging = false
                transitionDirection = 0
                isAnimatingTransition = false
                suppressAdherenceValueAnimation = false
            }
            warmVisibleMonths()
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
        transitionDirection = 0
        isAnimatingTransition = false
        suppressAdherenceValueAnimation = false
    }

    private func updateCalendarHeight(with heights: [String: CGFloat]) {
        guard !heights.isEmpty else { return }

        var merged = measuredMonthHeights
        for (monthID, height) in heights where height > 0 {
            merged[monthID] = height
        }
        measuredMonthHeights = merged

        guard let targetHeight = merged[monthIdentity] else { return }
        #if DEBUG || PILLIE_FRAME_PROBE
        TabSwitchFrameProbe.shared.recordLayout(
            name: "calendar",
            key: monthIdentity,
            value: targetHeight
        )
        #endif

        guard calendarContainerHeight == nil else { return }
        guard !isAnimatingTransition, !isDragging else { return }
        calendarContainerHeight = targetHeight
    }

    private func resetToCurrentMonthForProtocolChange() {
        let currentMonth = MonthCursor.monthStart(for: store.today)
        withAnimation(infoTransition) {
            infoMonth = currentMonth
        }

        monthSnapshotCache.removeAll(keepingCapacity: true)
        warmMonthSnapshotCache(for: currentMonth)
        displayedMonth = currentMonth
        resetDragState()

        let currentMonthID = MonthCursor.identity(for: currentMonth)
        if let knownHeight = measuredMonthHeights[currentMonthID] {
            calendarContainerHeight = knownHeight
        } else {
            calendarContainerHeight = nil
        }
    }

    private func warmMonthSnapshotCache(for month: Date) {
        let key = MonthCursor.identity(for: month)
        guard monthSnapshotCache[key] == nil else { return }

        monthSnapshotCache[key] = store.monthSnapshots(for: month)

        let keep = Set((-2...2).map { offset in
            MonthCursor.identity(for: MonthCursor.month(byAdding: offset, to: displayedMonth))
        } + [key])
        monthSnapshotCache = monthSnapshotCache.filter { keep.contains($0.key) }
    }
}

private struct HistoryMonthPage: Identifiable {
    let month: Date
    let shift: CGFloat

    var id: String { MonthCursor.identity(for: month) }
}

/// A horizontal-only month pan that explicitly wins over the surrounding
/// vertical scroll view. The recognizer is installed on the ancestor
/// `UIScrollView` (so it sees touches that land on SwiftUI day buttons) but
/// only begins for horizontal drags that start inside this surface's bounds;
/// the scroll view waits for it to fail before scrolling vertically, so a
/// drag never moves both axes at once and a swipe on the adherence card does
/// not change months.
private struct HorizontalMonthDragSurface: UIViewRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void
    var onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
    }

    func makeUIView(context: Context) -> MonthDragSurfaceView {
        let view = MonthDragSurfaceView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        view.isUserInteractionEnabled = false

        context.coordinator.surfaceView = view
        view.didMoveToWindowHandler = { [weak view, weak coordinator = context.coordinator] in
            guard let view, let coordinator else { return }
            coordinator.attach(toScrollViewFrom: view)
        }

        return view
    }

    func updateUIView(_ uiView: MonthDragSurfaceView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
        context.coordinator.attach(toScrollViewFrom: uiView)
    }

    static func dismantleUIView(_ uiView: MonthDragSurfaceView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void
        var onCancelled: () -> Void
        /// The coordinator owns the recognizer: it must outlive the moment it is
        /// added to the scroll view, which only happens once the surface is in
        /// a window. `UIGestureRecognizer` retains its targets, so this is a
        /// cycle until `tearDown()` removes the target.
        let panGesture = UIPanGestureRecognizer()
        weak var surfaceView: UIView?
        private weak var configuredScrollView: UIScrollView?

        init(
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (_ translation: CGFloat, _ velocity: CGFloat) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
            super.init()
            panGesture.addTarget(self, action: #selector(handlePan(_:)))
            panGesture.delegate = self
            panGesture.cancelsTouchesInView = true
        }

        func attach(toScrollViewFrom view: UIView) {
            var ancestor = view.superview
            while let candidate = ancestor {
                if let scrollView = candidate as? UIScrollView {
                    guard configuredScrollView !== scrollView else { return }
                    detach()
                    scrollView.addGestureRecognizer(panGesture)
                    scrollView.panGestureRecognizer.require(toFail: panGesture)
                    configuredScrollView = scrollView
                    return
                }
                ancestor = candidate.superview
            }
        }

        func detach() {
            configuredScrollView?.removeGestureRecognizer(panGesture)
            configuredScrollView = nil
        }

        func tearDown() {
            detach()
            panGesture.removeTarget(self, action: nil)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
                  let surfaceView else {
                return false
            }
            let startsOnCalendar = surfaceView.bounds.contains(panGesture.location(in: surfaceView))
            guard startsOnCalendar else { return false }
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
