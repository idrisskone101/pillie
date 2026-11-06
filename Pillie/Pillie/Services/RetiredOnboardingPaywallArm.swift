//
//  RetiredOnboardingPaywallArm.swift
//  Pillie
//

import Foundation
import Security

/// The Keychain arm the ended ENG-204 onboarding paywall test left on each install.
/// `hard_trial` installs never got the Reverse Trial, so `ExistingUserTrialGrant`
/// grants it once. Delete this type once 2.2.1 installs are gone.
nonisolated struct RetiredOnboardingPaywallArm {
    private struct Stored: Decodable {
        struct Assignment: Decodable {
            let arm: String
        }

        struct Assigned: Decodable {
            let _0: Assignment
        }

        let assigned: Assigned?
    }

    private let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.idrisskone.pillie.experiments",
        kSecAttrAccount as String: "onboarding_paywall_arm_v1",
    ]

    var isHardTrial: Bool {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let stored = try? JSONDecoder().decode(Stored.self, from: data)
        else { return false }
        return stored.assigned?._0.arm == "hard_trial"
    }

    func clear() {
        SecItemDelete(query as CFDictionary)
    }
}
