//
//  CustomPackEditorTypes.swift
//  Pillie
//

import CoreGraphics
import Foundation

/// The custom pack editor's working values. The break kind is kept apart from the
/// regimen so "No pills" survives stepping the break down to 0 and back up.
struct CustomPackDraft: Equatable {
    enum PreviewLayout: Equatable {
        case grid
        case map

        static let gridMaxDays = 35

        init(totalDays: Int) {
            self = totalDays <= Self.gridMaxDays ? .grid : .map
        }
    }

    static let activeRange = PackRegimen.activeDayRange
    static let typedDigitLimit = 3

    private(set) var activeDays: Int
    private(set) var breakDays: Int
    private(set) var breakKind: PackRegimen.BreakKind

    init(_ regimen: PackRegimen) {
        activeDays = regimen.activeDays
        breakDays = regimen.breakDays
        breakKind = regimen.breakKind
    }

    var breakRange: ClosedRange<Int> {
        0...min(PackRegimen.maxBreakDays, PackRegimen.maxTotalDays - activeDays)
    }

    var regimen: PackRegimen {
        PackRegimen(activeDays: activeDays, breakDays: breakDays, breakKind: breakKind)
    }

    var choice: PackChoice { PackChoice(regimen) }

    var totalDays: Int { activeDays + breakDays }

    var layout: PreviewLayout { PreviewLayout(totalDays: totalDays) }

    mutating func stepActive(by delta: Int) {
        setActive(activeDays + delta)
    }

    mutating func setActiveDays(typed value: Int) {
        setActive(value)
    }

    mutating func stepBreak(by delta: Int) {
        breakDays = (breakDays + delta).clamped(to: breakRange)
    }

    mutating func setBreakKind(_ kind: PackRegimen.BreakKind) {
        breakKind = kind
    }

    private mutating func setActive(_ value: Int) {
        activeDays = value.clamped(to: Self.activeRange)
        breakDays = min(breakDays, breakRange.upperBound)
    }

    func caption(locale: Locale = .current) -> String {
        let total = totalDays
        let wholeWeeks = total % 7 == 0
        switch (layout, wholeWeeks) {
        case (.grid, true) where total == 7:
            return PillieLocalization.formatted("custom_pack.preview.grid_week", locale: locale, arguments: total)
        case (.grid, true):
            return PillieLocalization.formatted("custom_pack.preview.grid_weeks", locale: locale, arguments: total, total / 7)
        case (.grid, false):
            return PillieLocalization.formatted("custom_pack.preview.grid_days", locale: locale, arguments: total)
        case (.map, true):
            return PillieLocalization.formatted("custom_pack.preview.map_weeks", locale: locale, arguments: total, total / 7)
        case (.map, false):
            let weeks = Int((Double(total) / 7).rounded())
            return PillieLocalization.formatted("custom_pack.preview.map_about", locale: locale, arguments: total, weeks)
        }
    }

    /// What the active-days field keeps while typing: digits only, at most three,
    /// and anything above the cap becomes the cap.
    static func sanitizedTyping(_ text: String) -> String {
        let digits = String(text.filter(\.isASCIIDigit).prefix(typedDigitLimit))
        guard let value = Int(digits), value > activeRange.upperBound else { return digits }
        return String(activeRange.upperBound)
    }
}

/// Dot map geometry for long packs: one column per week, seven rows, shrunk
/// uniformly so the widest pack still fits the card.
struct CustomPackMapMetrics: Equatable {
    static let maxDot: CGFloat = 15
    static let maxGap: CGFloat = 5.2
    static let rows = 7

    let columns: Int
    let pitch: CGFloat

    init(columns: Int, availableWidth: CGFloat) {
        self.columns = max(columns, 1)
        let widest = availableWidth / CGFloat(self.columns)
        pitch = min(Self.maxDot + Self.maxGap, widest)
    }

    var dot: CGFloat { pitch * Self.maxDot / (Self.maxDot + Self.maxGap) }

    var size: CGSize {
        CGSize(width: pitch * CGFloat(columns) - (pitch - dot), height: pitch * CGFloat(Self.rows) - (pitch - dot))
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
