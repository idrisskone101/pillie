//
//  HistoryMonthSlideHost.swift
//  Pillie
//

import SwiftUI
import UIKit

/// Owns month snapshots, chrome, and the month card. The strip itself lives
/// in UIKit so a drag does not rebuild History's title, legend, or card.
struct HistoryMonthSlideHost: View {
    @Environment(PillStore.self) private var store
    @Environment(\.locale) private var locale
    var onEditableDayActivate: (HistoryEditableDay) -> Void

    @State private var displayedMonth: Date = MonthCursor.monthStart(for: Date())
    @State private var monthSnapshotCache: [String: [Int: PillScheduleSnapshot]] = [:]
    @State private var calendarContainerHeight: CGFloat?
    @State private var pagerControl = HistoryMonthPagerControl()

    private let performanceTier = PerformanceTier.current

    private var infoTransition: Animation {
        .easeInOut(duration: performanceTier == .constrained ? 0.14 : 0.2)
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                monthChrome
                monthPages
            }
            AdherenceCard(
                displayedMonth: displayedMonth,
                animatesValueChanges: true
            )
        }
        .onAppear {
            let currentMonth = MonthCursor.monthStart(for: store.today)
            displayedMonth = currentMonth
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
            pagerControl.navigate(by: delta)
        }
        #endif
    }

    private var monthYearString: String {
        displayedMonth.formatted(
            Date.FormatStyle().month(.wide).year().locale(locale)
        )
    }

    private var monthChrome: some View {
        HStack {
            Button {
                pagerControl.navigate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(PillieTheme.textMuted)
            }

            Spacer()

            Text(monthYearString)
                .font(.pillieBodyBold())
                .foregroundStyle(PillieTheme.textPrimary)
                .contentTransition(.opacity)
                .animation(infoTransition, value: displayedMonth)

            Spacer()

            Button {
                pagerControl.navigate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(PillieTheme.textMuted)
            }
        }
        .padding(.vertical, 8)
    }

    private var monthPages: some View {
        HistoryMonthPager(
            displayedMonth: displayedMonth,
            recordsRevision: store.dayRecordsRevision,
            protocolChangeVersion: store.protocolChangeVersion,
            makePage: pageView(for:),
            control: pagerControl,
            onCommit: commitMonth,
            onMeasuredHeight: freezeCalendarHeight,
            constrainedMotion: performanceTier == .constrained
        )
        .frame(height: calendarContainerHeight ?? 360, alignment: .top)
        .clipped()
        .contentShape(Rectangle())
        .overlay {
            HorizontalMonthDragSurface(
                onChanged: { pagerControl.updateDrag($0) },
                onEnded: { pagerControl.endDrag(translation: $0, velocity: $1) },
                onCancelled: { pagerControl.cancelDrag() }
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func pageView(for month: Date) -> AnyView {
        AnyView(
            CalendarGrid(
                displayedMonth: month,
                monthSnapshots: snapshots(for: month),
                recordsRevision: store.dayRecordsRevision,
                protocolChangeVersion: store.protocolChangeVersion,
                onEditableDayActivate: onEditableDayActivate
            )
            .equatable()
            .environment(store)
            .environment(\.locale, locale)
        )
    }

    private func snapshots(for month: Date) -> [Int: PillScheduleSnapshot] {
        let key = MonthCursor.identity(for: month)
        return monthSnapshotCache[key] ?? store.monthSnapshots(for: month)
    }

    private func commitMonth(_ nextMonth: Date) {
        displayedMonth = nextMonth
        #if DEBUG || PILLIE_FRAME_PROBE
        if let height = calendarContainerHeight {
            TabSwitchFrameProbe.shared.recordLayout(
                name: "calendar",
                key: MonthCursor.identity(for: nextMonth),
                value: height
            )
        }
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            warmVisibleMonths()
        }
    }

    private func freezeCalendarHeight(_ height: CGFloat) {
        guard height > 0 else { return }
        #if DEBUG || PILLIE_FRAME_PROBE
        TabSwitchFrameProbe.shared.recordLayout(
            name: "calendar",
            key: MonthCursor.identity(for: displayedMonth),
            value: height
        )
        #endif
        guard calendarContainerHeight == nil else { return }
        calendarContainerHeight = height
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

    private func resetToCurrentMonthForProtocolChange() {
        let currentMonth = MonthCursor.monthStart(for: store.today)
        monthSnapshotCache.removeAll(keepingCapacity: true)
        displayedMonth = currentMonth
        warmMonthSnapshotCache(for: currentMonth)
        calendarContainerHeight = nil
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
