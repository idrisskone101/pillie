//
//  BlockingRehearsalPalette.swift
//  Pillie
//

import SwiftUI

/// Paper colours the rehearsal draws that `PillieTheme` has no token for.
enum BlockingRehearsalPalette {
    /// Paper's wallpaper circle on the mini Home Screen.
    static let wallpaperBlob = Color(hex: "FFDCD8")
    /// Paper's body grey inside cards, one step darker than `textMuted`.
    static let secondaryText = Color(hex: "57534E")
    /// The neutral and tinted buttons of the drawn system alert.
    static let alertNeutralButton = Color(hex: "E4E4E7")
    static let alertTintedButton = Color(hex: "2A9DF4")
    static let alertLabel = Color(hex: "18181B")
    /// The second sheet of a category tile's stack.
    static let tileStack = Color(hex: "E4E0EC")
}
