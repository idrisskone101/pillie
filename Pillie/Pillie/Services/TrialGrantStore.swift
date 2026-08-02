//
//  TrialGrantStore.swift
//  Pillie
//

import Foundation
import Security

/// Persistence seam for the Reverse Trial grant timestamp and immutable terms
/// cohort (ADRs 0007/0008). `trialActive` is always re-derived through
/// `ReverseTrialClock` so the trial state cannot be edited independently; the
/// cohort may be recorded before grant so reinstalling mid-onboarding cannot
/// move an installation across the cutover.
nonisolated protocol TrialGrantStoring {
    func loadGrantDate() -> Date?
    func saveGrantDate(_ date: Date)
    func loadTermsCohort() -> TrialTermsCohort?
    func saveTermsCohort(_ cohort: TrialTermsCohort)
    func clearGrantDate()
}

/// Keychain-backed grant store — the app's first Keychain use, deliberately:
/// every other Pillie value lives in UserDefaults, which a delete-and-reinstall
/// wipes, and a reinstall must not restart the 14-day clock (ADR 0007 accepts
/// the remaining abuse leakage for v1). `ThisDeviceOnly` keeps the grant out of
/// iCloud Keychain sync so one user's trial does not follow them across devices.
/// `nonisolated`: Keychain Services is thread-safe, and the module's MainActor
/// default isolation would otherwise give this class an isolated deinit, which
/// the Xcode 27 beta hosted-XCTest runner crashes on.
nonisolated final class KeychainTrialGrantStore: TrialGrantStoring {
    private static let service = "com.idrisskone.pillie.reverse-trial"
    private static let account = "reverse_trial_grant_date"
    private static let cohortAccount = "reverse_trial_terms_cohort"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
    }

    private var cohortQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.cohortAccount,
        ]
    }

    func loadGrantDate() -> Date? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let interval = TimeInterval(string)
        else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    func saveGrantDate(_ date: Date) {
        let data = Data(String(date.timeIntervalSince1970).utf8)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
    }

    func loadTermsCohort() -> TrialTermsCohort? {
        var query = cohortQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let rawValue = String(data: data, encoding: .utf8)
        else { return nil }
        return TrialTermsCohort(rawValue: rawValue)
    }

    func saveTermsCohort(_ cohort: TrialTermsCohort) {
        let data = Data(cohort.rawValue.utf8)
        var attributes = cohortQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemUpdate(cohortQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
    }

    func clearGrantDate() {
        SecItemDelete(baseQuery as CFDictionary)
        SecItemDelete(cohortQuery as CFDictionary)
    }
}
