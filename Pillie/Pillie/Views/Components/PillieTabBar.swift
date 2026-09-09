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

struct PillieTabBar: View {
    @Binding var selectedTab: PillieTab
    /// Tabs that show an unread pip on their icon. Owned by the caller so the
    /// bar stays ignorant of which feature is being announced.
    var badgedTabs: Set<PillieTab> = []
    var transitionDuration: TimeInterval = 0.25
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PillieTab.allCases, id: \.rawValue) { tab in
                Button {
                    guard selectedTab != tab else { return }
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                            .overlay(alignment: .topTrailing) {
                                if badgedTabs.contains(tab) {
                                    badgePip
                                }
                            }

                        Color.clear
                            .frame(width: 20, height: 5)
                            .anchorPreference(key: TabIndicatorSlotKey.self, value: .bounds) {
                                [tab: $0]
                            }

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
        .overlayPreferenceValue(TabIndicatorSlotKey.self) { anchors in
            GeometryReader { geo in
                TabIndicatorCapsule(
                    selectedIndex: selectedTab.rawValue,
                    slots: PillieTab.allCases.map { tab in
                        anchors[tab].map { geo[$0] } ?? .zero
                    },
                    duration: transitionDuration
                )
            }
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

/// Each tab reports the 20×5 slot under its icon so the capsule can sit on
/// the real layout instead of assuming equal-width thirds.
private struct TabIndicatorSlotKey: PreferenceKey {
    static var defaultValue: [PillieTab: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [PillieTab: Anchor<CGRect>],
        nextValue: () -> [PillieTab: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Same `UIViewPropertyAnimator` duration and curve as `TabPaneContainer`, so
/// the capsule travels with the sliding pane instead of a slower SwiftUI morph.
private struct TabIndicatorCapsule: UIViewRepresentable {
    var selectedIndex: Int
    var slots: [CGRect]
    var duration: TimeInterval

    func makeUIView(context: Context) -> TabIndicatorView {
        TabIndicatorView()
    }

    func updateUIView(_ view: TabIndicatorView, context: Context) {
        view.select(index: selectedIndex, slots: slots, duration: duration)
    }
}

private final class TabIndicatorView: UIView {
    private let capsule = UIView()
    private var selectedIndex = 0
    private var slots: [CGRect] = []
    private var animator: UIViewPropertyAnimator?

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

    func select(index: Int, slots: [CGRect], duration: TimeInterval) {
        let indexChanged = index != selectedIndex
        selectedIndex = index
        self.slots = slots

        guard let target = slotFrame(at: index) else { return }

        if !indexChanged {
            if animator?.state != .active {
                capsule.frame = target
            }
            return
        }

        if capsule.bounds.isEmpty {
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
        guard animator?.state != .active, let target = slotFrame(at: selectedIndex) else { return }
        capsule.frame = target
    }

    private func slotFrame(at index: Int) -> CGRect? {
        guard slots.indices.contains(index) else { return nil }
        let frame = slots[index]
        return frame.isEmpty ? nil : frame
    }
}

struct MainTabView: View {
    @State private var selectedTab: PillieTab = .home
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
                makePane: pane(for:)
            )
            // Full-bleed so UIKit hands each pane its real safe-area insets and the
            // slide carries the status-bar band along with the content.
            .ignoresSafeArea()

            PillieTabBar(
                selectedTab: tabBinding,
                badgedTabs: historyDiscoveryDismissed ? [] : [.history],
                transitionDuration: tabTransitionDuration
            )
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .bottom)
        #if DEBUG || PILLIE_FRAME_PROBE
        .task {
            guard TabSwitchFrameProbe.isLoopRequested else { return }
            await TabSwitchFrameProbe.shared.runLoop { switchTab(to: $0) }
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
