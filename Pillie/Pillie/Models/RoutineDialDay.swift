//
//  RoutineDialDay.swift
//  Pillie
//

import Foundation

enum RoutineDialMethod: String, Codable, CaseIterable {
    case patch
    case ring

    init?(_ method: ContraceptiveMethod) {
        switch method {
        case .pill: return nil
        case .patch: self = .patch
        case .ring: self = .ring
        }
    }

    var contraceptiveMethod: ContraceptiveMethod {
        switch self {
        case .patch: .patch
        case .ring: .ring
        }
    }
}

struct RoutineDialDay: Equatable {
    enum Phase: Equatable {
        case wearing
        case free
    }

    enum Task: Equatable {
        case putOn
        case takeOff
    }

    static let cycleLength = 28
    static let wearingDays = 21
    static let daysPerPatch = 7
    static let patchCount = wearingDays / daysPerPatch

    let cycleDay: Int
    let phase: Phase
    let patchNumber: Int?
    let task: Task?

    /// Cycle days 1...28 that carry a task: 1, 8, 15, 22 for the patch; 1, 22 for the ring.
    static func taskDays(method: RoutineDialMethod) -> [Int] {
        (1...cycleLength).filter { day($0, method: method).task != nil }
    }

    static func day(_ cycleDay: Int, method: RoutineDialMethod) -> RoutineDialDay {
        precondition((1...cycleLength).contains(cycleDay), "cycle day \(cycleDay) is outside 1...\(cycleLength)")
        let isWearing = cycleDay <= wearingDays
        let task: Task? = switch (method, cycleDay) {
        case (_, wearingDays + 1): .takeOff
        case (.patch, _) where isWearing && (cycleDay - 1) % daysPerPatch == 0: .putOn
        case (.ring, 1): .putOn
        default: nil
        }
        return RoutineDialDay(
            cycleDay: cycleDay,
            phase: isWearing ? .wearing : .free,
            patchNumber: method == .patch && isWearing ? (cycleDay - 1) / daysPerPatch + 1 : nil,
            task: task
        )
    }
}
