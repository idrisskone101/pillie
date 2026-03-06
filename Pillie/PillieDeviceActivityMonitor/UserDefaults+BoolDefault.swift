//
//  UserDefaults+BoolDefault.swift
//  Shared extension — keep in sync with Pillie/Shared/ScreenTimeSharedState.swift
//

import Foundation

extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) == nil ? defaultValue : bool(forKey: key)
    }
}
