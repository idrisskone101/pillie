//
//  FadeInUp.swift
//  Pillie
//

import SwiftUI

struct FadeInUp: ViewModifier {
    let appeared: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : 12)
            .opacity(appeared ? 1 : 0)
            .animation(PillieTheme.fadeInUpCurve.delay(delay), value: appeared)
    }
}
