//
//  PillieTabBar.swift
//  Pillie
//

import SwiftUI
import SwiftData
import UIKit

enum PillieTab: Int, CaseIterable {
    case home
    case history
    case settings

    func label(locale: Locale = .current) -> String {
        switch self {
        case .home:
            return PillieLocalization.string("today.navigation.title", locale: locale)
        case .history:
            return PillieLocalization.string("history.navigation.title", locale: locale)
        case .settings:
            return PillieLocalization.string("settings.navigation.title", locale: locale)
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .history: return "calendar"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
final class TabIndicatorControl {
    weak var view: TabIndicatorView?

    func select(index: Int, tabCount: Int, duration: TimeInterval, animated: Bool) {
        view?.select(index: index, tabCount: tabCount, duration: duration, animated: animated)
    }
}

private enum TabIndicatorLayout {
    static let iconSize: CGFloat = 22
    static let iconSpacing: CGFloat = 8
    static let size = CGSize(width: 20, height: 5)
    static let labelSpacing: CGFloat = 4

    static var topInset: CGFloat { iconSize + iconSpacing }
}

struct PillieTabBar: View {
    @Binding var selectedTab: PillieTab
    /// Tabs that show an unread pip on their icon. Owned by the caller so the
    /// bar stays ignorant of which feature is being announced.
    var badgedTabs: Set<PillieTab> = []
    var transitionDuration: TimeInterval = 0.25
    var indicator: TabIndicatorControl
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PillieTab.allCases, id: \.rawValue) { tab in
                Button {
                    guard selectedTab != tab else { return }
                    selectedTab = tab
                } label: {
                    VStack(spacing: 0) {
                        Image(systemName: tab.icon)
                            .font(.system(size: TabIndicatorLayout.iconSize))
                            .frame(
                                width: TabIndicatorLayout.iconSize,
                                height: TabIndicatorLayout.iconSize
                            )
                            .overlay(alignment: .topTrailing) {
                                if badgedTabs.contains(tab) {
                                    badgePip
                                }
                            }

                        Color.clear
                            .frame(height: TabIndicatorLayout.iconSpacing)

                        Color.clear
                            .frame(
                                width: TabIndicatorLayout.size.width,
                                height: TabIndicatorLayout.size.height
                            )

                        Color.clear
                            .frame(height: TabIndicatorLayout.labelSpacing)

                        Text(tab.label(locale: locale))
                            .font(.pillie(10, weight: selectedTab == tab ? .bold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? PillieTheme.coral : PillieTheme.textMuted.opacity(0.5))
                    // Color only — wrapping the bar would delay the UIKit capsule.
                    .animation(.easeInOut(duration: transitionDuration), value: selectedTab)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .top) {
            TabIndicatorCapsule(
                selectedIndex: selectedTab.rawValue,
                tabCount: PillieTab.allCases.count,
                duration: transitionDuration,
                control: indicator
            )
            .frame(height: TabIndicatorLayout.size.height)
            .padding(.top, TabIndicatorLayout.topInset)
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 28)
        .background(
            ZStack {
                // Flat fill: the previous material backdrop was 85% covered by white
                // (visually inert) but forced a live blur of the sliding panes on
                // every frame of a tab transition.
                Rectangle()
                    .fill(PillieTheme.bg)
                Rectangle()
                    .fill(.white.opacity(0.85))

                VStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.04))
                        .frame(height: 0.5)
                    Spacer()
                }
            }
        )
        .animation(PillieMotion.animation(for: .quick), value: badgedTabs)
    }

    /// Sits on the icon's top-trailing corner, nudged outward so it reads as a
    /// badge rather than part of the glyph.
    private var badgePip: some View {
        Circle()
            .fill(PillieTheme.coral)
            .overlay {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 1.5)
            }
            .frame(width: 8, height: 8)
            .offset(x: 4, y: -2)
            .accessibilityHidden(true)
            .transition(.opacity)
    }
}

/// Slots are equal-width. The pane container starts this capsule in the same
/// turn as the slide so the pink mark does not wait on a later SwiftUI pass.
private struct TabIndicatorCapsule: UIViewRepresentable {
    var selectedIndex: Int
    var tabCount: Int
    var duration: TimeInterval
    var control: TabIndicatorControl

    func makeUIView(context: Context) -> TabIndicatorView {
        let view = TabIndicatorView()
        control.view = view
        view.adopt(tabCount: tabCount, duration: duration)
        view.place(at: selectedIndex, animated: false)
        return view
    }

    func updateUIView(_ view: TabIndicatorView, context: Context) {
        control.view = view
        view.adopt(tabCount: tabCount, duration: duration)
    }
}

final class TabIndicatorView: UIView {
    private let capsule = UIView()
    private var selectedIndex = 0
    private var tabCount = 1
    private var duration: TimeInterval = 0.25
    private var animator: UIViewPropertyAnimator?
    private var pendingAnimated = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        capsule.backgroundColor = UIColor(PillieTheme.coral)
        capsule.layer.cornerRadius = 2.5
        addSubview(capsule)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("TabIndicatorView is code-only")
    }

    func adopt(tabCount: Int, duration: TimeInterval) {
        self.tabCount = max(tabCount, 1)
        self.duration = duration
    }

    func place(at index: Int, animated: Bool) {
        select(index: index, tabCount: tabCount, duration: duration, animated: animated)
    }

    func select(index: Int, tabCount: Int, duration: TimeInterval, animated: Bool) {
        adopt(tabCount: tabCount, duration: duration)
        let indexChanged = index != selectedIndex
        selectedIndex = index
        let shouldAnimate = animated && indexChanged
        guard bounds.width > 0 else {
            pendingAnimated = shouldAnimate
            return
        }
        moveCapsule(animated: shouldAnimate)
    }

    private func moveCapsule(animated: Bool) {
        pendingAnimated = false
        let target = slotFrame(at: selectedIndex)
        if !animated || capsule.bounds.isEmpty {
            if let animator {
                animator.stopAnimation(true)
                self.animator = nil
            }
            capsule.frame = target
            return
        }

        if let animator {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .end)
        }

        let next = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) { [capsule] in
            capsule.frame = target
        }
        next.addCompletion { [weak self] _ in
            self?.animator = nil
        }
        next.startAnimation()
        animator = next
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        if pendingAnimated {
            moveCapsule(animated: true)
            return
        }
        if animator?.state == .active {
            return
        }
        capsule.frame = slotFrame(at: selectedIndex)
    }

    private func slotFrame(at index: Int) -> CGRect {
        let count = CGFloat(tabCount)
        let tabWidth = bounds.width / count
        let width = TabIndicatorLayout.size.width
        let x = tabWidth * (CGFloat(index) + 0.5) - width / 2
        return CGRect(x: x, y: 0, width: width, height: bounds.height)
    }
}

