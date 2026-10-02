//
//  RestoreOutcome.swift
//  Pillie
//

import Foundation
import RevenueCat

/// What one Restore Purchases attempt found (ENG-74). `SubscriptionManager.restore()`
/// is the only producer; every restore surface consumes this value instead of
/// re-reading `hasEntitlement` or catching errors itself.
enum RestoreOutcome {
    /// RevenueCat confirmed an active `pillie_plus` entitlement.
    case restored
    /// The restore completed, but this Apple ID has no active Plus purchase.
    case noActivePurchase
    case failed(RestoreFailure)
}

struct RestoreFailure {
    let category: RestoreErrorCategory
    let error: Error

    init(error: Error) {
        self.category = RestoreErrorCategory(error: error)
        self.error = error
    }
}

enum RestoreErrorCategory: String, CaseIterable {
    case network
    case store
    case configuration
    case unknown

    init(error: Error) {
        if let purchaseError = error as? SubscriptionPurchaseError,
           purchaseError == .storefrontUnavailable {
            self = .configuration
            return
        }
        // RevenueCat hands out plain NSErrors in its own domain, and a thrown
        // `ErrorCode` bridges to the same domain and code through CustomNSError.
        let nsError = error as NSError
        if nsError.domain == ErrorCode.errorDomain, let code = ErrorCode(rawValue: nsError.code) {
            self = Self(revenueCatCode: code)
        } else if nsError.domain == NSURLErrorDomain {
            self = .network
        } else {
            self = .unknown
        }
    }

    private init(revenueCatCode code: ErrorCode) {
        switch code {
        case .networkError, .offlineConnectionError, .apiEndpointBlockedError, .productRequestTimedOut:
            self = .network
        case .storeProblemError, .purchaseNotAllowedError, .purchaseInvalidError,
             .invalidReceiptError, .missingReceiptFileError, .receiptAlreadyInUseError,
             .receiptInUseByOtherSubscriberError:
            self = .store
        case .configurationError, .invalidCredentialsError, .invalidAppleSubscriptionKeyError,
             .invalidAppUserIdError:
            self = .configuration
        default:
            self = .unknown
        }
    }
}
