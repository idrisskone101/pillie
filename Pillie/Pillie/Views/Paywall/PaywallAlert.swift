//
//  PaywallAlert.swift
//  Pillie
//

import SwiftUI

/// The one alert a purchase or restore surface can show at a time (ENG-74).
enum PaywallAlert: Equatable {
    case purchaseError(String)
    /// Restore could not reach or finish with the App Store.
    case restoreError
    /// Restore finished, but this Apple ID has no active Plus purchase.
    case noSubscription
}

extension View {
    /// Presents `alert` with its recovery actions. Restore alerts offer Contact
    /// support, which covers purchases made on a different Apple ID.
    func paywallAlert(
        _ alert: Binding<PaywallAlert?>,
        surface: AnalyticsPaywallSurface,
        onRetryRestore: @escaping () -> Void
    ) -> some View {
        modifier(PaywallAlertModifier(
            alert: alert,
            surface: surface,
            onRetryRestore: onRetryRestore
        ))
    }
}

private struct PaywallAlertModifier: ViewModifier {
    @Binding var alert: PaywallAlert?
    let surface: AnalyticsPaywallSurface
    let onRetryRestore: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @State private var showsMailFallback = false

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: isPresented, presenting: alert) { alert in
                switch alert {
                case .purchaseError:
                    Button(globalString("global.action.ok")) {}
                case .restoreError:
                    Button(globalString("global.action.retry"), action: onRetryRestore)
                    contactSupportButton
                    Button(globalString("global.action.not_now"), role: .cancel) {}
                case .noSubscription:
                    contactSupportButton
                    Button(globalString("global.action.ok"), role: .cancel) {}
                }
            } message: { alert in
                Text(message(for: alert))
            }
            .openLineMailFallbackAlert(isPresented: $showsMailFallback)
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { alert != nil },
            set: { if !$0 { alert = nil } }
        )
    }

    private var contactSupportButton: some View {
        Button(commerceString("paywall.action.contact_support")) {
            ProductAnalyticsTelemetry.live.openLineRestoreIssueTapped(surface: surface)
            openURL.openLineMail(
                OpenLine.mailURL(for: .restoreIssue(.current()), locale: locale)
            ) {
                showsMailFallback = true
            }
        }
    }

    private var title: String {
        switch alert {
        case .purchaseError, nil:
            commerceString("paywall.purchase_error.title")
        case .restoreError:
            commerceString("paywall.restore_error.title")
        case .noSubscription:
            commerceString("paywall.no_subscription.title")
        }
    }

    private func message(for alert: PaywallAlert) -> String {
        switch alert {
        case .purchaseError(let message):
            message
        case .restoreError:
            CommercePresentation.restoreErrorMessage(locale: locale)
        case .noSubscription:
            commerceString("paywall.no_subscription.body")
        }
    }

    private func commerceString(_ key: String) -> String {
        PillieLocalization.string(key, table: "Commerce", locale: locale)
    }

    private func globalString(_ key: String) -> String {
        PillieLocalization.string(key, locale: locale)
    }
}