struct MainTabView: View {
    @State private var selectedTab: PillieTab = .home
    @State private var tabIndicator = TabIndicatorControl()
    @AppStorage(HistoryDiscoveryAnnouncement.storageKey) private var historyDiscoveryDismissed = false
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PillStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    private let performanceTier = PerformanceTier.current

    var body: some View {
        ZStack(alignment: .bottom) {
            // All three panes stay alive inside a UIKit container so a tab switch
            // never rebuilds a screen, and the slide itself is a Core Animation
            // transform — committed once, interpolated off the main thread.
            TabPaneContainer(
                selectedTab: selectedTab,
                crossfades: crossfadesTabs,
                duration: tabTransitionDuration,
                onEdgeSwipe: navigateTab(by:),
                onTransitionStart: { tab, duration, animated in
                    tabIndicator.select(
                        index: tab.rawValue,
                        tabCount: PillieTab.allCases.count,
                        duration: duration,
                        animated: animated
                    )
                },
                makePane: pane(for:)
            )
            // Full-bleed so UIKit hands each pane its real safe-area insets and the
            // slide carries the status-bar band along with the content.
            .ignoresSafeArea()

            PillieTabBar(
                selectedTab: tabBinding,
                badgedTabs: historyDiscoveryDismissed ? [] : [.history],
                transitionDuration: tabTransitionDuration,
                indicator: tabIndicator
            )
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .bottom)
        #if DEBUG || PILLIE_FRAME_PROBE
        .task {
            if TabSwitchFrameProbe.isLoopRequested {
                await TabSwitchFrameProbe.shared.runLoop { switchTab(to: $0) }
                return
            }
            if TabSwitchFrameProbe.isCalendarLoopRequested {
                try? await Task.sleep(for: .seconds(2))
                switchTab(to: .history)
                try? await Task.sleep(for: .seconds(1))
                await TabSwitchFrameProbe.shared.runCalendarLoop { delta in
                    NotificationCenter.default.post(
                        name: .pillieMeasureNavigateMonth,
                        object: nil,
                        userInfo: ["delta": delta]
                    )
                }
                return
            }
            if TabSwitchFrameProbe.isIdleProbeRequested {
                await TabSwitchFrameProbe.shared.runIdleWindow()
            }
        }
        #endif
    }

    /// Each pane is hosted in its own `UIHostingController`, which does not inherit
    /// the SwiftUI environment from this hierarchy, so the app-level values the
    /// panes depend on are re-applied here. The bottom safe area is dropped to
    /// match the container's `ignoresSafeArea`; the tab bar floats over it.
    private func pane(for tab: PillieTab) -> AnyView {
        AnyView(
            paneContent(for: tab)
                .ignoresSafeArea(.container, edges: .bottom)
                .font(.pillieBody())
                .environment(store)
                .modelContainer(modelContext.container)
        )
    }

    @ViewBuilder
    private func paneContent(for tab: PillieTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .history: HistoryView()
        case .settings: SettingsView()
        }
    }

    // MARK: - Tab Slide Transition

    /// Crossfade instead of sliding when motion should stay minimal.
    private var crossfadesTabs: Bool {
        performanceTier == .constrained || accessibilityReduceMotion
    }

    private var tabTransitionDuration: TimeInterval {
        performanceTier == .constrained ? 0.16 : 0.25
    }

    private var tabBinding: Binding<PillieTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                switchTab(to: newTab)
            }
        )
    }

    private func switchTab(to target: PillieTab) {
        guard target != selectedTab else { return }
        #if DEBUG || PILLIE_FRAME_PROBE
        TabSwitchFrameProbe.shared.beginTransition(
            label: "\(selectedTab)->\(target)",
            duration: tabTransitionDuration
        )
        #endif
        // No withAnimation: the container animates the switch in Core Animation.
        selectedTab = target
        InteractionFeedback.live.perform(.tabChange)
        ProductAnalyticsTelemetry.live.mainTabSelected(target.analyticsTab)
    }

    // MARK: - Edge Swipe

    private func navigateTab(by offset: Int) {
        let allTabs = PillieTab.allCases
        guard let idx = allTabs.firstIndex(of: selectedTab) else { return }
        let newIndex = idx + offset
        guard allTabs.indices.contains(newIndex) else { return }
        switchTab(to: allTabs[newIndex])
    }
}

private extension PillieTab {
    var analyticsTab: ProductAnalyticsTelemetry.MainTab {
        switch self {
        case .home: return .today
        case .history: return .history
        case .settings: return .settings
        }
    }
}

#Preview {
    MainTabView()
        .environment(PillStore.previewStore())
        .environment(AppLanguagePreference())
        .modelContainer(PillStore.previewContainer)
}
