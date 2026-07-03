//
//  BlockerInterventionSharedState.swift
//  Pillie
//
//  App Group persistence for BlockerInterventionCounter (#161). The shield
//  extension (sandboxed, no network) records intercepts here; the main app
//  flushes the unflushed delta to PostHog on next open and later reads the
//  lifetime total for the Trial-End Paywall's own-stats.
//

import Foundation

struct BlockerInterventionSharedState {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = AppGroupConstants.sharedDefaults) {
        self.defaults = defaults
    }

    var counter: BlockerInterventionCounter {
        BlockerInterventionCounter(
            unflushedCount: defaults?.integer(forKey: AppGroupKeys.interventionUnflushedCount) ?? 0,
            lifetimeTotal: defaults?.integer(forKey: AppGroupKeys.interventionLifetimeTotal) ?? 0
        )
    }

    func recordIntercept() {
        var counter = counter
        counter.recordIntercept()
        save(counter)
    }

    /// Resets the persisted delta and returns it for reporting; the lifetime
    /// total stays put.
    func flushUnflushed() -> Int {
        var counter = counter
        let delta = counter.flush()
        save(counter)
        return delta
    }

    private func save(_ counter: BlockerInterventionCounter) {
        defaults?.set(counter.unflushedCount, forKey: AppGroupKeys.interventionUnflushedCount)
        defaults?.set(counter.lifetimeTotal, forKey: AppGroupKeys.interventionLifetimeTotal)
        defaults?.synchronize()
    }
}
