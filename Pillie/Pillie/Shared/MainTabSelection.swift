//
//  MainTabSelection.swift
//  Pillie
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class MainTabSelection: ObservableObject {
    @Published private(set) var selectedTab: PillieTab
    @Published private(set) var tabDirection: Edge = .trailing

    private let feedback: InteractionFeedback
    private let trackSelectedTab: (ProductAnalyticsTelemetry.MainTab) -> Void

    init(
        initialTab: PillieTab = .home,
        feedback: InteractionFeedback = .live,
        trackSelectedTab: @escaping (ProductAnalyticsTelemetry.MainTab) -> Void = {
            ProductAnalyticsTelemetry.live.mainTabSelected($0)
        }
    ) {
        self.selectedTab = initialTab
        self.feedback = feedback
        self.trackSelectedTab = trackSelectedTab
    }

    @discardableResult
    func select(_ newTab: PillieTab) -> Bool {
        guard newTab != selectedTab else { return false }

        tabDirection = newTab.rawValue > selectedTab.rawValue ? .leading : .trailing
        selectedTab = newTab
        feedback.perform(.tabChange)
        trackSelectedTab(newTab.analyticsTab)
        return true
    }

    func navigate(by offset: Int) -> Bool {
        let allTabs = PillieTab.allCases
        guard let idx = allTabs.firstIndex(of: selectedTab) else { return false }
        let newIndex = idx + offset
        guard allTabs.indices.contains(newIndex) else { return false }
        return select(allTabs[newIndex])
    }
}

extension PillieTab {
    var analyticsTab: ProductAnalyticsTelemetry.MainTab {
        switch self {
        case .home: return .today
        case .history: return .history
        case .settings: return .settings
        }
    }
}
