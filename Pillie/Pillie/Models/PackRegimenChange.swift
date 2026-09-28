//
//  PackRegimenChange.swift
//  Pillie
//

import Foundation

/// What switching the running pill pack to another regimen does to today's place in it.
enum PackRegimenChange: Equatable, Sendable {
    case unchanged
    /// Today's pill number fits the new pack, so the anchor stays and only the regimen changes.
    case keepAnchor
    /// The pack re-anchors so today lands on this 0-based index.
    case moveToday(toIndex: Int)

    /// `elapsedDays` and `anchorIndex` come from the pack before the change
    /// (`PillPack.elapsedCycleDays(on:)` and its normalized `cycleDayAnchorIndex`).
    static func resolve(
        from current: PackRegimen,
        to next: PackRegimen,
        elapsedDays: Int,
        anchorIndex: Int
    ) -> PackRegimenChange {
        guard current != next else { return .unchanged }
        // A finished pack has no pill number to keep; it stays finished until Start new.
        let isFinished = elapsedDays >= current.totalDays
        let todayIndex = isFinished ? elapsedDays : min(elapsedDays, next.totalDays - 1)
        // The anchor is stored modulo the pack length, so one past the new length would move today.
        if todayIndex == elapsedDays, anchorIndex < next.totalDays {
            return .keepAnchor
        }
        return .moveToday(toIndex: todayIndex)
    }
}
