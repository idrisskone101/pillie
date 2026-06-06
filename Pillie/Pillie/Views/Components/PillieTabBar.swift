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
    @StateObject private var tabSelection = MainTabSelection()
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    private let performanceTier = PerformanceTier.current

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                if tabSelection.selectedTab == .home {
                    HomeView()
                        .transition(tabSlideTransition)
                }
                if tabSelection.selectedTab == .history {
                    HistoryView()
                        .transition(tabSlideTransition)
                }
                if tabSelection.selectedTab == .settings {
                    SettingsView()
                        .transition(tabSlideTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .gesture(edgeSwipeGesture)

            PillieTabBar(selectedTab: tabBinding)
        }
        .background(PillieTheme.bg.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: - Tab Slide Transition

    private var tabSlideTransition: AnyTransition {
        if accessibilityReduceMotion || performanceTier == .constrained {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: tabSelection.tabDirection),
            removal: .move(edge: tabSelection.tabDirection == .trailing ? .leading : .trailing)
        )
    }

    private var tabTransitionAnimation: Animation {
        PillieMotion.animation(
            for: .standard,
            accessibilityReduceMotion: accessibilityReduceMotion,
            performanceTier: performanceTier
        )
    }

    /// Custom binding that sets slide direction before updating the selected tab.
    private var tabBinding: Binding<PillieTab> {
        Binding(
            get: { tabSelection.selectedTab },
            set: { newTab in
                withAnimation(tabTransitionAnimation) {
                    _ = tabSelection.select(newTab)
                }
            }
        )
    }

    // MARK: - Edge Swipe

    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let startX = value.startLocation.x
                let screenWidth = UIScreen.main.bounds.width
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
        withAnimation(tabTransitionAnimation) {
            _ = tabSelection.navigate(by: offset)
        }
    }
}

#Preview {
    MainTabView()
        .environment(PillStore.previewStore())
}
