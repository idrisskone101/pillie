//
//  PillieTabBar.swift
//  Pillie
//

import SwiftUI
import SwiftData

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
    @Environment(\.locale) private var locale
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
                            .overlay(alignment: .topTrailing) {
                                if badgedTabs.contains(tab) {
                                    badgePip
                                }
                            }

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

                        Text(tab.label(locale: locale))
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
        .animation(PillieMotion.animation(for: .quick), value: selectedTab)
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
                badgedTabs: historyDiscoveryDismissed ? [] : [.history]
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
