//
//  PerformanceTier.swift
//  Pillie
//

import Foundation

/// Runtime performance bucket used to adapt animation/rendering cost.
enum PerformanceTier {
    case constrained
    case standard

    static var current: PerformanceTier {
        let info = ProcessInfo.processInfo

        if info.isLowPowerModeEnabled {
            return .constrained
        }

        if info.thermalState == .serious || info.thermalState == .critical {
            return .constrained
        }

        // iPhone XR/11 class devices have limited RAM headroom for animated blur-heavy screens.
        if info.physicalMemory <= 3_500_000_000 {
            return .constrained
        }

        return .standard
    }
}
