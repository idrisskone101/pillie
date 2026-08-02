//
//  InMemoryTrialGrantStore.swift
//  PillieTests
//
//  In-memory TrialGrantStoring double for value-type tests (issue #160).
//  Kept honest by TrialGrantStoreTests, which runs the same contract against
//  the real Keychain store.
//

import Foundation

@testable import Pillie

nonisolated final class InMemoryTrialGrantStore: TrialGrantStoring {
    private(set) var grantDate: Date?
    private(set) var termsCohort: TrialTermsCohort?

    func loadGrantDate() -> Date? { grantDate }
    func saveGrantDate(_ date: Date) { grantDate = date }
    func loadTermsCohort() -> TrialTermsCohort? { termsCohort }
    func saveTermsCohort(_ cohort: TrialTermsCohort) { termsCohort = cohort }
    func clearGrantDate() {
        grantDate = nil
        termsCohort = nil
    }
}
