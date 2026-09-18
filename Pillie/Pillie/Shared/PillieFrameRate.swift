//
//  PillieFrameRate.swift
//  Pillie
//

import QuartzCore

enum PillieFrameRate {
    /// Ask Core Animation for 80–120 Hz on ProMotion. A 60 Hz display stays at 60.
    static let promotional = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
}
