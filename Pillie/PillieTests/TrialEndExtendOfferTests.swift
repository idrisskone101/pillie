//
//  TrialEndExtendOfferTests.swift
//  PillieTests
//
//  The one-time Trial-End extend offer (ENG-172): decision gates, timeline
//  dates, free-days parsing from RevenueCat products, the one-way phase
//  store, the cross-offering package lookup, and the wire payload.
//
//  No stored ivars or setUp/tearDown: the Xcode 27 beta hosted-XCTest runner
//  crashes on @MainActor-adjacent deinit, so state stays in locals and class
//  doubles are kept alive for the process.
//

import RevenueCat
import XCTest

@testable import Pillie

final class TrialEndExtendOfferTests: XCTestCase {
    private static var keptObjects: [AnyObject] = []

    // MARK: - Decision

    func testEligibleTrialEndBoardWithProductOffersOnce() {
        let offer = decide()

        XCTAssertEqual(offer?.trigger, .restoreEmpty)
        XCTAssertEqual(offer?.product, weekProduct)
        XCTAssertEqual(offer?.timeline.start, date("2026-10-06T09:30:00-04:00"))
        XCTAssertEqual(offer?.timeline.charge, date("2026-10-13T09:30:00-04:00"))
        XCTAssertEqual(offer?.timeline.reminder, date("2026-10-11T20:00:00-04:00"))
    }

    func testEachGateWithholdsTheOffer() {
        XCTAssertNotNil(decide(), "baseline must offer")
        XCTAssertNil(decide(isTrialEndBoard: false), "not the trial-end board")
        XCTAssertNil(decide(phase: .shown), "already shown")
        XCTAssertNil(decide(phase: .accepted), "already accepted")
        XCTAssertNil(decide(phase: .declined), "already declined")
        XCTAssertNil(decide(eligibility: .ineligible), "intro offer used")
        XCTAssertNil(decide(eligibility: .unknown), "eligibility unknown")
        XCTAssertNil(decide(hasProduct: false), "SKU not served")
    }

    func testEligibilityMapsOnlyEligibleToEligible() {
        XCTAssertEqual(TrialEndExtendEligibility(.eligible), .eligible)
        XCTAssertEqual(TrialEndExtendEligibility(.ineligible), .ineligible)
        XCTAssertEqual(TrialEndExtendEligibility(.noIntroOfferExists), .ineligible)
        XCTAssertEqual(TrialEndExtendEligibility(.unknown), .unknown)
    }

    // MARK: - Timeline

    func testTimelineKeepsWallClockAcrossDSTEnd() throws {
        // US DST ends 2026-11-01 02:00, so the 7 calendar days are 7 days + 1 hour.
        let start = date("2026-10-29T10:00:00-04:00")
        let timeline = try XCTUnwrap(TrialEndExtendTimeline(start: start, freeDays: 7, calendar: newYork))

        XCTAssertEqual(timeline.charge, date("2026-11-05T10:00:00-05:00"))
        XCTAssertEqual(timeline.charge.timeIntervalSince(start), 608_400)
        XCTAssertEqual(timeline.reminder, date("2026-11-03T20:00:00-05:00"))
    }

    func testTimelineReminderAcrossDSTStart() throws {
        // US DST starts 2027-03-14 02:00; the reminder lands on the switch day.
        let start = date("2027-03-09T08:00:00-05:00")
        let timeline = try XCTUnwrap(TrialEndExtendTimeline(start: start, freeDays: 7, calendar: newYork))

        XCTAssertEqual(timeline.charge, date("2027-03-16T08:00:00-04:00"))
        XCTAssertEqual(timeline.reminder, date("2027-03-14T20:00:00-04:00"))
    }

    func testTimelineDropsReminderWhenTwoDaysOrShorter() throws {
        let start = date("2026-10-06T21:00:00-04:00")

        let twoDays = try XCTUnwrap(TrialEndExtendTimeline(start: start, freeDays: 2, calendar: newYork))
        XCTAssertNil(twoDays.reminder)
        XCTAssertEqual(twoDays.charge, date("2026-10-08T21:00:00-04:00"))

        let threeDays = try XCTUnwrap(TrialEndExtendTimeline(start: start, freeDays: 3, calendar: newYork))
        XCTAssertEqual(threeDays.reminder, date("2026-10-07T20:00:00-04:00"))
    }

    // MARK: - Product parsing

    func testFreeDaysFromIntroPeriod() {
        XCTAssertEqual(freeDays(.freeTrial, 1, .week), 7)
        XCTAssertEqual(freeDays(.freeTrial, 3, .day), 3)
        XCTAssertEqual(freeDays(.freeTrial, 2, .week), 14)
        XCTAssertNil(freeDays(.freeTrial, 1, .month))
        XCTAssertNil(freeDays(.freeTrial, 1, .year))
        XCTAssertNil(freeDays(.payUpFront, 1, .week))
        XCTAssertNil(freeDays(.payAsYouGo, 1, .week))
    }

