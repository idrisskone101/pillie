//
//  PillieMotion.swift
//  Pillie
//

import Foundation
import SwiftUI

enum PillieMotion {
    enum Semantic: CaseIterable, Equatable {
        case quick
        case standard
        case entrance
        case commitSpring
        case rewardSpring
    }

    enum Curve: Equatable {
        case easeInOut
        case timingCurve
        case spring
    }

    struct Profile: Equatable {
        let curve: Curve
        let duration: Double
        let response: Double?
        let dampingFraction: Double?
        let usesCalmerSpatialMotion: Bool

        var animation: Animation {
            switch curve {
            case .easeInOut:
                return .easeInOut(duration: duration)
            case .timingCurve:
                return .timingCurve(0.2, 0.8, 0.2, 1.0, duration: duration)
            case .spring:
                return .spring(
                    response: response ?? duration,
                    dampingFraction: dampingFraction ?? 0.78
                )
            }
        }
    }

    static func profile(
        for semantic: Semantic,
        accessibilityReduceMotion: Bool = false,
        performanceTier: PerformanceTier = .standard
    ) -> Profile {
        if accessibilityReduceMotion || performanceTier == .constrained {
            return calmerProfile(for: semantic)
        }

        switch semantic {
        case .quick:
            return Profile(
                curve: .easeInOut,
                duration: 0.16,
                response: nil,
                dampingFraction: nil,
                usesCalmerSpatialMotion: false
            )
        case .standard:
            return Profile(
                curve: .easeInOut,
                duration: 0.25,
                response: nil,
                dampingFraction: nil,
                usesCalmerSpatialMotion: false
            )
        case .entrance:
            return Profile(
                curve: .timingCurve,
                duration: 0.5,
                response: nil,
                dampingFraction: nil,
                usesCalmerSpatialMotion: false
            )
        case .commitSpring:
            return Profile(
                curve: .spring,
                duration: 0.3,
                response: 0.3,
                dampingFraction: 0.7,
                usesCalmerSpatialMotion: false
            )
        case .rewardSpring:
            return Profile(
                curve: .spring,
                duration: 0.35,
                response: 0.35,
                dampingFraction: 0.6,
                usesCalmerSpatialMotion: false
            )
        }
    }

    static func animation(
        for semantic: Semantic,
        accessibilityReduceMotion: Bool = false,
        performanceTier: PerformanceTier = .standard
    ) -> Animation {
        profile(
            for: semantic,
            accessibilityReduceMotion: accessibilityReduceMotion,
            performanceTier: performanceTier
        ).animation
    }

    private static func calmerProfile(for semantic: Semantic) -> Profile {
        let duration: Double
        switch semantic {
        case .quick:
            duration = 0.12
        case .standard, .commitSpring, .rewardSpring:
            duration = 0.16
        case .entrance:
            duration = 0.22
        }

        return Profile(
            curve: .easeInOut,
            duration: duration,
            response: nil,
            dampingFraction: nil,
            usesCalmerSpatialMotion: true
        )
    }
}
