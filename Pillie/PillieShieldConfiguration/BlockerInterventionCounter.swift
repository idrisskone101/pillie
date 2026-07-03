//
//  BlockerInterventionCounter.swift
//  Shared counting logic — keep in sync with Pillie/Shared/BlockerInterventionCounter.swift
//
//  Counts shield intercepts (#161 / ADR 0007). The shield extension is
//  sandboxed with no network, so intercepts accumulate as an unflushed delta
//  the main app sends to PostHog on next open; the lifetime total is kept
//  separately so the Trial-End Paywall's own-stats survive every flush.
//  Coarse counts only — no app names, no routine details.
//

import Foundation

struct BlockerInterventionCounter: Equatable {
    private(set) var unflushedCount: Int
    private(set) var lifetimeTotal: Int

    init(unflushedCount: Int = 0, lifetimeTotal: Int = 0) {
        self.unflushedCount = max(0, unflushedCount)
        self.lifetimeTotal = max(0, lifetimeTotal)
    }

    mutating func recordIntercept() {
        unflushedCount += 1
        lifetimeTotal += 1
    }

    /// Returns the accumulated delta to report and resets it; the lifetime
    /// total is untouched.
    mutating func flush() -> Int {
        let delta = unflushedCount
        unflushedCount = 0
        return delta
    }
}
