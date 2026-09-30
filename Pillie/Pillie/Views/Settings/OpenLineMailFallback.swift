//
//  OpenLineMailFallback.swift
//  Pillie
//

import SwiftUI

extension OpenURLAction {
    /// The Open Line's no-silent-no-op guarantee (#155): open the composer when
    /// the device can route the mailto, otherwise call `onFailure` so the caller
    /// shows the copy-address fallback, including when URL composition failed.
    func openLineMail(_ mailURL: URL?, onFailure: @escaping () -> Void) {
        guard let mailURL else {
            onFailure()
            return
        }
        callAsFunction(mailURL) { accepted in
            if !accepted {
                onFailure()
            }
        }
    }
}

extension View {
    /// The copy-address alert shown when Mail cannot open an Open Line mailto.
    func openLineMailFallbackAlert(isPresented: Binding<Bool>) -> some View {
        modifier(OpenLineMailFallbackAlert(isPresented: isPresented))
    }
}

private struct OpenLineMailFallbackAlert: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.alert(PillieLocalization.string(
            "support.mail_failed.title",
            locale: locale
        ), isPresented: $isPresented) {
            Button(OpenLine.MailFallback.addressToCopy) {
                UIPasteboard.general.string = OpenLine.MailFallback.addressToCopy
            }
            Button(PillieLocalization.string(
                "global.action.close",
                locale: locale
            ), role: .cancel) {}
        } message: {
            Text(PillieLocalization.formatted(
                "support.mail_failed.body",
                locale: locale,
                arguments: OpenLine.MailFallback.addressToCopy
            ))
        }
    }
}
