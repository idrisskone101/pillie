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
        HStack {
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

                        Text(tab.label(locale: locale))
                            .font(.pillie(10, weight: selectedTab == tab ? .bold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? PillieTheme.coral : PillieTheme.textMuted.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            TabIndicatorCapsule(
                selectedIndex: selectedTab.rawValue,
                tabCount: PillieTab.allCases.count,
                duration: transitionDuration
            )
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
        .animation(.easeInOut(duration: transitionDuration), value: selectedTab)
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

private struct TabIndicatorCapsule: UIViewRepresentable {
    var selectedIndex: Int
    var tabCount: Int
    var duration: TimeInterval

    func makeUIView(context: Context) -> TabIndicatorView {
        TabIndicatorView(tabCount: tabCount)
    }

    func updateUIView(_ view: TabIndicatorView, context: Context) {
        view.tabCount = tabCount
        view.select(index: selectedIndex, duration: duration)
    }
}

private final class TabIndicatorView: UIView {
    private let capsule = UIView()
    private var selectedIndex = 0
    private var animator: UIViewPropertyAnimator?
    var tabCount: Int

    private static let capsuleSize = CGSize(width: 20, height: 5)
    private static let iconPointSize: CGFloat = 22
    private static let iconToCapsuleSpacing: CGFloat = 4

    init(tabCount: Int) {
        self.tabCount = tabCount
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        capsule.backgroundColor = UIColor(PillieTheme.coral)
        capsule.layer.cornerRadius = Self.capsuleSize.height / 2
        addSubview(capsule)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("TabIndicatorView is code-only")
    }

    func select(index: Int, duration: TimeInterval) {
        let changed = index != selectedIndex
        selectedIndex = index
        guard bounds.width > 0 else { return }
        let target = capsuleFrame(for: index)
        if !changed {
            if animator?.state != .active {
                capsule.frame = target
            }
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
        let running = animator?.state == .active
        if !running {
            capsule.frame = capsuleFrame(for: selectedIndex)
        }
    }

    private func capsuleFrame(for index: Int) -> CGRect {
        let slotWidth = bounds.width / CGFloat(tabCount)
        let size = Self.capsuleSize
        let x = slotWidth * (CGFloat(index) + 0.5) - size.width / 2
        let y = Self.iconPointSize + Self.iconToCapsuleSpacing
        return CGRect(x: x, y: y, width: size.width, height: size.height)
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