    func testProductParsesFromStoreProductWithFreeWeek() {
        let product = TrialEndExtendProduct(storeProduct: storeProduct(
            id: SubscriptionManager.extendAnnualProductID,
            intro: introDiscount(.freeTrial, 1, .week)
        ))

        XCTAssertEqual(product, TrialEndExtendProduct(
            productID: "com.idrisskone.pillie.plus.annual.extend",
            priceDisplay: "$29.99",
            freeDays: 7
        ))
    }

    func testProductWithoutFreeTrialIntroIsNotOffered() {
        XCTAssertNil(TrialEndExtendProduct(storeProduct: storeProduct(
            id: SubscriptionManager.extendAnnualProductID,
            intro: nil
        )))
        XCTAssertNil(TrialEndExtendProduct(storeProduct: storeProduct(
            id: SubscriptionManager.extendAnnualProductID,
            intro: introDiscount(.payUpFront, 1, .week)
        )))
    }

    // MARK: - Package lookup

    func testExtendPackageIsFoundInAnyOfferingCurrentFirst() {
        let annual = package("annual", productID: SubscriptionManager.annualProductID, offering: "default")
        let extendInCurrent = package("extend_current", productID: SubscriptionManager.extendAnnualProductID, offering: "default")
        let extendElsewhere = package("extend_other", productID: SubscriptionManager.extendAnnualProductID, offering: "a_extend")
        let current = offering("default", [annual, extendInCurrent])
        let other = offering("a_extend", [extendElsewhere])

        XCTAssertEqual(
            PaywallPurchaseBridge.extendPackage(current: current, all: ["default": current, "a_extend": other])?.identifier,
            "extend_current"
        )

        let currentWithoutExtend = offering("default", [annual])
        XCTAssertEqual(
            PaywallPurchaseBridge.extendPackage(
                current: currentWithoutExtend,
                all: ["default": currentWithoutExtend, "a_extend": other]
            )?.identifier,
            "extend_other"
        )

        XCTAssertNil(PaywallPurchaseBridge.extendPackage(
            current: currentWithoutExtend,
            all: ["default": currentWithoutExtend]
        ))
        XCTAssertNil(PaywallPurchaseBridge.extendPackage(offerings: nil))
    }

    func testExtendPackageOrderIsDeterministicAcrossOtherOfferings() {
        let first = offering("b_first", [package("from_b", productID: SubscriptionManager.extendAnnualProductID, offering: "b_first")])
        let second = offering("c_second", [package("from_c", productID: SubscriptionManager.extendAnnualProductID, offering: "c_second")])

        XCTAssertEqual(
            PaywallPurchaseBridge.extendPackage(current: nil, all: ["c_second": second, "b_first": first])?.identifier,
            "from_b"
        )
    }

    // MARK: - Phase store

    func testPhaseMovesOneWayInMemory() {
        assertPhaseContract(InMemoryTrialEndExtendOfferStore(), "in-memory")
    }

    func testPhaseMovesOneWayInKeychain() {
        assertPhaseContract(KeychainTrialEndExtendOfferStore(), "keychain")
    }

    func testDeclinedPathEndsInDeclined() {
        let store = InMemoryTrialEndExtendOfferStore()

        XCTAssertEqual(store.record(.present), .shown)
        XCTAssertEqual(store.record(.decline), .declined)
        XCTAssertEqual(store.record(.accept), .declined)
        XCTAssertEqual(store.record(.present), .declined)
    }

    // MARK: - Telemetry

    func testExtendEventsCarrySourceAndTrialEndCohorts() {
        let (telemetry, client) = makeTelemetry(name: "extend")

        telemetry.trialEndExtendOfferShown(trigger: .sheetCancel, cohort: .blockerConfigured, terms: .hardPaywall)
        telemetry.trialEndExtendOfferAccepted(trigger: .sheetCancel, cohort: .blockerConfigured, terms: .hardPaywall)
        telemetry.trialEndExtendOfferDismissed(trigger: .restoreEmpty, cohort: .reminderOnly, terms: .legacy)

        XCTAssertEqual(client.events.map(\.name), [
            "trial_end_extend_offer_shown",
            "trial_end_extend_offer_accepted",
            "trial_end_extend_offer_dismissed",
        ])
        XCTAssertEqual(client.events[0].properties, [
            "source": .string("trial_end"),
            "surface": .string("trial_end"),
            "extend_source": .string("sheet_cancel"),
            "cohort": .string("blocker_configured"),
            "paywall_variant": .string("blocker_configured"),
            "trial_terms_cohort": .string("post_cutover"),
            "is_plus": .bool(false),
        ])
        XCTAssertEqual(client.events[1].properties["extend_source"], .string("sheet_cancel"))
        XCTAssertEqual(client.events[2].properties["extend_source"], .string("restore_empty"))
        XCTAssertEqual(client.events[2].properties["cohort"], .string("reminder_only"))
        XCTAssertEqual(client.events[2].properties["trial_terms_cohort"], .string("pre_cutover"))
    }

    // MARK: - Helpers

