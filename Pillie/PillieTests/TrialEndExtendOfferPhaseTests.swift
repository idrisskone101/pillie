//
//  TrialEndExtendOfferPhaseTests.swift
//  PillieTests
//
//  The extend card's one-way lifecycle (ENG-175): shown at most once per
//  device, and a value an older build stored never brings it back.
//

import Testing

@testable import Pillie

@MainActor
struct TrialEndExtendOfferPhaseTests {
    @Test(arguments: [
        (TrialEndExtendOfferPhase.unseen, TrialEndExtendOfferPhase.Event.present, TrialEndExtendOfferPhase.shown),
        (.unseen, .accept, .unseen),
        (.unseen, .decline, .unseen),
        (.shown, .present, .shown),
        (.shown, .accept, .accepted),
        (.shown, .decline, .declined),
        (.accepted, .present, .accepted),
        (.accepted, .decline, .accepted),
        (.declined, .present, .declined),
        (.declined, .accept, .declined),
    ])
    func `Each event moves the phase one way`(
        from: TrialEndExtendOfferPhase,
        event: TrialEndExtendOfferPhase.Event,
        to: TrialEndExtendOfferPhase
    ) {
        #expect(from.next(on: event) == to)
    }

    @Test func `Only an unseen card offers`() {
        let all: [TrialEndExtendOfferPhase] = [.unseen, .shown, .accepted, .declined]
        #expect(all.filter(\.offers) == [.unseen])
    }

    @Test func `A no is final in the store`() {
        let store = InMemoryTrialEndExtendOfferStore()

        #expect(store.record(.present) == .shown)
        #expect(store.record(.decline) == .declined)
        #expect(store.record(.present) == .declined)
        #expect(store.loadPhase().offers == false)
    }

    @Test(arguments: [
        (String?.none, TrialEndExtendOfferPhase.unseen),
        ("unseen", .unseen),
        ("shown", .shown),
        ("accepted", .accepted),
        ("declined", .declined),
        ("rearmed", .declined),
        ("reshown", .declined),
        ("closed", .declined),
        ("", .declined),
    ])
    func `A stored value this build does not know reads as declined`(
        stored: String?,
        phase: TrialEndExtendOfferPhase
    ) {
        #expect(TrialEndExtendOfferPhase(stored: stored) == phase)
    }
}
