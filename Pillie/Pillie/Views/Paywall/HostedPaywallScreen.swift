import SwiftUI
import RevenueCat
import RevenueCatUI

struct HostedPaywallScreen: View {
    let offering: Offering
    let displayCloseButton: Bool
    let onPurchaseCompleted: (CustomerInfo) -> Void
    let onRestoreCompleted: (CustomerInfo) -> Void
    let onDismiss: () -> Void

    var body: some View {
        PaywallView(offering: offering, displayCloseButton: displayCloseButton)
            .onPurchaseCompleted { customerInfo in
                onPurchaseCompleted(customerInfo)
            }
            .onRestoreCompleted { customerInfo in
                onRestoreCompleted(customerInfo)
            }
            .onRequestedDismissal {
                onDismiss()
            }
            .accessibilityIdentifier("experimentPaywallEngine.hosted")
    }
}