    private var newYork: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private var weekProduct: TrialEndExtendProduct {
        TrialEndExtendProduct(
            productID: "com.idrisskone.pillie.plus.annual.extend",
            priceDisplay: "$29.99",
            freeDays: 7
        )
    }

    private func decide(
        isTrialEndBoard: Bool = true,
        phase: TrialEndExtendOfferPhase = .unseen,
        eligibility: TrialEndExtendEligibility = .eligible,
        hasProduct: Bool = true
    ) -> TrialEndExtendOffer? {
        TrialEndExtendOfferDecision.offer(
            trigger: .restoreEmpty,
            isTrialEndBoard: isTrialEndBoard,
            phase: phase,
            eligibility: eligibility,
            product: hasProduct ? weekProduct : nil,
            now: date("2026-10-06T09:30:00-04:00"),
            calendar: newYork
        )
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func freeDays(
        _ mode: StoreProductDiscount.PaymentMode,
        _ value: Int,
        _ unit: SubscriptionPeriod.Unit
    ) -> Int? {
        TrialEndExtendProduct.freeDays(
            paymentMode: mode,
            period: SubscriptionPeriod(value: value, unit: unit),
            numberOfPeriods: 1
        )
    }

    private func introDiscount(
        _ mode: StoreProductDiscount.PaymentMode,
        _ value: Int,
        _ unit: SubscriptionPeriod.Unit
    ) -> TestStoreProductDiscount {
        TestStoreProductDiscount(
            identifier: "intro",
            price: 0,
            localizedPriceString: "$0.00",
            paymentMode: mode,
            subscriptionPeriod: SubscriptionPeriod(value: value, unit: unit),
            numberOfPeriods: 1,
            type: .introductory
        )
    }

    private func storeProduct(id: String, intro: TestStoreProductDiscount?) -> StoreProduct {
        TestStoreProduct(
            localizedTitle: "Pillie Plus",
            price: 29.99,
            currencyCode: "USD",
            localizedPriceString: "$29.99",
            productIdentifier: id,
            productType: .autoRenewableSubscription,
            localizedDescription: "Annual",
            subscriptionPeriod: SubscriptionPeriod(value: 1, unit: .year),
            introductoryDiscount: intro,
            locale: Locale(identifier: "en_US")
        ).toStoreProduct()
    }

    private func package(_ identifier: String, productID: String, offering: String) -> Package {
        let package = Package(
            identifier: identifier,
            packageType: .custom,
            storeProduct: storeProduct(id: productID, intro: introDiscount(.freeTrial, 1, .week)),
            offeringIdentifier: offering,
            webCheckoutUrl: nil
        )
        Self.keptObjects.append(package)
        return package
    }

    private func offering(_ identifier: String, _ packages: [Package]) -> Offering {
        let offering = Offering(
            identifier: identifier,
            serverDescription: identifier,
            availablePackages: packages,
            webCheckoutUrl: nil
        )
        Self.keptObjects.append(offering)
        return offering
    }

    private func assertPhaseContract(_ store: TrialEndExtendOfferStoring, _ name: String) {
        defer { store.clear() }
        store.clear()

        XCTAssertEqual(store.loadPhase(), .unseen, "\(name): empty store is unseen")
        XCTAssertEqual(store.record(.accept), .unseen, "\(name): cannot accept before shown")
        XCTAssertEqual(store.record(.present), .shown, "\(name)")
        XCTAssertEqual(store.record(.present), .shown, "\(name): presenting twice stays shown")
        XCTAssertEqual(store.record(.accept), .accepted, "\(name)")
        XCTAssertEqual(store.record(.decline), .accepted, "\(name): terminal")
        XCTAssertEqual(store.record(.present), .accepted, "\(name): never re-arms")
        XCTAssertEqual(store.loadPhase(), .accepted, "\(name): persisted")
    }

    private func makeTelemetry(name: String) -> (ProductAnalyticsTelemetry, ExtendAnalyticsClientSpy) {
        let client = ExtendAnalyticsClientSpy()
        let defaultsName = "TrialEndExtendOfferTests.\(name)"
        UserDefaults().removePersistentDomain(forName: defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName)!
        let analytics = AnalyticsManager(
            defaults: defaults,
            client: client,
            infoDictionary: [
                "PostHogProjectToken": "test-token",
                "PostHogHost": "https://us.i.posthog.com",
            ]
        )
        Self.keptObjects.append(defaults)
        Self.keptObjects.append(client)
        Self.keptObjects.append(analytics)
        analytics.configure()
        return (ProductAnalyticsTelemetry(analytics: analytics, isPlus: { false }), client)
    }
}

private final class ExtendAnalyticsClientSpy: ProductAnalyticsClient {
    struct Event: Equatable {
        let name: String
        let properties: [String: AnalyticsPropertyValue]
    }

    private(set) var events: [Event] = []

    func configure(_ configuration: ProductAnalyticsConfiguration) {}

    func capture(
        event: String,
        properties: [String: AnalyticsPropertyValue],
        personProperties: [String: AnalyticsPropertyValue]
    ) {
        events.append(Event(name: event, properties: properties))
    }

    func distinctId() -> String? { nil }

    func flush() {}
}
