//
//  LifetimePlanTests.swift
//  PillieTests
//
//  Shared lifetime purchase-plan behavior for issue #257.
//

import Testing

@testable import Pillie

struct LifetimePlanTests {
    @Test func `Lifetime plan resolves the App Store product`() {
        #expect(PilliePlusPlan.lifetime.productID == "com.idrisskone.pillie.plus.lifetime")
        #expect(PilliePlusPlan.lifetime.analyticsPlan == .lifetime)
    }
}
