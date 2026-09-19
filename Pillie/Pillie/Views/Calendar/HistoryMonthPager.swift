//
//  HistoryMonthPager.swift
//  Pillie
//

import SwiftUI
import UIKit

/// Drives the History month strip through UIKit transforms so a swipe is
/// interpolated by the render server instead of SwiftUI's `dragOffset`.
@MainActor
final class HistoryMonthPagerControl {
    weak var controller: HistoryMonthPagerViewController?

    func updateDrag(_ translation: CGFloat) {
        controller?.updateDrag(translation)
    }

    func endDrag(translation: CGFloat, velocity: CGFloat) {
        controller?.endDrag(translation: translation, velocity: velocity)
    }

    func cancelDrag() {
        controller?.cancelDrag()
    }

    func navigate(by delta: Int) {
        controller?.navigate(by: delta)
    }
}

/// Three-page window after a settle. The recycled incoming host still shows
/// whatever month it had before the rotate, so a fast second swipe can put
/// that stale grid in the center.
struct HistoryMonthRecyclePlan: Equatable {
    var months: [Date]
    var boundMonths: [Date?]
    var incomingIndex: Int
    var incomingMonth: Date

    var centerNeedsBind: Bool {
        guard months.indices.contains(1), boundMonths.indices.contains(1) else {
            return true
        }
        return boundMonths[1] != months[1]
    }

    static func apply(
        delta: Int,
        months: [Date],
        boundMonths: [Date?],
        calendar: Calendar = .current
    ) -> HistoryMonthRecyclePlan {
        let bounds = boundMonths.count == 3
            ? boundMonths
            : [Date?](repeating: nil, count: 3)
        if delta > 0 {
            let incoming = MonthCursor.month(byAdding: 2, to: months[1], calendar: calendar)
            return HistoryMonthRecyclePlan(
                months: [months[1], months[2], incoming],
                boundMonths: [bounds[1], bounds[2], bounds[0]],
                incomingIndex: 2,
                incomingMonth: incoming
            )
        }
        let incoming = MonthCursor.month(byAdding: -2, to: months[1], calendar: calendar)
        return HistoryMonthRecyclePlan(
            months: [incoming, months[0], months[1]],
            boundMonths: [bounds[2], bounds[0], bounds[1]],
            incomingIndex: 0,
            incomingMonth: incoming
        )
    }
}

struct HistoryMonthPager: UIViewControllerRepresentable {
    var displayedMonth: Date
    var recordsRevision: Int
    var protocolChangeVersion: Int
    var makePage: (Date) -> AnyView
    var control: HistoryMonthPagerControl
    var onCommit: (Date) -> Void
    var onMeasuredHeight: (CGFloat) -> Void
    var constrainedMotion: Bool

    func makeUIViewController(context: Context) -> HistoryMonthPagerViewController {
        let controller = HistoryMonthPagerViewController()
        control.controller = controller
        bind(controller)
        controller.configure(
            current: displayedMonth,
            recordsRevision: recordsRevision,
            protocolChangeVersion: protocolChangeVersion,
            makePage: makePage
        )
        return controller
    }

    func updateUIViewController(_ controller: HistoryMonthPagerViewController, context: Context) {
        control.controller = controller
        bind(controller)
        controller.configure(
            current: displayedMonth,
            recordsRevision: recordsRevision,
            protocolChangeVersion: protocolChangeVersion,
            makePage: makePage
        )
    }

    private func bind(_ controller: HistoryMonthPagerViewController) {
        controller.onCommit = onCommit
        controller.onMeasuredHeight = onMeasuredHeight
        controller.constrainedMotion = constrainedMotion
    }
}

final class HistoryMonthPagerViewController: UIViewController {
    var onCommit: ((Date) -> Void)?
    var onMeasuredHeight: ((CGFloat) -> Void)?
    var constrainedMotion = false

