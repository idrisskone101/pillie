//
//  TabPaneContainer.swift
//  Pillie
//

import SwiftUI
import UIKit

/// Hosts the main tab panes in UIKit and animates the switch between them with
/// Core Animation. A SwiftUI-driven slide has to re-emit both panes' render
/// trees on the main thread every frame, which paces the transition below the
/// display's refresh rate on ProMotion phones; a UIKit transform animation is
/// committed once and interpolated by the render server, exactly like a sheet
/// presentation. All panes stay alive (state, scroll position, entrance
/// animations) — only visibility and transforms change.
struct TabPaneContainer: UIViewControllerRepresentable {
    let selectedTab: PillieTab
    let crossfades: Bool
    let duration: TimeInterval
    let onEdgeSwipe: (_ offset: Int) -> Void
    let makePane: (PillieTab) -> AnyView

    func makeUIViewController(context: Context) -> TabPaneContainerViewController {
        let controller = TabPaneContainerViewController(
            panes: PillieTab.allCases.map { tab in
                (tab, UIHostingController(rootView: makePane(tab)))
            }
        )
        controller.onEdgeSwipe = onEdgeSwipe
        controller.select(selectedTab, animated: false, crossfades: crossfades, duration: duration)
        return controller
    }

    func updateUIViewController(_ controller: TabPaneContainerViewController, context: Context) {
        controller.onEdgeSwipe = onEdgeSwipe
        controller.select(selectedTab, animated: true, crossfades: crossfades, duration: duration)
    }
}

final class TabPaneContainerViewController: UIViewController {
    var onEdgeSwipe: ((Int) -> Void)?

    private let panes: [(tab: PillieTab, controller: UIViewController)]
    private var selectedTab: PillieTab?
    private var animator: UIViewPropertyAnimator?

    init(panes: [(PillieTab, UIViewController)]) {
        self.panes = panes.map { (tab: $0.0, controller: $0.1) }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("TabPaneContainerViewController is code-only")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(PillieTheme.bg)
        view.overrideUserInterfaceStyle = .light
        view.clipsToBounds = true

        for pane in panes {
            let child = pane.controller
            addChild(child)
            child.view.frame = view.bounds
            child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            child.view.backgroundColor = UIColor(PillieTheme.bg)
            child.view.isHidden = true
            view.addSubview(child.view)
            child.didMove(toParent: self)
        }

        // A plain pan with an edge-zone check rather than UIScreenEdgePanGestureRecognizer,
        // which does not reliably begin for synthesized touches in the simulator.
        let edgePan = UIPanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        edgePan.maximumNumberOfTouches = 1
        edgePan.delegate = self
        view.addGestureRecognizer(edgePan)
    }

    private static let edgeZone: CGFloat = 30
    private static let swipeThreshold: CGFloat = 50

    private func startedEdge(of gesture: UIPanGestureRecognizer) -> UIRectEdge? {
        let x = gesture.location(in: view).x - gesture.translation(in: view).x
        if x < Self.edgeZone { return .left }
        if x > view.bounds.width - Self.edgeZone { return .right }
        return nil
    }

    func select(_ tab: PillieTab, animated: Bool, crossfades: Bool, duration: TimeInterval) {
        guard tab != selectedTab else { return }
        guard let incoming = paneView(for: tab) else { return }
        let previousTab = selectedTab
        let outgoing = previousTab.flatMap(paneView(for:))
        selectedTab = tab

        // A tap mid-transition lands the running one on its end state first so the
        // new animation starts from settled geometry rather than a partial offset.
        if let animator {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .end)
        }

        incoming.isHidden = false
        view.bringSubviewToFront(incoming)

        guard animated, let outgoing, let previousTab, outgoing !== incoming, view.bounds.width > 0 else {
            settlePanes()
            return
        }

        let width = view.bounds.width
        let direction: CGFloat = tab.rawValue > previousTab.rawValue ? 1 : -1
        if crossfades {
            incoming.alpha = 0
        } else {
            incoming.transform = CGAffineTransform(translationX: direction * width, y: 0)
            outgoing.transform = .identity
        }

        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) {
            if crossfades {
                incoming.alpha = 1
            } else {
                incoming.transform = .identity
                outgoing.transform = CGAffineTransform(translationX: -direction * width, y: 0)
            }
        }
        animator.addCompletion { [weak self] _ in
            self?.animator = nil
            self?.settlePanes()
        }
        animator.startAnimation()
        self.animator = animator
    }

    /// Final state after any transition: only the selected pane is visible and
    /// every pane is back at identity, so the next switch starts clean.
    private func settlePanes() {
        for pane in panes {
            let paneView = pane.controller.view!
            paneView.transform = .identity
            paneView.alpha = 1
            paneView.isHidden = pane.tab != selectedTab
        }
    }

    private func paneView(for tab: PillieTab) -> UIView? {
        panes.first { $0.tab == tab }?.controller.view
    }

    @objc private func handleEdgePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .ended, let edge = startedEdge(of: gesture) else { return }
        let translation = gesture.translation(in: view).x
        if edge == .left, translation > Self.swipeThreshold {
            onEdgeSwipe?(-1)
        } else if edge == .right, translation < -Self.swipeThreshold {
            onEdgeSwipe?(1)
        }
    }
}

extension TabPaneContainerViewController: UIGestureRecognizerDelegate {
    /// Only claim pans that start in the edge zone and move mostly horizontally;
    /// everything else fails immediately so pane scroll views behave normally.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              startedEdge(of: pan) != nil else { return false }
        let translation = pan.translation(in: view)
        return abs(translation.x) > abs(translation.y)
    }

    /// Same arrangement UIKit uses for the navigation pop gesture: pans inside the
    /// panes (scroll views, the History month drag) wait for an edge pan to fail,
    /// so a swipe that starts at the screen edge always reaches the tab switch.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
