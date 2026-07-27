//
//  TrialDeclineFeedbackResolutionStore.swift
//  Pillie
//
//  One-time, device-bound decline-feedback resolution for issue #243.
//

import Foundation
import Security

nonisolated protocol TrialDeclineFeedbackResolutionStoring {
    func isResolved() -> Bool
    func markResolved()
}

nonisolated final class KeychainTrialDeclineFeedbackResolutionStore:
    TrialDeclineFeedbackResolutionStoring
{
    private static let service = "com.idrisskone.pillie.trial-decline-feedback"
    private static let account = "questionnaire_resolved"
    private static let resolvedData = Data("1".utf8)

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
    }

    func isResolved() -> Bool {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else {
            return false
        }
        return data == Self.resolvedData
    }

    func markResolved() {
        var attributes = baseQuery
        attributes[kSecValueData as String] = Self.resolvedData
        attributes[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemUpdate(
                baseQuery as CFDictionary,
                [kSecValueData as String: Self.resolvedData] as CFDictionary
            )
        }
    }

    /// Test and deterministic DEBUG-QA seam. Production flow never clears a
    /// resolved questionnaire.
    func clearResolution() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
