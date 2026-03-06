//
//  PillieFontRegistration.swift
//  Pillie
//

import CoreText
import Foundation

enum PillieFontRegistration {
    private static var hasRegistered = false

    private static let fontFiles = [
        "Outfit-Black",
        "Outfit-Bold",
        "Outfit-ExtraBold",
        "Outfit-ExtraLight",
        "Outfit-Light",
        "Outfit-Medium",
        "Outfit-Regular",
        "Outfit-SemiBold",
        "Outfit-Thin",
        "ReenieBeanie-Regular"
    ]

    static func registerFontsIfNeeded() {
        guard !hasRegistered else { return }
        hasRegistered = true

        for file in fontFiles {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
