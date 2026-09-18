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
        refreshHosts()
        layoutStrip(preservingOffset: false)
        reportHeightIfNeeded()
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
        animator.startAnimation()
        self.animator = animator
    }

    private func finishTransition(delta: Int) {
        isDragging = false
        guard delta != 0, months.indices.contains(1) else {
            resetStrip()
            return
        }
        let next = MonthCursor.month(byAdding: delta, to: months[1])
        months = [
            MonthCursor.month(byAdding: -1, to: next),
            next,
            MonthCursor.month(byAdding: 1, to: next),
        ]
        refreshHosts()
        resetStrip()
        onCommit?(next)
    }

    private func refreshHosts() {
        guard hosts.count == 3, months.count == 3 else { return }
        for (index, month) in months.enumerated() {
            hosts[index].rootView = makePage(month)
        }
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
        onMeasuredHeight?(size.height)
    }
}
