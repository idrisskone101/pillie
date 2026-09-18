//
//  TabSwitchFrameProbe.swift
//  Pillie
//

#if DEBUG || PILLIE_FRAME_PROBE
import Foundation
import QuartzCore
import os

extension Notification.Name {
    static let pillieMeasureNavigateMonth = Notification.Name("pillieMeasureNavigateMonth")
}

/// Measures the main-thread frame cadence of tab transitions, calendar month
/// swipes, and idle windows. Launch arguments drive scripted loops so the
/// numbers are reproducible on a simulator or a device without touch automation:
///
///   `-PillieTabSwitchLoop 1`
///   `-PillieCalendarSwipeLoop 1`
///   `-PillieIdleFrameProbe 1`
///
/// Compiled only for DEBUG or the explicit `PILLIE_FRAME_PROBE` condition, so
/// Release builds carry none of it.
///
/// Read the results from the process console or the `frames` OSLog category:
///   `PILLIE_FRAMES <label> frames=<n> dropped=<n> worst=<ms>ms`
///   `PILLIE_LAYOUT calendar key=<month> value=<pt>`
///   `PILLIE_FRAMES SUMMARY transitions=<n> clean=<n> dropped=<n> worst=<ms>ms`
///   `PILLIE_FRAMES_JSON {...}`
@MainActor
final class TabSwitchFrameProbe: NSObject {
    static let shared = TabSwitchFrameProbe()

    static var isLoopRequested: Bool {
        UserDefaults.standard.bool(forKey: "PillieTabSwitchLoop")
    }

    static var isCalendarLoopRequested: Bool {
        UserDefaults.standard.bool(forKey: "PillieCalendarSwipeLoop")
    }

    static var isIdleProbeRequested: Bool {
        UserDefaults.standard.bool(forKey: "PillieIdleFrameProbe")
    }

    private struct Result {
        let label: String
        let frames: Int
        let dropped: Int
        let worstGapMs: Double
    }

    private let logger = Logger(subsystem: "com.idrisskone.pillie", category: "frames")
    private var displayLink: CADisplayLink?
    private var windowEnd: CFTimeInterval = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var frames = 0
    private var dropped = 0
    private var worstGapMs = 0.0
    private var label = ""
    private var results: [Result] = []
    private var layoutSamples: [String: [Double]] = [:]

    /// Opens a measurement window covering the transition plus a short tail so
    /// the settle frames are counted too.
    func beginTransition(label: String, duration: TimeInterval) {
        if windowEnd > 0 {
            finishWindow()
        }
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            // A default display link is paced at 60Hz on ProMotion and would hide
            // the rate the transition itself is actually running at.
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        self.label = label
        frames = 0
        dropped = 0
        worstGapMs = 0
        lastTimestamp = 0
        windowEnd = CACurrentMediaTime() + duration + 0.1
    }

    func recordLayout(name: String, key: String, value: Double) {
        layoutSamples[name, default: []].append(value)
        emit("PILLIE_LAYOUT \(name) key=\(key) value=\(String(format: "%.1f", value))")
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard windowEnd > 0 else { return }
        if lastTimestamp > 0 {
            let gap = link.timestamp - lastTimestamp
            let expected = max(link.targetTimestamp - link.timestamp, 1.0 / 120.0)
            frames += 1
            if gap > expected * 1.5 {
                dropped += max(Int((gap / expected).rounded()) - 1, 1)
            }
            worstGapMs = max(worstGapMs, gap * 1000)
        }
        lastTimestamp = link.timestamp
        if link.timestamp >= windowEnd {
            finishWindow()
        }
    }

    private func finishWindow() {
        let result = Result(label: label, frames: frames, dropped: dropped, worstGapMs: worstGapMs)
        results.append(result)
        windowEnd = 0
        emit("PILLIE_FRAMES \(result.label) frames=\(result.frames) dropped=\(result.dropped) worst=\(String(format: "%.1f", result.worstGapMs))ms")
    }

    private func emitSummary() {
        let clean = results.filter { $0.dropped == 0 }.count
        let dropped = results.reduce(0) { $0 + $1.dropped }
        let worst = results.map(\.worstGapMs).max() ?? 0
        emit("PILLIE_FRAMES SUMMARY transitions=\(results.count) clean=\(clean) dropped=\(dropped) worst=\(String(format: "%.1f", worst))ms")
        emitJSON(clean: clean, dropped: dropped, worst: worst)
    }

    private func emitJSON(clean: Int, dropped: Int, worst: Double) {
        let heights = layoutSamples["calendar"] ?? []
        let shift = (heights.max() ?? 0) - (heights.min() ?? 0)
        let payload: [String: Any] = [
            "transitions": results.count,
            "clean": clean,
            "dropped": dropped,
            "worst_ms": worst,
            "calendar_height_shift_pt": shift,
            "calendar_height_samples": heights,
            "windows": results.map { result in
                [
                    "label": result.label,
                    "frames": result.frames,
                    "dropped": result.dropped,
                    "worst_ms": result.worstGapMs,
                ] as [String: Any]
            },
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        emit("PILLIE_FRAMES_JSON \(json)")
    }

    private func emit(_ line: String) {
        print(line)
        logger.notice("\(line, privacy: .public)")
    }

    // MARK: - Scripted loops

    /// Home → History → Settings → History → Home → Settings → Home, repeated,
    /// so every adjacent and skip-a-tab direction is exercised.
    private static let loopSequence: [PillieTab] = [
        .history, .settings, .history, .home, .settings, .home,
    ]

    func runLoop(rounds: Int = 3, switchTo: @escaping (PillieTab) -> Void) async {
        results.removeAll()
        layoutSamples.removeAll()
        // Let the launch splash clear and the first frame settle.
        try? await Task.sleep(for: .seconds(3))
        for _ in 0..<rounds {
            for tab in Self.loopSequence {
                switchTo(tab)
                try? await Task.sleep(for: .milliseconds(900))
            }
        }
        try? await Task.sleep(for: .milliseconds(500))
        if windowEnd > 0 {
            finishWindow()
        }
        emitSummary()
    }

    /// Forward and back month changes, repeated, after the caller has already
    /// switched to History so the grid is on screen.
    func runCalendarLoop(rounds: Int = 3, swipe: @escaping (Int) -> Void) async {
        results.removeAll()
        layoutSamples.removeAll()
        try? await Task.sleep(for: .seconds(1))
        let sequence = [1, 1, -1, -1, 1, -1]
        for _ in 0..<rounds {
            for delta in sequence {
                beginTransition(label: delta > 0 ? "month+1" : "month-1", duration: 0.55)
                swipe(delta)
                try? await Task.sleep(for: .milliseconds(800))
            }
        }
        try? await Task.sleep(for: .milliseconds(400))
        if windowEnd > 0 {
            finishWindow()
        }
        emitSummary()
    }

    func runIdleWindow(seconds: TimeInterval = 2) async {
        results.removeAll()
        layoutSamples.removeAll()
        try? await Task.sleep(for: .seconds(2))
        beginTransition(label: "idle", duration: seconds)
        try? await Task.sleep(for: .seconds(seconds + 0.3))
        if windowEnd > 0 {
            finishWindow()
        }
        emitSummary()
    }
}
#endif
