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

    func caption(locale: Locale = PillieLocalization.appLocale) -> String {
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

    /// A keypad digit tap: append then re-sanitize, so an overshoot still clamps.
    static func typingByAppending(_ digit: Int, to typed: String) -> String {
        sanitizedTyping(typed + String(digit))
    }

    /// A keypad backspace tap. Deleting from an empty string stays empty.
    static func typingByDeletingLastDigit(from typed: String) -> String {
        String(typed.dropLast())
    }

    /// Done on the keypad: a parseable entry clamps into range (so "0" becomes
    /// the floor, not a revert); an empty entry reverts to the value typing
    /// started from.
    static func commitTyping(_ typed: String, previousValue: Int) -> Int {
        guard let value = Int(typed) else { return previousValue }
        return value.clamped(to: activeRange)
    }
}

/// Dot map geometry for long packs: one column per week, seven rows. The map always
/// fits a fixed box, so typing a longer pack never changes the preview's height. Weeks
/// wrap into up to three bands, picking whichever split draws the biggest dots.
struct CustomPackMapMetrics: Equatable {
    static let maxDot: CGFloat = 15
    static let maxGap: CGFloat = 5.2
    static let rows = 7
    static let boxHeight: CGFloat = 136.2
    static let bandGap: CGFloat = 10
    static let labelWidth: CGFloat = 10
    static let labelGap: CGFloat = 10
    // Below this a 10 pt weekday letter no longer fits its row.
    static let labelMinPitch: CGFloat = 13
    private static let maxBands = 3

    let bands: Int
    let columnsPerBand: Int
    let pitch: CGFloat
    let showsLabels: Bool

    init(weeks: Int, availableWidth: CGFloat) {
        let weeks = max(weeks, 1)
        let candidates = (1...Self.maxBands).map { bands in
            Self.fit(weeks: weeks, bands: bands, availableWidth: availableWidth)
        }
        self = candidates.max { $0.pitch < $1.pitch } ?? candidates[0]
    }

    private init(bands: Int, columnsPerBand: Int, pitch: CGFloat, showsLabels: Bool) {
        self.bands = bands
        self.columnsPerBand = columnsPerBand
        self.pitch = pitch
        self.showsLabels = showsLabels
    }

    private static func fit(weeks: Int, bands: Int, availableWidth: CGFloat) -> CustomPackMapMetrics {
        let columns = (weeks + bands - 1) / bands
        let bandHeightPerPitch = CGFloat(rows) - maxGap / (maxDot + maxGap)
        let byHeight = (boxHeight - CGFloat(bands - 1) * bandGap) / (CGFloat(bands) * bandHeightPerPitch)
        let cap = min(maxDot + maxGap, byHeight)
        let labelled = min(cap, (availableWidth - labelWidth - labelGap) / CGFloat(columns))
        if bands == 1, labelled >= labelMinPitch {
            return CustomPackMapMetrics(bands: bands, columnsPerBand: columns, pitch: labelled, showsLabels: true)
        }
        return CustomPackMapMetrics(
            bands: bands,
            columnsPerBand: columns,
            pitch: min(cap, availableWidth / CGFloat(columns)),
            showsLabels: false
        )
    }

    var dot: CGFloat { pitch * Self.maxDot / (Self.maxDot + Self.maxGap) }

    var bandHeight: CGFloat { pitch * CGFloat(Self.rows) - (pitch - dot) }

    var size: CGSize {
        CGSize(
            width: pitch * CGFloat(columnsPerBand) - (pitch - dot),
            height: bandHeight * CGFloat(bands) + Self.bandGap * CGFloat(bands - 1)
        )
    }

    func origin(ofDay index: Int) -> CGPoint {
        let week = index / Self.rows
        let band = week / columnsPerBand
        return CGPoint(
            x: CGFloat(week % columnsPerBand) * pitch,
            y: CGFloat(band) * (bandHeight + Self.bandGap) + CGFloat(index % Self.rows) * pitch
        )
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
