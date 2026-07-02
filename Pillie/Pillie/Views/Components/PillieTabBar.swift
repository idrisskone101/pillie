//
//  PillieTabBar.swift
//  Pillie
//

import SwiftUI

enum PillieTab: Int, CaseIterable {
    case home
    case history
    case settings

    var label: String {
        switch self {
        case .home: return "Home"
        case .history: return "History"
        case .settings: return "Settings"
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
    @Namespace private var indicatorNamespace

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

                        if selectedTab == tab {
                            Capsule()
                                .fill(PillieTheme.coral)
                                .matchedGeometryEffect(id: "selected-tab-indicator", in: indicatorNamespace)
                                .frame(width: 20, height: 5)
                                .transition(.opacity)
                        } else {
                            Capsule()
                                .fill(Color.clear)
                                .frame(width: 20, height: 5)
                        }

                        Text(tab.label)
                            .font(.pillie(10, weight: selectedTab == tab ? .bold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? PillieTheme.coral : PillieTheme.textMuted.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 28)
        .background(
            ZStack {
                Rectangle()
                    .fill(.white.opacity(0.85))
                    .background(.ultraThinMaterial)

                VStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.04))
                        .frame(height: 0.5)
                    Spacer()
                }
            }
        )
        .animation(PillieMotion.animation(for: .quick), value: selectedTab)
    }
}

struct MainTabView: View {
    @State private var selectedTab: PillieTab = .home
    @State private var previousTab: PillieTab = .home
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    private let performanceTier = PerformanceTier.current

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                // All three panes stay alive so a tab switch only animates offset and
                // opacity — it never rebuilds a screen (rebuilds caused first-frame
                // hitches and replayed every entrance animation). The transition is a
                // fade with a short directional nudge rather than a full-width slide:
                // dense text sweeping a whole screen shimmers on sample-and-hold
                // displays even at a perfect frame rate, so the content never travels
                // more than `slideNudge` points.
                ZStack {
                    ForEach(PillieTab.allCases, id: \.rawValue) { tab in
                        pane(for: tab)
                            .offset(x: paneOffset(for: tab))
                            .opacity(tab == selectedTab ? 1 : 0)
                            .zIndex(tab == selectedTab ? 2 : (tab == previousTab ? 1 : 0))
                            .allowsHitTesting(tab == selectedTab)
                            .accessibilityHidden(tab != selectedTab)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .gesture(edgeSwipeGesture(screenWidth: proxy.size.width))
            }

            PillieTabBar(selectedTab: tabBinding)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .bottom)
    }

    @ViewBuilder
    private func pane(for tab: PillieTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .history: HistoryView()
        case .settings: SettingsView()
        }
    }

    // MARK: - Tab Transition (fade + directional nudge)

    /// How far a pane rests toward its side of the selected tab. Small on purpose —
    /// enough to read direction, not enough for text to visibly sweep.
    private let slideNudge: CGFloat = 24

    /// Pure crossfade (no nudge) when motion should stay minimal.
    private var crossfadesTabs: Bool {
        performanceTier == .constrained || accessibilityReduceMotion
    }

    private func paneOffset(for tab: PillieTab) -> CGFloat {
        guard !crossfadesTabs, tab != selectedTab else { return 0 }
        return tab.rawValue > selectedTab.rawValue ? slideNudge : -slideNudge
    }

    private var tabTransitionAnimation: Animation {
        performanceTier == .constrained
            ? .easeInOut(duration: 0.16)
            : .spring(response: 0.3, dampingFraction: 0.9)
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
        previousTab = selectedTab
        withAnimation(tabTransitionAnimation) {
            selectedTab = target
        }
        InteractionFeedback.live.perform(.tabChange)
        ProductAnalyticsTelemetry.live.mainTabSelected(target.analyticsTab)
    }

    // MARK: - Edge Swipe

    private func edgeSwipeGesture(screenWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let startX = value.startLocation.x
                let edgeZone: CGFloat = 30
                let tx = value.translation.width

                // Swipe right from left edge → previous tab
                if startX < edgeZone, tx > 50 {
                    navigateTab(by: -1)
                }
                // Swipe left from right edge → next tab
                else if startX > screenWidth - edgeZone, tx < -50 {
                    navigateTab(by: 1)
                }
            }
    }

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
}