    private let strip = UIView()
    private var hosts: [UIHostingController<AnyView>] = []
    private var months: [Date] = []
    private var recordsRevision = -1
    private var protocolChangeVersion = -1
    private var makePage: (Date) -> AnyView = { _ in AnyView(EmptyView()) }
    private var animator: UIViewPropertyAnimator?
    private var isDragging = false
    private var didReportHeight = false
    private var pendingIncoming: (index: Int, month: Date)?
    private var incomingFillWork: DispatchWorkItem?
    private var boundMonths: [Date?] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        strip.backgroundColor = .clear
        view.addSubview(strip)

        hosts = (0..<3).map { _ in
            let host = UIHostingController(rootView: AnyView(EmptyView()))
            host.safeAreaRegions = []
            host.view.backgroundColor = .clear
            host.view.isOpaque = false
            addChild(host)
            strip.addSubview(host.view)
            host.didMove(toParent: self)
            return host
        }
        boundMonths = Array(repeating: nil, count: hosts.count)

        if months.count == 3 {
            refreshHosts()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutStrip(preservingOffset: true)
        reportHeightIfNeeded()
    }

    func configure(
        current: Date,
        recordsRevision: Int,
        protocolChangeVersion: Int,
        makePage: @escaping (Date) -> AnyView
    ) {
        self.makePage = makePage
        let pages = [
            MonthCursor.month(byAdding: -1, to: current),
            current,
            MonthCursor.month(byAdding: 1, to: current),
        ]
        let monthsChanged = months != pages
        let dataChanged = self.recordsRevision != recordsRevision
            || self.protocolChangeVersion != protocolChangeVersion
        self.recordsRevision = recordsRevision
        self.protocolChangeVersion = protocolChangeVersion

        guard animator == nil, !isDragging else { return }
        guard monthsChanged || dataChanged || hosts.contains(where: { $0.view.superview == nil }) else {
            return
        }
        months = pages
        DispatchQueue.main.async { [weak self] in
            guard let self, self.animator == nil, !self.isDragging else { return }
            self.refreshHosts()
            self.layoutStrip(preservingOffset: false)
            self.reportHeightIfNeeded()
        }
    }

    func updateDrag(_ translation: CGFloat) {
        guard animator == nil else { return }
        isDragging = true
        strip.transform = CGAffineTransform(translationX: translation, y: 0)
    }

    func endDrag(translation: CGFloat, velocity: CGFloat) {
        guard isDragging else {
            resetStrip()
            return
        }

        let width = max(view.bounds.width, 1)
        let threshold = width * 0.25
        let matchingVelocity = (translation < 0 && velocity < -200)
            || (translation > 0 && velocity > 200)
        if abs(translation) > threshold || matchingVelocity {
            let delta = translation < 0 ? 1 : -1
            animateStrip(to: -CGFloat(delta) * width, commitDelta: delta)
        } else {
            animateStrip(to: 0, commitDelta: 0)
        }
    }

    func cancelDrag() {
        guard isDragging else {
            resetStrip()
            return
        }
        animateStrip(to: 0, commitDelta: 0)
    }

    func navigate(by delta: Int) {
        guard animator == nil, !isDragging, delta != 0 else { return }
        let width = max(view.bounds.width, 1)
        let step = delta > 0 ? 1 : -1
        animateStrip(to: -CGFloat(step) * width, commitDelta: step)
    }

