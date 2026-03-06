//
//  PillieTheme.swift
//  Pillie
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Design Tokens

enum PillieTheme {
    // Colors
    static let bg = Color(hex: "FDFCF8")
    static let textPrimary = Color(hex: "292524")
    static let textMuted = Color(hex: "78716C")
    static let coral = Color(hex: "FFB7B2")
    static let coralLight = Color(hex: "FFF0ED")
    static let coralFaded = Color(hex: "FFB7B2").opacity(0.2)
    static let amber = Color(hex: "E8A87C")
    static let amberFaded = Color(hex: "E8A87C").opacity(0.2)
    static let sage = Color(hex: "E8EFE8")
    static let sageHalf = Color(hex: "E8EFE8").opacity(0.5)
    static let lavender = Color(hex: "EFEDF4")
    static let patchChangeRose = Color(hex: "E07A8F")
    static let ringReinsertCoral = Color(hex: "D4826A")
    static let cardWhite = Color.white

    // Dark background (for CTA + pill pack)
    static let dark = Color(hex: "292524")

    // Corner Radii
    static let cardRadius: CGFloat = 28
    static let buttonRadius: CGFloat = 24

    // Shadows
    static let cardShadow = Color.black.opacity(0.05)
    static let cardShadowRadius: CGFloat = 15
    static let cardShadowY: CGFloat = 8

    // CTA Height
    static let ctaHeight: CGFloat = 64

    // Animation
    static let stagger1: Double = 0.05
    static let stagger2: Double = 0.10
    static let stagger3: Double = 0.15
    static let stagger4: Double = 0.20

    // Secondary button height
    static let secondaryButtonHeight: CGFloat = 56

    // Layout constants
    static let scrollBottomPaddingWithCTA: CGFloat = 180
    static let scrollBottomPaddingDefault: CGFloat = 100
    static let scrollTopPadding: CGFloat = 12
    static let screenHorizontalPadding: CGFloat = 20
    static let primaryTitleAccessoryHeight: CGFloat = 44
    static let primaryTitleAccessoryToTitleSpacing: CGFloat = 16

    // Custom fade-in-up curve matching design's cubic-bezier
    static let fadeInUpCurve: Animation = .timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.5)
}

// MARK: - Font Helpers

enum PillieFontWeight {
    case thin
    case extraLight
    case light
    case regular
    case medium
    case semibold
    case bold
    case extraBold
    case black

    fileprivate var outfitName: String {
        switch self {
        case .thin: return "Outfit-Thin"
        case .extraLight: return "Outfit-ExtraLight"
        case .light: return "Outfit-Light"
        case .regular: return "Outfit-Regular"
        case .medium: return "Outfit-Medium"
        case .semibold: return "Outfit-SemiBold"
        case .bold: return "Outfit-Bold"
        case .extraBold: return "Outfit-ExtraBold"
        case .black: return "Outfit-Black"
        }
    }

    fileprivate var fallbackWeight: Font.Weight {
        switch self {
        case .thin: return .thin
        case .extraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .extraBold: return .heavy
        case .black: return .black
        }
    }
}

extension Font {
    private static func pillieCustomFont(
        _ name: String,
        size: CGFloat,
        fallbackWeight: Font.Weight,
        fallbackDesign: Font.Design = .rounded
    ) -> Font {
        #if os(iOS)
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        #endif
        return .system(size: size, weight: fallbackWeight, design: fallbackDesign)
    }

    static func pillie(_ size: CGFloat, weight: PillieFontWeight = .regular) -> Font {
        pillieCustomFont(
            weight.outfitName,
            size: size,
            fallbackWeight: weight.fallbackWeight
        )
    }

    static func pillieHandwriting(size: CGFloat = 24) -> Font {
        pillieCustomFont(
            "ReenieBeanie",
            size: size,
            fallbackWeight: .regular,
            fallbackDesign: .serif
        )
    }

    static func pillieTitle() -> Font {
        .pillie(42, weight: .bold)
    }

    static func pillieHeadline() -> Font {
        .pillie(32, weight: .bold)
    }

    static func pillieBody() -> Font {
        .pillie(16, weight: .regular)
    }

    static func pillieBodyLarge() -> Font {
        .pillie(18, weight: .regular)
    }

    static func pillieCaption() -> Font {
        .pillie(10, weight: .bold)
    }

    static func pillieCaptionMedium() -> Font {
        .pillie(12, weight: .bold)
    }

    static func pillieDate() -> Font {
        .pillie(14, weight: .medium)
    }

    static func pillieHuge() -> Font {
        .pillie(40, weight: .bold)
    }

    static func pillieExtraBold(_ size: CGFloat) -> Font {
        .pillie(size, weight: .black)
    }

    static func pillieBodySemibold() -> Font {
        .pillie(16, weight: .semibold)
    }

    static func pillieBodyBold() -> Font {
        .pillie(18, weight: .bold)
    }

    static func pillieSubtitleBold() -> Font {
        .pillie(16, weight: .bold)
    }
}
