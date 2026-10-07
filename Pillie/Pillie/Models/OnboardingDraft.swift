//
//  OnboardingDraft.swift
//  Pillie
//

import Foundation
import os

protocol OnboardingDraftPick: Codable, Equatable {
    static var storageKey: String { get }
}

struct OnboardingDraft<Pick: OnboardingDraftPick>: Codable, Equatable {
    let pick: Pick
    let pickedAt: Date

    private static var logger: Logger {
        Logger(subsystem: "com.idrisskone.pillie", category: "OnboardingDraft")
    }

    /// A draft without `pickedAt` loads as nil, so the person taps today's pill again.
    static func load(from defaults: UserDefaults = .standard) -> OnboardingDraft? {
        guard let data = defaults.data(forKey: Pick.storageKey) else { return nil }
        do {
            return try JSONDecoder().decode(OnboardingDraft.self, from: data)
        } catch {
            Self.logger.error("onboarding_draft.load failed: \(error.localizedDescription, privacy: .public) key: \(Pick.storageKey, privacy: .public)")
            return nil
        }
    }

    func save(to defaults: UserDefaults = .standard) {
        do {
            defaults.set(try JSONEncoder().encode(self), forKey: Pick.storageKey)
        } catch {
            Self.logger.error("onboarding_draft.save failed: \(error.localizedDescription, privacy: .public) key: \(Pick.storageKey, privacy: .public)")
        }
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Pick.storageKey)
    }
}

extension OnboardingDraftPick {
    /// Saving the pick already on disk keeps when it was first made, so a step
    /// resumed on a later day still names the pill of the day it was picked.
    func save(to defaults: UserDefaults = .standard, at pickedAt: Date = PillieClock.now) {
        let firstPickedAt = OnboardingDraft<Self>.load(from: defaults).flatMap { $0.pick == self ? $0.pickedAt : nil }
        OnboardingDraft(pick: self, pickedAt: firstPickedAt ?? pickedAt).save(to: defaults)
    }

    static func load(from defaults: UserDefaults = .standard) -> Self? {
        OnboardingDraft<Self>.load(from: defaults)?.pick
    }

    static func clear(from defaults: UserDefaults = .standard) {
        OnboardingDraft<Self>.clear(from: defaults)
    }
}