    private func animateStrip(to target: CGFloat, commitDelta: Int) {
        animator?.stopAnimation(true)
        let duration: TimeInterval = constrainedMotion ? 0.2 : 0.35
        let animator: UIViewPropertyAnimator
        if constrainedMotion {
            animator = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) { [strip] in
                strip.transform = CGAffineTransform(translationX: target, y: 0)
            }
        } else {
            animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.86) { [strip] in
                strip.transform = CGAffineTransform(translationX: target, y: 0)
            }
        }
        animator.addCompletion { [weak self] _ in
            self?.animator = nil
            self?.finishTransition(delta: commitDelta)
        }
        self.animator = animator
        if commitDelta != 0, months.indices.contains(1) {
            onCommit?(MonthCursor.month(byAdding: commitDelta, to: months[1]))
        }
        animator.startAnimation()
    }

    private func finishTransition(delta: Int) {
        isDragging = false
        guard delta != 0, months.count == 3, hosts.count == 3 else {
            resetStrip()
            return
        }

        incomingFillWork?.cancel()
        let plan = HistoryMonthRecyclePlan.apply(
            delta: delta,
            months: months,
            boundMonths: boundMonths
        )
        if delta > 0 {
            hosts = [hosts[1], hosts[2], hosts[0]]
        } else {
            hosts = [hosts[2], hosts[0], hosts[1]]
        }
        months = plan.months
        boundMonths = plan.boundMonths
        pendingIncoming = (plan.incomingIndex, plan.incomingMonth)
        resetStrip()
        layoutStrip(preservingOffset: false)
        concealPendingIncoming()
        if plan.centerNeedsBind {
            hosts[1].view.alpha = 0
            let center = months[1]
            DispatchQueue.main.async { [weak self] in
                guard let self, self.months.indices.contains(1), self.months[1] == center else {
                    return
                }
                self.bindHost(at: 1, to: center)
            }
        }

        let expected = months[1]
        let work = DispatchWorkItem { [weak self] in
            self?.fillPendingIncoming(expectedCurrent: expected)
        }
        incomingFillWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func fillPendingIncoming(expectedCurrent: Date) {
        guard months.indices.contains(1), months[1] == expectedCurrent,
              let pending = pendingIncoming, hosts.indices.contains(pending.index) else {
            return
        }
        pendingIncoming = nil
        bindHost(at: pending.index, to: pending.month)
    }

    private func refreshHosts() {
        guard hosts.count == 3, months.count == 3 else { return }
        if boundMonths.count != hosts.count {
            boundMonths = Array(repeating: nil, count: hosts.count)
        }
        for (index, month) in months.enumerated() {
            bindHost(at: index, to: month)
        }
    }

    private func bindHost(at index: Int, to month: Date) {
        guard hosts.indices.contains(index) else { return }
        if boundMonths.indices.contains(index), boundMonths[index] == month {
            hosts[index].view.alpha = 1
            return
        }
        hosts[index].rootView = makePage(month)
        if boundMonths.indices.contains(index) {
            boundMonths[index] = month
        }
        hosts[index].view.alpha = 1
    }

    private func concealPendingIncoming() {
        guard let pending = pendingIncoming, hosts.indices.contains(pending.index) else { return }
        guard !boundMonths.indices.contains(pending.index)
                || boundMonths[pending.index] != pending.month else {
            hosts[pending.index].view.alpha = 1
            return
        }
        hosts[pending.index].view.alpha = 0
    }

    private func layoutStrip(preservingOffset: Bool) {
        let width = view.bounds.width
        let height = view.bounds.height
        guard width > 0, height > 0, hosts.count == 3 else { return }
        let offset = preservingOffset ? strip.transform.tx : 0
        strip.transform = .identity
        strip.frame = CGRect(x: -width, y: 0, width: width * 3, height: height)
        for (index, host) in hosts.enumerated() {
            host.view.frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: height)
        }
        if preservingOffset {
            strip.transform = CGAffineTransform(translationX: offset, y: 0)
        }
    }

    private func resetStrip() {
        strip.transform = .identity
        isDragging = false
    }

    private func reportHeightIfNeeded() {
        guard !didReportHeight, hosts.indices.contains(1), view.bounds.width > 0 else { return }
        let size = hosts[1].sizeThatFits(
            in: CGSize(width: view.bounds.width, height: UIView.layoutFittingExpandedSize.height)
        )
        guard size.height > 0 else { return }
        didReportHeight = true
        let height = size.height
        DispatchQueue.main.async { [weak self] in
            self?.onMeasuredHeight?(height)
        }
    }
}
