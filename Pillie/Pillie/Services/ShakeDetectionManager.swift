//
//  ShakeDetectionManager.swift
//  Pillie
//

import Foundation
import Observation
#if os(iOS)
import CoreMotion
#endif

@Observable
final class ShakeDetectionManager {

    // MARK: - Configuration

    let requiredShakes: Int

    init(requiredShakes: Int = 3) {
        self.requiredShakes = requiredShakes
    }

    // MARK: - Published State

    private(set) var shakeCount: Int = 0

    var isComplete: Bool { shakeCount >= requiredShakes }
    var progress: Double { min(Double(shakeCount) / Double(requiredShakes), 1.0) }

    // MARK: - Private

    #if os(iOS)
    private let motionManager = CMMotionManager()
    #endif
    private var lastShakeTime: Date = .distantPast
    private let shakeThreshold: Double = 1.8
    private let shakeCooldown: TimeInterval = 0.3

    // MARK: - Public API

    func startDetecting() {
        shakeCount = 0

        #if targetEnvironment(simulator)
        // CoreMotion doesn't work on simulator — use tap fallback
        return
        #else
        #if os(iOS)
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 30.0
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.processAcceleration(data.acceleration)
        }
        #endif
        #endif
    }

    func stopDetecting() {
        #if os(iOS)
        motionManager.stopAccelerometerUpdates()
        #endif
    }

    func reset() {
        shakeCount = 0
        lastShakeTime = .distantPast
    }

    /// Simulator fallback — call this on tap to simulate a shake.
    func simulateShake() {
        registerShake()
    }

    /// Instantly fill progress to complete (used by tap-to-confirm alternative).
    func fillToComplete() {
        shakeCount = requiredShakes
    }

    // MARK: - Private

    #if os(iOS)
    private func processAcceleration(_ acceleration: CMAcceleration) {
        let magnitude = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )
        if magnitude > shakeThreshold {
            registerShake()
        }
    }
    #endif

    private func registerShake() {
        let now = Date()
        guard now.timeIntervalSince(lastShakeTime) >= shakeCooldown else { return }
        lastShakeTime = now
        guard !isComplete else { return }
        shakeCount += 1
    }
}
