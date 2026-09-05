//
//  TabSwitchFrameProbe.swift
//  Pillie
//

#if DEBUG || PILLIE_FRAME_PROBE
import Foundation
import QuartzCore
import os

/// Measures the main-thread frame cadence of tab transitions and, when the app is
/// launched with `-PillieTabSwitchLoop 1`, drives a scripted switch loop so the
/// numbers are reproducible on a physical device where touch automation is not
/// available. Compiled only for DEBUG or the explicit `PILLIE_FRAME_PROBE`
/// condition, so Release builds carry none of it.
///
/// Read the results from the process console:
///   `PILLIE_FRAMES <label> frames=<n> dropped=<n> worst=<ms>ms`
///   `PILLIE_FRAMES SUMMARY transitions=<n> clean=<n> dropped=<n> worst=<ms>ms`
@MainActor
final class TabSwitchFrameProbe: NSObject {
    static let shared = TabSwitchFrameProbe()

    static var isLoopRequested: Bool {
        UserDefaults.standard.bool(forKey: "PillieTabSwitchLoop")
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
    }

    private func emit(_ line: String) {
        print(line)
        logger.notice("\(line, privacy: .public)")
    }

    // MARK: - Scripted loop

    /// Home → History → Settings → History → Home → Settings → Home, repeated,
    /// so every adjacent and skip-a-tab direction is exercised.
    private static let loopSequence: [PillieTab] = [
        .history, .settings, .history, .home, .settings, .home,
    ]

    func runLoop(rounds: Int = 3, switchTo: @escaping (PillieTab) -> Void) async {
        results.removeAll()
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
}
#endif
