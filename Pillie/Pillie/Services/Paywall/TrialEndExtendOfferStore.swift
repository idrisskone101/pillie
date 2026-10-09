//
//  TrialEndExtendOfferStore.swift
//  Pillie
//

import Foundation
import Security

/// Persistence seam for `TrialEndExtendOfferPhase`. Callers move the phase
/// only through `record(_:)`, so the lifecycle rules live in the phase itself.
nonisolated protocol TrialEndExtendOfferStoring {
    func loadPhase() -> TrialEndExtendOfferPhase
    func savePhase(_ phase: TrialEndExtendOfferPhase)
    #if DEBUG
    func clear()
    #endif
}

extension TrialEndExtendOfferStoring {
    @discardableResult
    func record(_ event: TrialEndExtendOfferPhase.Event) -> TrialEndExtendOfferPhase {
        let current = loadPhase()
        let next = current.next(on: event)
        if next != current {
            savePhase(next)
        }
        return next
    }
}

/// Keychain-backed so a delete-and-reinstall cannot bring the one-time offer
/// back, mirroring `KeychainTrialGrantStore`: `ThisDeviceOnly` keeps it out of
/// iCloud Keychain sync, and `nonisolated` avoids the MainActor deinit that
/// the Xcode 27 beta hosted-XCTest runner crashes on.
nonisolated final class KeychainTrialEndExtendOfferStore: TrialEndExtendOfferStoring {
    private static let service = "com.idrisskone.pillie.trial-end-extend"
    private static let account = "trial_end_extend_offer_phase"

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
    }

    func loadPhase() -> TrialEndExtendOfferPhase {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return .unseen }
        return TrialEndExtendOfferPhase(stored: String(decoding: data, as: UTF8.self))
    }

    func savePhase(_ phase: TrialEndExtendOfferPhase) {
        let data = Data(phase.rawValue.utf8)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
    }

    #if DEBUG
    func clear() {
        SecItemDelete(query as CFDictionary)
    }
    #endif
}

nonisolated final class InMemoryTrialEndExtendOfferStore: TrialEndExtendOfferStoring {
    private var phase: TrialEndExtendOfferPhase = .unseen

    func loadPhase() -> TrialEndExtendOfferPhase { phase }
    func savePhase(_ phase: TrialEndExtendOfferPhase) { self.phase = phase }

    #if DEBUG
    func clear() { phase = .unseen }
    #endif
}
