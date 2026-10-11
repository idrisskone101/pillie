//
//  OnboardingPaywallEnrollmentStore.swift
//  Pillie
//

import Foundation
import Security

nonisolated protocol OnboardingPaywallEnrollmentStoring {
    func load() -> OnboardingPaywallEnrollment?
    func save(_ enrollment: OnboardingPaywallEnrollment)
    func clear()
}

/// Keychain so the arm survives delete and reinstall, like `KeychainTrialGrantStore`.
/// `nonisolated`: Keychain Services is thread-safe, and a MainActor deinit crashes the
/// Xcode 27 beta hosted-XCTest runner.
nonisolated final class KeychainOnboardingPaywallEnrollmentStore: OnboardingPaywallEnrollmentStoring {
    private static let service = "com.idrisskone.pillie.experiments"
    private static let account = "onboarding_paywall_arm_v1"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
    }

    func load() -> OnboardingPaywallEnrollment? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(OnboardingPaywallEnrollment.self, from: data)
    }

    func save(_ enrollment: OnboardingPaywallEnrollment) {
        guard let data = try? JSONEncoder().encode(enrollment) else { return }
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

nonisolated final class InMemoryOnboardingPaywallEnrollmentStore: OnboardingPaywallEnrollmentStoring {
    private var enrollment: OnboardingPaywallEnrollment?

    func load() -> OnboardingPaywallEnrollment? { enrollment }
    func save(_ enrollment: OnboardingPaywallEnrollment) { self.enrollment = enrollment }
    func clear() { enrollment = nil }
}
